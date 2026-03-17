import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/app/features/book/book_now_page_mobile.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';
import 'package:soundimplosion/models/models.dart';

class MyBookingsPageMobile extends StatefulWidget {
  const MyBookingsPageMobile({super.key, this.initialBookingIdToOpen});

  final String? initialBookingIdToOpen;

  @override
  State<MyBookingsPageMobile> createState() => _MyBookingsPageMobileState();
}

class _MyBookingsPageMobileState extends State<MyBookingsPageMobile> {
  final BookingRepository _bookingRepository = FirebaseBookingRepository();
  bool _didOpenInitialBooking = false;

  Map<String, List<BookingListItem>> _groupBookingsByDate(
    List<BookingListItem> bookings,
  ) {
    final grouped = <String, List<BookingListItem>>{};
    for (final item in bookings) {
      final date = item.booking.data;
      grouped.putIfAbsent(date, () => <BookingListItem>[]).add(item);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {
      for (final key in sortedKeys)
        key: (grouped[key]!..sort(
          (a, b) => a.booking.oraInizio.compareTo(b.booking.oraInizio),
        )),
    };
  }

  String _formatDateLabel(String rawDate) {
    try {
      final parsed = DateTime.parse(rawDate);
      final label = DateFormat('EEEE d MMMM yyyy').format(parsed);
      return label[0].toUpperCase() + label.substring(1);
    } catch (_) {
      return rawDate;
    }
  }

  Color _statusColor(BookingListItem item) {
    switch (item.booking.stato) {
      case BookingStatus.confermata:
        return Colors.green.shade100;
      case BookingStatus.inElaborazione:
        return Colors.orange.shade100;
      case BookingStatus.annullata:
        return Colors.red.shade100;
      case BookingStatus.sospesa:
        return Colors.blueGrey.shade100;
      case BookingStatus.superata:
        return Colors.grey.shade300;
    }
  }

  Color _statusTextColor(BookingListItem item) {
    switch (item.booking.stato) {
      case BookingStatus.confermata:
        return Colors.green.shade900;
      case BookingStatus.inElaborazione:
        return Colors.orange.shade900;
      case BookingStatus.annullata:
        return Colors.red.shade900;
      case BookingStatus.sospesa:
        return Colors.blueGrey.shade900;
      case BookingStatus.superata:
        return Colors.grey.shade800;
    }
  }

  Widget _buildBookingCard(BookingListItem item) {
    final booking = item.booking;
    final startTime = booking.oraInizio.isEmpty ? 'N/A' : booking.oraInizio;
    final endTime = booking.oraFine.isEmpty ? 'N/A' : booking.oraFine;
    final people = booking.numeroUtenti;
    final groupText = item.groupLabel;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBookingDetails(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 84,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.schedule, color: Colors.white, size: 18),
                    const SizedBox(height: 6),
                    Text(
                      startTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      endTime,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(
                            item.statusLabel,
                            style: TextStyle(
                              color: _statusTextColor(item),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: _statusColor(item),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            '$people persone',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      groupText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (booking.attrezzatura.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Attrezzatura: ${booking.attrezzatura}'),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
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
                      title: Text(
                        'Elimina',
                        style: TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteBooking(String bookingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Elimina Prenotazione"),
        content: const Text(
          "Sei sicuro di voler eliminare questa prenotazione?",
        ),
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Errore: $e')));
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
            booking: Booking.fromMap(
              bookingId,
              Map<String, dynamic>.from(data),
            ),
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

  Future<void> _showBookingDetails(BookingListItem item) async {
    final booking = item.booking;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dettagli prenotazione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data: ${booking.data}'),
            Text('Orario: ${booking.oraInizio} - ${booking.oraFine}'),
            Text(item.groupLabel),
            Text('Partecipanti: ${booking.numeroUtenti}'),
            Text('Stato: ${item.statusLabel}'),
            if (booking.attrezzatura.isNotEmpty)
              Text('Attrezzatura: ${booking.attrezzatura}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
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
            return const Center(
              child: Text('Non ci sono prenotazioni personali o di gruppo.'),
            );
          }

          final bookings = snapshot.data!;

          if (!_didOpenInitialBooking &&
              widget.initialBookingIdToOpen != null &&
              widget.initialBookingIdToOpen!.isNotEmpty) {
            final match = bookings.where(
              (item) => item.id == widget.initialBookingIdToOpen,
            );
            if (match.isNotEmpty) {
              _didOpenInitialBooking = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showBookingDetails(match.first);
                }
              });
            }
          }

          if (bookings.isEmpty) {
            return const Center(
              child: Text('Non ci sono prenotazioni personali o di gruppo.'),
            );
          }

          final groupedBookings = _groupBookingsByDate(bookings);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in groupedBookings.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _formatDateLabel(entry.key),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ...entry.value.map(_buildBookingCard),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}
