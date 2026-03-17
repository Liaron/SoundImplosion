import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/book/book_now_page_mobile.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';
import 'package:soundimplosion/models/models.dart';

class MyBookingsPageMobile extends StatefulWidget {
  const MyBookingsPageMobile({super.key});

  @override
  State<MyBookingsPageMobile> createState() => _MyBookingsPageMobileState();
}

class _MyBookingsPageMobileState extends State<MyBookingsPageMobile> {
  final BookingRepository _bookingRepository = FirebaseBookingRepository();

  void _deleteBooking(String bookingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Elimina Prenotazione"),
        content: const Text("Sei sicuro di voler eliminare questa prenotazione?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annulla"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _bookingRepository.deleteBooking(bookingId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Prenotazione eliminata")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Errore: $e')),
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

  Future<void> _editBooking(String bookingId, Map data) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookNowPageMobile(
          initialBooking: BookingListItem(
            id: bookingId,
            booking: Booking.fromMap(bookingId, Map<String, dynamic>.from(data)),
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prenotazione aggiornata correttamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<BookingListItem>>(
        stream: _bookingRepository.watchAccessibleBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Non ci sono prenotazioni personali o di gruppo.'));
          }

          final bookings = snapshot.data!;

          if (bookings.isEmpty) {
             return const Center(child: Text('Non ci sono prenotazioni personali o di gruppo.'));
          }

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final item = bookings[index];
              final booking = item.booking;
              final date = booking.data.isEmpty ? 'N/A' : booking.data;
              final startTime = booking.oraInizio.isEmpty ? 'N/A' : booking.oraInizio;
              final endTime = booking.oraFine.isEmpty ? 'N/A' : booking.oraFine;
              final status = item.statusLabel;
              final people = booking.numeroUtenti;
              final groupText = item.groupLabel;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(height: 4),
                      Text(date, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  title: Text('$startTime - $endTime'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$groupText • $people Persone'),
                      Text(
                        'Stato: $status',
                        style: TextStyle(
                          color: status == 'confermata' ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editBooking(item.id, booking.toMap());
                      } else if (value == 'delete') {
                        _deleteBooking(item.id);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Modifica'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Elimina', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
