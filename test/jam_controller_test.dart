import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/jam/find_jam_controller.dart';
import 'package:soundimplosion/app/features/jam/jam_repository.dart';
import 'package:soundimplosion/app/features/jam/organize_jam_controller.dart';
import 'package:soundimplosion/models/models.dart';

void main() {
  test('OrganizeJamController validates and delegates submit', () async {
    final repository = FakeJamRepository(
      availableDates: [DateTime(2026, 3, 20)],
      availableSlotsByDate: {
        '2026-03-20': ['10:00', '10:30', '11:30'],
      },
      userGroups: const [
        {'id': 'group-1', 'name': 'Group 1'},
      ],
    );
    final controller = OrganizeJamController(repository: repository);

    await controller.initialize();
    await controller.selectDate(DateTime(2026, 3, 20));
    controller.toggleSlot('10:00');
    controller.toggleSlot('11:30');
    controller.setSelectedPayment('Offerto');

    expect(
      controller.validateSelection(),
      'Per selezionare slot separati e necessario effettuare due richieste distinte.',
    );

    controller.toggleSlot('11:30');
    controller.toggleSlot('10:30');

    expect(controller.validateSelection(), isNull);
    expect(controller.selectedRangeLabel, '10:00 - 11:00');

    await controller.submitJam(
      title: 'Jam blues night',
      presentPeople: 2,
      requiredPeople: 3,
      description: 'Jam blues',
      equipment: 'Batteria',
    );

    expect(repository.submitJamCalls, 1);
    expect(repository.lastSubmittedJamSlots, ['10:00', '10:30']);

    controller.dispose();
  });

  test('OrganizeJamController updates existing jam in edit mode', () async {
    final jam = JamListItem(
      id: 'jam-9',
      jam: Jam(
        id: 'jam-9',
        creatorId: 'user-1',
        groupId: 'group-1',
        titolo: 'Old jam title',
        data: '2026-03-20',
        oraInizio: '10:00',
        oraFine: '11:00',
        personePresenti: 2,
        personeRichieste: 3,
        descrizione: 'Old jam',
        pagamento: 'Offerto',
        attrezzatura: 'Amp',
      ),
    );
    final repository = FakeJamRepository(
      userGroups: const [
        {'id': 'group-1', 'name': 'Group 1'},
      ],
    );
    final controller = OrganizeJamController(repository: repository);

    await controller.initialize(initialJam: jam);

    expect(controller.isEditing, isTrue);
    expect(controller.editingTimeRangeLabel, '10:00 - 11:00');
    expect(controller.selectedSlots, ['10:00', '10:30']);
    expect(controller.validateSelection(), isNull);

    await controller.submitJam(
      title: 'Updated jam title',
      presentPeople: 3,
      requiredPeople: 2,
      description: 'Updated jam',
      equipment: 'Updated amp',
    );

    expect(repository.updatedJamId, 'jam-9');
    expect(repository.updatedDescription, 'Updated jam');
    expect(repository.updateJamCalls, 1);

    controller.dispose();
  });

  test('FindJamController filters owned jams and selected dates', () async {
    final jamOne = JamListItem(
      id: 'jam-1',
      jam: Jam(
        id: 'jam-1',
        creatorId: 'user-1',
        titolo: 'Blues title',
        data: '2026-03-20',
        oraInizio: '10:00',
        oraFine: '12:30',
        personePresenti: 2,
        personeRichieste: 3,
        descrizione: 'Blues',
        pagamento: 'Offerto',
        attrezzatura: '',
        stato: JamStatus.pubblicata,
      ),
      participantIds: const {'user-1'},
    );
    final jamTwo = JamListItem(
      id: 'jam-2',
      jam: Jam(
        id: 'jam-2',
        creatorId: 'user-2',
        titolo: 'Rock title',
        data: '2026-03-21',
        oraInizio: '14:00',
        oraFine: '16:30',
        personePresenti: 1,
        personeRichieste: 4,
        descrizione: 'Rock',
        pagamento: 'Diviso',
        attrezzatura: '',
        stato: JamStatus.pubblicata,
      ),
    );

    final repository = FakeJamRepository(
      streamItems: [jamOne, jamTwo],
      publishedItems: [jamOne],
    );
    final controller = FindJamController(
      repository: repository,
      currentUserId: 'user-1',
    );

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(controller.filteredJams, hasLength(2));

    controller.setShowMyJams(true);
    expect(controller.filteredJams, hasLength(1));

    controller.setShowMyJams(false);
    controller.setShowParticipatingJams(true);
    expect(controller.filteredJams, hasLength(1));
    expect(controller.filteredJams.single.id, 'jam-1');

    controller.setSelectedDates([DateTime(2026, 3, 20)]);
    expect(controller.filteredJams.single.id, 'jam-1');

    final dates = await controller.loadAvailableFilterDates();
    expect(dates, hasLength(1));

    controller.dispose();
  });

  test('FindJamController loads jam by id for feed deep link', () async {
    final jam = JamListItem(
      id: 'jam-1',
      jam: Jam(
        id: 'jam-1',
        creatorId: 'user-1',
        titolo: 'Blues title',
        data: '2026-03-20',
        oraInizio: '10:00',
        oraFine: '12:30',
        personePresenti: 2,
        personeRichieste: 3,
        descrizione: 'Blues',
        pagamento: 'Offerto',
        attrezzatura: '',
        stato: JamStatus.pubblicata,
      ),
    );
    final repository = FakeJamRepository(jamById: {'jam-1': jam});
    final controller = FindJamController(
      repository: repository,
      currentUserId: 'user-1',
    );

    final loadedJam = await controller.loadJamById('jam-1');

    expect(loadedJam?.id, 'jam-1');
    expect(loadedJam?.jam.descrizione, 'Blues');

    controller.dispose();
  });

  test('FindJamController joins jam through repository', () async {
    final repository = FakeJamRepository();
    final controller = FindJamController(
      repository: repository,
      currentUserId: 'user-1',
    );

    await controller.joinJam('jam-42');

    expect(repository.joinedJamIds, ['jam-42']);

    controller.dispose();
  });

  test(
    'FindJamController keeps pending jams visible only in Mie Jam filter',
    () async {
      final pendingOwnJam = JamListItem(
        id: 'jam-pending',
        jam: Jam(
          id: 'jam-pending',
          creatorId: 'user-1',
          titolo: 'Pending jam title',
          data: '2026-03-22',
          oraInizio: '10:00',
          oraFine: '12:30',
          personePresenti: 1,
          personeRichieste: 3,
          descrizione: 'Pending jam',
          pagamento: 'Offerto',
          attrezzatura: '',
          stato: JamStatus.inElaborazione,
        ),
      );
      final publishedJam = JamListItem(
        id: 'jam-published',
        jam: Jam(
          id: 'jam-published',
          creatorId: 'user-2',
          titolo: 'Published jam title',
          data: '2026-03-23',
          oraInizio: '14:00',
          oraFine: '16:30',
          personePresenti: 2,
          personeRichieste: 2,
          descrizione: 'Published jam',
          pagamento: 'Diviso',
          attrezzatura: '',
          stato: JamStatus.pubblicata,
        ),
      );
      final controller = FindJamController(
        repository: FakeJamRepository(
          streamItems: [pendingOwnJam, publishedJam],
        ),
        currentUserId: 'user-1',
      );

      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(controller.filteredJams.map((jam) => jam.id), ['jam-published']);

      controller.setShowMyJams(true);

      expect(controller.filteredJams.map((jam) => jam.id), ['jam-pending']);

      controller.dispose();
    },
  );

  test('FindJamController leaves jam through repository', () async {
    final repository = FakeJamRepository();
    final controller = FindJamController(
      repository: repository,
      currentUserId: 'user-1',
    );

    await controller.leaveJam('jam-42');

    expect(repository.leftJamIds, ['jam-42']);

    controller.dispose();
  });

  test(
    'OrganizeJamController requires at least two contiguous slots',
    () async {
      final repository = FakeJamRepository(
        availableDates: [DateTime(2026, 3, 20)],
        availableSlotsByDate: {
          '2026-03-20': ['10:00', '10:30'],
        },
      );
      final controller = OrganizeJamController(repository: repository);

      await controller.initialize();
      await controller.selectDate(DateTime(2026, 3, 20));
      controller.toggleSlot('10:00');
      controller.setSelectedPayment('Offerto');

      expect(
        controller.validateSelection(),
        'Seleziona almeno due slot contigui.',
      );

      controller.dispose();
    },
  );
}

