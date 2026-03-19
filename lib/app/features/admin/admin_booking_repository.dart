import 'package:firebase_database/firebase_database.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/database_service.dart';

abstract class AdminBookingRepository {
  Stream<List<BookingListItem>> watchPendingBookings();
  Stream<List<BookingListItem>> watchApprovedBookings();
  Future<void> confirmBooking(String bookingId);
  Future<void> cancelBooking(String bookingId);
  Future<void> deleteBooking(String bookingId);
  Future<Map<String, String>> getUsernames(Iterable<String> userIds);
}

class FirebaseAdminBookingRepository implements AdminBookingRepository {
  FirebaseAdminBookingRepository({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;

  @override
  Future<Map<String, String>> getUsernames(Iterable<String> userIds) {
    return _databaseService.getUsernamesByIds(userIds);
  }

  Map<String, dynamic>? _mapFromRawValue(dynamic rawValue) {
    if (rawValue is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(rawValue);
  }

  @override
  Stream<List<BookingListItem>> watchPendingBookings() {
    return _databaseService.getPendingBookingsStream().map(_parseBookingItems);
  }

  @override
  Stream<List<BookingListItem>> watchApprovedBookings() {
    return _databaseService.getApprovedBookingsStream().map(_parseBookingItems);
  }

  @override
  Future<void> confirmBooking(String bookingId) {
    return _databaseService.confirmBooking(bookingId);
  }

  @override
  Future<void> cancelBooking(String bookingId) {
    return _databaseService.cancelBooking(bookingId);
  }

  @override
  Future<void> deleteBooking(String bookingId) {
    return _databaseService.deleteBooking(bookingId);
  }

  List<BookingListItem> _parseBookingItems(DatabaseEvent event) {
    final rawData = event.snapshot.value;
    final bookings = <BookingListItem>[];

    if (rawData is Map) {
      for (final entry in rawData.entries) {
        final bookingData = _mapFromRawValue(entry.value);
        if (bookingData == null) {
          continue;
        }
        bookings.add(
          BookingListItem(
            id: entry.key.toString(),
            booking: Booking.fromMap(entry.key.toString(), bookingData),
          ),
        );
      }
    } else if (rawData is List) {
      for (int index = 0; index < rawData.length; index++) {
        final item = rawData[index];
        if (item == null) {
          continue;
        }
        final bookingData = _mapFromRawValue(item);
        if (bookingData == null) {
          continue;
        }
        bookings.add(
          BookingListItem(
            id: index.toString(),
            booking: Booking.fromMap(index.toString(), bookingData),
          ),
        );
      }
    }

    bookings.sort(
      (a, b) => '${a.booking.data} ${a.booking.oraInizio}'.compareTo(
        '${b.booking.data} ${b.booking.oraInizio}',
      ),
    );
    return bookings;
  }
}
