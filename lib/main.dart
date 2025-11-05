import 'package:flutter/material.dart';
import 'package:flutter_device_type/flutter_device_type.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:soundimplosion/app/features/app_scaffold_mobile.dart';
import 'firebase_options.dart';
import 'package:soundimplosion/app/auth_wrapper.dart';
import 'package:soundimplosion/app/features/home/auth_page_mobile.dart';
import 'package:soundimplosion/app/features/home/home_page_mobile.dart';
import 'package:soundimplosion/services/firebase_auth.dart';
import 'package:soundimplosion/platform_layout.dart';
import 'package:soundimplosion/web/web_scaffold_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundImplosion',
      theme: ThemeData(
        primaryColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E1E1E),
          secondary: Color(0xFFE63946),
          tertiary: Color(0xFFFFD166),
          background: Color(0xFFF7F7F7),
          onPrimary: Color(0xFFFFFFFF),
          onSecondary: Color(0xFFFFFFFF),
          onTertiary: Color(0xFF222222),
          onBackground: Color(0xFF222222),
          surface: Color(0xFFF7F7F7),
          onSurface: Color(0xFF222222),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF222222)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Color(0xFFFFFFFF),
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
      ),
      home: StreamBuilder(
          stream: AuthService().authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              if (snapshot.hasData) {
                return const AppScaffoldMobile();
              }
              return const AuthPageMobile();
            }
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
      ),
    );
  }
}
