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

  final _titleController = TextEditingController();
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
    _titleController.dispose();
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

    _titleController.text = jam.titolo;
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

  List<DateTime> _weekDays() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return List<DateTime>.generate(
      7,
      (index) => DateTime(start.year, start.month, start.day + index),
    );
  }

  bool _isSelectableDay(DateTime day) {
    return _controller.availableDates.any(
      (available) => _isSameDay(available, day),
    );
  }

  Future<void> _selectQuickDay(DateTime date) async {
    if (!_isSelectableDay(date)) {
      return;
    }
    await _controller.selectDate(date);
  }

  Widget _buildWeeklyStrip() {
    final days = _weekDays();
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelectable = _isSelectableDay(day);
          final isSelected =
              _controller.selectedDate != null &&
              _isSameDay(_controller.selectedDate!, day);
          return InkWell(
            onTap: isSelectable ? () => _selectQuickDay(day) : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 76,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : isSelectable
                    ? Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : isSelectable
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(day),
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                          : isSelectable
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : isSelectable
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelectable
                          ? (isSelected ? Theme.of(context).colorScheme.onPrimary : const Color(0xFF4CAF50))
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: days.length,
      ),
    );
  }

  Widget _buildSlotSelector() {
    if (_controller.isLoadingSlots) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.availableSlots.isEmpty) {
      return const Text("Nessuna disponibilità per questa data.");
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _controller.availableSlots.map((slot) {
        final isSelected = _controller.selectedSlots.contains(slot);
        return GestureDetector(
          onTap: () => _controller.toggleSlot(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black87 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.black87 : Colors.green.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSelected ? 'Selezionato' : 'Libero',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white : Colors.green.shade900,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
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
        title: _titleController.text,
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prossimi giorni',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _buildWeeklyStrip(),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _controller.availableDates.isEmpty
                              ? null
                              : () => _selectDateFromCalendar(context),
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            _controller.selectedDate == null
                                ? 'Apri selettore data'
                                : DateFormat(
                                    'EEEE d MMMM yyyy',
                                  ).format(_controller.selectedDate!),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 24),

              if (showJamForm) ...[
                const Text(
                  "Seleziona Orari",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildSlotSelector(),
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
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titolo jam',
                    hintText: 'Es. Rock Session del venerdi',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.music_note),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Inserisci un titolo'
                      : null,
                ),
                const SizedBox(height: 16),

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
