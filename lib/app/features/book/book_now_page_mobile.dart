import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/app/features/app_scaffold_mobile.dart';
import 'package:soundimplosion/app/features/book/book_now_controller.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';

typedef BookingEditSubmitCallback = Future<void> Function({
  required DateTime selectedDate,
  required List<String> selectedSlots,
  String? groupId,
  required int peopleCount,
  required String equipment,
});

class BookNowPageMobile extends StatefulWidget {
  const BookNowPageMobile({
    super.key,
    this.initialBooking,
    this.onEditSubmit,
    this.editSuccessTitle,
    this.editSuccessMessage,
    this.editSubmitLabel,
    this.editAppBarTitle,
  });

  final BookingListItem? initialBooking;
  final BookingEditSubmitCallback? onEditSubmit;
  final String? editSuccessTitle;
  final String? editSuccessMessage;
  final String? editSubmitLabel;
  final String? editAppBarTitle;

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
      // Questa funzione abilita solo i giorni presenti in _availableDates
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
    return _controller.availableDates.any((available) => _isSameDay(available, day));
  }

  Future<void> _selectCalendarDay(DateTime date) async {
    if (!_isSelectableDay(date)) {
      return;
    }
    await _controller.selectDate(date);
  }

  Color _slotBackgroundColor(BookingSlotItem slot, bool isSelected) {
    if (isSelected) {
      return Colors.black87;
    }
    if (slot.isDisabled) {
      return Colors.grey.shade200;
    }
    if (slot.isFree) {
      return Colors.green.shade50;
    }
    return slot.isJam ? Colors.deepPurple.shade50 : Colors.orange.shade50;
  }

  Color _slotBorderColor(BookingSlotItem slot, bool isSelected) {
    if (isSelected) {
      return Colors.black87;
    }
    if (slot.isDisabled) {
      return Colors.grey.shade400;
    }
    if (slot.isFree) {
      return Colors.green.shade300;
    }
    return slot.isJam ? Colors.deepPurple.shade300 : Colors.orange.shade300;
  }

  Color _slotTextColor(BookingSlotItem slot, bool isSelected) {
    if (isSelected) {
      return Colors.white;
    }
    if (slot.isDisabled) {
      return Colors.grey.shade700;
    }
    if (slot.isFree) {
      return Colors.green.shade900;
    }
    return slot.isJam ? Colors.deepPurple.shade900 : Colors.orange.shade900;
  }

  bool _canToggleSlot(BookingSlotItem slot) {
    if (_controller.selectedSlots.contains(slot.time)) {
      return true;
    }
    if (slot.isFree) {
      return true;
    }
    return _isEditing && slot.bookingId == widget.initialBooking?.id;
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    Color? borderColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor ?? color),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
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
            onTap: isSelectable ? () => _selectCalendarDay(day) : null,
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

  Widget _buildSlotOverview() {
    if (_controller.isLoadingSlots) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.slotOverview.isEmpty) {
      return const Text("Nessuna disponibilità per questa data.");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            _buildLegendItem(
              color: Colors.green.shade50,
              borderColor: Colors.green.shade300,
              label: 'Libero',
            ),
            _buildLegendItem(
              color: Colors.orange.shade50,
              borderColor: Colors.orange.shade300,
              label: 'Occupato',
            ),
            _buildLegendItem(
              color: Colors.deepPurple.shade50,
              borderColor: Colors.deepPurple.shade300,
              label: 'Jam',
            ),
            _buildLegendItem(
              color: Colors.grey.shade200,
              borderColor: Colors.grey.shade400,
              label: 'Disabilitato',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _controller.slotOverview.map((slot) {
            final isSelected = _controller.selectedSlots.contains(slot.time);
            final canToggle = _canToggleSlot(slot);
            return GestureDetector(
              onTap: canToggle ? () => _controller.toggleSlot(slot.time) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _slotBackgroundColor(slot, isSelected),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _slotBorderColor(slot, isSelected),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slot.time,
                      style: TextStyle(
                        color: _slotTextColor(slot, isSelected),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSelected ? 'Selezionato' : slot.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: _slotTextColor(slot, isSelected),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _submitBooking() async {
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
      if (_isEditing && widget.onEditSubmit != null) {
        await widget.onEditSubmit!(
          selectedDate: _controller.selectedDate!,
          selectedSlots: List<String>.from(_controller.selectedSlots),
          groupId: _controller.selectedGroupId,
          peopleCount: int.parse(_peopleController.text),
          equipment: _equipmentController.text,
        );
      } else {
        await _controller.submitBooking(
          peopleCount: int.parse(_peopleController.text),
          equipment: _equipmentController.text,
        );
      }

      if (mounted) {
        if (loadingDialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingDialogShown = false;
        }

        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => AlertDialog(
            title: Text(
              _isEditing
                  ? (widget.editSuccessTitle ?? 'Prenotazione aggiornata')
                  : 'Prenotazione inviata',
            ),
            content: Text(
              _isEditing
                  ? (widget.editSuccessMessage ??
                        'Le modifiche alla prenotazione sono state salvate.')
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
    final showBookingForm = _controller.selectedDate != null;

    return Scaffold(
      appBar: _isEditing
          ? AppBar(
              title: Text(
                widget.editAppBarTitle ?? 'Modifica Prenotazione',
              ),
            )
          : null,
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

              if (showBookingForm) ...[
                const Text(
                  "Seleziona Orari (slot da 75 min)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildSlotOverview(),
                const SizedBox(height: 8),
                if (_controller.selectedRangeLabel != null)
                  Text(
                    'Intervallo selezionato: ${_controller.selectedRangeLabel!}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
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
                        _isEditing
                          ? (widget.editSubmitLabel ?? 'SALVA MODIFICHE')
                          : 'INVIA PRENOTAZIONE',
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
