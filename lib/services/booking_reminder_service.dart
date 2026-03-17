import 'package:intl/intl.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/local_notification_service.dart';

class BookingReminderService {
  BookingReminderService._();

  static final BookingReminderService instance = BookingReminderService._();

  Future<void> syncReminders({
    required List<BookingListItem> bookings,
    required bool enabled,
    required int minutesBefore,
  }) async {
    await LocalNotificationService.instance.initialize();

    final desiredIds = <int>{};
    final now = DateTime.now();

    for (final item in bookings) {
      if (item.booking.stato != BookingStatus.confermata) {
        await LocalNotificationService.instance.cancelNotification(
          _notificationId(item.id),
        );
        continue;
      }

      final startAt = _bookingStart(item.booking);
      if (startAt == null) {
        continue;
      }

      final scheduledAt = startAt.subtract(Duration(minutes: minutesBefore));
      final notificationId = _notificationId(item.id);

      if (!enabled || !scheduledAt.isAfter(now)) {
        await LocalNotificationService.instance.cancelNotification(
          notificationId,
        );
        continue;
      }

      desiredIds.add(notificationId);
      await LocalNotificationService.instance.scheduleNotification(
        id: notificationId,
        title: 'Promemoria prenotazione',
        body:
            'Hai una prenotazione il ${item.booking.data} alle ${item.booking.oraInizio}.',
        scheduledAt: scheduledAt,
        payload: 'booking_reminder:${item.id}',
      );
    }

    final pending = await LocalNotificationService.instance
        .pendingNotificationRequests();
    for (final request in pending) {
      final payload = request.payload ?? '';
      if (!payload.startsWith('booking_reminder:')) {
        continue;
      }
      if (!desiredIds.contains(request.id)) {
        await LocalNotificationService.instance.cancelNotification(request.id);
      }
    }
  }

  DateTime? _bookingStart(Booking booking) {
    try {
      return DateFormat(
        'yyyy-MM-dd HH:mm',
      ).parse('${booking.data} ${booking.oraInizio}');
    } catch (_) {
      return null;
    }
  }

  int _notificationId(String bookingId) {
    return 'booking_reminder_$bookingId'.hashCode & 0x7fffffff;
  }
}