class FakeJamRepository implements JamRepository {
  FakeJamRepository({
    this.availableDates = const [],
    this.availableSlotsByDate = const {},
    this.userGroups = const [],
    this.streamItems = const [],
    this.publishedItems = const [],
    this.jamById = const {},
  });

  final List<DateTime> availableDates;
  final Map<String, List<String>> availableSlotsByDate;
  final List<Map<String, String>> userGroups;
  final List<JamListItem> streamItems;
  final List<JamListItem> publishedItems;
  final Map<String, JamListItem> jamById;
  final List<String> joinedJamIds = [];
  final List<String> leftJamIds = [];
  int updateJamCalls = 0;
  String? updatedJamId;
  String? updatedDescription;

  int submitJamCalls = 0;
  List<String>? lastSubmittedJamSlots;

  @override
  bool areSlotsContiguous(List<String> slots) {
    if (slots.length <= 1) {
      return true;
    }

    for (int index = 0; index < slots.length - 1; index++) {
      if (_timeToMinutes(slots[index + 1]) - _timeToMinutes(slots[index]) !=
          30) {
        return false;
      }
    }

    return true;
  }

  @override
  String calculateEndTime(String startSlot) {
    final totalMinutes = _timeToMinutes(startSlot) + 30;
    final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Future<void> deleteJam(String jamId) async {}

  @override
  Future<List<DateTime>> loadAvailableDates() async => availableDates;

  @override
  Future<List<String>> loadAvailableSlots(DateTime date) async {
    return availableSlotsByDate[_dateKey(date)] ?? const [];
  }

  @override
  Future<JamListItem?> loadJamById(String jamId) async => jamById[jamId];

  @override
  Future<Map<String, String>> loadParticipantUsernames(
    Iterable<String> userIds,
  ) async {
    return {for (final userId in userIds) userId: 'User $userId'};
  }

  @override
  Future<void> joinJam(String jamId) async {
    joinedJamIds.add(jamId);
  }

  @override
  Future<void> leaveJam(String jamId) async {
    leftJamIds.add(jamId);
  }

  @override
  Future<void> updateJam({
    required String jamId,
    required DateTime selectedDate,
    required List<String> selectedSlots,
    String? groupId,
    required String title,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String payment,
    required String equipment,
  }) async {
    updateJamCalls += 1;
    updatedJamId = jamId;
    updatedDescription = description;
  }

  @override
  Future<List<JamListItem>> loadPublishedJamsOnce() async => publishedItems;

  @override
  Future<List<Map<String, String>>> loadUserGroups() async => userGroups;

  @override
  Future<void> submitJam({
    required DateTime selectedDate,
    required List<String> selectedSlots,
    required String title,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String payment,
    required String equipment,
    String? selectedGroupId,
  }) async {
    submitJamCalls += 1;
    lastSubmittedJamSlots = List<String>.from(selectedSlots);
  }

  @override
  Stream<List<JamListItem>> watchJams() {
    return Stream<List<JamListItem>>.value(streamItems);
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
