import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/admin/admin_booking_controller.dart';
import 'package:soundimplosion/app/features/admin/admin_booking_repository.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';
import 'package:soundimplosion/models/models.dart';

void main() {
  test(
    'AdminBookingController loads pending bookings from repository',
    () async {
      final repository = FakeAdminBookingRepository(
        pendingItems: [
          BookingListItem(
            id: 'booking-1',
            booking: Booking(
              id: 'booking-1',
              userId: 'user-1',
              data: '2026-03-21',
              oraInizio: '10:00',
              oraFine: '12:30',
              numeroUtenti: 3,
              attrezzatura: 'Mixer',
            ),
          ),
        ],
        approvedItems: const [],
      );
      final controller = AdminBookingController(repository: repository);

      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(controller.isLoading, isFalse);
      expect(controller.pendingBookings, hasLength(1));

      controller.dispose();
    },
  );

  test('AdminBookingController delegates confirm and cancel actions', () async {
    final repository = FakeAdminBookingRepository(
      pendingItems: const [],
      approvedItems: const [],
    );
    final controller = AdminBookingController(repository: repository);

    await controller.confirmBooking('booking-1');
    await controller.cancelBooking('booking-2');

    expect(repository.confirmedBookingIds, ['booking-1']);
    expect(repository.cancelledBookingIds, ['booking-2']);

    controller.dispose();
  });

  test(
    'AdminBookingController loads approved bookings from repository',
    () async {
      final repository = FakeAdminBookingRepository(
        pendingItems: const [],
        approvedItems: [
          BookingListItem(
            id: 'booking-approved-1',
            booking: Booking(
              id: 'booking-approved-1',
              userId: 'user-2',
              data: '2026-03-22',
              oraInizio: '12:30',
              oraFine: '13:45',
              numeroUtenti: 2,
              attrezzatura: 'Microfono',
              stato: BookingStatus.confermata,
            ),
          ),
        ],
      );
      final controller = AdminBookingController(repository: repository);

      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(controller.approvedBookings, hasLength(1));

      controller.dispose();
    },
  );

  test('AdminBookingController delegates delete action', () async {
    final repository = FakeAdminBookingRepository(
      pendingItems: const [],
      approvedItems: const [],
    );
    final controller = AdminBookingController(repository: repository);

    await controller.deleteBooking('booking-3');

    expect(repository.deletedBookingIds, ['booking-3']);

    controller.dispose();
  });
}

class FakeAdminBookingRepository implements AdminBookingRepository {
  FakeAdminBookingRepository({
    required this.pendingItems,
    required this.approvedItems,
  });

  final List<BookingListItem> pendingItems;
  final List<BookingListItem> approvedItems;
  final List<String> confirmedBookingIds = [];
  final List<String> cancelledBookingIds = [];
  final List<String> deletedBookingIds = [];

  @override
  Future<void> cancelBooking(String bookingId) async {
    cancelledBookingIds.add(bookingId);
  }

  @override
  Future<void> confirmBooking(String bookingId) async {
    confirmedBookingIds.add(bookingId);
  }

  @override
  Future<void> deleteBooking(String bookingId) async {
    deletedBookingIds.add(bookingId);
  }

  @override
  Stream<List<BookingListItem>> watchPendingBookings() {
    return Stream<List<BookingListItem>>.value(pendingItems);
  }

  @override
  Stream<List<BookingListItem>> watchApprovedBookings() {
    return Stream<List<BookingListItem>>.value(approvedItems);
  }

  @override
  Future<Map<String, String>> getUsernames(Iterable<String> userIds) async {
    final map = <String, String>{};
    for (final id in userIds) {
      map[id] = 'User_$id';
    }
    return map;
  }
}
