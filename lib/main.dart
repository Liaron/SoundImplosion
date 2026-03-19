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
        ? const Color(0xFF0F111A)
        : (prefs.highContrast ? Colors.white : const Color(0xFFF9F9FB));
    final surface = isDark
        ? const Color(0xFF1B1D29)
        : (prefs.highContrast ? Colors.white : Colors.white);
    final textColor = isDark ? const Color(0xFFE0E6ED) : const Color(0xFF1A1A24);
    final primary = isDark ? const Color(0xFF00E5FF) : const Color(0xFF0044CC);
    final secondary = isDark ? const Color(0xFFFF2A5F) : const Color(0xFFD60036);
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
        displayLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 32),
        displayMedium: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 24),
        displaySmall: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
        headlineLarge: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 22),
        headlineMedium: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 18),
        headlineSmall: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16),
        titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 18),
        titleMedium: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 16),
        titleSmall: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge: TextStyle(color: textColor, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(color: textColor, fontSize: 14, height: 1.5),
        bodySmall: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, height: 1.4),
        labelLarge: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 14),
        labelMedium: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 12),
        labelSmall: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500, fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 2 : 4,
        shadowColor: isDark ? Colors.black54 : Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? const Color(0xFF69F0AE) : const Color(0xFF4CAF50); // Green
          }
          return isDark ? const Color(0xFFFF5252) : const Color(0xFFF44336); // Red
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? const Color(0xFF69F0AE).withValues(alpha: 0.3) : const Color(0xFF4CAF50).withValues(alpha: 0.3);
          }
          return isDark ? const Color(0xFFFF5252).withValues(alpha: 0.3) : const Color(0xFFF44336).withValues(alpha: 0.3);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textColor,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textColor.withValues(alpha: 0.6),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: textColor.withValues(alpha: 0.6)),
        selectedLabelTextStyle: TextStyle(color: primary),
        unselectedLabelTextStyle: TextStyle(color: textColor.withValues(alpha: 0.6)),
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
