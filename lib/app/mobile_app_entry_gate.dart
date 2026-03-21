import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/app_scaffold_mobile.dart';
import 'package:soundimplosion/app/features/home/auth_page_mobile.dart';
import 'package:soundimplosion/app/force_update_required_screen.dart';
import 'package:soundimplosion/app/startup_loading_screen.dart';
import 'package:soundimplosion/services/app_update_service.dart';
import 'package:soundimplosion/services/firebase_auth.dart';

class MobileAppEntryGate extends StatefulWidget {
  const MobileAppEntryGate({super.key});

  @override
  State<MobileAppEntryGate> createState() => _MobileAppEntryGateState();
}

class _MobileAppEntryGateState extends State<MobileAppEntryGate>
    with WidgetsBindingObserver {
  late Future<AppUpdateStatus> _updateCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateCheck = AppUpdateService.instance.checkForRequiredUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshUpdateCheck();
    }
  }

  void _refreshUpdateCheck() {
    setState(() {
      _updateCheck = AppUpdateService.instance.checkForRequiredUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUpdateStatus>(
      future: _updateCheck,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const StartupLoadingScreen();
        }

        final status = snapshot.data!;
        if (status.requiresUpdate) {
          return ForceUpdateRequiredScreen(
            status: status,
            onRetry: () async => _refreshUpdateCheck(),
          );
        }

        return StreamBuilder(
          stream: AuthService().authStateChanges,
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.active) {
              if (authSnapshot.hasData) {
                return const AppScaffoldMobile();
              }
              return const AuthPageMobile();
            }
            return const StartupLoadingScreen();
          },
        );
      },
    );
  }
}