import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/services/database_service.dart';
import 'package:soundimplosion/app/features/jam/view/mobile/custom_multi_month_picker.dart';

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

  // State per i filtri
  List<DateTime> _selectedDates = [];
  bool _showMyJams = false;
  bool _showParticipatingJams = false;
  List<Map<String, dynamic>> _allJams = [];

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
              if (jam['creator_nickname'] != null) ...[
                Text("Organizzata da: ${jam['creator_nickname']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
              ],
              Text("Data: ${jam['data'] ?? 'N/A'}"),
              Text("Orario: ${jam['ora_inizio'] ?? 'N/A'} - ${jam['ora_fine'] ?? 'N/A'}"),
              const SizedBox(height: 16),
              const Text("Descrizione: ", style: TextStyle(fontWeight: FontWeight.bold)),
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
  
  DateTime? _parseDate(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(dateStr);
    } catch (e) {
      return null;
    }
  }

  bool _isJamPublished(Map<String, dynamic> jam) {
    final dynamic rawState = jam['stato'] ?? jam['status'];
    if (rawState == null) {
      return true;
    }
    final state = rawState.toString().toLowerCase();
    return state == 'pubblicata' || state == 'published';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _selectDates(BuildContext context, Function(List<DateTime>) onDatesSelected) async {
    // 1. Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // 2. Fetch data (Jams)
      // Note: We fetch ALL jams to determine which days have active jams
      // This might be redundant if we already have the stream, but the request asks for a request on click.
      final jams = await _databaseService.getPublishedJamsOnce();

      final Set<DateTime> availableDays = {};
      for (final jam in jams) {
        if (!_isJamPublished(jam)) continue;
        final parsed = _parseDate(jam['data'] ?? '');
        if (parsed != null) {
          availableDays.add(DateTime(parsed.year, parsed.month, parsed.day));
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading

      // 3. Show Custom Picker
      final result = await showDialog<List<DateTime>>(
        context: context,
        builder: (ctx) => CustomMultiMonthPicker(
          jamDates: availableDays.toList(),
          selectedDates: _selectedDates,
        ),
      );

      if (result != null) {
        onDatesSelected(result);
      }
    } catch (e) {
       if (mounted) Navigator.pop(context); // Dismiss loading on error
       debugPrint("Error selecting dates: $e");
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      barrierDismissible: true, // User can close it, but it won't auto-close on selection
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Filtri di ricerca'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Date selezionate:", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                _selectedDates.isEmpty
                                    ? 'Tutte'
                                    : '${_selectedDates.length} date',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                _selectDates(context, (dates) {
                                  // Update state inside dialog
                                  setStateDialog(() {
                                    _selectedDates = dates;
                                  });
                                  // Update main state
                                  setState(() {
                                    _selectedDates = dates;
                                  });
                                });
                              },
                              child: const Text('Seleziona'),
                            ),
                            if (_selectedDates.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setStateDialog(() => _selectedDates = []);
                                  setState(() => _selectedDates = []);
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Solo le mie Jam'),
                      value: _showMyJams,
                      onChanged: (bool value) {
                        setStateDialog(() {
                          _showMyJams = value;
                        });
                        setState(() {
                          _showMyJams = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Jam a cui partecipo'),
                      value: _showParticipatingJams,
                      onChanged: (bool value) {
                         setStateDialog(() {
                            _showParticipatingJams = value;
                         });
                         setState(() {
                            _showParticipatingJams = value;
                         });
                         if (value) {
                             ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Filtro "Partecipo" non ancora disponibile.')),
                             );
                         }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Chiudi"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cerca Jam"),
        actions: [
           IconButton(
             icon: const Icon(Icons.filter_list),
             onPressed: _showFilterDialog,
           )
        ],
      ),
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
            _allJams = [];
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

          _allJams = List<Map<String, dynamic>>.from(jams);

          // Applica i filtri
          List<Map<String, dynamic>> filteredJams = _allJams.where(_isJamPublished).toList();

          if (_showMyJams) {
            filteredJams = filteredJams.where((jam) {
              return jam['creator_id'] == currentUser?.uid;
            }).toList();
          }

          if (_showParticipatingJams) {
            // La logica di questo filtro non è applicata
          }

          if (_selectedDates.isNotEmpty) {
            filteredJams = filteredJams.where((jam) {
              final jamDateStr = jam['data'] ?? '';
              final jamDate = _parseDate(jamDateStr);
              if (jamDate == null) return false;

              return _selectedDates.any((selected) => _isSameDay(selected, jamDate));
            }).toList();
          }

          filteredJams.sort((a, b) {
            final dateA = _parseDate(a['data'] ?? '');
            final dateB = _parseDate(b['data'] ?? '');
            if (dateA == null || dateB == null) return 0;
            return dateB.compareTo(dateA);
          });
          
          return Column(
            children: [
              // Show active filters summary
              if (_selectedDates.isNotEmpty || _showMyJams)
                 Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: Row(
                     children: [
                       const Text("Filtri attivi: ", style: TextStyle(fontWeight: FontWeight.bold)),
                       if (_showMyJams) const Chip(label: Text("Mie Jam"), visualDensity: VisualDensity.compact),
                       if (_selectedDates.isNotEmpty)
                         Padding(
                           padding: const EdgeInsets.only(left: 4.0),
                           child: Chip(label: Text("${_selectedDates.length} date"), visualDensity: VisualDensity.compact),
                         ),
                       const Spacer(),
                       TextButton(
                         onPressed: () {
                           setState(() {
                             _selectedDates = [];
                             _showMyJams = false;
                           });
                         },
                         child: const Text("Reset")
                       )
                     ],
                   ),
                 ),

              Expanded(
                child: filteredJams.isEmpty
                    ? const Center(child: Text('Nessuna jam corrisponde ai filtri selezionati.'))
                    : ListView.builder(
                        itemCount: filteredJams.length,
                        itemBuilder: (context, index) {
                          final jam = filteredJams[index];
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
                                    if (jam['creator_nickname'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          "Organizzata da: ${jam['creator_nickname']}",
                                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                                        ),
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
