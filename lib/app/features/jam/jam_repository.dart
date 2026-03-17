import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/database_service.dart';

class JamListItem {
  const JamListItem({
    required this.id,
    required this.jam,
    this.participantIds = const <String>{},
  });

  final String id;
  final Jam jam;
  final Set<String> participantIds;

  String get dateLabel => jam.data.isEmpty ? 'N/A' : jam.data;
  String get timeRangeLabel => '${jam.oraInizio} - ${jam.oraFine}';
  String get paymentLabel => jam.pagamento.isEmpty ? 'Diviso' : jam.pagamento;
  bool get isPublished => jam.stato == JamStatus.pubblicata;

  String get statusLabel {
    switch (jam.stato) {
      case JamStatus.inElaborazione:
        return 'In approvazione';
      case JamStatus.pubblicata:
        return 'Pubblicata';
      case JamStatus.annullata:
        return 'Annullata';
      case JamStatus.sospesa:
        return 'Sospesa';
    }
  }

  bool isOwnedBy(String? userId) {
    return userId != null && jam.creatorId == userId;
  }

  bool isJoinedBy(String? userId) {
    return userId != null && participantIds.contains(userId);
  }

  bool get hasOpenSpots => jam.personeRichieste > 0;

  Map<String, dynamic> toMap() {
    return {
      ...jam.toMap(),
      'key': id,
      'status': jam.stato.name,
      'participants': {
        for (final participantId in participantIds) participantId: true,
      },
    };
  }

  factory JamListItem.fromMap(String id, Map<String, dynamic> map) {
    return JamListItem(
      id: id,
      jam: Jam.fromMap(id, map),
      participantIds: _extractParticipantIds(map['participants']),
    );
  }

  static Set<String> _extractParticipantIds(dynamic rawValue) {
    if (rawValue is Map) {
      return rawValue.keys.map((key) => key.toString()).toSet();
    }
    if (rawValue is List) {
      return rawValue
          .where((item) => item != null)
          .map((item) => item.toString())
          .toSet();
    }
    return <String>{};
  }
}

abstract class JamRepository {
  Future<List<DateTime>> loadAvailableDates();
  Future<List<String>> loadAvailableSlots(DateTime date);
  Future<List<Map<String, String>>> loadUserGroups();
  Future<JamListItem?> loadJamById(String jamId);
  Future<void> joinJam(String jamId);
  Future<void> leaveJam(String jamId);
  Future<void> updateJam({
    required String jamId,
    required DateTime selectedDate,
    required List<String> selectedSlots,
    String? groupId,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String payment,
    required String equipment,
  });
  Future<void> submitJam({
    required DateTime selectedDate,
    required List<String> selectedSlots,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String payment,
    required String equipment,
    String? selectedGroupId,
  });
  Stream<List<JamListItem>> watchJams();
  Future<List<JamListItem>> loadPublishedJamsOnce();
  Future<void> deleteJam(String jamId);
  bool areSlotsContiguous(List<String> slots);
  String calculateEndTime(String startSlot);
}

class FirebaseJamRepository implements JamRepository {
  FirebaseJamRepository({DatabaseService? databaseService, FirebaseAuth? auth})
    : _databaseService = databaseService ?? DatabaseService(),
      _auth = auth ?? FirebaseAuth.instance;

  final DatabaseService _databaseService;
  final FirebaseAuth _auth;

  static const int _slotDurationMinutes = 75;

