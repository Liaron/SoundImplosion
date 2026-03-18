import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/profile/profile_controller.dart';

class ProfileDetailsPageMobile extends StatefulWidget {
  const ProfileDetailsPageMobile({super.key});

  @override
  State<ProfileDetailsPageMobile> createState() =>
      _ProfileDetailsPageMobileState();
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

  Future<void> _addInstrument() async {
    final nameController = TextEditingController();
    double level = 1;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          return AlertDialog(
            title: const Text("Aggiungi Strumento"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Nome Strumento (es. Chitarra)",
                  ),
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
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Annulla"),
              ),
              TextButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty &&
                      _controller.user != null) {
                    await _controller.addInstrument(
                      name: nameController.text,
                      level: level.toInt(),
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  }
                },
                child: const Text("Aggiungi"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeInstrument(int index) async {
    await _controller.removeInstrument(index);
  }

  // Placeholder per gestione foto (senza Storage vero e proprio per ora)
  Future<void> _manageProfilePhoto() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Funzionalità foto in arrivo (richiede Firebase Storage)",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _controller.user;
    if (user == null) {
      return Center(
        child: Text(_controller.errorMessage ?? 'Errore caricamento profilo'),
      );
    }

    final city = user.preferenze['general'] is Map
        ? ((user.preferenze['general'] as Map)['city']?.toString() ?? '')
        : '';

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
                            user.nickname.isNotEmpty
                                ? user.nickname[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.black54,
                            ),
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
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _manageProfilePhoto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              user.nickname,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              city.isEmpty ? 'Citta non impostata' : city,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              user.skillLevel,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            if (user.genres.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: user.genres
                    .map((genre) => Chip(label: Text(genre)))
                    .toList(),
              ),
            ],
            if (user.availability.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Disponibilita: ${user.availability.join(', ')}',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
            if (user.bio.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                user.bio,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[800]),
              ),
            ],
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            user.strumentiList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      "Nessuno strumento aggiunto.",
                      style: TextStyle(color: Colors.grey),
                    ),
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
