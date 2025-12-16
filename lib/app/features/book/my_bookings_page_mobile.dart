import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soundimplosion/services/database_service.dart';

class MyBookingsPageMobile extends StatefulWidget {
  const MyBookingsPageMobile({super.key});

  @override
  State<MyBookingsPageMobile> createState() => _MyBookingsPageMobileState();
}

class _MyBookingsPageMobileState extends State<MyBookingsPageMobile> {
  final DatabaseService _databaseService = DatabaseService();

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
              await _databaseService.deleteBooking(bookingId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Prenotazione eliminata")),
                );
              }
            },
            child: const Text("Elimina", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editBooking(String bookingId, Map data) {
    // TODO: Implementare la navigazione alla pagina di modifica
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Funzionalità di modifica non ancora disponibile")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DatabaseEvent>(
        stream: _databaseService.getBookingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text('Non hai nessuna prenotazione.'));
          }

          final dynamic rawData = snapshot.data!.snapshot.value;
          List<Map<String, dynamic>> bookings = [];

          try {
            if (rawData is Map) {
              bookings = rawData.entries.map((entry) {
                final bookingData = Map<String, dynamic>.from(entry.value as Map);
                bookingData['key'] = entry.key; 
                return bookingData;
              }).toList();
            } else if (rawData is List) {
              for (int i = 0; i < rawData.length; i++) {
                if (rawData[i] != null) {
                  final bookingData = Map<String, dynamic>.from(rawData[i] as Map);
                  bookingData['key'] = i.toString();
                  bookings.add(bookingData);
                }
              }
            }
          } catch (e) {
            return Center(child: Text('Errore nel formato dati: $e'));
          }
          
          // Ordina per data (opzionale, qui semplice string sort)
          bookings.sort((a, b) => (b['data'] ?? '').compareTo(a['data'] ?? ''));

          if (bookings.isEmpty) {
             return const Center(child: Text('Non hai nessuna prenotazione.'));
          }

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final date = booking['data'] ?? 'N/A';
              final startTime = booking['ora_inizio'] ?? 'N/A';
              final endTime = booking['ora_fine'] ?? 'N/A';
              final status = (booking['stato'] == 'inElaborazione') ? 'In elaborazione' : booking['stato'];
              final people = booking['numero_utenti'] ?? 0;
              final groupId = booking['group_id'];
              final groupText = (groupId != null && groupId.toString().isNotEmpty) 
                  ? 'Gruppo: $groupId' 
                  : 'Nessun gruppo';

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
                        _editBooking(booking['key'], booking);
                      } else if (value == 'delete') {
                        _deleteBooking(booking['key']);
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
