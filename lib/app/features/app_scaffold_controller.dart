import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/profile/profile_repository.dart';
import 'package:soundimplosion/models/models.dart';

class AppScaffoldController extends ChangeNotifier {
  AppScaffoldController({ProfileRepository? profileRepository})
      : _profileRepository = profileRepository ?? FirebaseProfileRepository();

  final ProfileRepository _profileRepository;

  bool isLoadingProfile = true;
  bool isProfileConfigured = false;
  AppUser? user;

  bool get isAdmin => user?.isAdmin ?? false;

  Future<void> initialize() async {
    isLoadingProfile = true;
    notifyListeners();

    try {
      var loadedUser = await _profileRepository.loadProfile();
      if (loadedUser == null) {
        isProfileConfigured = false;
        isLoadingProfile = false;
        notifyListeners();
        return;
      }

      if (loadedUser.nickname == loadedUser.uid) {
        user = loadedUser;
        isProfileConfigured = false;
      } else {
        user = loadedUser;
        isProfileConfigured = true;
      }
    } catch (_) {
      isProfileConfigured = false;
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> saveInitialProfile(String nickname) async {
    final currentUser = user;
    final trimmedNickname = nickname.trim();
    if (currentUser == null || trimmedNickname.isEmpty) {
      return;
    }

    isLoadingProfile = true;
    notifyListeners();

    try {
      final updatedUser = currentUser.copyWith(nickname: trimmedNickname);
      await _profileRepository.saveProfile(updatedUser);
      user = updatedUser;
      isProfileConfigured = true;
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }
}