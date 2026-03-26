import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/jam/jam_repository.dart';
import 'package:soundimplosion/services/app_telemetry_service.dart';

class OrganizeJamController extends ChangeNotifier {
  OrganizeJamController({JamRepository? repository})
    : _repository = repository ?? FirebaseJamRepository();

  final JamRepository _repository;

  bool isLoading = false;
  bool isLoadingSlots = false;
  bool isLoadingDates = true;

  List<DateTime> availableDates = [];
  List<String> availableSlots = [];
  List<Map<String, String>> userGroups = [];
  JamListItem? editingJam;
  DateTime? _originalDate;
  List<String> _originalSelectedSlots = [];

  DateTime? selectedDate;
  String? selectedPayment;
  String? selectedGroupId;
  final List<String> _selectedSlots = [];

  static const List<String> paymentOptions = ['Offerto', 'Diviso'];

  bool get isEditing => editingJam != null;

  String? get editingDateLabel => editingJam?.dateLabel;

  String? get editingTimeRangeLabel => editingJam?.timeRangeLabel;

  List<String> get selectedSlots => List.unmodifiable(_selectedSlots);

  String? get selectedRangeLabel {
    if (_selectedSlots.isEmpty) {
      return null;
    }
    return '${_selectedSlots.first} - ${_repository.calculateEndTime(_selectedSlots.last)}';
  }

  Future<void> initialize({JamListItem? initialJam}) async {
    editingJam = initialJam;

    if (initialJam != null) {
      _hydrateFromExistingJam(initialJam);
      await Future.wait([loadAvailableDates(), loadUserGroups()]);
      await refreshAvailableSlots();
      return;
    }

    await Future.wait([loadAvailableDates(), loadUserGroups()]);
  }

  Future<void> loadAvailableDates() async {
    isLoadingDates = true;
    notifyListeners();

    try {
      availableDates = await _repository.loadAvailableDates();
      if (_originalDate != null &&
          !_containsDay(availableDates, _originalDate!)) {
        availableDates = [...availableDates, _originalDate!]
          ..sort((a, b) => a.compareTo(b));
      }
      if (selectedDate != null &&
          !_containsDay(availableDates, selectedDate!)) {
        selectedDate = null;
        availableSlots = [];
        _selectedSlots.clear();
      }
    } finally {
      isLoadingDates = false;
      notifyListeners();
    }
  }

  Future<void> loadUserGroups() async {
    userGroups = await _repository.loadUserGroups();

    final currentGroupId = selectedGroupId;
    if (currentGroupId != null &&
        currentGroupId.isNotEmpty &&
        !userGroups.any((group) => group['id'] == currentGroupId)) {
      userGroups = [
        ...userGroups,
        {'id': currentGroupId, 'name': 'Gruppo corrente'},
      ];
    }

    notifyListeners();
  }

  Future<void> selectDate(DateTime date) async {
    selectedDate = date;
    await refreshAvailableSlots();
  }

  Future<void> refreshAvailableSlots() async {
    final currentDate = selectedDate;
    if (currentDate == null) {
      return;
    }

    isLoadingSlots = true;
    availableSlots = [];
    notifyListeners();

    try {
      final loadedSlots = await _repository.loadAvailableSlots(currentDate);
      final mergedSlots = {...loadedSlots};

      if (_originalDate != null &&
          _containsDay([_originalDate!], currentDate)) {
        mergedSlots.addAll(_originalSelectedSlots);
      }

      availableSlots = mergedSlots.toList()..sort();
      _selectedSlots
        ..clear()
        ..addAll(
          _originalDate != null && _containsDay([_originalDate!], currentDate)
              ? _originalSelectedSlots
              : const <String>[],
        );
    } finally {
      isLoadingSlots = false;
      notifyListeners();
    }
  }

  void toggleSlot(String slot) {
    if (_selectedSlots.contains(slot)) {
      _selectedSlots.remove(slot);
    } else {
      _selectedSlots.add(slot);
      _selectedSlots.sort();
    }
    notifyListeners();
  }

  void setSelectedPayment(String? value) {
    selectedPayment = value;
    notifyListeners();
  }

  void setSelectedGroup(String? value) {
    selectedGroupId = value;
    notifyListeners();
  }

  String? validateSelection() {
    if (selectedDate == null) {
      return 'Seleziona una data';
    }
    if (_selectedSlots.isEmpty) {
      return 'Seleziona almeno un orario';
    }
    if (_selectedSlots.length < 2) {
      return 'Seleziona almeno due slot contigui.';
    }
    if (!_repository.areSlotsContiguous(_selectedSlots)) {
      return 'Per selezionare slot separati e necessario effettuare due richieste distinte.';
    }
    if (selectedPayment == null) {
      return 'Seleziona una modalità di pagamento';
    }
    return null;
  }

  Future<void> submitJam({
    required String title,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String equipment,
  }) async {
    final currentDate = selectedDate;
    final payment = selectedPayment;
    if (currentDate == null) {
      throw Exception('Seleziona una data');
    }
    if (payment == null) {
      throw Exception('Seleziona una modalità di pagamento');
    }

    isLoading = true;
    notifyListeners();

    try {
      if (isEditing) {
        final jamId = editingJam?.id;
        if (jamId == null || jamId.isEmpty) {
          throw Exception('Jam non valida');
        }

        await _repository.updateJam(
          jamId: jamId,
          selectedDate: currentDate,
          selectedSlots: _selectedSlots,
          groupId: selectedGroupId,
          title: title,
          presentPeople: presentPeople,
          requiredPeople: requiredPeople,
          description: description,
          payment: payment,
          equipment: equipment,
        );
        await AppTelemetryService.instance.logJamUpdated(
          hasGroup: (selectedGroupId ?? '').isNotEmpty,
        );
      } else {
        await _repository.submitJam(
          selectedDate: currentDate,
          selectedSlots: _selectedSlots,
          title: title,
          presentPeople: presentPeople,
          requiredPeople: requiredPeople,
          description: description,
          payment: payment,
          equipment: equipment,
          selectedGroupId: selectedGroupId,
        );
        await AppTelemetryService.instance.logJamCreated(
          hasGroup: (selectedGroupId ?? '').isNotEmpty,
        );
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _hydrateFromExistingJam(JamListItem jam) {
    selectedDate = DateTime.tryParse(jam.jam.data);
    _originalDate = selectedDate;
    selectedPayment = jam.jam.pagamento.isEmpty ? null : jam.jam.pagamento;
    selectedGroupId = jam.jam.groupId;
    _originalSelectedSlots = _buildSlotRange(
      jam.jam.oraInizio,
      jam.jam.oraFine,
    );
  }

  List<String> _buildSlotRange(String startTime, String endTime) {
    final slots = <String>[];
    var currentMinutes = _timeToMinutes(startTime);
    final endMinutes = _timeToMinutes(endTime);

    while (currentMinutes < endMinutes) {
      final hour = (currentMinutes ~/ 60).toString().padLeft(2, '0');
      final minute = (currentMinutes % 60).toString().padLeft(2, '0');
      slots.add('$hour:$minute');
      currentMinutes += 30;
    }

    return slots;
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  bool _containsDay(List<DateTime> days, DateTime target) {
    return days.any(
      (day) =>
          day.year == target.year &&
          day.month == target.month &&
          day.day == target.day,
    );
  }
}
