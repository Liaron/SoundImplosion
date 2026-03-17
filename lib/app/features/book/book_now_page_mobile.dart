import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/app/features/app_scaffold_mobile.dart';
import 'package:soundimplosion/app/features/book/book_now_controller.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';

class BookNowPageMobile extends StatefulWidget {
  const BookNowPageMobile({super.key, this.initialBooking});

  final BookingListItem? initialBooking;

  @override
  State<BookNowPageMobile> createState() => _BookNowPageMobileState();
}

class _BookNowPageMobileState extends State<BookNowPageMobile> {
  final _formKey = GlobalKey<FormState>();
  final BookNowController _controller = BookNowController();

  final _peopleController = TextEditingController();
  final _equipmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    _prefillFromExistingBooking();
    _controller.initialize(initialBooking: widget.initialBooking);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _peopleController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isEditing => widget.initialBooking != null;

  void _prefillFromExistingBooking() {
    final booking = widget.initialBooking?.booking;
    if (booking == null) {
      return;
    }

    _peopleController.text = booking.numeroUtenti.toString();
    _equipmentController.text = booking.attrezzatura;
  }

  // --- Gestione Calendario ---

  Future<void> _selectDateFromCalendar(BuildContext context) async {
    final now = DateTime.now();
    final lastDate = now.add(const Duration(days: 30));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _controller.selectedDate ?? _controller.availableDates.firstOrNull ?? now,
      firstDate: now,
      lastDate: lastDate,
      // Questa funzione abilita solo i giorni presenti in _availableDates
      selectableDayPredicate: (DateTime day) {
        return _controller.availableDates.any((available) => _isSameDay(available, day));
      },
    );

    if (picked != null && picked != _controller.selectedDate) {
      try {
        await _controller.selectDate(picked);
      } catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento orari: $e')),
        );
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final validationError = _controller.validateSelection();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    bool loadingDialogShown = false;

    if (mounted) {
      loadingDialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      await _controller.submitBooking(
        peopleCount: int.parse(_peopleController.text),
        equipment: _equipmentController.text,
      );

      if (mounted) {
        if (loadingDialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingDialogShown = false;
        }

        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => AlertDialog(
            title: Text(_isEditing ? 'Prenotazione aggiornata' : 'Prenotazione inviata'),
            content: Text(
              _isEditing
                  ? 'Le modifiche alla prenotazione sono state salvate.'
                  : 'La prenotazione è stata registrata con successo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        if (_isEditing) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const AppScaffoldMobile(initialIndex: 1),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint("Errore submit: $e");
      if (mounted) {
        if (loadingDialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingDialogShown = false;
        }
        await _controller.refreshAvailableSlots();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBookingForm = _controller.selectedDate != null;

    return Scaffold(
      appBar: _isEditing ? AppBar(title: const Text('Modifica Prenotazione')) : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _controller.isLoadingDates
                  ? const SizedBox(
                      height: 60,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 16),
                            Text("Verifica disponibilità date..."),
                          ],
                        ),
                      ),
                    )
                  : InkWell(
                      onTap: _controller.availableDates.isEmpty 
                        ? null 
                        : () => _selectDateFromCalendar(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Seleziona Giorno',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _controller.selectedDate == null
                            ? (_controller.availableDates.isEmpty 
                                  ? 'Nessuna data disponibile' 
                                  : 'Tocca per scegliere una data')
                            : DateFormat('EEEE d MMMM yyyy').format(_controller.selectedDate!),
                          style: _controller.selectedDate == null 
                            ? TextStyle(color: Colors.grey[600]) 
                            : const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),

              if (showBookingForm) ...[
                // 2. Selezione Orari (Multi-select Chips)
                const Text(
                  "Seleziona Orari (slot da 75 min)", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                const SizedBox(height: 8),
                _controller.isLoadingSlots 
                  ? const Center(child: CircularProgressIndicator())
                  : _controller.availableSlots.isEmpty 
                    ? const Text("Nessuna disponibilità per questa data.")
                    : Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _controller.availableSlots.map((slot) {
                          final isSelected = _controller.selectedSlots.contains(slot);
                          return FilterChip(
                            label: Text(slot),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              _controller.toggleSlot(slot);
                            },
                            selectedColor: Colors.green[200],
                            checkmarkColor: Colors.green[900],
                          );
                        }).toList(),
                      ),
                 const SizedBox(height: 8),
                 if (_controller.selectedRangeLabel != null)
                   Text(
                     'Intervallo selezionato: ${_controller.selectedRangeLabel!}',
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
                  initialValue: _controller.selectedGroupId,
                  items: _controller.userGroups.map((group) {
                    return DropdownMenuItem(
                      value: group['id'],
                      child: Text(group['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: _controller.setSelectedGroup,
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
                  onPressed: _controller.isLoading ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[850],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _controller.isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(
                        _isEditing ? 'SALVA MODIFICHE' : 'INVIA PRENOTAZIONE',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
