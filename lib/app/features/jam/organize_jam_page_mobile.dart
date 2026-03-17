import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/app/features/app_scaffold_mobile.dart';
import 'package:soundimplosion/app/features/jam/organize_jam_controller.dart';
import 'package:soundimplosion/app/features/jam/jam_repository.dart';

class OrganizeJamPageMobile extends StatefulWidget {
  const OrganizeJamPageMobile({super.key, this.initialJam});

  final JamListItem? initialJam;

  @override
  State<OrganizeJamPageMobile> createState() => _OrganizeJamPageMobileState();
}

class _OrganizeJamPageMobileState extends State<OrganizeJamPageMobile> {
  final _formKey = GlobalKey<FormState>();
  final OrganizeJamController _controller = OrganizeJamController();

  final _presentPeopleController = TextEditingController();
  final _requiredPeopleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _equipmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    _prefillFromExistingJam();
    _controller.initialize(initialJam: widget.initialJam);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _presentPeopleController.dispose();
    _requiredPeopleController.dispose();
    _descriptionController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isEditing => widget.initialJam != null;

  void _prefillFromExistingJam() {
    final jam = widget.initialJam?.jam;
    if (jam == null) {
      return;
    }

    _presentPeopleController.text = jam.personePresenti.toString();
    _requiredPeopleController.text = jam.personeRichieste.toString();
    _descriptionController.text = jam.descrizione;
    _equipmentController.text = jam.attrezzatura;
  }

  Future<void> _selectDateFromCalendar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final lastDate = now.add(const Duration(days: 30));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _controller.selectedDate ??
          _controller.availableDates.firstOrNull ??
          now,
      firstDate: now,
      lastDate: lastDate,
      selectableDayPredicate: (DateTime day) {
        return _controller.availableDates.any(
          (available) => _isSameDay(available, day),
        );
      },
    );

    if (picked != null && picked != _controller.selectedDate) {
      try {
        await _controller.selectDate(picked);
      } catch (e) {
        if (!mounted) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text('Errore caricamento orari: $e')),
        );
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _submitJam() async {
    if (!_formKey.currentState!.validate()) return;

    final validationError = _controller.validateSelection();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
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
      await _controller.submitJam(
        presentPeople: int.parse(_presentPeopleController.text),
        requiredPeople: int.parse(_requiredPeopleController.text),
        description: _descriptionController.text,
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
            title: Text(_isEditing ? 'Jam aggiornata!' : 'Jam Organizzata!'),
            content: Text(
              _isEditing
                  ? 'Le modifiche alla tua Jam Session sono state salvate.'
                  : 'La tua Jam Session è stata inviata per approvazione.',
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
              builder: (_) => const AppScaffoldMobile(initialIndex: 2),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint("Errore submit jam: $e");
      if (mounted) {
        if (loadingDialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingDialogShown = false;
        }
        await _controller.refreshAvailableSlots();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore: ${e.toString().replaceAll("Exception: ", "")}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showJamForm = _controller.selectedDate != null;

    return Scaffold(
      appBar: _isEditing ? AppBar(title: const Text('Modifica Jam')) : null,
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
                      child: Center(child: CircularProgressIndicator()),
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
                                    : 'Tocca per scegliere')
                              : DateFormat(
                                  'EEEE d MMMM yyyy',
                                ).format(_controller.selectedDate!),
                          style: TextStyle(
                            color: _controller.selectedDate == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),

              if (showJamForm) ...[
                const Text(
                  "Seleziona Orari",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _controller.isLoadingSlots
                    ? const Center(child: CircularProgressIndicator())
                    : _controller.availableSlots.isEmpty
                    ? const Text("Nessuna disponibilità.")
                    : Wrap(
                        spacing: 8.0,
                        children: _controller.availableSlots.map((slot) {
                          return FilterChip(
                            label: Text(slot),
                            selected: _controller.selectedSlots.contains(slot),
                            onSelected: (_) => _controller.toggleSlot(slot),
                            selectedColor: Colors.green[200],
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 8),
                if (_controller.selectedRangeLabel != null)
                  Text(
                    'Intervallo: ${_controller.selectedRangeLabel!}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                          if (value == null || value.isEmpty) {
                            return 'Obbligatorio';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Inserisci un numero';
                          }
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
                          if (value == null || value.isEmpty) {
                            return 'Obbligatorio';
                          }
                          final n = int.tryParse(value);
                          if (n == null || n < 1 || n > 20) {
                            return 'Tra 1 e 20';
                          }
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
                  validator: (value) => value == null || value.isEmpty
                      ? 'Inserisci una descrizione'
                      : null,
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
                        initialValue: _controller.selectedGroupId,
                        items: _controller.userGroups.map((group) {
                          return DropdownMenuItem(
                            value: group['id'],
                            child: Text(
                              group['name'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _controller.setSelectedGroup,
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
                        initialValue: _controller.selectedPayment,
                        items: OrganizeJamController.paymentOptions.map((opt) {
                          return DropdownMenuItem(value: opt, child: Text(opt));
                        }).toList(),
                        onChanged: _controller.setSelectedPayment,
                        validator: (value) =>
                            value == null ? 'Obbligatorio' : null,
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
                  onPressed: _controller.isLoading ? null : _submitJam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[850],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _controller.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isEditing ? 'SALVA MODIFICHE' : 'PUBBLICA JAM',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
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
