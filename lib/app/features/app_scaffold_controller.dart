import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soundimplosion/app/features/profile/profile_repository.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/app_preferences_service.dart';

class AppScaffoldController extends ChangeNotifier {
  AppScaffoldController({
    ProfileRepository? profileRepository,
    User? Function()? currentAuthUser,
    bool Function()? currentEmailVerified,
    Future<bool> Function()? refreshEmailVerification,
    Future<void> Function()? sendVerificationEmail,
  }) : _profileRepository = profileRepository ?? FirebaseProfileRepository(),
       _currentAuthUser =
           currentAuthUser ?? (() => FirebaseAuth.instance.currentUser),
       _currentEmailVerified =
           currentEmailVerified ??
           (() => FirebaseAuth.instance.currentUser?.emailVerified ?? false),
       _refreshEmailVerification =
           refreshEmailVerification ??
           (() async {
             final currentUser = FirebaseAuth.instance.currentUser;
             if (currentUser == null) {
               return false;
             }
             await currentUser.reload();
             return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
           }),
       _sendVerificationEmail =
           sendVerificationEmail ??
           (() async {
             final currentUser = FirebaseAuth.instance.currentUser;
             if (currentUser == null) {
               throw Exception('Utente non loggato');
             }
             await currentUser.sendEmailVerification();
           });

  final ProfileRepository _profileRepository;
  final User? Function() _currentAuthUser;
  final bool Function() _currentEmailVerified;
  final Future<bool> Function() _refreshEmailVerification;
  final Future<void> Function() _sendVerificationEmail;

  bool isLoadingProfile = true;
  bool isEmailVerified = false;
  AppUser? user;

  bool get isAdmin => user?.isAdmin ?? false;

  Future<void> initialize() async {
    isLoadingProfile = true;
    notifyListeners();

    try {
      final currentUser = _currentAuthUser();
      isEmailVerified = _currentEmailVerified();
      final loadedUser = await _profileRepository
          .loadProfile()
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => _buildFallbackUser(currentUser),
          );
      if (loadedUser == null) {
        user = _buildFallbackUser(currentUser);
      } else {
        user = loadedUser;
        AppPreferencesService.instance.applyUserPreferences(
          loadedUser.preferenze,
        );
      }
    } catch (_) {
      user = _buildFallbackUser(_currentAuthUser());
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> refreshEmailVerification() async {
    isLoadingProfile = true;
    notifyListeners();

    try {
      isEmailVerified = await _refreshEmailVerification();
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> sendVerificationEmail() {
    return _sendVerificationEmail();
  }

  AppUser? _buildFallbackUser(User? firebaseUser) {
    if (firebaseUser == null) {
      return null;
    }

    final nickname = firebaseUser.displayName?.trim().isNotEmpty == true
        ? firebaseUser.displayName!
        : firebaseUser.uid;

    return AppUser(
      uid: firebaseUser.uid,
      nickname: nickname,
      email: firebaseUser.email,
      profileImageUrl: firebaseUser.photoURL,
    );
  }
}
