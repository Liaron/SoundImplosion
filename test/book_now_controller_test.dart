import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/book/book_now_controller.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';
import 'package:soundimplosion/models/models.dart';

void main() {
  test('BookNowController loads dates and groups on initialize', () async {
    final repository = FakeBookingRepository(
      availableDates: [DateTime(2026, 3, 20)],
      userGroups: const [
        {'id': 'band-1', 'name': 'Band One'},
      ],
    );
    final controller = BookNowController(repository: repository);

    await controller.initialize();

    expect(controller.availableDates, hasLength(1));
    expect(controller.userGroups, hasLength(1));
    expect(controller.isLoadingDates, isFalse);

    controller.dispose();
  });

  test(
    'BookNowController validates slot continuity and delegates submit',
    () async {
      final repository = FakeBookingRepository(
        availableDates: [DateTime(2026, 3, 20)],
        availableSlotsByDate: {
          '2026-03-20': ['10:00', '11:15', '13:45'],
        },
      );
      final controller = BookNowController(repository: repository);

      await controller.selectDate(DateTime(2026, 3, 20));
      controller.toggleSlot('10:00');
      controller.toggleSlot('13:45');

      expect(
        controller.validateSelection(),
        'Gli orari selezionati devono essere consecutivi.',
      );

      controller.toggleSlot('13:45');
      controller.toggleSlot('11:15');

      expect(controller.validateSelection(), isNull);
      expect(controller.selectedRangeLabel, '10:00 - 12:30');

      await controller.submitBooking(
        peopleCount: 3,
        equipment: 'Amplificatore',
      );

      expect(repository.submitCallCount, 1);
      expect(repository.lastSubmittedPeopleCount, 3);
      expect(repository.lastSubmittedSlots, ['10:00', '11:15']);

      controller.dispose();
    },
  );

  test('BookNowController updates existing booking in edit mode', () async {
    final repository = FakeBookingRepository(
      userGroups: const [
        {'id': 'band-1', 'name': 'Band One'},
      ],
    );
    final controller = BookNowController(repository: repository);

    await controller.initialize(
      initialBooking: BookingListItem(
        id: 'booking-1',
        booking: Booking(
          id: 'booking-1',
          userId: 'user-1',
          groupId: 'band-1',
          data: '2026-03-20',
          oraInizio: '10:00',
          oraFine: '12:30',
          numeroUtenti: 2,
          attrezzatura: 'Mixer',
          stato: BookingStatus.inElaborazione,
        ),
      ),
    );

    expect(controller.isEditing, isTrue);
    expect(controller.editingTimeRangeLabel, '10:00 - 12:30');
    expect(controller.selectedSlots, ['10:00', '11:15']);
    expect(controller.validateSelection(), isNull);

    await controller.submitBooking(peopleCount: 4, equipment: 'Nuovo mixer');

    expect(repository.updateCallCount, 1);
    expect(repository.lastUpdatedBookingId, 'booking-1');
    expect(repository.lastUpdatedPeopleCount, 4);

    controller.dispose();
  });
}

class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({
    this.availableDates = const [],
    this.userGroups = const [],
    this.availableSlotsByDate = const {},
  });

  final List<DateTime> availableDates;
  final List<Map<String, String>> userGroups;
  final Map<String, List<String>> availableSlotsByDate;

  int submitCallCount = 0;
  int? lastSubmittedPeopleCount;
  List<String>? lastSubmittedSlots;
  int updateCallCount = 0;
  String? lastUpdatedBookingId;
  int? lastUpdatedPeopleCount;

  @override
  bool areSlotsContiguous(List<String> slots) {
    if (slots.length <= 1) {
      return true;
    }

    for (int index = 0; index < slots.length - 1; index++) {
      if (_timeToMinutes(slots[index + 1]) - _timeToMinutes(slots[index]) !=
          75) {
        return false;
      }
    }

    return true;
  }

  @override
  String calculateEndTime(String startSlot) {
    final totalMinutes = _timeToMinutes(startSlot) + 75;
    final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Future<void> deleteBooking(String bookingId) async {}

  @override
  Future<void> updateBooking({
    required String bookingId,
    required DateTime selectedDate,
    required List<String> selectedSlots,
    String? groupId,
    required int peopleCount,
    required String equipment,
  }) async {
    updateCallCount += 1;
    lastUpdatedBookingId = bookingId;
    lastUpdatedPeopleCount = peopleCount;
  }

  @override
  Future<List<DateTime>> loadAvailableDates() async => availableDates;

  @override
  Future<List<String>> loadAvailableSlots(DateTime date) async {
    return availableSlotsByDate[_dateKey(date)] ?? const [];
  }

  @override
  Future<List<Map<String, String>>> loadUserGroups() async => userGroups;

  @override
  Future<void> submitBooking({
    required DateTime selectedDate,
    required List<String> selectedSlots,
    required int peopleCount,
    required String equipment,
    String? selectedGroupId,
  }) async {
    submitCallCount += 1;
    lastSubmittedPeopleCount = peopleCount;
    lastSubmittedSlots = List<String>.from(selectedSlots);
  }

  @override
  Stream<List<BookingListItem>> watchUserBookings() {
    return const Stream<List<BookingListItem>>.empty();
  }

  @override
  Stream<List<BookingListItem>> watchAccessibleBookings() {
    return const Stream<List<BookingListItem>>.empty();
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
