import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/app/features/app_scaffold_mobile.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/database_service.dart';

class OrganizeJamPageMobile extends StatefulWidget {
  const OrganizeJamPageMobile({super.key});

  @override
  State<OrganizeJamPageMobile> createState() => _OrganizeJamPageMobileState();
}

class _OrganizeJamPageMobileState extends State<OrganizeJamPageMobile> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();
  final _auth = FirebaseAuth.instance;

  // Stato UI
  bool _isLoading = false;
  bool _isLoadingSlots = false;
  bool _isLoadingDates = true;

  // Dati
  List<DateTime> _availableDates = [];
  List<String> _availableSlots = [];
  List<Map<String, String>> _userGroups = [];
  
  static const _slotDurationMinutes = 75;

  // Selezioni Utente
  DateTime? _selectedDate;
  final List<String> _selectedSlots = [];
  String? _selectedPayment; 
  String? _selectedGroupId;

  // Controller
  final _presentPeopleController = TextEditingController();
  final _requiredPeopleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _equipmentController = TextEditingController();

  final List<String> _paymentOptions = ['Offerto', 'Diviso'];

  @override
  void initState() {
    super.initState();
    _loadAvailableDates();
    _loadUserGroups();
  }

  Future<void> _loadUserGroups() async {
    final groups = await _databaseService.getUserGroups();
    if (mounted) {
      setState(() {
        _userGroups = groups;
      });
    }
  }

  Future<void> _loadAvailableDates() async {
    final now = DateTime.now();
    final candidateDates = List.generate(30, (index) => now.add(Duration(days: index)));
    
    final results = await Future.wait(candidateDates.map((date) async {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      try {
        final freeSlots = await _databaseService.getFreeSlotsForDate(dateStr);
        bool hasBookableSlot = false;
        for (final slot in freeSlots) {
          if (_isSlotAtLeast24HoursAway(slot, date)) {
            hasBookableSlot = true;
            break; 
          }
        }
        return hasBookableSlot ? date : null;
      } catch (e) {
        debugPrint("Errore controllo data $dateStr: $e");
        return null;
      }
    }));

    if (mounted) {
      setState(() {
        _availableDates = results.whereType<DateTime>().toList();
        _isLoadingDates = false;
        
        if (_selectedDate != null && !_availableDates.any((d) => _isSameDay(d, _selectedDate!))) {
          _selectedDate = null;
          _availableSlots.clear();
        }
      });
    }
  }

  Future<void> _loadAvailableSlots() async {
    if (_selectedDate == null) return;

    setState(() {
      _isLoadingSlots = true;
      _selectedSlots.clear();
      _availableSlots.clear();
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final freeSlotsFromDb = await _databaseService.getFreeSlotsForDate(dateStr);
      
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
    final minAllowedStart = DateTime.now().add(const Duration(hours: 24));
    return slotDateTime.isAfter(minAllowedStart);
  }

  Future<void> _selectDateFromCalendar(BuildContext context) async {
    final now = DateTime.now();
    final lastDate = now.add(const Duration(days: 30));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? _availableDates.firstOrNull ?? now,
      firstDate: now,
      lastDate: lastDate,
      selectableDayPredicate: (DateTime day) {
        return _availableDates.any((available) => _isSameDay(available, day));
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAvailableSlots();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _toggleSlot(String slot) {
    setState(() {
      if (_selectedSlots.contains(slot)) {
        _selectedSlots.remove(slot);
      } else {
        _selectedSlots.add(slot);
        _selectedSlots.sort(); 
      }
    });
  }

  Future<void> _submitJam() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona una data')));
       return;
    }
    
    if (_selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona almeno un orario')));
      return;
    }

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

      final startSlot = _selectedSlots.first;
      final endSlotLast = _selectedSlots.last;
      
      final endMin = _timeToMinutes(endSlotLast) + _slotDurationMinutes;
      final endHour = (endMin ~/ 60).toString().padLeft(2, '0');
      final endMinute = (endMin % 60).toString().padLeft(2, '0');
      final endTimeStr = "$endHour:$endMinute";

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      final jam = Jam(
        creatorId: user.uid,
        groupId: _selectedGroupId,
        data: dateStr,
        oraInizio: startSlot,
        oraFine: endTimeStr,
        personePresenti: int.parse(_presentPeopleController.text),
        personeRichieste: int.parse(_requiredPeopleController.text),
        descrizione: _descriptionController.text,
        pagamento: _selectedPayment!,
        attrezzatura: _equipmentController.text,
      );

      await _databaseService.createJam(jam, _selectedSlots);

      if (mounted) {
        if (loadingDialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingDialogShown = false;
        }

        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => AlertDialog(
            title: const Text('Jam Organizzata!'),
            content: const Text('La tua Jam Session è stata pubblicata.'),
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
            builder: (_) => const AppScaffoldMobile(initialIndex: 2),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Errore submit jam: $e");
      if (mounted) {
        if (loadingDialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingDialogShown = false;
        }
        _loadAvailableSlots(); 
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
              // 1. Data e Orari
              _isLoadingDates
                  ? const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : InkWell(
                      onTap: _availableDates.isEmpty ? null : () => _selectDateFromCalendar(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Seleziona Giorno',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _selectedDate == null
                              ? (_availableDates.isEmpty ? 'Nessuna data disponibile' : 'Tocca per scegliere')
                              : DateFormat('EEEE d MMMM yyyy').format(_selectedDate!),
                          style: TextStyle(color: _selectedDate == null ? Colors.grey : Colors.black),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),

              if (_selectedDate != null) ...[
                const Text("Seleziona Orari", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _isLoadingSlots 
                  ? const Center(child: CircularProgressIndicator())
                  : _availableSlots.isEmpty 
                    ? const Text("Nessuna disponibilità.")
                    : Wrap(
                        spacing: 8.0,
                        children: _availableSlots.map((slot) {
                          return FilterChip(
                            label: Text(slot),
                            selected: _selectedSlots.contains(slot),
                            onSelected: (_) => _toggleSlot(slot),
                            selectedColor: Colors.green[200],
                          );
                        }).toList(),
                      ),
                 const SizedBox(height: 8),
                 if (_selectedSlots.isNotEmpty)
                   Text("Intervallo: ${_selectedSlots.first} - ${_calculateEndTime(_selectedSlots.last)}",
                     style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

                // 2. Campi Specifici Jam
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _presentPeopleController,
                        decoration: const InputDecoration(
                          labelText: 'Persone presenti',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Obbligatorio';
                          if (int.tryParse(value) == null) return 'Inserisci un numero';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _requiredPeopleController,
                        decoration: const InputDecoration(
                          labelText: 'Persone richieste',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_add),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Obbligatorio';
                          final n = int.tryParse(value);
                          if (n == null || n < 1 || n > 20) return 'Tra 1 e 20';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrizione',
                    hintText: 'Descrivi la tua jam o chi stai cercando...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                  validator: (value) => value == null || value.isEmpty ? 'Inserisci una descrizione' : null,
                ),
                const SizedBox(height: 16),

                // Gruppo e Pagamento sulla stessa riga
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Gruppo',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                        ),
                        initialValue: _selectedGroupId,
                        items: _userGroups.map((group) {
                          return DropdownMenuItem(
                            value: group['id'],
                            child: Text(group['name'] ?? '', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedGroupId = value),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Pagamento',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.payment),
                        ),
                        initialValue: _selectedPayment,
                        items: _paymentOptions.map((opt) {
                          return DropdownMenuItem(value: opt, child: Text(opt));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedPayment = val),
                        validator: (value) => value == null ? 'Obbligatorio' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _equipmentController,
                  decoration: const InputDecoration(
                    labelText: 'Attrezzatura (Opzionale)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.speaker),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submitJam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[850],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('PUBBLICA JAM', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
