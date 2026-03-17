import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/admin/admin_management_page_mobile.dart';
import 'package:soundimplosion/app/features/app_scaffold_controller.dart';
import 'package:soundimplosion/app/features/book/bookings_scaffold_mobile.dart';
import 'package:soundimplosion/app/features/home/home_page_mobile.dart';
import 'package:soundimplosion/app/features/jam/jam_session_page_mobile.dart';
import 'package:soundimplosion/app/features/groups/groups_page_mobile.dart';
import 'package:soundimplosion/app/features/profile/profile_details_page_mobile.dart';
import 'package:soundimplosion/app/features/contact_us/contact_us_page_mobile.dart';
import 'package:soundimplosion/common/variables.dart';
import 'package:soundimplosion/services/firebase_auth.dart';

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

  void _navigateToPage(int index) {
    Navigator.pop(context); // Chiude il drawer
    setState(() {
      _selectedIndex = index;
      _currentPageTitle = _pageTitles[index];
    });
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);

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
      const PlaceholderPage(title: 'Impostazioni'), // 7
    ];

    final maxIndex = _widgetOptions.length - 1;
    final incoming = widget.initialIndex;
    _selectedIndex = incoming < 0
        ? 0
        : (incoming > maxIndex ? maxIndex : incoming);
    _currentPageTitle = _pageTitles[_selectedIndex];

    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      appBar: AppBar(title: Text(_currentPageTitle)),
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
                'SoundImplosion v${AppVariables.appVersion}',
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
