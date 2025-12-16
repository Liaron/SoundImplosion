import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soundimplosion/services/database_service.dart';

class FindJamPageMobile extends StatefulWidget {
  // Parametro per aprire una jam specifica al caricamento
  final Map<String, dynamic>? initialJamToOpen;

  const FindJamPageMobile({super.key, this.initialJamToOpen});

  @override
  State<FindJamPageMobile> createState() => _FindJamPageMobileState();
}

class _FindJamPageMobileState extends State<FindJamPageMobile> {
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Se riceviamo una jam da aprire, la mostriamo in un dialog dopo la build
    if (widget.initialJamToOpen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showJamDetails(widget.initialJamToOpen!);
      });
    }
  }

  void _showJamDetails(Map<String, dynamic> jam) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Dettagli Jam"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Data: ${jam['data'] ?? 'N/A'}"),
              Text("Orario: ${jam['ora_inizio'] ?? 'N/A'} - ${jam['ora_fine'] ?? 'N/A'}"),
              const SizedBox(height: 16),
              Text("Descrizione: ", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(jam['descrizione'] ?? ''),
              const SizedBox(height: 8),
              Text("Persone: ${jam['persone_presenti'] ?? 0} presenti, si cercano ${jam['persone_richieste'] ?? 0}"),
              Text("Pagamento: ${jam['pagamento'] ?? 'N/A'}"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Chiudi"),
          ),
          ElevatedButton(
            onPressed: () => _joinJam(jam['key']),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            child: const Text("Partecipa"),
          ),
        ],
      ),
    );
  }

  void _joinJam(String jamId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funzionalità "Partecipa" in arrivo!')),
    );
  }

  void _deleteJam(String jamId) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Elimina Jam"),
        content: const Text("Sei sicuro di voler eliminare questa Jam Session?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annulla"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _databaseService.deleteJam(jamId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Jam eliminata correttamente")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Errore: ${e.toString()}")),
                  );
                }
              }
            },
            child: const Text("Elimina", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editJam(String jamId, Map data) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Funzionalità di modifica non ancora disponibile")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      body: StreamBuilder<DatabaseEvent>(
        stream: _databaseService.getJamsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text('Non ci sono Jam session attive.'));
          }

          final dynamic rawData = snapshot.data!.snapshot.value;
          List<Map<String, dynamic>> jams = [];

          try {
            if (rawData is Map) {
              jams = rawData.entries.map((entry) {
                final jamData = Map<String, dynamic>.from(entry.value as Map);
                jamData['key'] = entry.key; 
                return jamData;
              }).toList();
            } else if (rawData is List) {
              for (int i = 0; i < rawData.length; i++) {
                if (rawData[i] != null) {
                  final jamData = Map<String, dynamic>.from(rawData[i] as Map);
                  jamData['key'] = i.toString();
                  jams.add(jamData);
                }
              }
            }
          } catch (e) {
            return Center(child: Text('Errore nel formato dati: $e'));
          }
          
          jams.sort((a, b) => (b['data'] ?? '').compareTo(a['data'] ?? ''));

          if (jams.isEmpty) {
             return const Center(child: Text('Non ci sono Jam session attive.'));
          }

          return ListView.builder(
            itemCount: jams.length,
            itemBuilder: (context, index) {
              final jam = jams[index];
              final date = jam['data'] ?? 'N/A';
              final startTime = jam['ora_inizio'] ?? 'N/A';
              final endTime = jam['ora_fine'] ?? 'N/A';
              final desc = jam['descrizione'] ?? '';
              final payment = jam['pagamento'] ?? 'Diviso';
              final present = jam['persone_presenti'] ?? 0;
              final required = jam['persone_richieste'] ?? 0;
              final jamId = jam['key'];
              final creatorId = jam['creator_id'];
              
              final isMyJam = currentUser != null && creatorId == currentUser.uid;

              return InkWell(
                onTap: () => _showJamDetails(jam),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.music_note, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                  date,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            if (isMyJam)
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editJam(jamId, jam);
                                  } else if (value == 'delete') {
                                    _deleteJam(jamId);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: ListTile(leading: Icon(Icons.edit), title: Text('Modifica')),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Elimina', style: TextStyle(color: Colors.red))),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        Text('$startTime - $endTime', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(desc, style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 12),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.people, size: 18, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('$present presenti / Cerchiamo $required'),
                              ],
                            ),
                            Chip(
                              label: Text(payment, style: const TextStyle(fontSize: 12)),
                              backgroundColor: payment == 'Offerto' ? Colors.green[100] : Colors.orange[100],
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
