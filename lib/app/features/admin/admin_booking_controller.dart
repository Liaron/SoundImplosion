import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/admin/admin_booking_repository.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';

class AdminBookingController extends ChangeNotifier {
  AdminBookingController({AdminBookingRepository? repository})
    : _repository = repository ?? FirebaseAdminBookingRepository();

  final AdminBookingRepository _repository;

  bool isLoading = true;
  bool isSubmitting = false;
  Object? error;
  List<BookingListItem> pendingBookings = [];

  StreamSubscription<List<BookingListItem>>? _subscription;

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    notifyListeners();

    _subscription = _repository.watchPendingBookings().listen(
      (items) {
        pendingBookings = items;
        isLoading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object streamError) {
        error = streamError;
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> confirmBooking(String bookingId) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.confirmBooking(bookingId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.cancelBooking(bookingId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
