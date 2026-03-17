import 'package:soundimplosion/app/features/jam/jam_repository.dart';
import 'package:soundimplosion/services/database_service.dart';

abstract class AdminJamRepository {
  Stream<List<JamListItem>> watchPendingJams();
  Future<void> approveJam(String jamId);
  Future<void> rejectJam(String jamId);
}

class FirebaseAdminJamRepository implements AdminJamRepository {
  FirebaseAdminJamRepository({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;

  @override
  Stream<List<JamListItem>> watchPendingJams() {
    return _databaseService.getPendingJamsStream().map((event) {
      final rawData = event.snapshot.value;
      final jams = <JamListItem>[];

      if (rawData is Map) {
        for (final entry in rawData.entries) {
          final jamData = Map<String, dynamic>.from(entry.value as Map);
          jams.add(JamListItem.fromMap(entry.key.toString(), jamData));
        }
      } else if (rawData is List) {
        for (int index = 0; index < rawData.length; index++) {
          final item = rawData[index];
          if (item == null) {
            continue;
          }
          final jamData = Map<String, dynamic>.from(item as Map);
          jams.add(JamListItem.fromMap(index.toString(), jamData));
        }
      }

      jams.sort((a, b) => '${a.jam.data} ${a.jam.oraInizio}'.compareTo('${b.jam.data} ${b.jam.oraInizio}'));
      return jams;
    });
  }

  @override
  Future<void> approveJam(String jamId) {
    return _databaseService.approveJam(jamId);
  }

  @override
  Future<void> rejectJam(String jamId) {
    return _databaseService.rejectJam(jamId);
  }
}