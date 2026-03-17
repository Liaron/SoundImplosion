import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soundimplosion/app/features/profile/profile_repository.dart';
import 'package:soundimplosion/models/models.dart';

class AppScaffoldController extends ChangeNotifier {
  AppScaffoldController({
    ProfileRepository? profileRepository,
    bool Function()? currentEmailVerified,
    Future<bool> Function()? refreshEmailVerification,
    Future<void> Function()? sendVerificationEmail,
  }) : _profileRepository = profileRepository ?? FirebaseProfileRepository(),
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
      isEmailVerified = _currentEmailVerified();
      var loadedUser = await _profileRepository.loadProfile();
      if (loadedUser == null) {
        user = null;
        isLoadingProfile = false;
        notifyListeners();
        return;
      }

      user = loadedUser;
    } catch (_) {
      user = null;
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
}
