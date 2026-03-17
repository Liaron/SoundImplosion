import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/admin/admin_slot_management_controller.dart';
import 'package:soundimplosion/app/features/admin/admin_slot_management_repository.dart';

void main() {
  test('AdminSlotManagementController loads slots from repository', () async {
    final repository = FakeAdminSlotManagementRepository(
      items: const [
        AdminSlotItem(time: '10:00', status: 'libero'),
        AdminSlotItem(time: '11:15', status: 'disabilitato'),
      ],
    );
    final controller = AdminSlotManagementController(repository: repository);

    await controller.initialize();

    expect(controller.isLoading, isFalse);
    expect(controller.slots, hasLength(2));

    controller.dispose();
  });

  test('AdminSlotManagementController disables morning slots only', () async {
    final repository = FakeAdminSlotManagementRepository(
      items: const [
        AdminSlotItem(time: '10:00', status: 'libero'),
        AdminSlotItem(time: '11:15', status: 'libero'),
        AdminSlotItem(time: '15:00', status: 'libero'),
        AdminSlotItem(
          time: '16:15',
          status: 'occupato',
          bookingId: 'booking-1',
        ),
      ],
    );
    final controller = AdminSlotManagementController(repository: repository);

    await controller.initialize();
    await controller.disableMorningSlots();

    expect(repository.lastUpdatedSlots, ['10:00', '11:15']);
    expect(repository.lastDisabledValue, isTrue);

    controller.dispose();
  });

  test('AdminSlotManagementController updates selected slots', () async {
    final repository = FakeAdminSlotManagementRepository(
      items: const [
        AdminSlotItem(time: '10:00', status: 'libero'),
        AdminSlotItem(time: '11:15', status: 'disabilitato'),
      ],
    );
    final controller = AdminSlotManagementController(repository: repository);

    await controller.initialize();
    controller.toggleSlot('11:15');
    await controller.enableSelected();

    expect(repository.lastUpdatedSlots, ['11:15']);
    expect(repository.lastDisabledValue, isFalse);

    controller.dispose();
  });
}

class FakeAdminSlotManagementRepository
    implements AdminSlotManagementRepository {
  FakeAdminSlotManagementRepository({required this.items});

  final List<AdminSlotItem> items;
  List<String> lastUpdatedSlots = const [];
  bool? lastDisabledValue;

  @override
  Future<List<AdminSlotItem>> loadSlots(DateTime date) async => items;

  @override
  Future<void> updateSlots({
    required DateTime date,
    required List<String> slotTimes,
    required bool disabled,
  }) async {
    lastUpdatedSlots = List<String>.from(slotTimes)..sort();
    lastDisabledValue = disabled;
  }
}
