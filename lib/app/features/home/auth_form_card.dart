import 'package:flutter/material.dart';
import 'package:soundimplosion/app/startup_loading_screen.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/app_telemetry_service.dart';
import 'package:soundimplosion/services/database_service.dart';
import 'package:soundimplosion/services/firebase_auth.dart';

class AuthFormCard extends StatefulWidget {
  const AuthFormCard({
    super.key,
    this.maxWidth = 460,
    this.showSurface = true,
    this.showLogo = true,
    this.onAuthenticated,
  });

  final double maxWidth;
  final bool showSurface;
  final bool showLogo;
  final VoidCallback? onAuthenticated;

  @override
  State<AuthFormCard> createState() => _AuthFormCardState();
}

class _AuthFormCardState extends State<AuthFormCard> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;
  String? _pendingMessage;

  void _handleAuthenticationSuccess() {
    widget.onAuthenticated?.call();
  }

  String _formatAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'Questa email e gia registrata';
        case 'account-exists-with-different-credential':
          return 'Esiste gia un account con questa email e un metodo di accesso diverso';
        case 'invalid-email':
          return 'Inserisci un indirizzo email valido';
        case 'weak-password':
          return 'La password e troppo debole';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Credenziali non valide';
      }
    }

    return error.toString().replaceAll('Exception: ', '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submitWithGoogle() async {
    setState(() {
      _isLoading = true;
      _pendingMessage = 'Accesso con Google in corso...';
    });

    try {
      final userCredential = await _authService.signInWithGoogle();
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Utente Google non disponibile');
      }

      final snapshot = await _dbService.readData('users/${firebaseUser.uid}');
      if (!snapshot.exists || snapshot.value == null) {
        final generatedUsername = await _dbService.generateAvailableUsername(
          preferredName: firebaseUser.displayName,
          email: firebaseUser.email,
          excludingUid: firebaseUser.uid,
        );
        final newUser = AppUser(
          uid: firebaseUser.uid,
          nickname: generatedUsername,
          email: firebaseUser.email,
          profileImageUrl: firebaseUser.photoURL,
        );
        await _dbService.saveUser(newUser);
      }

      final isNewUser = userCredential.additionalUserInfo?.isNewUser == true;
      if (isNewUser) {
        await AppTelemetryService.instance.logSignUp(method: 'google');
      } else {
        await AppTelemetryService.instance.logLogin(method: 'google');
      }

      _handleAuthenticationSuccess();
    } catch (error, stackTrace) {
      await AppTelemetryService.instance.recordError(
        error,
        stackTrace,
        reason: 'Google auth flow failed',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_formatAuthError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _pendingMessage = null;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _pendingMessage = _isLogin
          ? null
          : 'Verifica email e username in corso...';
    });

    try {
      if (_isLogin) {
        await _authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await AppTelemetryService.instance.logLogin(method: 'password');
        _handleAuthenticationSuccess();
      } else {
        final email = _emailController.text.trim();
        final username = _nicknameController.text.trim();
        final password = _passwordController.text.trim();

        final availability = await _dbService.checkRegistrationAvailability(
          nickname: username,
          email: email,
        );
        if (!availability.isAvailable) {
          throw Exception(availability.errorMessage);
        }

        if (mounted) {
          setState(() {
            _pendingMessage = 'Conferma registrazione in corso...';
          });
        }

        final userCredential = await _authService
            .createUserWithEmailAndPassword(email: email, password: password);

        if (userCredential.user != null) {
          final uid = userCredential.user!.uid;
          await userCredential.user!.updateDisplayName(username);
          await userCredential.user!.reload();

          final newUser = AppUser(uid: uid, nickname: username, email: email);

          try {
            await _dbService.saveUser(newUser);
            try {
              await _authService.sendEmailVerification();
            } catch (_) {}
            await AppTelemetryService.instance.logSignUp(method: 'password');
            _handleAuthenticationSuccess();
          } catch (error) {
            await userCredential.user?.delete();
            rethrow;
          }
        }
      }
    } catch (error, stackTrace) {
      await AppTelemetryService.instance.recordError(
        error,
        stackTrace,
        reason: 'Email/password auth flow failed',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_formatAuthError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _pendingMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final content = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.showLogo) ...[
            Image.asset(startupLogoAsset, width: 220, height: 92),
            const SizedBox(height: 12),
          ],
          Text(
            'Benvenuto in SoundImplosion',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isLogin ? 'Accedi al tuo account.' : 'Crea un nuovo account.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 32),
          if (!_isLogin) ...[
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci uno username';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Inserisci la tua email';
              }
              final trimmedValue = value.trim();
              if (!trimmedValue.contains('@') || !trimmedValue.contains('.')) {
                return 'Inserisci una email valida';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Inserisci la tua password';
              }
              if (!_isLogin && value.length < 6) {
                return 'La password deve essere di almeno 6 caratteri';
              }
              return null;
            },
          ),
          if (!_isLogin) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Conferma password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (value) {
                if (_isLogin) {
                  return null;
                }
                if (value == null || value.isEmpty) {
                  return 'Conferma la password';
                }
                if (value != _passwordController.text) {
                  return 'Le password non coincidono';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 24),
          if (_isLoading)
            Column(
              children: [
                const Center(child: CircularProgressIndicator()),
                if ((_pendingMessage ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _pendingMessage!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_isLogin ? 'Accedi' : 'Registrati'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _submitWithGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.login),
                  label: Text(
                    _isLogin ? 'Continua con Google' : 'Registrati con Google',
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _isLogin = !_isLogin;
                if (_isLogin) {
                  _nicknameController.clear();
                  _confirmPasswordController.clear();
                }
              });
            },
            child: Text(
              _isLogin
                  ? 'Non hai un account? Registrati'
                  : 'Hai gia un account? Accedi',
            ),
          ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: widget.showSurface
          ? Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: content,
            )
          : content,
    );
  }
}
