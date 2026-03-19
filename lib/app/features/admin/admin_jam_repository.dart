import 'package:firebase_database/firebase_database.dart';
import 'package:soundimplosion/app/features/jam/jam_repository.dart';
import 'package:soundimplosion/services/database_service.dart';

abstract class AdminJamRepository {
  Stream<List<JamListItem>> watchPendingJams();
  Stream<List<JamListItem>> watchApprovedJams();
  Future<void> approveJam(String jamId);
  Future<void> rejectJam(String jamId);
  Future<void> deleteJam(String jamId);
  Future<void> proposeJamUpdate({
    required String jamId,
    required String date,
    required List<String> selectedSlotTimes,
    String? groupId,
    required String title,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String payment,
    required String equipment,
  });
}

class FirebaseAdminJamRepository implements AdminJamRepository {
  FirebaseAdminJamRepository({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;

  Map<String, dynamic>? _mapFromRawValue(dynamic rawValue) {
    if (rawValue is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(rawValue);
  }

  @override
  Stream<List<JamListItem>> watchPendingJams() {
    return _databaseService.getPendingJamsStream().map(_parseJamItems);
  }

  @override
  Stream<List<JamListItem>> watchApprovedJams() {
    return _databaseService.getPublishedJamsStream().map(_parseJamItems);
  }

  @override
  Future<void> approveJam(String jamId) {
    return _databaseService.approveJam(jamId);
  }

  @override
  Future<void> rejectJam(String jamId) {
    return _databaseService.rejectJam(jamId);
  }

  @override
  Future<void> deleteJam(String jamId) {
    return _databaseService.deleteJam(jamId);
  }

  @override
  Future<void> proposeJamUpdate({
    required String jamId,
    required String date,
    required List<String> selectedSlotTimes,
    String? groupId,
    required String title,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String payment,
    required String equipment,
  }) {
    return _databaseService.proposeJamUpdate(
      jamId: jamId,
      date: date,
      selectedSlotTimes: selectedSlotTimes,
      groupId: groupId,
      title: title,
      presentPeople: presentPeople,
      requiredPeople: requiredPeople,
      description: description,
      payment: payment,
      equipment: equipment,
    );
  }

  List<JamListItem> _parseJamItems(DatabaseEvent event) {
    final rawData = event.snapshot.value;
    final jams = <JamListItem>[];

    if (rawData is Map) {
      for (final entry in rawData.entries) {
        final jamData = _mapFromRawValue(entry.value);
        if (jamData == null) {
          continue;
        }
        jams.add(JamListItem.fromMap(entry.key.toString(), jamData));
      }
    } else if (rawData is List) {
      for (int index = 0; index < rawData.length; index++) {
        final item = rawData[index];
        if (item == null) {
          continue;
        }
        final jamData = _mapFromRawValue(item);
        if (jamData == null) {
          continue;
        }
        jams.add(JamListItem.fromMap(index.toString(), jamData));
      }
    }

    jams.sort(
      (a, b) => '${a.jam.data} ${a.jam.oraInizio}'.compareTo(
        '${b.jam.data} ${b.jam.oraInizio}',
      ),
    );
    return jams;
  }
}
