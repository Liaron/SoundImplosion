import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:soundimplosion/app/features/admin/admin_management_page_mobile.dart';
import 'package:soundimplosion/app/features/app_scaffold_controller.dart';
import 'package:soundimplosion/app/startup_loading_screen.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';
import 'package:soundimplosion/app/features/book/bookings_scaffold_mobile.dart';
import 'package:soundimplosion/app/features/home/home_page_mobile.dart';
import 'package:soundimplosion/app/features/jam/jam_session_page_mobile.dart';
import 'package:soundimplosion/app/features/groups/groups_page_mobile.dart';
import 'package:soundimplosion/app/features/notifications/notifications_page_mobile.dart';
import 'package:soundimplosion/app/features/notifications/notifications_repository.dart';
import 'package:soundimplosion/app/features/profile/profile_details_page_mobile.dart';
import 'package:soundimplosion/app/features/settings/settings_page_mobile.dart';
import 'package:soundimplosion/app/features/contact_us/contact_us_page_mobile.dart';
import 'package:soundimplosion/services/app_preferences_service.dart';
import 'package:soundimplosion/services/booking_reminder_service.dart';
import 'package:soundimplosion/services/firebase_auth.dart';
import 'package:soundimplosion/services/local_notification_service.dart';
import 'package:soundimplosion/services/push_notification_service.dart';

// Widget segnaposto per le pagine non ancora create.
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Pagina: $title'));
  }
}

class AppScaffoldMobile extends StatefulWidget {
  const AppScaffoldMobile({
    super.key,
    this.initialIndex = 0,
    this.initialJamToOpen, // Parametro opzionale per aprire una jam specifica
  });

  final int initialIndex;
  final Map<String, dynamic>? initialJamToOpen;

  @override
  State<AppScaffoldMobile> createState() => _AppScaffoldMobileState();
}

class _AppScaffoldMobileState extends State<AppScaffoldMobile> {
  final AuthService _authService = AuthService();
  final AppScaffoldController _controller = AppScaffoldController();
  final NotificationsRepository _notificationsRepository =
      FirebaseNotificationsRepository();
  final BookingRepository _bookingRepository = FirebaseBookingRepository();
  StreamSubscription<List<AppNotificationItem>>? _notificationSubscription;
  StreamSubscription<List<BookingListItem>>? _bookingReminderSubscription;
  StreamSubscription<String>? _notificationTapSubscription;
  StreamSubscription<String>? _pushOpenedSubscription;
  final Set<String> _knownNotificationIds = <String>{};
  bool _hasSeededNotifications = false;
  List<BookingListItem> _latestBookings = const [];
  bool _postProfileBootstrapped = false;
  String? _appVersionLabel;
  int _unreadNotificationCount = 0;

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  int _selectedIndex = 0;
  String _currentPageTitle = 'Home';

  late List<Widget> _widgetOptions;

  static const List<String> _pageTitles = <String>[
    'Home',
    'Prenotazioni',
    'Jam Session',
    'Gruppi',
    'Admin',
    'Notifiche',
    'Profilo',
    'Contattaci',
    'Impostazioni',
  ];

