import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/notifications/notifications_repository.dart';
import 'package:soundimplosion/firebase_options.dart';
import 'package:soundimplosion/services/database_service.dart';

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
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
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
      case 'group_booking_modified':
      case 'group_booking_confirmed':
      case 'group_booking_cancelled':
      case 'booking_confirmed':
      case 'booking_cancelled':
      case 'admin_booking_created':
      case 'admin_booking_modified':
      case 'admin_booking_cancelled':
      case 'admin_booking_update_proposed':
      case 'admin_booking_update_accepted':
      case 'admin_booking_update_rejected':
      case 'booking_update_proposal':
        return NotificationCategory.bookings;
      case 'group_jam_created':
      case 'group_jam_modified':
      case 'group_jam_approved':
      case 'group_jam_rejected':
      case 'jam_approved':
      case 'jam_rejected':
      case 'admin_jam_created':
      case 'admin_jam_modified':
      case 'admin_jam_cancelled':
      case 'admin_jam_update_proposed':
      case 'admin_jam_update_accepted':
      case 'admin_jam_update_rejected':
      case 'jam_update_proposal':
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
    if (type == 'support_chat_message') {
      return 7;
    }
    if (type?.startsWith('admin_') == true) {
      return 4;
    }
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

  String? _bookingIdForType(Map<String, dynamic> data) {
    final type = data['type'];
    return _categoryForType(type) == NotificationCategory.bookings
        ? data['booking_id'] ?? data['subject_id'] ?? data['notification_id']
        : null;
  }

  String? _jamIdForType(Map<String, dynamic> data) {
    final type = data['type'];
    return _categoryForType(type) == NotificationCategory.jams
        ? data['jam_id'] ?? data['subject_id'] ?? data['notification_id']
        : null;
  }

  String? _payloadFromMessage(RemoteMessage? message) {
    if (message == null) {
      return null;
    }

    return NotificationRouteTarget(
      pageIndex: _pageIndexForType(message.data['type']),
      bookingId: _bookingIdForType(message.data),
      jamId: _jamIdForType(message.data),
      groupId: message.data['group_id'],
      chatId: message.data['chat_id'],
    ).toPayload();
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    _initialized = false;
  }
}
