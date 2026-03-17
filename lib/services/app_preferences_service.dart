import 'package:flutter/material.dart';

class AppPreferencesService extends ChangeNotifier {
  AppPreferencesService._();

  static final AppPreferencesService instance = AppPreferencesService._();

  ThemeMode _themeMode = ThemeMode.system;
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _reduceMotion = false;
  bool _bookingRemindersEnabled = true;
  int _bookingReminderMinutes = 60;

  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;
  bool get bookingRemindersEnabled => _bookingRemindersEnabled;
  int get bookingReminderMinutes => _bookingReminderMinutes;

  void applyUserPreferences(Map<String, dynamic> preferences) {
    final general = _asStringKeyedMap(preferences['general']);
    final accessibility = _asStringKeyedMap(general['accessibility']);

    final nextThemeMode = _parseThemeMode(general['theme_mode']?.toString());
    final nextTextScale = _parseTextScale(accessibility['text_scale']);
    final nextHighContrast = accessibility['high_contrast'] == true;
    final nextReduceMotion = accessibility['reduce_motion'] == true;
    final nextBookingRemindersEnabled =
        general['booking_reminders_enabled'] != false;
    final nextBookingReminderMinutes = _parseReminderMinutes(
      general['booking_reminder_minutes'],
    );

    if (_themeMode == nextThemeMode &&
        _textScale == nextTextScale &&
        _highContrast == nextHighContrast &&
        _reduceMotion == nextReduceMotion &&
        _bookingRemindersEnabled == nextBookingRemindersEnabled &&
        _bookingReminderMinutes == nextBookingReminderMinutes) {
      return;
    }

    _themeMode = nextThemeMode;
    _textScale = nextTextScale;
    _highContrast = nextHighContrast;
    _reduceMotion = nextReduceMotion;
    _bookingRemindersEnabled = nextBookingRemindersEnabled;
    _bookingReminderMinutes = nextBookingReminderMinutes;
    notifyListeners();
  }

  void updateThemeMode(ThemeMode themeMode) {
    if (_themeMode == themeMode) {
      return;
    }
    _themeMode = themeMode;
    notifyListeners();
  }

  void updateAccessibility({
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
  }) {
    final nextTextScale = _parseTextScale(textScale);
    final nextHighContrast = highContrast ?? _highContrast;
    final nextReduceMotion = reduceMotion ?? _reduceMotion;
    if (_textScale == nextTextScale &&
        _highContrast == nextHighContrast &&
        _reduceMotion == nextReduceMotion) {
      return;
    }
    _textScale = nextTextScale;
    _highContrast = nextHighContrast;
    _reduceMotion = nextReduceMotion;
    notifyListeners();
  }

  void updateBookingReminders({bool? enabled, int? minutes}) {
    final nextEnabled = enabled ?? _bookingRemindersEnabled;
    final nextMinutes = _parseReminderMinutes(minutes);
    if (_bookingRemindersEnabled == nextEnabled &&
        _bookingReminderMinutes == nextMinutes) {
      return;
    }
    _bookingRemindersEnabled = nextEnabled;
    _bookingReminderMinutes = nextMinutes;
    notifyListeners();
  }

  static Map<String, dynamic> _asStringKeyedMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static double _parseTextScale(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return 1.0;
    }
    return parsed.clamp(0.9, 1.4);
  }

  static int _parseReminderMinutes(dynamic value) {
    final parsed = value is int
        ? value
        : int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return 60;
    }
    const allowed = <int>{15, 30, 60, 120, 180, 1440};
    return allowed.contains(parsed) ? parsed : 60;
  }
}
