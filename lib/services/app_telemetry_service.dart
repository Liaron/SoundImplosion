import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppTelemetryService {
  AppTelemetryService._();

  static final AppTelemetryService instance = AppTelemetryService._();

  NavigatorObserver? _observer;

  FirebaseAnalytics? get _analyticsOrNull {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseCrashlytics? get _crashlyticsOrNull {
    try {
      return FirebaseCrashlytics.instance;
    } catch (_) {
      return null;
    }
  }

  NavigatorObserver get navigatorObserver =>
      _observer ??=
          (_analyticsOrNull != null
              ? FirebaseAnalyticsObserver(analytics: _analyticsOrNull!)
              : NavigatorObserver());

  Future<void> initialize() async {
    await _crashlyticsOrNull?.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  }

  Future<void> syncCurrentUser(User? user) async {
    await _analyticsOrNull?.setUserId(id: user?.uid);
  }

  Future<void> logLogin({required String method}) {
    return _analyticsOrNull?.logLogin(loginMethod: method) ?? Future.value();
  }

  Future<void> logSignUp({required String method}) {
    return _analyticsOrNull?.logSignUp(signUpMethod: method) ?? Future.value();
  }

  Future<void> logCreateGroup({required bool hasDescription}) {
    return logEvent(
      'create_group',
      parameters: {'has_description': hasDescription},
    );
  }

  Future<void> logInviteGroup() {
    return logEvent('invite_group');
  }

  Future<void> logBookingCreated({required bool isGroupBooking}) {
    return logEvent(
      'create_booking',
      parameters: {'is_group_booking': isGroupBooking},
    );
  }

  Future<void> logBookingUpdated({required bool isGroupBooking}) {
    return logEvent(
      'update_booking',
      parameters: {'is_group_booking': isGroupBooking},
    );
  }

  Future<void> logJamCreated({required bool hasGroup}) {
    return logEvent('create_jam', parameters: {'has_group': hasGroup});
  }

  Future<void> logJamUpdated({required bool hasGroup}) {
    return logEvent('update_jam', parameters: {'has_group': hasGroup});
  }

  Future<void> logEmailChangeRequested() {
    return logEvent('request_email_change');
  }

  Future<void> logPasswordUpdated() {
    return logEvent('update_password');
  }

  Future<void> logPasswordResetRequested() {
    return logEvent('request_password_reset');
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
  }) async {
    final analytics = _analyticsOrNull;
    if (analytics == null) {
      return;
    }
    final filtered = <String, Object>{};
    for (final entry in (parameters ?? const <String, Object?>{}).entries) {
      final value = entry.value;
      if (value is String) {
        filtered[entry.key] = value;
      } else if (value is int) {
        filtered[entry.key] = value;
      } else if (value is double) {
        filtered[entry.key] = value;
      } else if (value is bool) {
        filtered[entry.key] = value ? 1 : 0;
      }
    }
    await analytics.logEvent(name: name, parameters: filtered);
  }

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    return _crashlyticsOrNull?.recordError(
          error,
          stackTrace,
          reason: reason,
          fatal: fatal,
        ) ??
        Future.value();
  }

  void recordFlutterError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _crashlyticsOrNull?.recordFlutterFatalError(details);
  }
}
