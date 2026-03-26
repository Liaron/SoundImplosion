import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';
import 'package:soundimplosion/app/features/home/feed_repository.dart';
import 'package:soundimplosion/models/models.dart';

class HomeFeedController extends ChangeNotifier {
  HomeFeedController({
    FeedRepository? feedRepository,
    BookingRepository? bookingRepository,
  }) : _feedRepository = feedRepository ?? FirebaseFeedRepository(),
       _bookingRepository = bookingRepository ?? FirebaseBookingRepository();

  final FeedRepository _feedRepository;
  final BookingRepository _bookingRepository;

  bool isLoading = true;
  Object? error;
  List<HomeFeedItem> items = [];
  List<BookingListItem> bookings = [];

  StreamSubscription<List<HomeFeedItem>>? _feedSubscription;
  StreamSubscription<List<BookingListItem>>? _bookingSubscription;
  bool _feedLoaded = false;
  bool _bookingsLoaded = false;

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    _feedLoaded = false;
    _bookingsLoaded = false;
    notifyListeners();

    _feedSubscription = _feedRepository.watchFeedItems().listen(
      (feedItems) {
        items = feedItems;
        error = null;
        _feedLoaded = true;
        _refreshState();
      },
      onError: (Object streamError) {
        error = streamError;
        _feedLoaded = true;
        _refreshState();
      },
    );

    _bookingSubscription = _bookingRepository.watchAccessibleBookings().listen(
      (bookingItems) {
        bookings = _filterVisibleBookings(bookingItems);
        error = null;
        _bookingsLoaded = true;
        _refreshState();
      },
      onError: (Object streamError) {
        error = streamError;
        _bookingsLoaded = true;
        _refreshState();
      },
    );
  }

  void _refreshState() {
    isLoading = !_feedLoaded || !_bookingsLoaded;
    notifyListeners();
  }

  List<BookingListItem> _filterVisibleBookings(List<BookingListItem> source) {
    final now = DateTime.now();
    final visible = source.where((item) {
      if (item.booking.stato == BookingStatus.annullata ||
          item.booking.stato == BookingStatus.superata) {
        return false;
      }
      final endAt = _parseBookingDateTime(
        item.booking.data,
        item.booking.oraFine,
      );
      return endAt == null || !endAt.isBefore(now);
    }).toList();

    visible.sort((a, b) {
      final left = _parseBookingDateTime(a.booking.data, a.booking.oraInizio);
      final right = _parseBookingDateTime(b.booking.data, b.booking.oraInizio);
      if (left == null && right == null) {
        return 0;
      }
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      return left.compareTo(right);
    });
    return visible;
  }

  DateTime? _parseBookingDateTime(String rawDate, String rawTime) {
    try {
      final date = DateTime.parse(rawDate);
      final parts = rawTime.split(':');
      if (parts.length != 2) {
        return null;
      }
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _feedSubscription?.cancel();
    _bookingSubscription?.cancel();
    super.dispose();
  }
}