  void _navigateToPage(int index, {bool closeDrawer = true}) {
    if (closeDrawer) {
      Navigator.pop(context);
    }
    setState(() {
      _selectedIndex = index;
      _currentPageTitle = _pageTitles[index];
    });
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    AppPreferencesService.instance.addListener(_handlePreferencesChanged);

    _widgetOptions = <Widget>[
      const HomePageMobile(), // 0
      const BookingsScaffoldMobile(), // 1
      JamSessionPageMobile(
        initialJamToOpen: widget.initialJamToOpen,
      ), // 2 - Passiamo il parametro
      const GroupsPageMobile(embedded: true), // 3
      const AdminManagementPageMobile(embedded: true), // 4
      const NotificationsPageMobile(), // 5
      const ProfileDetailsPageMobile(), // 6
      const ContactUsPageMobile(), // 7
      const SettingsPageMobile(), // 8
    ];

    final maxIndex = _widgetOptions.length - 1;
    final incoming = widget.initialIndex;
    _selectedIndex = incoming < 0
        ? 0
        : (incoming > maxIndex ? maxIndex : incoming);
    _currentPageTitle = _pageTitles[_selectedIndex];

    _loadAppVersion();
    _controller.initialize();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _bookingReminderSubscription?.cancel();
    _notificationTapSubscription?.cancel();
    _pushOpenedSubscription?.cancel();
    _controller.removeListener(_handleControllerChanged);
    AppPreferencesService.instance.removeListener(_handlePreferencesChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!_controller.isLoadingProfile && !_postProfileBootstrapped) {
      _postProfileBootstrapped = true;
      _bootstrapNotifications();
      _bootstrapBookingReminders();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _handlePreferencesChanged() {
    _syncBookingReminders();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _appVersionLabel = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _bootstrapNotifications() async {
    _notificationTapSubscription = LocalNotificationService.instance.tapStream
        .listen(_handleNotificationPayload);
    _pushOpenedSubscription = PushNotificationService.instance.openedPayloadStream
        .listen(_handleNotificationPayload);
    final initialPayload = LocalNotificationService.instance.takeInitialPayload();
    if (initialPayload != null && initialPayload.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationPayload(initialPayload);
      });
    }
    final initialPushPayload = PushNotificationService.instance
        .takeInitialPayload();
    if (initialPushPayload != null && initialPushPayload.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationPayload(initialPushPayload);
      });
    }

