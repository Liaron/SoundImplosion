import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:soundimplosion/services/push_notification_service.dart';
export 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInitialization;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;
  bool get isEmailVerified => _firebaseAuth.currentUser?.emailVerified ?? false;
  bool get isPasswordProviderLinked =>
      _firebaseAuth.currentUser?.providerData.any(
        (provider) => provider.providerId == 'password',
      ) ??
      false;
  bool get isGoogleProviderLinked =>
      _firebaseAuth.currentUser?.providerData.any(
        (provider) => provider.providerId == 'google.com',
      ) ??
      false;

  Future<void> _ensureGoogleInitialized() {
    return _googleInitialization ??= _googleSignIn.initialize();
  }

  // Registrazione con email + password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Login con email + password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _firebaseAuth.signInWithCredential(credential);
  }

  // Logout da Firebase e Google (se applicabile)
  Future<void> signOut() async {
    try {
      await PushNotificationService.instance.unregisterCurrentDeviceToken();
    } catch (_) {
      // Ignore token cleanup failures during logout.
    }

    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore Google session cleanup failures during logout.
    }
    await _firebaseAuth.signOut();
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    await user.sendEmailVerification();
  }

  Future<void> requestEmailChange(String newEmail) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    await _reauthenticateIfNeeded();
    await user.verifyBeforeUpdateEmail(newEmail.trim());
  }

  Future<void> requestEmailChangeWithReauthentication({
    required String newEmail,
    String? currentPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    await _reauthenticateIfNeeded(currentPassword: currentPassword);
    await user.verifyBeforeUpdateEmail(newEmail.trim());
  }

  Future<void> updatePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    await _reauthenticateIfNeeded(currentPassword: currentPassword);
    await user.updatePassword(newPassword.trim());
  }

  Future<bool> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return false;
    }

    await user.reload();
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    await user.delete();
  }

  Future<void> _reauthenticateIfNeeded({String? currentPassword}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    if (isPasswordProviderLinked) {
      final email = user.email?.trim() ?? '';
      final password = currentPassword?.trim() ?? '';
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Inserisci la password attuale per confermare');
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    if (isGoogleProviderLinked) {
      await _ensureGoogleInitialized();
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    throw Exception(
      "Provider di accesso non supportato per la riconferma dell'identita",
    );
  }
}