  Map<String, dynamic>? _mapFromRawValue(dynamic rawValue) {
    if (rawValue is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(rawValue);
  }

  @override
  Future<List<DateTime>> loadAvailableDates() async {
    await _databaseService.cleanupPastSlots();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final candidateDates = List.generate(
      30,
      (index) => now.add(Duration(days: index)),
    );

    final results = await Future.wait(
      candidateDates.map((date) async {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final freeSlots = await _databaseService.getFreeSlotsForDate(dateStr);
        final hasBookableSlot = freeSlots.any(
          (slot) => _isSlotAtLeast24HoursAway(slot, date),
        );
        return hasBookableSlot
            ? DateTime(date.year, date.month, date.day)
            : null;
      }),
    );

    return results
        .whereType<DateTime>()
        .where(
          (date) => !DateTime(date.year, date.month, date.day).isBefore(today),
        )
        .toList();
  }

  @override
  Future<List<String>> loadAvailableSlots(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final freeSlots = await _databaseService.getFreeSlotsForDate(dateStr);
    return freeSlots
        .where((slot) => _isSlotAtLeast24HoursAway(slot, date))
        .toList();
  }

  @override
  Future<List<Map<String, String>>> loadUserGroups() {
    return _databaseService.getUserGroups();
  }

  @override
  Future<JamListItem?> loadJamById(String jamId) async {
    final jam = await _databaseService.getJamById(jamId);
    if (jam == null) {
      return null;
    }

    return JamListItem.fromMap(jamId, jam);
  }

  @override
  Future<void> joinJam(String jamId) {
    return _databaseService.joinJam(jamId);
  }

  @override
  Future<void> leaveJam(String jamId) {
    return _databaseService.leaveJam(jamId);
  }

  @override
  Future<void> updateJam({
    required String jamId,
    required DateTime selectedDate,
    required List<String> selectedSlots,
    String? groupId,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String payment,
    required String equipment,
  }) {
    return _databaseService.updateJam(
      jamId: jamId,
      date: DateFormat('yyyy-MM-dd').format(selectedDate),
      selectedSlotTimes: selectedSlots,
      groupId: groupId,
      presentPeople: presentPeople,
      requiredPeople: requiredPeople,
      description: description,
      payment: payment,
      equipment: equipment,
    );
  }

  @override
  Future<void> submitJam({
    required DateTime selectedDate,
    required List<String> selectedSlots,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String payment,
    required String equipment,
    String? selectedGroupId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final orderedSlots = List<String>.from(selectedSlots)..sort();
    if (orderedSlots.isEmpty) {
      throw Exception('Seleziona almeno un orario');
    }
    if (!areSlotsContiguous(orderedSlots)) {
      throw Exception('Gli orari selezionati devono essere consecutivi.');
    }

    final jam = Jam(
      creatorId: user.uid,
      groupId: selectedGroupId,
      data: DateFormat('yyyy-MM-dd').format(selectedDate),
      oraInizio: orderedSlots.first,
      oraFine: calculateEndTime(orderedSlots.last),
      personePresenti: presentPeople,
      personeRichieste: requiredPeople,
      descrizione: description.trim(),
      pagamento: payment,
      attrezzatura: equipment.trim(),
      creatorNickname: user.displayName,
      stato: JamStatus.inElaborazione,
    );

    await _databaseService.createJam(jam, orderedSlots);
  }

  @override
  Stream<List<JamListItem>> watchJams() {
    final controller = StreamController<List<JamListItem>>();
    List<JamListItem> publishedJams = const [];
    List<JamListItem> ownJams = const [];

    void emitMerged() {
      final merged =
          <String, JamListItem>{
            for (final jam in publishedJams) jam.id: jam,
            for (final jam in ownJams) jam.id: jam,
          }.values.toList()..sort(
            (a, b) => '${b.jam.data} ${b.jam.oraInizio}'.compareTo(
              '${a.jam.data} ${a.jam.oraInizio}',
            ),
          );
      controller.add(merged);
    }

    final publishedSubscription = _databaseService
        .getPublishedJamsStream()
        .listen((event) {
          publishedJams = _parseJamCollection(event.snapshot.value);
          emitMerged();
        }, onError: controller.addError);

    final ownSubscription = _databaseService.getOwnJamsStream().listen((event) {
      ownJams = _parseJamCollection(event.snapshot.value);
      emitMerged();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await publishedSubscription.cancel();
      await ownSubscription.cancel();
    };

    return controller.stream;
  }

  @override
  Future<List<JamListItem>> loadPublishedJamsOnce() async {
    final jams = await _databaseService.getPublishedJamsOnce();
    return jams
        .map((jam) => JamListItem.fromMap(jam['key'].toString(), jam))
        .toList();
  }

  @override
  Future<void> deleteJam(String jamId) {
    return _databaseService.deleteJam(jamId);
  }

  @override
  bool areSlotsContiguous(List<String> slots) {
    if (slots.length <= 1) {
      return true;
    }

    for (int index = 0; index < slots.length - 1; index++) {
      final current = _timeToMinutes(slots[index]);
      final next = _timeToMinutes(slots[index + 1]);
      if (next - current != _slotDurationMinutes) {
        return false;
      }
    }

    return true;
  }

  @override
  String calculateEndTime(String startSlot) {
    final totalMinutes = _timeToMinutes(startSlot) + _slotDurationMinutes;
    final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<JamListItem> _parseJamCollection(dynamic rawData) {
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
      (a, b) => '${b.jam.data} ${b.jam.oraInizio}'.compareTo(
        '${a.jam.data} ${a.jam.oraInizio}',
      ),
    );
    return jams;
  }

  bool _isSlotAtLeast24HoursAway(String slot, DateTime date) {
    final parts = slot.split(':');
    final slotDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    final minAllowedStart = DateTime.now().add(const Duration(hours: 24));
    return slotDateTime.isAfter(minAllowedStart);
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
