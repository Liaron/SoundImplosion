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

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  String? _lastSyncedUid;

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
          await _databaseService.removeDeviceToken(_lastSyncedUid!, token);
        }
        _lastSyncedUid = null;
        return;
      }

      await _syncTokenForCurrentUser();
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      await _syncToken(token);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      final preferences = await _notificationsRepository.loadPreferences();
      if (!preferences.systemEnabled) {
        return;
      }

      final title = message.notification?.title ?? 'Nuova notifica';
      final body = message.notification?.body ?? 'Hai un nuovo aggiornamento.';
      await LocalNotificationService.instance.showRawNotification(
        id: title.hashCode ^ body.hashCode,
        title: title,
        body: body,
      );
    });

    _initialized = true;
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

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _initialized = false;
  }
}
