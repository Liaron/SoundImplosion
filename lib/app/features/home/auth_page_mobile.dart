import 'package:flutter/material.dart';
import 'package:soundimplosion/models/models.dart';
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
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController(); // Controller per il nickname
  
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        if (_isLogin) {
          await _authService.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
        } else {
          // REGISTRAZIONE
          // 1. Crea utente su Firebase Auth
          final userCredential = await _authService.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          
          // 2. Se successo, crea il profilo utente sul DB con il nickname
          if (userCredential.user != null) {
            final uid = userCredential.user!.uid;
            final nickname = _nicknameController.text.trim();
            
            final newUser = AppUser(
              uid: uid,
              nickname: nickname,
            );
            
            await _dbService.saveUser(newUser);
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
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
                    'lib/common/images/soundimplosion_logo_no_sfondo.png'),
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
                
                // CAMPO NICKNAME (Visibile solo in registrazione)
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: 'Nickname',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci un nickname';
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
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_isLogin ? 'Accedi' : 'Registrati'),
                  ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      // Pulisci i campi quando cambi modalità per evitare confusione
                      if (_isLogin) {
                        _nicknameController.clear();
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
