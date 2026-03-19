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
  List<BookingListItem> approvedBookings = [];
  Map<String, String> userNames = {};

  StreamSubscription<List<BookingListItem>>? _pendingSubscription;
  StreamSubscription<List<BookingListItem>>? _approvedSubscription;

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    notifyListeners();

    _pendingSubscription = _repository.watchPendingBookings().listen(
      (items) async {
        pendingBookings = items;
        await _loadUserNames();
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

    _approvedSubscription = _repository.watchApprovedBookings().listen(
      (items) async {
        approvedBookings = items;
        await _loadUserNames();
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

  Future<void> deleteBooking(String bookingId) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.deleteBooking(bookingId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> proposeBookingUpdate({
    required String bookingId,
    required DateTime selectedDate,
    required List<String> selectedSlots,
    String? groupId,
    required int peopleCount,
    required String equipment,
  }) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.proposeBookingUpdate(
        bookingId: bookingId,
        date: selectedDate.toIso8601String().split('T').first,
        selectedSlotTimes: selectedSlots,
        groupId: groupId,
        peopleCount: peopleCount,
        equipment: equipment,
      );
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserNames() async {
    final userIds = {
      ...pendingBookings.map((item) => item.booking.userId),
      ...approvedBookings.map((item) => item.booking.userId),
    };
    if (userIds.isEmpty) {
      return;
    }
    try {
      final names = await _repository.getUsernames(userIds);
      userNames.addAll(names);
    } catch (_) {
      // Ignoriamo gli errori di fetch dei nomi
    }
  }

  @override
  void dispose() {
    _pendingSubscription?.cancel();
    _approvedSubscription?.cancel();
    super.dispose();
  }
}
