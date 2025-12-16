import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/book/bookings_scaffold_mobile.dart';
import 'package:soundimplosion/app/features/home/home_page_mobile.dart';
import 'package:soundimplosion/app/features/jam/jam_session_page_mobile.dart';
import 'package:soundimplosion/app/features/profile/profile_details_page_mobile.dart';
import 'package:soundimplosion/app/features/contact_us/contact_us_page_mobile.dart';
import 'package:soundimplosion/common/variables.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/database_service.dart';
import 'package:soundimplosion/services/firebase_auth.dart';


// Widget segnaposto per le pagine non ancora create.
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Pagina: $title'),
    );
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
  final DatabaseService _dbService = DatabaseService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool _isLoadingProfile = true;
  bool _isProfileConfigured = false;
  final TextEditingController _nicknameController = TextEditingController();

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
    'Profilo',
    'Contattaci',
    'Impostazioni',
    'LogOut'
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
    
    _widgetOptions = <Widget>[
      const HomePageMobile(), // 0
      const BookingsScaffoldMobile(), // 1
      JamSessionPageMobile(initialJamToOpen: widget.initialJamToOpen), // 2 - Passiamo il parametro
      const ProfileDetailsPageMobile(), // 3
      const ContactUsPageMobile(), // 4
      const PlaceholderPage(title: 'Impostazioni'),
    ];

    final maxIndex = _widgetOptions.length - 1;
    final incoming = widget.initialIndex;
    _selectedIndex = incoming < 0
        ? 0
        : (incoming > maxIndex ? maxIndex : incoming);
    _currentPageTitle = _pageTitles[_selectedIndex];
    
    _checkUserProfile();
  }

  Future<void> _checkUserProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      // CORREZIONE: Uso l'istanza DB corretta (europe-west1)
      final dbRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(), 
        databaseURL: 'https://liaron-soundimplosion-default-rtdb.europe-west1.firebasedatabase.app'
      ).ref();

      final snapshot = await dbRef.child('users').child(user.uid).get();
      
      if (snapshot.exists && snapshot.value != null) {
        final userData = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final appUser = AppUser.fromMap(user.uid, userData);
        
        if (appUser.nickname == user.uid) {
          if (mounted) {
            setState(() {
              _isProfileConfigured = false;
              _isLoadingProfile = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isProfileConfigured = true;
              _isLoadingProfile = false;
            });
          }
        }
      } else {
        final newUser = AppUser(uid: user.uid, nickname: user.uid);
        await _dbService.saveUser(newUser);
        
        if (mounted) {
          setState(() {
            _isProfileConfigured = false; 
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Errore check profilo: $e");
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _saveInitialProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Inserisci un nickname valido")),
      );
      return;
    }

    setState(() => _isLoadingProfile = true);

    try {
      final dbRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(), 
        databaseURL: 'https://liaron-soundimplosion-default-rtdb.europe-west1.firebasedatabase.app'
      ).ref();
      
      final snapshot = await dbRef.child('users').child(user.uid).get();
      AppUser currentUserData;
      
      if (snapshot.exists && snapshot.value != null) {
        final userData = Map<dynamic, dynamic>.from(snapshot.value as Map);
        currentUserData = AppUser.fromMap(user.uid, userData);
      } else {
        currentUserData = AppUser(uid: user.uid, nickname: user.uid);
      }

      final updatedUser = AppUser(
        uid: currentUserData.uid,
        nickname: _nicknameController.text.trim(),
        gruppi: currentUserData.gruppi,
        amici: currentUserData.amici,
        preferenze: currentUserData.preferenze,
        strumentiList: currentUserData.strumentiList,
        profileImageUrl: currentUserData.profileImageUrl,
      );

      await _dbService.saveUser(updatedUser);

      if (mounted) {
        setState(() {
          _isProfileConfigured = true;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint("Errore salvataggio profilo iniziale: $e");
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore salvataggio: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isProfileConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text("Benvenuto su SoundImplosion")),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Configura il tuo profilo",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                "Per continuare, scegli un Nickname unico che ti rappresenti nella community.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: "Nickname",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveInitialProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("SALVA E CONTINUA"),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPageTitle),
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
            const Spacer(), 
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profilo'),
              onTap: () => _navigateToPage(3),
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('Contattaci'),
              onTap: () => _navigateToPage(4),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Impostazioni'),
              onTap: () => _navigateToPage(5),
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
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
