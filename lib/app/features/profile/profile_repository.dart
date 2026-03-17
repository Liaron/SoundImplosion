import 'package:firebase_auth/firebase_auth.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/database_service.dart';

abstract class ProfileRepository {
  Future<AppUser?> loadProfile();
  Future<void> saveProfile(AppUser user);
}

class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({
    DatabaseService? databaseService,
    FirebaseAuth? auth,
  })  : _databaseService = databaseService ?? DatabaseService(),
        _auth = auth ?? FirebaseAuth.instance;

  final DatabaseService _databaseService;
  final FirebaseAuth _auth;

  @override
  Future<AppUser?> loadProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return null;
    }

    final snapshot = await _databaseService.readData('users/${currentUser.uid}');
    if (snapshot.exists && snapshot.value != null) {
      final userData = Map<dynamic, dynamic>.from(snapshot.value as Map);
      return AppUser.fromMap(currentUser.uid, userData);
    }

    return AppUser(
      uid: currentUser.uid,
      nickname: currentUser.displayName ?? 'Utente',
    );
  }

  @override
  Future<void> saveProfile(AppUser user) {
    return _databaseService.saveUser(user);
  }
}