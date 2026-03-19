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
  OverlayEntry? _inAppNotificationOverlay;
  Timer? _inAppNotificationTimer;

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
      const ProfileDetailsPageMobile(), // 5
      const ContactUsPageMobile(), // 6
      const SettingsPageMobile(), // 7
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
    _removeInAppNotificationOverlay();
    _notificationSubscription?.cancel();
    _bookingReminderSubscription?.cancel();
    _notificationTapSubscription?.cancel();
    _pushOpenedSubscription?.cancel();
    _controller.removeListener(_handleControllerChanged);
    AppPreferencesService.instance.removeListener(_handlePreferencesChanged);
    _controller.dispose();
    super.dispose();
  }

  void _removeInAppNotificationOverlay() {
    _inAppNotificationTimer?.cancel();
    _inAppNotificationTimer = null;
    _inAppNotificationOverlay?.remove();
    _inAppNotificationOverlay = null;
  }

  void _showInAppNotificationPopup(AppNotificationItem item) {
    if (!mounted) {
      return;
    }

    _removeInAppNotificationOverlay();

    final overlay = Overlay.of(context);

    _inAppNotificationOverlay = OverlayEntry(
      builder: (overlayContext) {
        final topInset = MediaQuery.of(overlayContext).padding.top;
        final theme = Theme.of(overlayContext);
        return Positioned(
          top: topInset + 12,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: GestureDetector(
                    onTap: () {
                      _removeInAppNotificationOverlay();
                      _openNotificationTarget(item.routeTarget);
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.notifications_active,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.body,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _removeInAppNotificationOverlay,
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Chiudi',
                                ),
                                TextButton(
                                  onPressed: () {
                                    _removeInAppNotificationOverlay();
                                    _openNotificationTarget(item.routeTarget);
                                  },
                                  child: const Text('Apri'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_inAppNotificationOverlay!);
    _inAppNotificationTimer = Timer(const Duration(seconds: 5), () {
      _removeInAppNotificationOverlay();
    });
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
              _showInAppNotificationPopup(item);
            }
          }
        });
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
      case 5:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsPageMobile()),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _openNotificationsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsPageMobile()),
    );
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
            onPressed: _openNotificationsPage,
            icon: Badge.count(
              isLabelVisible: _unreadNotificationCount > 0,
              count: _unreadNotificationCount > 99
                  ? 99
                  : _unreadNotificationCount,
              child: const Icon(Icons.notifications),
            ),
            tooltip: 'Notifiche',
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
              onTap: () => _navigateToPage(5),
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('Contattaci'),
              onTap: () => _navigateToPage(6),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Impostazioni'),
              onTap: () => _navigateToPage(7),
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
