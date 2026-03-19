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
        builder: (_) => BookNowPageMobile(initialBooking: item),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prenotazione riprogrammata')),
      );
    }
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.error != null) {
      return Center(child: Text('Errore caricamento: ${_controller.error}'));
    }

    if (_controller.pendingBookings.isEmpty) {
      return const Center(child: Text('Non ci sono prenotazioni in attesa.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _controller.pendingBookings.length,
      itemBuilder: (context, index) {
        final item = _controller.pendingBookings[index];
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
                      backgroundColor: Colors.orange[100],
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Richiedente: ${_controller.userNames[booking.userId] ?? booking.userId}'),
                Text(item.groupLabel),
                Text('Partecipanti: ${booking.numeroUtenti}'),
                if (booking.attrezzatura.isNotEmpty)
                  Text('Attrezzatura: ${booking.attrezzatura}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _controller.isSubmitting
                          ? null
                          : () => _cancelBooking(item.id),
                      child: const Text('Rifiuta'),
                    ),
                    OutlinedButton(
                      onPressed: _controller.isSubmitting
                          ? null
                          : () => _rescheduleBooking(item),
                      child: const Text('Riprogramma'),
                    ),
                    ElevatedButton(
                      onPressed: _controller.isSubmitting
                          ? null
                          : () => _confirmBooking(item.id),
                      child: const Text('Conferma'),
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
    final body = _buildBody();
    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Prenotazioni')),
      body: body,
    );
  }
}
