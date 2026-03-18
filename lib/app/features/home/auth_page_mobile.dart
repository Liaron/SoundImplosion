import 'package:flutter/material.dart';
import 'package:soundimplosion/app/startup_loading_screen.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/app_telemetry_service.dart';
import 'package:soundimplosion/services/database_service.dart';
import 'package:soundimplosion/services/firebase_auth.dart';

class AuthPageMobile extends StatefulWidget {
  const AuthPageMobile({super.key});

  @override
  State<AuthPageMobile> createState() => _AuthPageMobileState();
}

class _AuthPageMobileState extends State<AuthPageMobile> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _pendingMessage;
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _isLogin = true;

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
    } catch (e, stackTrace) {
      await AppTelemetryService.instance.recordError(
        e,
        stackTrace,
        reason: 'Google auth flow failed',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_formatAuthError(e))));
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
    if (_formKey.currentState!.validate()) {
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

          // 2. Se successo, crea il profilo utente sul DB con il nickname
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
            } catch (e) {
              await userCredential.user?.delete();
              rethrow;
            }
          }
        }
      } catch (e, stackTrace) {
        await AppTelemetryService.instance.recordError(
          e,
          stackTrace,
          reason: 'Email/password auth flow failed',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_formatAuthError(e))));
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _pendingMessage = null;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Image.asset(
                  startupLogoAsset,
                  width: 260,
                ),
                const SizedBox(height: 0),
                Text(
                  'Benvenuto in SoundImplosion',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Accedi al tuo account.'
                      : 'Crea un nuovo account.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 48),

                // CAMPO USERNAME (Visibile solo in registrazione)
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
                    if (!trimmedValue.contains('@') ||
                        !trimmedValue.contains('.')) {
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
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(_isLogin ? 'Accedi' : 'Registrati'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _submitWithGoogle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.login),
                        label: Text(
                          _isLogin
                              ? 'Continua con Google'
                              : 'Registrati con Google',
                        ),
                      ),
                    ],
                  ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      // Pulisci i campi quando cambi modalità per evitare confusione
                      if (_isLogin) {
                        _nicknameController.clear();
                        _confirmPasswordController.clear();
                      }
                    });
                  },
                  child: Text(
                    _isLogin
                        ? 'Non hai un account? Registrati'
                        : 'Hai già un account? Accedi',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
