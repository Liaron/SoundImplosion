import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/jam/find_jam_controller.dart';
import 'package:soundimplosion/app/features/jam/jam_repository.dart';
import 'package:soundimplosion/app/features/jam/organize_jam_page_mobile.dart';
import 'package:soundimplosion/app/features/jam/view/mobile/custom_multi_month_picker.dart';

class FindJamPageMobile extends StatefulWidget {
  // Parametro per aprire una jam specifica al caricamento
  final Map<String, dynamic>? initialJamToOpen;

  const FindJamPageMobile({super.key, this.initialJamToOpen});

  @override
  State<FindJamPageMobile> createState() => _FindJamPageMobileState();
}

class _FindJamPageMobileState extends State<FindJamPageMobile> {
  late final FindJamController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FindJamController(
      currentUserId: FirebaseAuth.instance.currentUser?.uid,
    );
    _controller.addListener(_handleControllerChanged);
    _controller.initialize();
    if (widget.initialJamToOpen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openInitialJam(widget.initialJamToOpen!);
      });
    }
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

  Future<void> _openInitialJam(Map<String, dynamic> rawJam) async {
    final jamId = rawJam['jam_id']?.toString() ?? rawJam['key']?.toString();
    if (jamId != null && jamId.isNotEmpty) {
      final loadedJam = await _controller.loadJamById(jamId);
      if (!mounted) {
        return;
      }
      if (loadedJam != null) {
        _showJamDetails(loadedJam);
        return;
      }
    }

    if (!mounted) {
      return;
    }

    final jam = JamListItem.fromMap(
      rawJam['key']?.toString() ?? jamId ?? 'initial-jam',
      Map<String, dynamic>.from(rawJam),
    );
    _showJamDetails(jam);
  }

  void _showJamDetails(JamListItem jam) {
    final isOwnedByCurrentUser = jam.isOwnedBy(_controller.currentUserId);
    final isJoinedByCurrentUser = jam.isJoinedBy(_controller.currentUserId);
    final canJoin =
        jam.isPublished &&
        !isOwnedByCurrentUser &&
        !isJoinedByCurrentUser &&
        jam.hasOpenSpots;
    final canLeave = isJoinedByCurrentUser && !isOwnedByCurrentUser;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Dettagli Jam"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((jam.jam.creatorNickname ?? '').isNotEmpty) ...[
                Text(
                  'Organizzata da: ${jam.jam.creatorNickname}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],
              if (jam.hasGroup) ...[
                Text('Gruppo associato: ${jam.groupLabel}'),
                const SizedBox(height: 8),
              ],
              Text('Data: ${jam.dateLabel}'),
              Text('Orario: ${jam.timeRangeLabel}'),
              const SizedBox(height: 16),
              const Text(
                "Descrizione: ",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(jam.jam.descrizione),
              const SizedBox(height: 8),
              if (jam.jam.attrezzatura.trim().isNotEmpty)
                Text('Attrezzatura: ${jam.jam.attrezzatura}'),
              if (jam.jam.attrezzatura.trim().isNotEmpty)
                const SizedBox(height: 8),
              Text(
                'Presenti confermati: ${jam.confirmedParticipantsCount} • Ancora richiesti: ${jam.remainingSpots}',
              ),
              Text(
                isOwnedByCurrentUser
                    ? 'Stato partecipazione: sei il creatore'
                    : isJoinedByCurrentUser
                    ? 'Stato partecipazione: stai partecipando'
                    : jam.hasOpenSpots
                    ? 'Stato partecipazione: puoi unirti'
                    : 'Stato partecipazione: jam al completo',
              ),
              Text('Pagamento: ${jam.paymentLabel}'),
              Text('Stato: ${jam.statusLabel}'),
              const SizedBox(height: 16),
              const Text(
                'Partecipanti confermati',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FutureBuilder<Map<String, String>>(
                future: _controller.loadParticipantUsernames(jam.participantIds),
                builder: (context, snapshot) {
                  final names = snapshot.data?.values.toList() ?? jam.confirmedParticipantNames;
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      names.isEmpty) {
                    return const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (names.isEmpty) {
                    return const Text('Nessun partecipante aggiuntivo confermato.');
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: names.map((name) => Chip(label: Text(name))).toList(),
                  );
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
          ElevatedButton(
            onPressed: canJoin
                ? () => _joinJam(jam.id)
                : canLeave
                ? () => _leaveJam(jam.id)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            child: Text(
              isOwnedByCurrentUser
                  ? (jam.isPublished ? 'La tua jam' : 'In approvazione')
                  : isJoinedByCurrentUser
                  ? 'Esci'
                  : jam.hasOpenSpots
                  ? (jam.isPublished ? 'Partecipa' : 'Non disponibile')
                  : 'Al completo',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinJam(String jamId) async {
    Navigator.of(context).pop();

    try {
      await _controller.joinJam(jamId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partecipazione confermata')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _leaveJam(String jamId) async {
    Navigator.of(context).pop();

    try {
      await _controller.leaveJam(jamId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sei uscito dalla jam')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  void _deleteJam(String jamId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Elimina Jam"),
        content: const Text(
          "Sei sicuro di voler eliminare questa Jam Session?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annulla"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _controller.deleteJam(jamId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Jam eliminata correttamente"),
                    ),
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

  Future<void> _editJam(String jamId, Map data) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrganizeJamPageMobile(
          initialJam: JamListItem.fromMap(
            jamId,
            Map<String, dynamic>.from(data),
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam aggiornata correttamente')),
      );
    }
  }

  Future<void> _selectDates(
    BuildContext context,
    Function(List<DateTime>) onDatesSelected,
  ) async {
    final navigator = Navigator.of(context);
    // 1. Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final availableDays = await _controller.loadAvailableFilterDates();

      if (!mounted || !context.mounted) {
        return;
      }
      navigator.pop(); // Dismiss loading

      // 3. Show Custom Picker
      final result = await showDialog<List<DateTime>>(
        context: context,
        builder: (ctx) => CustomMultiMonthPicker(
          jamDates: availableDays,
          selectedDates: _controller.selectedDates,
        ),
      );

      if (result != null) {
        onDatesSelected(result);
      }
    } catch (e) {
      if (mounted && context.mounted) {
        navigator.pop();
      }
      debugPrint("Error selecting dates: $e");
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      barrierDismissible:
          true, // User can close it, but it won't auto-close on selection
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
                              const Text(
                                "Date selezionate:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _controller.selectedDates.isEmpty
                                    ? 'Tutte'
                                    : '${_controller.selectedDates.length} date',
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
                                  setStateDialog(() {
                                    _controller.setSelectedDates(dates);
                                  });
                                });
                              },
                              child: const Text('Seleziona'),
                            ),
                            if (_controller.selectedDates.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setStateDialog(() {
                                    _controller.clearSelectedDates();
                                  });
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
                      value: _controller.showMyJams,
                      onChanged: (bool value) {
                        setStateDialog(() {
                          _controller.setShowMyJams(value);
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Jam a cui partecipo'),
                      value: _controller.showParticipatingJams,
                      onChanged: (bool value) {
                        setStateDialog(() {
                          _controller.setShowParticipatingJams(value);
                        });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cerca Jam"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.streamError != null) {
            return Center(child: Text('Errore: ${_controller.streamError}'));
          }

          if (_controller.allJams.isEmpty) {
            return const Center(child: Text('Non ci sono Jam session attive.'));
          }

          final filteredJams = _controller.filteredJams;

          return Column(
            children: [
              // Show active filters summary
              if (_controller.selectedDates.isNotEmpty ||
                  _controller.showMyJams ||
                  _controller.showParticipatingJams)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Text(
                        "Filtri attivi: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_controller.showMyJams)
                        const Chip(
                          label: Text("Mie Jam"),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (_controller.showParticipatingJams)
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Chip(
                            label: Text('Partecipo'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      if (_controller.selectedDates.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Chip(
                            label: Text(
                              '${_controller.selectedDates.length} date',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: _controller.resetFilters,
                        child: const Text("Reset"),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: filteredJams.isEmpty
                    ? const Center(
                        child: Text(
                          'Nessuna jam corrisponde ai filtri selezionati.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredJams.length,
                        itemBuilder: (context, index) {
                          final jam = filteredJams[index];
                          final isMyJam = jam.isOwnedBy(
                            _controller.currentUserId,
                          );

                          return InkWell(
                            onTap: () => _showJamDetails(jam),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.music_note,
                                              color: Colors.red,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              jam.dateLabel,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (isMyJam)
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _editJam(jam.id, jam.toMap());
                                              } else if (value == 'delete') {
                                                _deleteJam(jam.id);
                                              }
                                            },
                                            itemBuilder:
                                                (
                                                  BuildContext context,
                                                ) => <PopupMenuEntry<String>>[
                                                  const PopupMenuItem<String>(
                                                    value: 'edit',
                                                    child: ListTile(
                                                      leading: Icon(Icons.edit),
                                                      title: Text('Modifica'),
                                                    ),
                                                  ),
                                                  const PopupMenuItem<String>(
                                                    value: 'delete',
                                                    child: ListTile(
                                                      leading: Icon(
                                                        Icons.delete,
                                                        color: Colors.red,
                                                      ),
                                                      title: Text(
                                                        'Elimina',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                          ),
                                      ],
                                    ),
                                    if ((jam.jam.creatorNickname ?? '')
                                        .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          'Organizzata da: ${jam.jam.creatorNickname}',
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      jam.timeRangeLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (jam.hasGroup)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Gruppo: ${jam.groupLabel}',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      jam.jam.descrizione,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Chip(
                                        label: Text(
                                          jam.statusLabel,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: jam.isPublished
                                            ? Colors.green[100]
                                            : Colors.orange[100],
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.people,
                                              size: 18,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${jam.confirmedParticipantsCount} presenti / Mancano ${jam.remainingSpots}',
                                            ),
                                          ],
                                        ),
                                        Chip(
                                          label: Text(
                                            jam.paymentLabel,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          backgroundColor:
                                              jam.paymentLabel == 'Offerto'
                                              ? Colors.green[100]
                                              : Colors.orange[100],
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
