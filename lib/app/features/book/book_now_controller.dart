import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';
import 'package:soundimplosion/services/app_telemetry_service.dart';

class BookNowController extends ChangeNotifier {
  BookNowController({BookingRepository? repository})
    : _repository = repository ?? FirebaseBookingRepository();

  final BookingRepository _repository;

  bool isLoading = false;
  bool isLoadingSlots = false;
  bool isLoadingDates = true;

  List<DateTime> availableDates = [];
  List<Map<String, String>> userGroups = [];
  List<String> availableSlots = [];
  List<BookingSlotItem> slotOverview = [];
  BookingListItem? editingBooking;
  DateTime? _originalDate;
  List<String> _originalSelectedSlots = [];

  DateTime? selectedDate;
  String? selectedGroupId;
  final List<String> _selectedSlots = [];

  List<String> get selectedSlots => List.unmodifiable(_selectedSlots);

  bool get isEditing => editingBooking != null;

  String? get editingDateLabel => editingBooking?.booking.data;

  String? get editingTimeRangeLabel {
    final booking = editingBooking?.booking;
    if (booking == null) {
      return null;
    }
    return '${booking.oraInizio} - ${booking.oraFine}';
  }

  String? get selectedRangeLabel {
    if (_selectedSlots.isEmpty) {
      return null;
    }
    return '${_selectedSlots.first} - ${_repository.calculateEndTime(_selectedSlots.last)}';
  }

  Future<void> initialize({BookingListItem? initialBooking}) async {
    editingBooking = initialBooking;

    if (initialBooking != null) {
      _hydrateFromExistingBooking(initialBooking);
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
        _selectedSlots.clear();
        availableSlots = [];
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
    slotOverview = [];
    notifyListeners();

    try {
      final loadedSlots = await _repository.loadAvailableSlots(currentDate);
      final overviewSlots = await _repository.loadSlotsOverview(currentDate);
      final mergedSlots = {...loadedSlots};

      if (_originalDate != null &&
          _containsDay([_originalDate!], currentDate)) {
        mergedSlots.addAll(_originalSelectedSlots);
      }

      availableSlots = mergedSlots.toList()..sort();
      slotOverview = overviewSlots;
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
    BookingSlotItem? slotItem;
    for (final candidate in slotOverview) {
      if (candidate.time == slot) {
        slotItem = candidate;
        break;
      }
    }
    final canToggle =
        slotItem == null ||
        slotItem.isFree ||
        _selectedSlots.contains(slot) ||
        (isEditing &&
            slotItem.bookingId != null &&
            slotItem.bookingId == editingBooking?.id);
    if (!canToggle) {
      return;
    }

    if (_selectedSlots.contains(slot)) {
      _selectedSlots.remove(slot);
    } else {
      _selectedSlots.add(slot);
      _selectedSlots.sort();
    }
    notifyListeners();
  }

  void setSelectedGroup(String? groupId) {
    selectedGroupId = groupId;
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
    return null;
  }

  Future<void> submitBooking({
    required int peopleCount,
    required String equipment,
  }) async {
    final currentDate = selectedDate;
    if (currentDate == null) {
      throw Exception('Seleziona una data');
    }

    isLoading = true;
    notifyListeners();

    try {
      if (isEditing) {
        final bookingId = editingBooking?.id;
        if (bookingId == null || bookingId.isEmpty) {
          throw Exception('Prenotazione non valida');
        }

        await _repository.updateBooking(
          bookingId: bookingId,
          selectedDate: currentDate,
          selectedSlots: _selectedSlots,
          groupId: selectedGroupId,
          peopleCount: peopleCount,
          equipment: equipment,
        );
        await AppTelemetryService.instance.logBookingUpdated(
          isGroupBooking: (selectedGroupId ?? '').isNotEmpty,
        );
      } else {
        await _repository.submitBooking(
          selectedDate: currentDate,
          selectedSlots: _selectedSlots,
          peopleCount: peopleCount,
          equipment: equipment,
          selectedGroupId: selectedGroupId,
        );
        await AppTelemetryService.instance.logBookingCreated(
          isGroupBooking: (selectedGroupId ?? '').isNotEmpty,
        );
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _hydrateFromExistingBooking(BookingListItem bookingItem) {
    selectedDate = DateTime.tryParse(bookingItem.booking.data);
    _originalDate = selectedDate;
    selectedGroupId = bookingItem.booking.groupId;
    _originalSelectedSlots = _buildSlotRange(
      bookingItem.booking.oraInizio,
      bookingItem.booking.oraFine,
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
