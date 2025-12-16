import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soundimplosion/services/database_service.dart';

class HomePageMobile extends StatefulWidget {
  const HomePageMobile({super.key});

  @override
  State<HomePageMobile> createState() => _HomePageMobileState();
}

class _HomePageMobileState extends State<HomePageMobile> {
  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DatabaseEvent>(
        stream: _dbService.getFeedStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Errore caricamento feed: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text("Nessun aggiornamento nel feed."));
          }

          // --- Parsing e Ordinamento ---
          final dynamic rawData = snapshot.data!.snapshot.value;
          List<Map<String, dynamic>> feedItems = [];

          try {
            if (rawData is Map) {
              feedItems = rawData.entries.map((entry) {
                final itemData = Map<String, dynamic>.from(entry.value as Map);
                itemData['key'] = entry.key;
                return itemData;
              }).toList();
            } else if (rawData is List) {
              for (int i = 0; i < rawData.length; i++) {
                if (rawData[i] != null) {
                  final itemData = Map<String, dynamic>.from(rawData[i] as Map);
                  itemData['key'] = i.toString();
                  feedItems.add(itemData);
                }
              }
            }

            // Ordiniamo in modo decrescente (più nuovi prima)
            feedItems.sort((a, b) {
              final timestampA = a['timestamp'] ?? 0;
              final timestampB = b['timestamp'] ?? 0;
              return (timestampB as int).compareTo(timestampA as int);
            });

          } catch (e) {
            return Center(child: Text("Errore nel formato dati del feed: $e"));
          }

          if (feedItems.isEmpty) {
            return const Center(child: Text("Il feed è vuoto."));
          }

          // --- UI Feed ---
          return ListView.builder(
            itemCount: feedItems.length,
            itemBuilder: (context, index) {
              final item = feedItems[index];
              final type = item['type'];

              // Widget specifici per tipo di post
              if (type == 'jam_published') {
                return _buildJamPostCard(item);
              }

              // Qui puoi aggiungere altri tipi di post, es. 'staff_update'
              // if (type == 'staff_update') {
              //   return _buildStaffPostCard(item);
              // }

              // Fallback per tipi sconosciuti
              return const SizedBox.shrink(); 
            },
          );
        },
      ),
    );
  }

  // Widget per mostrare una nuova JAM nel feed
  Widget _buildJamPostCard(Map<String, dynamic> item) {
    final date = item['data'] ?? 'N/A';
    final startTime = item['ora_inizio'] ?? 'N/A';
    final description = item['descrizione'] ?? '';
    // Potremmo recuperare il nickname del creatore, ma per ora teniamolo semplice
    // final creatorId = item['creator_id']; 

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note_rounded, color: Colors.purple, size: 24),
                const SizedBox(width: 8),
                const Text(
                  "Nuova Jam Session!",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '"$description"',
              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Quando? Il $date alle ore $startTime',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Navigare alla pagina 'Cerca Jam' o direttamente al dettaglio della Jam
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Navigazione al dettaglio Jam in arrivo...")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[100],
                  foregroundColor: Colors.purple[900],
                ),
                child: const Text("Vedi dettagli"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget per aggiornamenti dello staff (da implementare)
  // Widget _buildStaffPostCard(Map<String, dynamic> item) {
  //   // ...
  // }
}
