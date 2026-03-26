import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';
import 'package:soundimplosion/app/features/home/feed_repository.dart';
import 'package:soundimplosion/app/features/home/home_feed_controller.dart';
import 'package:soundimplosion/models/models.dart';

void main() {
  test(
    'HomeFeedController loads feed and visible accessible bookings',
    () async {
      final feedController = StreamController<List<HomeFeedItem>>();
      final bookingController = StreamController<List<BookingListItem>>();
      final controller = HomeFeedController(
        feedRepository: FakeFeedRepository(feedController.stream),
        bookingRepository: FakeBookingRepository(bookingController.stream),
      );

      await controller.initialize();

      feedController.add([
        const HomeFeedItem(
          id: 'jam-1',
          type: 'jam_published',
          timestamp: 10,
          jamId: 'jam-1',
        ),
      ]);
      bookingController.add([
        BookingListItem(
          id: 'booking-past',
          booking: Booking(
            id: 'booking-past',
            userId: 'user-1',
            data: '2020-03-20',
            oraInizio: '10:00',
            oraFine: '10:30',
            numeroUtenti: 2,
            attrezzatura: '',
            stato: BookingStatus.confermata,
          ),
        ),
        BookingListItem(
          id: 'booking-visible',
          booking: Booking(
            id: 'booking-visible',
            userId: 'user-1',
            groupId: 'group-1',
            groupName: 'Group 1',
            data: '2099-03-20',
            oraInizio: '10:00',
            oraFine: '10:30',
            numeroUtenti: 3,
            attrezzatura: 'Mixer',
            stato: BookingStatus.inElaborazione,
          ),
        ),
        BookingListItem(
          id: 'booking-cancelled',
          booking: Booking(
            id: 'booking-cancelled',
            userId: 'user-1',
            data: '2099-03-21',
            oraInizio: '10:00',
            oraFine: '10:30',
            numeroUtenti: 1,
            attrezzatura: '',
            stato: BookingStatus.annullata,
          ),
        ),
      ]);

      await Future<void>.delayed(Duration.zero);

      expect(controller.isLoading, isFalse);
      expect(controller.items, hasLength(1));
      expect(controller.bookings.map((item) => item.id), ['booking-visible']);

      await feedController.close();
      await bookingController.close();
      controller.dispose();
    },
  );
}

class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository(this.stream);

  final Stream<List<HomeFeedItem>> stream;

  @override
  Stream<List<HomeFeedItem>> watchFeedItems() => stream;
}

class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository(this.stream);

  final Stream<List<BookingListItem>> stream;

  @override
  bool areSlotsContiguous(List<String> slots) => true;

  @override
  String calculateEndTime(String startSlot) => startSlot;

  @override
  Future<void> deleteBooking(String bookingId) async {}

  @override
  Future<List<DateTime>> loadAvailableDates() async => const [];

  @override
  Future<List<String>> loadAvailableSlots(DateTime date) async => const [];

  @override
  Future<List<BookingSlotItem>> loadSlotsOverview(DateTime date) async =>
      const [];

  @override
  Future<List<Map<String, String>>> loadUserGroups() async => const [];

  @override
  Future<void> submitBooking({
    required DateTime selectedDate,
    required List<String> selectedSlots,
    required int peopleCount,
    required String equipment,
    String? selectedGroupId,
  }) async {}

  @override
  Future<void> updateBooking({
    required String bookingId,
    required DateTime selectedDate,
    required List<String> selectedSlots,
    String? groupId,
    required int peopleCount,
    required String equipment,
  }) async {}

  @override
  Stream<List<BookingListItem>> watchAccessibleBookings() => stream;

  @override
  Stream<List<BookingListItem>> watchUserBookings() =>
      const Stream<List<BookingListItem>>.empty();
}
