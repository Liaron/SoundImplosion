import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/admin/admin_jam_controller.dart';
import 'package:soundimplosion/app/features/admin/admin_jam_repository.dart';
import 'package:soundimplosion/app/features/jam/jam_repository.dart';
import 'package:soundimplosion/models/models.dart';

void main() {
  test('AdminJamController loads pending jams from repository', () async {
    final repository = FakeAdminJamRepository(
      pendingItems: [
        JamListItem(
          id: 'jam-1',
          jam: Jam(
            id: 'jam-1',
            creatorId: 'creator-1',
            titolo: 'Jam pending title',
            data: '2026-03-21',
            oraInizio: '10:00',
            oraFine: '12:30',
            personePresenti: 2,
            personeRichieste: 3,
            descrizione: 'Jam pending',
            pagamento: 'Offerto',
            attrezzatura: 'Mixer',
            stato: JamStatus.inElaborazione,
          ),
        ),
      ],
      approvedItems: const [],
    );
    final controller = AdminJamController(repository: repository);

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(controller.isLoading, isFalse);
    expect(controller.pendingJams, hasLength(1));

    controller.dispose();
  });

  test('AdminJamController delegates approve and reject actions', () async {
    final repository = FakeAdminJamRepository(
      pendingItems: const [],
      approvedItems: const [],
    );
    final controller = AdminJamController(repository: repository);

    await controller.approveJam('jam-1');
    await controller.rejectJam('jam-2');

    expect(repository.approvedJamIds, ['jam-1']);
    expect(repository.rejectedJamIds, ['jam-2']);

    controller.dispose();
  });

  test('AdminJamController loads approved jams from repository', () async {
    final repository = FakeAdminJamRepository(
      pendingItems: const [],
      approvedItems: [
        JamListItem(
          id: 'jam-approved-1',
          jam: Jam(
            id: 'jam-approved-1',
            creatorId: 'creator-2',
            titolo: 'Approved jam title',
            data: '2026-03-25',
            oraInizio: '18:00',
            oraFine: '19:15',
            personePresenti: 3,
            personeRichieste: 1,
            descrizione: 'Jam approved',
            pagamento: 'Diviso',
            attrezzatura: 'Mixer',
            stato: JamStatus.pubblicata,
          ),
        ),
      ],
    );
    final controller = AdminJamController(repository: repository);

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(controller.approvedJams, hasLength(1));

    controller.dispose();
  });

  test('AdminJamController delegates delete action', () async {
    final repository = FakeAdminJamRepository(
      pendingItems: const [],
      approvedItems: const [],
    );
    final controller = AdminJamController(repository: repository);

    await controller.deleteJam('jam-3');

    expect(repository.deletedJamIds, ['jam-3']);

    controller.dispose();
  });
}

class FakeAdminJamRepository implements AdminJamRepository {
  FakeAdminJamRepository({
    required this.pendingItems,
    required this.approvedItems,
  });

  final List<JamListItem> pendingItems;
  final List<JamListItem> approvedItems;
  final List<String> approvedJamIds = [];
  final List<String> rejectedJamIds = [];
  final List<String> deletedJamIds = [];
  final List<String> proposedJamIds = [];

  @override
  Future<void> approveJam(String jamId) async {
    approvedJamIds.add(jamId);
  }

  @override
  Future<void> rejectJam(String jamId) async {
    rejectedJamIds.add(jamId);
  }

  @override
  Future<void> deleteJam(String jamId) async {
    deletedJamIds.add(jamId);
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
  }) async {
    proposedJamIds.add(jamId);
  }

  @override
  Stream<List<JamListItem>> watchPendingJams() {
    return Stream<List<JamListItem>>.value(pendingItems);
  }

  @override
  Stream<List<JamListItem>> watchApprovedJams() {
    return Stream<List<JamListItem>>.value(approvedItems);
  }
}
