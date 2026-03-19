import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/app/features/admin/admin_slot_management_controller.dart';
import 'package:soundimplosion/app/features/admin/admin_slot_management_repository.dart';

class AdminSlotManagementPageMobile extends StatefulWidget {
  const AdminSlotManagementPageMobile({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminSlotManagementPageMobile> createState() =>
      _AdminSlotManagementPageMobileState();
}

class _AdminSlotManagementPageMobileState
    extends State<AdminSlotManagementPageMobile> {
  final AdminSlotManagementController _controller =
      AdminSlotManagementController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    _controller.initialize();
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _controller.selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked == null) {
      return;
    }

    await _controller.loadSlotsForDate(picked);
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Color _statusColor(AdminSlotItem slot) {
    if (slot.isDisabled) {
      return Colors.grey.shade300;
    }
    if (slot.isOccupied) {
      return slot.isJam ? Colors.deepPurple.shade100 : Colors.orange.shade100;
    }
    return Colors.green.shade100;
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.error != null && _controller.slots.isEmpty) {
      return Center(
        child: Text(
          'Errore caricamento slot: ${_controller.error.toString().replaceAll('Exception: ', '')}',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestione slot',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Disabilita gli slot liberi per manutenzione o altre chiusure straordinarie.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    DateFormat('dd/MM/yyyy').format(_controller.selectedDate),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _controller.isSubmitting
                          ? null
                          : () => _runAction(
                              _controller.disableMorningSlots,
                              'Slot mattutini disabilitati',
                            ),
                      icon: const Icon(Icons.event_busy),
                      label: const Text('Disabilita mattina'),
                    ),
                    OutlinedButton(
                      onPressed:
                          _controller.isSubmitting ||
                              _controller.selectedSlotTimes.isEmpty
                          ? null
                          : () => _runAction(
                              _controller.disableSelected,
                              'Slot selezionati disabilitati',
                            ),
                      child: const Text('Disabilita selezionati'),
                    ),
                    OutlinedButton(
                      onPressed:
                          _controller.isSubmitting ||
                              _controller.selectedSlotTimes.isEmpty
                          ? null
                          : () => _runAction(
                              _controller.enableSelected,
                              'Slot selezionati riabilitati',
                            ),
                      child: const Text('Riabilita selezionati'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_controller.slots.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nessuno slot disponibile per la data selezionata.'),
            ),
          )
        else
          ..._controller.slots.map((slot) {
            final mutable = slot.isMutable;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                value: _controller.isSelected(slot.time),
                onChanged: mutable
                    ? (_) => _controller.toggleSlot(slot.time)
                    : null,
                title: Text(slot.time),
                subtitle: slot.bookedBy?.isNotEmpty == true
                    ? Text('Assegnato a: ${slot.bookedBy}')
                    : null,
                secondary: Chip(
                  label: Text(
                    slot.statusLabel,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  backgroundColor: _statusColor(slot),
                  side: BorderSide.none,
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Slot')),
      body: body,
    );
  }
}
