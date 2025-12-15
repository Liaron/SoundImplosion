import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/app/features/app_scaffold_mobile.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/database_service.dart';

class BookNowPageMobile extends StatefulWidget {
  const BookNowPageMobile({super.key});

  @override
  State<BookNowPageMobile> createState() => _BookNowPageMobileState();
}

class _BookNowPageMobileState extends State<BookNowPageMobile> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();
  final _auth = FirebaseAuth.instance;

  // Stato UI
  bool _isLoading = false;
  bool _isLoadingSlots = false;

  // Dati
  List<DateTime> _next30Days = [];
  List<Map<String, String>> _userGroups = [];
  List<String> _availableSlots = []; // Lista di orari "HH:mm" disponibili
  
  static const _slotDurationMinutes = 75;

  // Selezioni Utente
  DateTime? _selectedDate;
  final List<String> _selectedSlots = []; // Slot selezionati dall'utente
  String? _selectedGroupId;

  // Controller
  final _peopleController = TextEditingController();
  final _equipmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generateNext30Days();
    _loadUserGroups();
  }

  void _generateNext30Days() {
    final now = DateTime.now();
    _next30Days = List.generate(30, (index) => now.add(Duration(days: index)));
  }

  Future<void> _loadUserGroups() async {
    final groups = await _databaseService.getUserGroups();
    if (mounted) {
      setState(() {
        _userGroups = groups;
      });
    }
  }

  // --- Calcolo Slot Disponibili ---

  Future<void> _loadAvailableSlots() async {
    if (_selectedDate == null) return;

    setState(() {
      _isLoadingSlots = true;
      _selectedSlots.clear();
      _availableSlots.clear();
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      // NUOVA LOGICA: Chiediamo al DB quali slot sono liberi per questa data.
      // Se non esistono, il DB li genererà al volo.
      final freeSlotsFromDb = await _databaseService.getFreeSlotsForDate(dateStr);
      
      // Filtro aggiuntivo: rimuoviamo slot passati (se oggi) o troppo vicini (regola 24h opzionale)
      final validSlots = <String>[];
      for (final slot in freeSlotsFromDb) {
        if (_isSlotAtLeast24HoursAway(slot, _selectedDate!)) {
          validSlots.add(slot);
        }
      }

      if (mounted) {
        setState(() {
          _availableSlots = validSlots;
        });
      }
    } catch (e) {
      debugPrint("Errore caricamento slot: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore caricamento orari: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
        });
      }
    }
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  bool _isSlotAtLeast24HoursAway(String slot, DateTime date) {
    final parts = slot.split(':');
    final slotDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    // Controllo 24 ore (o logica personalizzata)
    final minAllowedStart = DateTime.now().add(const Duration(hours: 24));
    return slotDateTime.isAfter(minAllowedStart);
  }

  // --- Gestione Selezione Slot ---

  void _toggleSlot(String slot) {
    setState(() {
      if (_selectedSlots.contains(slot)) {
        _selectedSlots.remove(slot);
      } else {
        _selectedSlots.add(slot);
        _selectedSlots.sort(); // Mantiene ordine temporale
      }
    });
  }

  // --- Invio Prenotazione ---

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona una data')));
       return;
    }
    
    if (_selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona almeno un orario')));
      return;
    }

    // Verifica continuità degli slot
    if (!_areSlotsContiguous(_selectedSlots)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gli orari selezionati devono essere consecutivi.')));
      return;
    }

    bool loadingDialogShown = false;

    setState(() {
      _isLoading = true;
    });

    if (mounted) {
      loadingDialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("Utente non loggato");

      // Calcola inizio e fine totali
      final startSlot = _selectedSlots.first;
      final endSlotLast = _selectedSlots.last;
      
      // L'ora di fine è la fine dell'ultimo slot (+75 min)
      final endMin = _timeToMinutes(endSlotLast) + _slotDurationMinutes;
      final endHour = (endMin ~/ 60).toString().padLeft(2, '0');
      final endMinute = (endMin % 60).toString().padLeft(2, '0');
      final endTimeStr = "$endHour:$endMinute";

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      final booking = Booking(
        userId: user.uid,
        groupId: _selectedGroupId,
        data: dateStr,
        oraInizio: startSlot,
        oraFine: endTimeStr,
        numeroUtenti: int.parse(_peopleController.text),
        attrezzatura: _equipmentController.text,
        stato: BookingStatus.inElaborazione,
      );

      // Passiamo anche la lista degli slot selezionati per aggiornarne lo stato nel DB
      await _databaseService.createBooking(booking, _selectedSlots);

      if (mounted) {
        if (loadingDialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingDialogShown = false;
        }

        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => AlertDialog(
            title: const Text('Prenotazione inviata'),
            content: const Text('La prenotazione è stata registrata con successo.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const AppScaffoldMobile(initialIndex: 1),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Errore submit: $e");
      if (mounted) {
        if (loadingDialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingDialogShown = false;
        }
        _loadAvailableSlots(); // Ricarica per mostrare stato aggiornato
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _areSlotsContiguous(List<String> slots) {
    if (slots.length <= 1) return true;
    
    for (int i = 0; i < slots.length - 1; i++) {
      final current = _timeToMinutes(slots[i]);
      final next = _timeToMinutes(slots[i+1]);
      // Devono distare esattamente 75 minuti
      if (next - current != _slotDurationMinutes) return false;
    }
    return true;
  }
  
  String _calculateEndTime(String startSlot) {
    final min = _timeToMinutes(startSlot) + _slotDurationMinutes;
    final h = (min ~/ 60).toString().padLeft(2, '0');
    final m = (min % 60).toString().padLeft(2, '0');
    return "$h:$m";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1. Selezione Giorno (Menu a tendina 30gg)
              DropdownButtonFormField<DateTime>(
                decoration: const InputDecoration(
                  labelText: 'Seleziona Giorno',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                value: _selectedDate,
                items: _next30Days.map((date) {
                  return DropdownMenuItem(
                    value: date,
                    child: Text(DateFormat('EEEE d MMMM yyyy').format(date)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && value != _selectedDate) {
                    setState(() {
                      _selectedDate = value;
                    });
                    _loadAvailableSlots();
                  }
                },
              ),
              const SizedBox(height: 24),

              // Mostra il resto solo se data selezionata
              if (_selectedDate != null) ...[
                
                // 2. Selezione Orari (Multi-select Chips)
                const Text(
                  "Seleziona Orari (slot da 75 min)", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                const SizedBox(height: 8),
                _isLoadingSlots 
                  ? const Center(child: CircularProgressIndicator())
                  : _availableSlots.isEmpty 
                    ? const Text("Nessuna disponibilità per questa data.")
                    : Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _availableSlots.map((slot) {
                          final isSelected = _selectedSlots.contains(slot);
                          return FilterChip(
                            label: Text(slot),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              _toggleSlot(slot);
                            },
                            selectedColor: Colors.green[200],
                            checkmarkColor: Colors.green[900],
                          );
                        }).toList(),
                      ),
                 const SizedBox(height: 8),
                 if (_selectedSlots.isNotEmpty)
                   Text(
                     "Intervallo selezionato: ${_selectedSlots.first} - ${_calculateEndTime(_selectedSlots.last)}",
                     style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                   ),

                const SizedBox(height: 24),

                // 3. Numero Persone
                TextFormField(
                  controller: _peopleController,
                  decoration: const InputDecoration(
                    labelText: 'Numero di persone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Obbligatorio';
                    final n = int.tryParse(value);
                    if (n == null || n < 1 || n > 10) return 'Tra 1 e 10';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 4. Gruppo
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Gruppo (Opzionale)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                  value: _selectedGroupId,
                  items: _userGroups.map((group) {
                    return DropdownMenuItem(
                      value: group['id'],
                      child: Text(group['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedGroupId = value),
                ),
                const SizedBox(height: 16),

                // 5. Attrezzatura
                TextFormField(
                  controller: _equipmentController,
                  decoration: const InputDecoration(
                    labelText: 'Attrezzatura (Opzionale)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.speaker),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // 6. Invia
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[850],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('INVIA PRENOTAZIONE', style: TextStyle(fontSize: 16)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
