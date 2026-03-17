import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/notifications/notifications_repository.dart';
import 'package:soundimplosion/services/local_notification_service.dart';

class SettingsPageMobile extends StatefulWidget {
  const SettingsPageMobile({super.key});

  @override
  State<SettingsPageMobile> createState() => _SettingsPageMobileState();
}

class _SettingsPageMobileState extends State<SettingsPageMobile> {
  final NotificationsRepository _repository = FirebaseNotificationsRepository();
  bool _isLoading = true;
  NotificationPreferences _preferences = const NotificationPreferences();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await _repository.loadPreferences();
    if (!mounted) {
      return;
    }
    setState(() {
      _preferences = preferences;
      _isLoading = false;
    });
  }

  Future<void> _updatePreferences(NotificationPreferences preferences) async {
    setState(() {
      _preferences = preferences;
    });
    await _repository.savePreferences(preferences);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Impostazioni'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Generale'),
              Tab(text: 'Notifiche'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const Center(child: Text('Impostazioni generali in arrivo.')),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  value: _preferences.inAppEnabled,
                  title: const Text('Popup in-app'),
                  subtitle: const Text(
                    'Mostra avvisi rapidi mentre usi l’app.',
                  ),
                  onChanged: (value) {
                    _updatePreferences(
                      _preferences.copyWith(inAppEnabled: value),
                    );
                  },
                ),
                SwitchListTile(
                  value: _preferences.systemEnabled,
                  title: const Text('Notifiche di sistema'),
                  subtitle: const Text(
                    'Mostra banner e barra notifiche quando arriva un evento.',
                  ),
                  onChanged: (value) async {
                    if (value) {
                      await LocalNotificationService.instance
                          .requestPermissions();
                    }
                    await _updatePreferences(
                      _preferences.copyWith(systemEnabled: value),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
