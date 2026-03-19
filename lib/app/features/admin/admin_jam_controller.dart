import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/admin/admin_jam_repository.dart';
import 'package:soundimplosion/app/features/jam/jam_repository.dart';

class AdminJamController extends ChangeNotifier {
  AdminJamController({AdminJamRepository? repository})
    : _repository = repository ?? FirebaseAdminJamRepository();

  final AdminJamRepository _repository;

  bool isLoading = true;
  bool isSubmitting = false;
  Object? error;
  List<JamListItem> pendingJams = [];
  List<JamListItem> approvedJams = [];

  StreamSubscription<List<JamListItem>>? _pendingSubscription;
  StreamSubscription<List<JamListItem>>? _approvedSubscription;

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    notifyListeners();

    _pendingSubscription = _repository.watchPendingJams().listen(
      (items) {
        pendingJams = items;
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

    _approvedSubscription = _repository.watchApprovedJams().listen(
      (items) {
        approvedJams = items;
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

  Future<void> approveJam(String jamId) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.approveJam(jamId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> rejectJam(String jamId) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.rejectJam(jamId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> deleteJam(String jamId) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.deleteJam(jamId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> proposeJamUpdate({
    required String jamId,
    required DateTime selectedDate,
    required List<String> selectedSlots,
    String? groupId,
    required String title,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String payment,
    required String equipment,
  }) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.proposeJamUpdate(
        jamId: jamId,
        date: selectedDate.toIso8601String().split('T').first,
        selectedSlotTimes: selectedSlots,
        groupId: groupId,
        title: title,
        presentPeople: presentPeople,
        requiredPeople: requiredPeople,
        description: description,
        payment: payment,
        equipment: equipment,
      );
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pendingSubscription?.cancel();
    _approvedSubscription?.cancel();
    super.dispose();
  }
}
