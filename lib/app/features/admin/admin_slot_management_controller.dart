import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/admin/admin_slot_management_repository.dart';

class AdminSlotManagementController extends ChangeNotifier {
  AdminSlotManagementController({AdminSlotManagementRepository? repository})
    : _repository = repository ?? FirebaseAdminSlotManagementRepository();

  final AdminSlotManagementRepository _repository;

  bool isLoading = true;
  bool isSubmitting = false;
  Object? error;
  DateTime selectedDate = DateTime.now();
  List<AdminSlotItem> slots = [];
  final Set<String> _selectedSlotTimes = <String>{};

  Set<String> get selectedSlotTimes => Set.unmodifiable(_selectedSlotTimes);

  Future<void> initialize() async {
    await loadSlotsForDate(selectedDate);
  }

  Future<void> loadSlotsForDate(DateTime date) async {
    selectedDate = DateTime(date.year, date.month, date.day);
    isLoading = true;
    error = null;
    _selectedSlotTimes.clear();
    notifyListeners();

    try {
      slots = await _repository.loadSlots(selectedDate);
    } catch (e) {
      error = e;
      slots = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void toggleSlot(String slotTime) {
    if (_selectedSlotTimes.contains(slotTime)) {
      _selectedSlotTimes.remove(slotTime);
    } else {
      _selectedSlotTimes.add(slotTime);
    }
    notifyListeners();
  }

  bool isSelected(String slotTime) => _selectedSlotTimes.contains(slotTime);

  Future<void> disableSelected() {
    return _updateSelected(disabled: true);
  }

  Future<void> enableSelected() {
    return _updateSelected(disabled: false);
  }

  Future<void> disableMorningSlots() async {
    final morningSlots = slots
        .where((slot) => slot.isMutable && _timeToMinutes(slot.time) < 14 * 60)
        .map((slot) => slot.time)
        .toList();

    if (morningSlots.isEmpty) {
      return;
    }

    await _submitUpdate(slotTimes: morningSlots, disabled: true);
  }

  Future<void> _updateSelected({required bool disabled}) async {
    if (_selectedSlotTimes.isEmpty) {
      return;
    }

    await _submitUpdate(
      slotTimes: _selectedSlotTimes.toList()..sort(),
      disabled: disabled,
    );
  }

  Future<void> _submitUpdate({
    required List<String> slotTimes,
    required bool disabled,
  }) async {
    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      await _repository.updateSlots(
        date: selectedDate,
        slotTimes: slotTimes,
        disabled: disabled,
      );
      await loadSlotsForDate(selectedDate);
    } catch (e) {
      error = e;
      notifyListeners();
      rethrow;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
