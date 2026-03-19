import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/notifications/notifications_repository.dart';
import 'package:soundimplosion/firebase_options.dart';
import 'package:soundimplosion/services/database_service.dart';
import 'package:soundimplosion/services/local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();
  final NotificationsRepository _notificationsRepository =
      FirebaseNotificationsRepository();
  final StreamController<String> _openedPayloadController =
      StreamController<String>.broadcast();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  bool _initialized = false;
  String? _lastSyncedUid;
  String? _initialPayload;

  Stream<String> get openedPayloadStream => _openedPayloadController.stream;

  String? takeInitialPayload() {
    final payload = _initialPayload;
    _initialPayload = null;
    return payload;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _syncTokenForCurrentUser();

    _authSubscription = _auth.authStateChanges().listen((user) async {
      final token = await _messaging.getToken();
      if (user == null) {
        if (_lastSyncedUid != null && token != null) {
          try {
            await _databaseService.removeDeviceToken(_lastSyncedUid!, token);
          } catch (error) {
            debugPrint(
              'Push token cleanup skipped after sign-out: $error',
            );
          }
        }
        _lastSyncedUid = null;
        return;
      }

      await _syncTokenForCurrentUser();
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      await _syncToken(token);
    });

    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      final payload = _payloadFromMessage(message);
      if (payload != null) {
        _openedPayloadController.add(payload);
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    _initialPayload = _payloadFromMessage(initialMessage);

    FirebaseMessaging.onMessage.listen((message) async {
      final preferences = await _notificationsRepository.loadPreferences();
      final payload = _payloadFromMessage(message);
      final routeTarget = NotificationRouteTarget.fromPayload(payload);
      final category = _categoryForType(message.data['type']);

      if (routeTarget == null ||
          !preferences.systemEnabled ||
          !preferences.allowsCategory(category)) {
        return;
      }

      final title = message.notification?.title ?? 'Nuova notifica';
      final body = message.notification?.body ?? 'Hai un nuovo aggiornamento.';
      await LocalNotificationService.instance.showRawNotification(
        id: title.hashCode ^ body.hashCode,
        title: title,
        body: body,
        payload: payload,
      );
    });

    _initialized = true;
  }

  Future<void> unregisterCurrentDeviceToken() async {
    final user = _auth.currentUser;
    final token = await _messaging.getToken();
    if (user == null || token == null || token.isEmpty) {
      return;
    }

    await _databaseService.removeDeviceToken(user.uid, token);
    if (_lastSyncedUid == user.uid) {
      _lastSyncedUid = null;
    }
  }

  Future<void> _syncTokenForCurrentUser() async {
    final token = await _messaging.getToken();
    if (token == null) {
      return;
    }
    await _syncToken(token);
  }

  Future<void> _syncToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    _lastSyncedUid = user.uid;
    await _databaseService.saveDeviceToken(
      token,
      platform: kIsWeb
          ? 'web'
          : (defaultTargetPlatform == TargetPlatform.android
                ? 'android'
                : (defaultTargetPlatform == TargetPlatform.iOS
                      ? 'ios'
                      : 'unknown')),
    );
  }

  NotificationCategory _categoryForType(String? type) {
    switch (type) {
      case 'booking_created':
      case 'booking_confirmed':
      case 'booking_cancelled':
        return NotificationCategory.bookings;
      case 'jam_approved':
      case 'jam_rejected':
        return NotificationCategory.jams;
      case 'group_invite':
      case 'group_invite_accepted':
      case 'group_invite_rejected':
        return NotificationCategory.groups;
      default:
        return NotificationCategory.system;
    }
  }

  int _pageIndexForType(String? type) {
    switch (_categoryForType(type)) {
      case NotificationCategory.bookings:
        return 1;
      case NotificationCategory.jams:
        return 2;
      case NotificationCategory.groups:
        return 3;
      case NotificationCategory.system:
        return 5;
    }
  }

  String? _bookingIdForType(String? type, String? notificationId) {
    return _categoryForType(type) == NotificationCategory.bookings
        ? notificationId
        : null;
  }

  String? _jamIdForType(String? type, String? notificationId) {
    return _categoryForType(type) == NotificationCategory.jams
        ? notificationId
        : null;
  }

  String? _payloadFromMessage(RemoteMessage? message) {
    if (message == null) {
      return null;
    }

    return NotificationRouteTarget(
      pageIndex: _pageIndexForType(message.data['type']),
      bookingId: _bookingIdForType(
        message.data['type'],
        message.data['notification_id'],
      ),
      jamId: _jamIdForType(message.data['type'], message.data['notification_id']),
      groupId: message.data['group_id'],
    ).toPayload();
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    _initialized = false;
  }
}
