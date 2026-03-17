import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/notifications/notifications_repository.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController({NotificationsRepository? repository})
    : _repository = repository ?? FirebaseNotificationsRepository();

  final NotificationsRepository _repository;

  bool isLoading = true;
  Object? error;
  List<AppNotificationItem> notifications = [];
  StreamSubscription<List<AppNotificationItem>>? _subscription;

  int get unreadCount => notifications.where((item) => !item.isRead).length;

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    notifyListeners();

    _subscription = _repository.watchNotifications().listen(
      (items) {
        notifications = items;
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

  Future<void> markAsRead(String notificationId) {
    return _repository.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() {
    return _repository.markAllAsRead();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
