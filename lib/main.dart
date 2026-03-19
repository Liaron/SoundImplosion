import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:soundimplosion/app/features/app_scaffold_mobile.dart';
import 'package:soundimplosion/app/startup_loading_screen.dart';
import 'firebase_options.dart';
import 'package:soundimplosion/app/features/home/auth_page_mobile.dart';
import 'package:soundimplosion/services/app_preferences_service.dart';
import 'package:soundimplosion/services/firebase_auth.dart';
import 'package:soundimplosion/services/local_notification_service.dart';
import 'package:soundimplosion/services/app_telemetry_service.dart';
import 'package:soundimplosion/services/push_notification_service.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FlutterError.onError = AppTelemetryService.instance.recordFlutterError;
      runApp(const MyApp());
      _configureErrorHandling();
      _initializeBackgroundServices();
    },
    (error, stackTrace) {
      unawaited(
        AppTelemetryService.instance.recordError(
          error,
          stackTrace,
          reason: 'runZonedGuarded',
          fatal: true,
        ),
      );
    },
  );
}

void _configureErrorHandling() {
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      AppTelemetryService.instance.recordError(
        error,
        stackTrace,
        reason: 'PlatformDispatcher.onError',
        fatal: true,
      ),
    );
    return true;
  };
}

void _initializeBackgroundServices() {
  unawaited(
    _runStartupTask(
      'app telemetry',
      () => AppTelemetryService.instance.initialize(),
    ),
  );
  AuthService().authStateChanges.listen(AppTelemetryService.instance.syncCurrentUser);
  unawaited(
    _runStartupTask(
      'local notifications',
      () => LocalNotificationService.instance.initialize().timeout(
        const Duration(seconds: 5),
      ),
    ),
  );
  unawaited(
    _runStartupTask(
      'push notifications',
      () => PushNotificationService.instance.initialize().timeout(
        const Duration(seconds: 8),
      ),
    ),
  );
}

Future<void> _runStartupTask(
  String label,
  Future<void> Function() task,
) async {
  try {
    await task();
  } catch (error, stackTrace) {
    debugPrint('Startup task failed ($label): $error');
    await AppTelemetryService.instance.recordError(
      error,
      stackTrace,
      reason: 'Startup task failed: $label',
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final prefs = AppPreferencesService.instance;
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF111111)
        : (prefs.highContrast ? Colors.white : const Color(0xFFF7F7F7));
    final surface = isDark
        ? const Color(0xFF1E1E1E)
        : (prefs.highContrast ? Colors.white : const Color(0xFFF7F7F7));
    final textColor = isDark ? Colors.white : Colors.black;
    final primary = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final secondary = const Color(0xFFE63946);

    return ThemeData(
      brightness: brightness,
      primaryColor: primary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: secondary,
        onSecondary: Colors.white,
        error: Colors.red.shade700,
        onError: Colors.white,
        surface: surface,
        onSurface: textColor,
      ),
      scaffoldBackgroundColor: background,
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: textColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Color(0xFFE63946),
        unselectedItemColor: Color(0xFFFFFFFF),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedIconTheme: IconThemeData(color: Color(0xFFE63946)),
        unselectedIconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
        selectedLabelTextStyle: TextStyle(color: Color(0xFFE63946)),
        unselectedLabelTextStyle: TextStyle(color: Color(0xFFFFFFFF)),
      ),
      pageTransitionsTheme: prefs.reduceMotion
          ? const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
              },
            )
          : const PageTransitionsTheme(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferencesService.instance,
      builder: (context, _) {
        final prefs = AppPreferencesService.instance;
        return MaterialApp(
          title: 'SoundImplosion',
          themeMode: prefs.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          navigatorObservers: [AppTelemetryService.instance.navigatorObserver],
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(prefs.textScale),
                disableAnimations: prefs.reduceMotion,
              ),
              child: child!,
            );
          },
          home: StreamBuilder(
            stream: AuthService().authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.active) {
                if (snapshot.hasData) {
                  return const AppScaffoldMobile();
                }
                return const AuthPageMobile();
              }
              return const StartupLoadingScreen();
            },
          ),
        );
      },
    );
  }
}