    _notificationSubscription = _notificationsRepository
        .watchNotifications()
        .listen((items) async {
          final unreadCount = items.where((item) => !item.isRead).length;
          if (mounted && _unreadNotificationCount != unreadCount) {
            setState(() {
              _unreadNotificationCount = unreadCount;
            });
          }

          if (!_hasSeededNotifications) {
            _knownNotificationIds.addAll(items.map((item) => item.id));
            _hasSeededNotifications = true;
            return;
          }

          final preferences = await _notificationsRepository.loadPreferences();
          final newItems =
              items
                  .where((item) => !_knownNotificationIds.contains(item.id))
                  .toList()
                ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

          _knownNotificationIds
            ..clear()
            ..addAll(items.map((item) => item.id));

          for (final item in newItems) {
            if (!preferences.allowsCategory(item.category)) {
              continue;
            }

            if (preferences.inAppEnabled && mounted) {
              _showInAppNotificationBanner(item);
            }
          }
        });
  }

  void _showInAppNotificationBanner(AppNotificationItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = _notificationAccentColor(item, colorScheme);
    final stateLabel = _notificationStateLabel(item);
    final stateColor = _notificationStateColor(item, colorScheme);
    final messenger = ScaffoldMessenger.of(context);
    final isAdminNotification = item.type.startsWith('admin_');

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: EdgeInsets.zero,
          duration: _notificationDisplayDuration(item),
          backgroundColor: Colors.transparent,
          content: IntrinsicHeight(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accentColor.withValues(alpha: 0.22)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _notificationIcon(item),
                              color: accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (isAdminNotification)
                                      _InAppNotificationChip(
                                        label: 'Admin',
                                        backgroundColor: colorScheme.error
                                            .withValues(alpha: 0.12),
                                        foregroundColor: colorScheme.error,
                                      ),
                                    _InAppNotificationChip(
                                      label: _categoryLabel(item),
                                      backgroundColor: accentColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      foregroundColor: accentColor,
                                    ),
                                    if (stateLabel != null)
                                      _InAppNotificationChip(
                                        label: stateLabel,
                                        backgroundColor: stateColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        foregroundColor: stateColor,
                                      ),
                                    TextButton(
                                      onPressed: () {
                                        messenger.hideCurrentSnackBar();
                                        _openNotificationTarget(item.routeTarget);
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: accentColor,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 0,
                                        ),
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        _notificationActionLabel(item),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Color _notificationAccentColor(
    AppNotificationItem item,
    ColorScheme colorScheme,
  ) {
    if (item.type.startsWith('admin_')) {
      return colorScheme.error;
    }

    switch (item.category) {
      case NotificationCategory.bookings:
        return colorScheme.primary;
      case NotificationCategory.jams:
        return colorScheme.secondary;
      case NotificationCategory.groups:
        return const Color(0xFF2E7D32);
      case NotificationCategory.system:
        return colorScheme.tertiary;
    }
  }

  IconData _notificationIcon(AppNotificationItem item) {
    if (item.isPendingAction) {
      return Icons.pending_actions_outlined;
    }
    if (item.type.startsWith('admin_')) {
      return Icons.admin_panel_settings_outlined;
    }
    if (item.type.contains('accepted') ||
        item.type.contains('confirmed') ||
        item.type.contains('approved')) {
      return Icons.check_circle_outline;
    }
    if (item.type.contains('rejected') || item.type.contains('cancelled')) {
      return Icons.cancel_outlined;
    }
    if (item.type.contains('modified')) {
      return Icons.edit_calendar_outlined;
    }

    switch (item.category) {
      case NotificationCategory.bookings:
        return Icons.event_available_outlined;
      case NotificationCategory.jams:
        return Icons.music_note_outlined;
      case NotificationCategory.groups:
        return Icons.groups_2_outlined;
      case NotificationCategory.system:
        return Icons.notifications_active_outlined;
    }
  }

  String? _notificationStateLabel(AppNotificationItem item) {
    if (item.isPendingAction) {
      return 'Da gestire';
    }
    if (item.type.contains('accepted')) {
      return 'Accettata';
    }
    if (item.type.contains('confirmed')) {
      return 'Confermata';
    }
    if (item.type.contains('approved')) {
      return 'Approvata';
    }
    if (item.type.contains('rejected')) {
      return 'Rifiutata';
    }
    if (item.type.contains('cancelled')) {
      return 'Annullata';
    }
    if (item.type.contains('modified')) {
      return 'Aggiornata';
    }
    if (item.type.contains('created')) {
      return 'Nuova';
    }
    return null;
  }

  Color _notificationStateColor(
    AppNotificationItem item,
    ColorScheme colorScheme,
  ) {
    if (item.isPendingAction) {
      return const Color(0xFFB26A00);
    }
    if (item.type.contains('accepted') ||
        item.type.contains('confirmed') ||
        item.type.contains('approved')) {
      return const Color(0xFF2E7D32);
    }
    if (item.type.contains('rejected') || item.type.contains('cancelled')) {
      return colorScheme.error;
    }
    if (item.type.contains('modified')) {
      return colorScheme.secondary;
    }
    return _notificationAccentColor(item, colorScheme);
  }

  String _notificationActionLabel(AppNotificationItem item) {
    if (item.isPendingAction) {
      return 'Apri richiesta';
    }
    switch (item.routeTarget.pageIndex) {
      case 1:
      case 2:
      case 3:
        return 'Apri dettagli';
      case 4:
        return 'Vai ad Admin';
      case 5:
        return 'Apri centro';
      default:
        return 'Apri';
    }
  }

  Duration _notificationDisplayDuration(AppNotificationItem item) {
    if (item.isPendingAction) {
      return const Duration(seconds: 8);
    }
    if (item.type.startsWith('admin_')) {
      return const Duration(seconds: 7);
    }
    return const Duration(seconds: 6);
  }

  String _categoryLabel(AppNotificationItem item) {
    if (item.type.startsWith('admin_')) {
      return 'Moderazione';
    }

    switch (item.category) {
      case NotificationCategory.bookings:
        return 'Prenotazioni';
      case NotificationCategory.jams:
        return 'Jam';
      case NotificationCategory.groups:
        return 'Gruppi';
      case NotificationCategory.system:
        return 'Sistema';
    }
  }

  Future<void> _handleNotificationPayload(String payload) async {
    final target = NotificationRouteTarget.fromPayload(payload);
    if (target == null || !mounted) {
      return;
    }
    await _openNotificationTarget(target);
  }

  Future<void> _openNotificationTarget(NotificationRouteTarget target) async {
    if (!mounted) {
      return;
    }

    switch (target.pageIndex) {
      case 1:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookingsScaffoldMobile(
              initialBookingIdToOpen: target.bookingId,
            ),
          ),
        );
        break;
      case 2:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JamSessionPageMobile(
              initialJamToOpen: target.jamId == null
                  ? null
                  : <String, dynamic>{'jam_id': target.jamId},
            ),
          ),
        );
        break;
      case 3:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                GroupsPageMobile(initialGroupIdToOpen: target.groupId),
          ),
        );
        break;
      case 4:
        if (_controller.isAdmin) {
          _navigateToPage(4, closeDrawer: false);
        }
        break;
      case 5:
        _navigateToPage(5, closeDrawer: false);
        break;
      default:
        break;
    }
  }

  Future<void> _bootstrapBookingReminders() async {
    _bookingReminderSubscription = _bookingRepository.watchUserBookings().listen(
      (items) {
        _latestBookings = items;
        _syncBookingReminders();
      },
      onError: (_) {},
    );
  }

  Future<void> _syncBookingReminders() async {
    try {
      await BookingReminderService.instance.syncReminders(
        bookings: _latestBookings,
        enabled: AppPreferencesService.instance.bookingRemindersEnabled,
        minutesBefore: AppPreferencesService.instance.bookingReminderMinutes,
      );
    } catch (_) {}
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await _controller.sendVerificationEmail();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email di verifica inviata. Controlla la tua casella.'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invio email fallito: $e')));
    }
  }

  Future<void> _refreshEmailVerification() async {
    try {
      await _controller.refreshEmailVerification();
      if (!mounted || !_controller.isEmailVerified) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verificata correttamente.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Verifica non aggiornata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoadingProfile) {
      return const StartupLoadingScreen();
    }

    if (!_controller.isEmailVerified) {
      final email =
          _authService.currentUser?.email ?? _controller.user?.email ?? '';
      return Scaffold(
        appBar: AppBar(title: const Text("Benvenuto su SoundImplosion")),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Verifica la tua email",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                email.isEmpty
                    ? "Apri l'email ricevuta e conferma il tuo account per continuare."
                    : "Abbiamo inviato un link di verifica a $email. Aprilo e poi torna qui.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendVerificationEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: const Text("INVIA DI NUOVO EMAIL"),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _refreshEmailVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text("HO GIA VERIFICATO"),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _signOut, child: const Text('Esci')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPageTitle),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotificationCount > 99
                            ? '99+'
                            : '$_unreadNotificationCount',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _navigateToPage(5, closeDrawer: false),
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Center(
                child: Image.asset('lib/common/images/soundimplosion_logo.jpg'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => _navigateToPage(0),
            ),
            ListTile(
              leading: const Icon(Icons.book_online),
              title: const Text('Prenotazioni'),
              onTap: () => _navigateToPage(1),
            ),
            ListTile(
              leading: const Icon(Icons.music_video),
              title: const Text('Jam Session'),
              onTap: () => _navigateToPage(2),
            ),
            ListTile(
              leading: const Icon(Icons.groups),
              title: const Text('Gruppi'),
              onTap: () => _navigateToPage(3),
            ),
            if (_controller.isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Admin'),
                onTap: () => _navigateToPage(4),
              ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profilo'),
              onTap: () => _navigateToPage(6),
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('Contattaci'),
              onTap: () => _navigateToPage(7),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Impostazioni'),
              onTap: () => _navigateToPage(8),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _signOut(),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'SoundImplosion ${_appVersionLabel ?? ''}'.trimRight(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 11.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InAppNotificationChip extends StatelessWidget {
  const _InAppNotificationChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
