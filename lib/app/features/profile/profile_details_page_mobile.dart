import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/database_service.dart';

class ProfileDetailsPageMobile extends StatefulWidget {
  const ProfileDetailsPageMobile({super.key});

  @override
  State<ProfileDetailsPageMobile> createState() => _ProfileDetailsPageMobileState();
}

class _ProfileDetailsPageMobileState extends State<ProfileDetailsPageMobile> {
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  AppUser? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Modifica qui: Specifica l'URL europeo
      final snapshot = await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://liaron-soundimplosion-default-rtdb.europe-west1.firebasedatabase.app',
      ).ref().child('users').child(currentUser.uid).get();

      if (snapshot.exists && snapshot.value != null) {
        final userData = Map<dynamic, dynamic>.from(snapshot.value as Map);
        if (mounted) {
          setState(() {
            _user = AppUser.fromMap(currentUser.uid, userData);
            _isLoading = false;
          });
        }
      } else {
        // Utente non trovato nel DB, creiamo profilo base
        if (mounted) {
          setState(() {
            _user = AppUser(
              uid: currentUser.uid, 
              nickname: currentUser.displayName ?? 'Utente',
            );
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Errore caricamento profilo: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateNickname() async {
    final controller = TextEditingController(text: _user?.nickname);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Modifica Nickname"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Nuovo Nickname"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annulla")),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && _user != null) {
                final updatedUser = AppUser(
                  uid: _user!.uid,
                  nickname: controller.text,
                  gruppi: _user!.gruppi,
                  amici: _user!.amici,
                  preferenze: _user!.preferenze,
                  strumentiList: _user!.strumentiList,
                  profileImageUrl: _user!.profileImageUrl,
                );
                
                await _databaseService.saveUser(updatedUser);
                setState(() => _user = updatedUser);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Salva"),
          ),
        ],
      ),
    );
  }

  Future<void> _addInstrument() async {
    final nameController = TextEditingController();
    double level = 1;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Aggiungi Strumento"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nome Strumento (es. Chitarra)"),
                ),
                const SizedBox(height: 16),
                Text("Livello Abilità: ${level.toInt()}"),
                Slider(
                  value: level,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: level.toInt().toString(),
                  onChanged: (val) => setStateDialog(() => level = val),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annulla")),
              TextButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty && _user != null) {
                    final newInstrument = {
                      'nome': nameController.text,
                      'livello': level.toInt(),
                    };
                    
                    final updatedList = List<Map<String, dynamic>>.from(_user!.strumentiList);
                    updatedList.add(newInstrument);

                    final updatedUser = AppUser(
                      uid: _user!.uid,
                      nickname: _user!.nickname,
                      gruppi: _user!.gruppi,
                      amici: _user!.amici,
                      preferenze: _user!.preferenze,
                      strumentiList: updatedList,
                      profileImageUrl: _user!.profileImageUrl,
                    );

                    await _databaseService.saveUser(updatedUser);
                    setState(() => _user = updatedUser);
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text("Aggiungi"),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _removeInstrument(int index) async {
    if (_user == null) return;
    
    final updatedList = List<Map<String, dynamic>>.from(_user!.strumentiList);
    updatedList.removeAt(index);

    final updatedUser = AppUser(
      uid: _user!.uid,
      nickname: _user!.nickname,
      gruppi: _user!.gruppi,
      amici: _user!.amici,
      preferenze: _user!.preferenze,
      strumentiList: updatedList,
      profileImageUrl: _user!.profileImageUrl,
    );

    await _databaseService.saveUser(updatedUser);
    setState(() => _user = updatedUser);
  }

  // Placeholder per gestione foto (senza Storage vero e proprio per ora)
  Future<void> _manageProfilePhoto() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Funzionalità foto in arrivo (richiede Firebase Storage)")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_user == null) {
      return const Center(child: Text("Errore caricamento profilo"));
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Immagine Profilo
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _user!.profileImageUrl != null 
                        ? NetworkImage(_user!.profileImageUrl!) 
                        : null,
                    child: _user!.profileImageUrl == null
                        ? Text(
                            _user!.nickname.isNotEmpty ? _user!.nickname[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 40, color: Colors.black54),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[850],
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        onPressed: _manageProfilePhoto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Nickname
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _user!.nickname,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: _updateNickname,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 3. Sezione Strumenti
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Strumenti",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addInstrument,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Aggiungi"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[850],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _user!.strumentiList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("Nessuno strumento aggiunto.", style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _user!.strumentiList.length,
                    itemBuilder: (context, index) {
                      final item = _user!.strumentiList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.music_note),
                          title: Text(item['nome'] ?? 'Sconosciuto'),
                          subtitle: Text('Livello: ${item['livello']}/10'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeInstrument(index),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
