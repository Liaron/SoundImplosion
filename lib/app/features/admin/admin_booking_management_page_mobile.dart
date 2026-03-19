import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/admin/admin_booking_controller.dart';
import 'package:soundimplosion/app/features/book/book_now_page_mobile.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';

class AdminBookingManagementPageMobile extends StatefulWidget {
  const AdminBookingManagementPageMobile({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminBookingManagementPageMobile> createState() =>
      _AdminBookingManagementPageMobileState();
}

class _AdminBookingManagementPageMobileState
    extends State<AdminBookingManagementPageMobile> {
  final AdminBookingController _controller = AdminBookingController();

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

  Future<void> _confirmBooking(String bookingId) async {
    try {
      await _controller.confirmBooking(bookingId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prenotazione confermata')));
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

  Future<void> _cancelBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rifiuta prenotazione'),
        content: const Text(
          'Vuoi rifiutare questa prenotazione e liberare gli slot?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rifiuta prenotazione'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _controller.cancelBooking(bookingId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prenotazione rifiutata')));
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

  Future<void> _rescheduleBooking(BookingListItem item) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookNowPageMobile(
          initialBooking: item,
          onEditSubmit: ({
            required DateTime selectedDate,
            required List<String> selectedSlots,
            String? groupId,
            required int peopleCount,
            required String equipment,
          }) {
            return _controller.proposeBookingUpdate(
              bookingId: item.id,
              selectedDate: selectedDate,
              selectedSlots: selectedSlots,
              groupId: groupId,
              peopleCount: peopleCount,
              equipment: equipment,
            );
          },
          editAppBarTitle: 'Proponi modifica prenotazione',
          editSubmitLabel: 'INVIA PROPOSTA',
          editSuccessTitle: 'Proposta inviata',
          editSuccessMessage:
              'La proposta di modifica e stata inviata all\'utente.',
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposta di modifica inviata')),
      );
    }
  }

  Future<void> _deleteBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina prenotazione'),
        content: const Text(
          'Vuoi eliminare questa prenotazione gia approvata?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _controller.deleteBooking(bookingId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prenotazione eliminata')));
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

  Widget _buildList({
    required List<BookingListItem> items,
    required bool approved,
  }) {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.error != null) {
      return Center(child: Text('Errore caricamento: ${_controller.error}'));
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          approved
              ? 'Non ci sono prenotazioni gia approvate.'
              : 'Non ci sono prenotazioni in attesa.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final booking = item.booking;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${booking.data} ${booking.oraInizio} - ${booking.oraFine}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        item.statusLabel,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      backgroundColor: approved
                          ? Colors.green[100]
                          : Colors.orange[100],
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Richiedente: ${_controller.userNames[booking.userId] ?? booking.userId}',
                ),
                Text(item.groupLabel),
                Text('Partecipanti: ${booking.numeroUtenti}'),
                if (booking.attrezzatura.isNotEmpty)
                  Text('Attrezzatura: ${booking.attrezzatura}'),
                const SizedBox(height: 12),
                if (!approved) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _controller.isSubmitting
                              ? null
                              : () => _cancelBooking(item.id),
                          child: const Text('Rifiuta'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _controller.isSubmitting
                              ? null
                              : () => _rescheduleBooking(item),
                          child: const Text('Riprogramma'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _controller.isSubmitting
                          ? null
                          : () => _confirmBooking(item.id),
                      child: const Text('Conferma prenotazione'),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _controller.isSubmitting
                              ? null
                              : () => _rescheduleBooking(item),
                          child: const Text('Proponi modifica'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _controller.isSubmitting
                              ? null
                              : () => _deleteBooking(item.id),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Elimina'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Proposte'),
              Tab(text: 'Approvate'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildList(items: _controller.pendingBookings, approved: false),
                _buildList(items: _controller.approvedBookings, approved: true),
              ],
            ),
          ),
        ],
      ),
    );
    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Prenotazioni')),
      body: body,
    );
  }
}
