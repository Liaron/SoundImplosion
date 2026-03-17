import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/profile/profile_controller.dart';

class ProfileDetailsPageMobile extends StatefulWidget {
  const ProfileDetailsPageMobile({super.key});

  @override
  State<ProfileDetailsPageMobile> createState() => _ProfileDetailsPageMobileState();
}

class _ProfileDetailsPageMobileState extends State<ProfileDetailsPageMobile> {
  final ProfileController _controller = ProfileController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
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

  Future<void> _updateNickname() async {
    final currentUser = _controller.user;
    final controller = TextEditingController(text: currentUser?.nickname);
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
              if (controller.text.isNotEmpty && currentUser != null) {
                await _controller.updateNickname(controller.text);
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
                  if (nameController.text.isNotEmpty && _controller.user != null) {
                    await _controller.addInstrument(
                      name: nameController.text,
                      level: level.toInt(),
                    );
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
    await _controller.removeInstrument(index);
  }

  // Placeholder per gestione foto (senza Storage vero e proprio per ora)
  Future<void> _manageProfilePhoto() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Funzionalità foto in arrivo (richiede Firebase Storage)")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _controller.user;
    if (user == null) {
      return Center(child: Text(_controller.errorMessage ?? 'Errore caricamento profilo'));
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
                    backgroundImage: user.profileImageUrl != null 
                        ? NetworkImage(user.profileImageUrl!) 
                        : null,
                    child: user.profileImageUrl == null
                        ? Text(
                            user.nickname.isNotEmpty ? user.nickname[0].toUpperCase() : '?',
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
                  user.nickname,
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

            user.strumentiList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("Nessuno strumento aggiunto.", style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: user.strumentiList.length,
                    itemBuilder: (context, index) {
                      final item = user.strumentiList[index];
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
