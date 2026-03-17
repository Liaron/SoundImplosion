import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/profile/profile_repository.dart';
import 'package:soundimplosion/models/models.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({ProfileRepository? repository})
    : _repository = repository ?? FirebaseProfileRepository();

  final ProfileRepository _repository;

  AppUser? user;
  bool isLoading = true;
  String? errorMessage;

  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      user = await _repository.loadProfile();
      if (user == null) {
        errorMessage = 'Errore caricamento profilo';
      }
    } catch (e) {
      errorMessage = 'Errore caricamento profilo';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateNickname(String nickname) async {
    final currentUser = user;
    final trimmedNickname = nickname.trim();
    if (currentUser == null || trimmedNickname.isEmpty) {
      return;
    }

    final updatedUser = currentUser.copyWith(nickname: trimmedNickname);
    await _repository.saveProfile(updatedUser);
    user = updatedUser;
    notifyListeners();
  }

  Future<void> addInstrument({required String name, required int level}) async {
    final currentUser = user;
    final trimmedName = name.trim();
    if (currentUser == null || trimmedName.isEmpty) {
      return;
    }

    final updatedInstruments = List<Map<String, dynamic>>.from(
      currentUser.strumentiList,
    )..add({'nome': trimmedName, 'livello': level});

    final updatedUser = currentUser.copyWith(strumentiList: updatedInstruments);
    await _repository.saveProfile(updatedUser);
    user = updatedUser;
    notifyListeners();
  }

  Future<void> removeInstrument(int index) async {
    final currentUser = user;
    if (currentUser == null ||
        index < 0 ||
        index >= currentUser.strumentiList.length) {
      return;
    }

    final updatedInstruments = List<Map<String, dynamic>>.from(
      currentUser.strumentiList,
    )..removeAt(index);

    final updatedUser = currentUser.copyWith(strumentiList: updatedInstruments);
    await _repository.saveProfile(updatedUser);
    user = updatedUser;
    notifyListeners();
  }

  Future<void> deleteProfile() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteProfile();
      user = null;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
