import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/notifications/notifications_repository.dart';
import 'package:soundimplosion/app/features/profile/profile_repository.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/app_preferences_service.dart';
import 'package:soundimplosion/services/app_telemetry_service.dart';
import 'package:soundimplosion/services/database_service.dart';
import 'package:soundimplosion/services/firebase_auth.dart';
import 'package:soundimplosion/services/local_notification_service.dart';

class SettingsPageMobile extends StatefulWidget {
  const SettingsPageMobile({super.key});

  @override
  State<SettingsPageMobile> createState() => _SettingsPageMobileState();
}

class _SettingsPageMobileState extends State<SettingsPageMobile> {
  final NotificationsRepository _notificationsRepository =
      FirebaseNotificationsRepository();
  final ProfileRepository _profileRepository = FirebaseProfileRepository();
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  bool _isLoading = true;
  bool _isSavingGeneral = false;
  NotificationPreferences _notificationPreferences =
      const NotificationPreferences();
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final results = await Future.wait<dynamic>([
      _notificationsRepository.loadPreferences(),
      _profileRepository.loadProfile(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _notificationPreferences = results[0] as NotificationPreferences;
      _user = results[1] as AppUser?;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile(AppUser updatedUser) async {
    setState(() {
      _isSavingGeneral = true;
    });

    try {
      await _profileRepository.saveProfile(updatedUser);
      AppPreferencesService.instance.applyUserPreferences(
        updatedUser.preferenze,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _user = updatedUser;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingGeneral = false;
        });
      }
    }
  }

  Map<String, dynamic> _generalPreferences([AppUser? user]) {
    final currentPreferences = user?.preferenze ?? _user?.preferenze ?? const {};
    final general = currentPreferences['general'];
    if (general is Map) {
      return Map<String, dynamic>.from(general);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _accessibilityPreferences([AppUser? user]) {
    final accessibility = _generalPreferences(user)['accessibility'];
    if (accessibility is Map) {
      return Map<String, dynamic>.from(accessibility);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _profilePreferences([AppUser? user]) {
    final currentPreferences = user?.preferenze ?? _user?.preferenze ?? const {};
    final profile = currentPreferences['profile'];
    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }
    return <String, dynamic>{};
  }

  Future<void> _updateGeneralPreferences({
    String? city,
    ThemeMode? themeMode,
    bool? bookingRemindersEnabled,
    int? bookingReminderMinutes,
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
  }) async {
    final currentUser = _user;
    if (currentUser == null) {
      return;
    }

    final preferences = Map<String, dynamic>.from(currentUser.preferenze);
    final general = _generalPreferences(currentUser);
    final accessibility = _accessibilityPreferences(currentUser);

    if (city != null) {
      general['city'] = city;
    }
    if (themeMode != null) {
      general['theme_mode'] = themeMode.name;
    }
    if (bookingRemindersEnabled != null) {
      general['booking_reminders_enabled'] = bookingRemindersEnabled;
    }
    if (bookingReminderMinutes != null) {
      general['booking_reminder_minutes'] = bookingReminderMinutes;
    }
    if (textScale != null) {
      accessibility['text_scale'] = textScale;
    }
    if (highContrast != null) {
      accessibility['high_contrast'] = highContrast;
    }
    if (reduceMotion != null) {
      accessibility['reduce_motion'] = reduceMotion;
    }

    general['accessibility'] = accessibility;
    preferences['general'] = general;

    await _saveProfile(currentUser.copyWith(preferenze: preferences));
  }

  Future<void> _updateExtendedProfilePreferences({
    String? bio,
    List<String>? genres,
    String? skillLevel,
    List<String>? availability,
  }) async {
    final currentUser = _user;
    if (currentUser == null) {
      return;
    }

    final preferences = Map<String, dynamic>.from(currentUser.preferenze);
    final profile = _profilePreferences(currentUser);

    if (bio != null) {
      profile['bio'] = bio;
    }
    if (genres != null) {
      profile['genres'] = genres;
    }
    if (skillLevel != null) {
      profile['skill_level'] = skillLevel;
    }
    if (availability != null) {
      profile['availability'] = availability;
    }

    preferences['profile'] = profile;
    await _saveProfile(currentUser.copyWith(preferenze: preferences));
  }

  Future<void> _requestEmailChange() async {
    final currentUser = _user;
    if (currentUser == null) {
      return;
    }

    final emailController = TextEditingController(text: currentUser.email ?? '');
    final passwordController = TextEditingController();
    final requiresPassword = _authService.isPasswordProviderLinked;
    final messenger = ScaffoldMessenger.of(context);
    final result =
        await showDialog<({String newEmail, String currentPassword})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifica email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Nuova email'),
            ),
            const SizedBox(height: 12),
            if (requiresPassword)
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password attuale',
                ),
              )
            else
              const Text(
                'Per confermare la modifica verra richiesta una nuova autenticazione con il provider collegato.',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, (
              newEmail: emailController.text.trim(),
              currentPassword: passwordController.text,
            )),
            child: const Text('Invia verifica'),
          ),
        ],
      ),
    );

    final newEmail = result?.newEmail.trim() ?? '';
    if (newEmail.isEmpty || newEmail == currentUser.email) {
      return;
    }

    try {
      final isAvailable = await _databaseService.isEmailAvailable(
        newEmail,
        excludingUid: currentUser.uid,
      );
      if (!isAvailable) {
        throw Exception('Questa email e gia registrata');
      }

      await _authService.requestEmailChangeWithReauthentication(
        newEmail: newEmail,
        currentPassword: result?.currentPassword,
      );
      await AppTelemetryService.instance.logEmailChangeRequested();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "Email di conferma inviata a $newEmail. Dopo la verifica, l'account verra aggiornato.",
          ),
        ),
      );
    } catch (e, stackTrace) {
      await AppTelemetryService.instance.recordError(
        e,
        stackTrace,
        reason: 'Email change request failed',
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _updatePassword() async {
    final user = _authService.currentUser;
    if (user == null || !_authService.isPasswordProviderLinked) {
      return;
    }

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<
      ({String currentPassword, String newPassword, String confirmPassword})
    >(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifica password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password attuale',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nuova password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Conferma nuova password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, (
              currentPassword: currentPasswordController.text,
              newPassword: newPasswordController.text,
              confirmPassword: confirmPasswordController.text,
            )),
            child: const Text('Aggiorna'),
          ),
        ],
      ),
    );

    if (result == null) {
      return;
    }

    final newPassword = result.newPassword.trim();
    if (newPassword.length < 6) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('La nuova password deve essere di almeno 6 caratteri'),
        ),
      );
      return;
    }
    if (newPassword != result.confirmPassword.trim()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Le nuove password non coincidono')),
      );
      return;
    }

    try {
      await _authService.updatePassword(
        newPassword: newPassword,
        currentPassword: result.currentPassword,
      );
      await AppTelemetryService.instance.logPasswordUpdated();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Password aggiornata correttamente')),
      );
    } catch (e, stackTrace) {
      await AppTelemetryService.instance.recordError(
        e,
        stackTrace,
        reason: 'Password update failed',
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _updateUsername() async {
    final currentUser = _user;
    if (currentUser == null) {
      return;
    }

    final controller = TextEditingController(text: currentUser.nickname);
    final messenger = ScaffoldMessenger.of(context);
    final newUsername = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifica username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (newUsername == null || newUsername.isEmpty || newUsername == currentUser.nickname) {
      return;
    }

    try {
      await _saveProfile(currentUser.copyWith(nickname: newUsername));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _updateCity() async {
    final currentUser = _user;
    if (currentUser == null) {
      return;
    }

    final controller = TextEditingController(
      text: _generalPreferences(currentUser)['city']?.toString() ?? '',
    );
    final newCity = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Citta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Citta'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (newCity == null) {
      return;
    }

    await _updateGeneralPreferences(city: newCity);
  }

  Future<void> _updateBio() async {
    final controller = TextEditingController(
      text: _profilePreferences(_user)['bio']?.toString() ?? '',
    );
    final newBio = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bio'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Bio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (newBio == null) {
      return;
    }
    await _updateExtendedProfilePreferences(bio: newBio);
  }

  Future<void> _updateGenres() async {
    final currentGenres = _profilePreferences(_user)['genres'];
    final controller = TextEditingController(
      text: currentGenres is List ? currentGenres.join(', ') : '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generi musicali'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Generi',
            hintText: 'Rock, Jazz, Blues',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (value == null) {
      return;
    }
    final genres = value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    await _updateExtendedProfilePreferences(genres: genres);
  }

  Future<void> _updateSkillLevel() async {
    const levels = [
      'Principiante',
      'Intermedio',
      'Avanzato',
      'Professionista',
    ];
    final currentLevel =
        _profilePreferences(_user)['skill_level']?.toString() ??
        'Non specificato';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Livello'),
        children: levels
            .map(
              (level) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, level),
                child: Row(
                  children: [
                    Icon(
                      level == currentLevel
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    const SizedBox(width: 12),
                    Text(level),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );

    if (selected == null) {
      return;
    }
    await _updateExtendedProfilePreferences(skillLevel: selected);
  }

  Future<void> _updateAvailability() async {
    final raw = _profilePreferences(_user)['availability'];
    final controller = TextEditingController(
      text: raw is List ? raw.join(', ') : '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disponibilita'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Disponibilita',
            hintText: 'Mattina, Pomeriggio, Sera',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (value == null) {
      return;
    }
    final availability = value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    await _updateExtendedProfilePreferences(availability: availability);
  }

  Future<void> _sendPasswordReset() async {
    final email = _authService.currentUser?.email ?? _user?.email;
    if (email == null || email.isEmpty) {
      return;
    }

    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    await AppTelemetryService.instance.logPasswordResetRequested();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Email di reset inviata a $email')),
    );
  }

  Future<void> _updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    setState(() {
      _notificationPreferences = preferences;
    });
    await _notificationsRepository.savePreferences(preferences);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina account'),
        content: const Text(
          'L’account verra eliminato insieme a prenotazioni, jam, partecipazioni e riferimenti collegati. Vuoi continuare?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _profileRepository.deleteProfile();
    } catch (e, stackTrace) {
      await AppTelemetryService.instance.recordError(
        e,
        stackTrace,
        reason: 'Account deletion failed',
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = _user;
    final general = _generalPreferences(user);
    final accessibility = _accessibilityPreferences(user);
    final themeService = AppPreferencesService.instance;
    final city = general['city']?.toString() ?? '';
    final profile = _profilePreferences(user);
    final bio = profile['bio']?.toString() ?? '';
    final genres = profile['genres'] is List
        ? List<String>.from(profile['genres'] as List)
        : const <String>[];
    final skillLevel =
        profile['skill_level']?.toString() ?? 'Non specificato';
    final availability = profile['availability'] is List
        ? List<String>.from(profile['availability'] as List)
        : const <String>[];
    final bookingRemindersEnabled =
        general['booking_reminders_enabled'] as bool? ?? true;
    final bookingReminderMinutes =
        general['booking_reminder_minutes'] as int? ??
        themeService.bookingReminderMinutes;
    final textScale =
        (accessibility['text_scale'] as num?)?.toDouble() ?? themeService.textScale;
    final highContrast =
        accessibility['high_contrast'] as bool? ?? themeService.highContrast;
    final reduceMotion =
        accessibility['reduce_motion'] as bool? ?? themeService.reduceMotion;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Impostazioni'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Generale'),
              Tab(text: 'Notifiche'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_isSavingGeneral) const LinearProgressIndicator(),
                _buildSection(
                  title: 'Aspetto',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tema'),
                      subtitle: const Text('Scegli come visualizzare l’app.'),
                      trailing: DropdownButton<ThemeMode>(
                        value: themeService.themeMode,
                        onChanged: (value) async {
                          if (value == null) {
                            return;
                          }
                          themeService.updateThemeMode(value);
                          await _updateGeneralPreferences(themeMode: value);
                        },
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text('Sistema'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('Chiaro'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Scuro'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Profilo',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Username'),
                      subtitle: Text(user?.nickname ?? '-'),
                      trailing: TextButton(
                        onPressed: _updateUsername,
                        child: const Text('Modifica'),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Citta'),
                      subtitle: Text(city.isEmpty ? 'Non impostata' : city),
                      trailing: TextButton(
                        onPressed: _updateCity,
                        child: const Text('Modifica'),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bio'),
                      subtitle: Text(
                        bio.isEmpty ? 'Non impostata' : bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        onPressed: _updateBio,
                        child: const Text('Modifica'),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Generi musicali'),
                      subtitle: Text(
                        genres.isEmpty ? 'Non impostati' : genres.join(', '),
                      ),
                      trailing: TextButton(
                        onPressed: _updateGenres,
                        child: const Text('Modifica'),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Livello'),
                      subtitle: Text(skillLevel),
                      trailing: TextButton(
                        onPressed: _updateSkillLevel,
                        child: const Text('Modifica'),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Disponibilita'),
                      subtitle: Text(
                        availability.isEmpty
                            ? 'Non impostata'
                            : availability.join(', '),
                      ),
                      trailing: TextButton(
                        onPressed: _updateAvailability,
                        child: const Text('Modifica'),
                      ),
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Prenotazioni',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: bookingRemindersEnabled,
                      title: const Text('Promemoria prenotazioni'),
                      subtitle: const Text(
                        'Mantiene attivi i promemoria legati alle prenotazioni.',
                      ),
                      onChanged: (value) async {
                        themeService.updateBookingReminders(enabled: value);
                        await _updateGeneralPreferences(
                          bookingRemindersEnabled: value,
                        );
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Anticipo promemoria'),
                      subtitle: const Text(
                        'Quando ricevere il promemoria prima della prenotazione.',
                      ),
                      trailing: DropdownButton<int>(
                        value: bookingReminderMinutes,
                        onChanged: bookingRemindersEnabled
                            ? (value) async {
                                if (value == null) {
                                  return;
                                }
                                themeService.updateBookingReminders(
                                  minutes: value,
                                );
                                await _updateGeneralPreferences(
                                  bookingReminderMinutes: value,
                                );
                              }
                            : null,
                        items: const [
                          DropdownMenuItem(
                            value: 15,
                            child: Text('15 min'),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text('30 min'),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text('1 ora'),
                          ),
                          DropdownMenuItem(
                            value: 120,
                            child: Text('2 ore'),
                          ),
                          DropdownMenuItem(
                            value: 180,
                            child: Text('3 ore'),
                          ),
                          DropdownMenuItem(
                            value: 1440,
                            child: Text('1 giorno'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Sicurezza',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Email account'),
                      subtitle: Text(user?.email ?? 'Non disponibile'),
                      trailing: TextButton(
                        onPressed: _requestEmailChange,
                        child: const Text('Modifica'),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Verifica email'),
                      subtitle: Text(
                        FirebaseAuth.instance.currentUser?.emailVerified == true
                            ? 'Verificata'
                            : 'Non verificata',
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Password'),
                      subtitle: Text(
                        _authService.isPasswordProviderLinked
                            ? 'Aggiorna la password con conferma credenziali.'
                            : 'Nessuna password locale collegata a questo account.',
                      ),
                      trailing: _authService.isPasswordProviderLinked
                          ? TextButton(
                              onPressed: _updatePassword,
                              child: const Text('Modifica'),
                            )
                          : null,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reset password via email'),
                      subtitle: const Text(
                        'Invia una email per reimpostare la password.',
                      ),
                      trailing: TextButton(
                        onPressed: _sendPasswordReset,
                        child: const Text('Invia'),
                      ),
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Accessibilita',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dimensione testo'),
                      subtitle: Slider(
                        value: textScale,
                        min: 0.9,
                        max: 1.4,
                        divisions: 5,
                        label: textScale.toStringAsFixed(2),
                        onChanged: (value) {
                          themeService.updateAccessibility(textScale: value);
                        },
                        onChangeEnd: (value) async {
                          await _updateGeneralPreferences(textScale: value);
                        },
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: highContrast,
                      title: const Text('Contrasto elevato'),
                      onChanged: (value) async {
                        themeService.updateAccessibility(highContrast: value);
                        await _updateGeneralPreferences(highContrast: value);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: reduceMotion,
                      title: const Text('Riduci animazioni'),
                      onChanged: (value) async {
                        themeService.updateAccessibility(reduceMotion: value);
                        await _updateGeneralPreferences(reduceMotion: value);
                      },
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Area pericolosa',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                      ),
                      title: const Text(
                        'Elimina account',
                        style: TextStyle(color: Colors.red),
                      ),
                      subtitle: const Text(
                        'Rimuove definitivamente account e dati collegati.',
                      ),
                      trailing: TextButton(
                        onPressed: _deleteAccount,
                        child: const Text(
                          'Elimina',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  value: _notificationPreferences.inAppEnabled,
                  title: const Text('Popup in-app'),
                  subtitle: const Text(
                    'Mostra avvisi rapidi mentre usi l’app.',
                  ),
                  onChanged: (value) {
                    _updateNotificationPreferences(
                      _notificationPreferences.copyWith(inAppEnabled: value),
                    );
                  },
                ),
                SwitchListTile(
                  value: _notificationPreferences.systemEnabled,
                  title: const Text('Notifiche di sistema'),
                  subtitle: const Text(
                    'Mostra banner e barra notifiche quando arriva un evento.',
                  ),
                  onChanged: (value) async {
                    if (value) {
                      await LocalNotificationService.instance
                          .requestPermissions();
                    }
                    await _updateNotificationPreferences(
                      _notificationPreferences.copyWith(systemEnabled: value),
                    );
                  },
                ),
                const Divider(),
                SwitchListTile(
                  value: _notificationPreferences.bookingEnabled,
                  title: const Text('Categoria prenotazioni'),
                  subtitle: const Text(
                    'Conferme, rifiuti e aggiornamenti prenotazioni.',
                  ),
                  onChanged: (value) {
                    _updateNotificationPreferences(
                      _notificationPreferences.copyWith(bookingEnabled: value),
                    );
                  },
                ),
                SwitchListTile(
                  value: _notificationPreferences.jamEnabled,
                  title: const Text('Categoria jam'),
                  subtitle: const Text(
                    'Approvazioni, rifiuti e aggiornamenti jam.',
                  ),
                  onChanged: (value) {
                    _updateNotificationPreferences(
                      _notificationPreferences.copyWith(jamEnabled: value),
                    );
                  },
                ),
                SwitchListTile(
                  value: _notificationPreferences.groupEnabled,
                  title: const Text('Categoria gruppi'),
                  subtitle: const Text(
                    'Inviti e risposte relative ai gruppi.',
                  ),
                  onChanged: (value) {
                    _updateNotificationPreferences(
                      _notificationPreferences.copyWith(groupEnabled: value),
                    );
                  },
                ),
                SwitchListTile(
                  value: _notificationPreferences.systemCategoryEnabled,
                  title: const Text('Categoria sistema'),
                  subtitle: const Text(
                    'Messaggi generici e notifiche non classificate.',
                  ),
                  onChanged: (value) {
                    _updateNotificationPreferences(
                      _notificationPreferences.copyWith(
                        systemCategoryEnabled: value,
                      ),
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
