import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/admin/admin_jam_controller.dart';
import 'package:soundimplosion/app/features/admin/admin_jam_repository.dart';
import 'package:soundimplosion/app/features/jam/jam_repository.dart';
import 'package:soundimplosion/models/models.dart';

void main() {
  test('AdminJamController loads pending jams from repository', () async {
    final repository = FakeAdminJamRepository(
      items: [
        JamListItem(
          id: 'jam-1',
          jam: Jam(
            id: 'jam-1',
            creatorId: 'creator-1',
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
    );
    final controller = AdminJamController(repository: repository);

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(controller.isLoading, isFalse);
    expect(controller.pendingJams, hasLength(1));

    controller.dispose();
  });

  test('AdminJamController delegates approve and reject actions', () async {
    final repository = FakeAdminJamRepository(items: const []);
    final controller = AdminJamController(repository: repository);

    await controller.approveJam('jam-1');
    await controller.rejectJam('jam-2');

    expect(repository.approvedJamIds, ['jam-1']);
    expect(repository.rejectedJamIds, ['jam-2']);

    controller.dispose();
  });
}

class FakeAdminJamRepository implements AdminJamRepository {
  FakeAdminJamRepository({required this.items});

  final List<JamListItem> items;
  final List<String> approvedJamIds = [];
  final List<String> rejectedJamIds = [];

  @override
  Future<void> approveJam(String jamId) async {
    approvedJamIds.add(jamId);
  }

  @override
  Future<void> rejectJam(String jamId) async {
    rejectedJamIds.add(jamId);
  }

  @override
  Stream<List<JamListItem>> watchPendingJams() {
    return Stream<List<JamListItem>>.value(items);
  }
}