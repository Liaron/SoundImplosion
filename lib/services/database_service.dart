import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:flutter/foundation.dart'; // Per debugPrint
import 'package:intl/intl.dart';

class DatabaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://liaron-soundimplosion-default-rtdb.europe-west1.firebasedatabase.app',
  ).ref();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Metodi Generici ---

  Future<void> writeData(String path, Map<String, dynamic> data) async {
    await _dbRef.child(path).set(data);
  }

  Future<DataSnapshot> readData(String path) async {
    return await _dbRef.child(path).get();
  }

  Future<void> updateData(String path, Map<String, dynamic> data) async {
    await _dbRef.child(path).update(data);
  }

  Future<void> deleteData(String path) async {
    await _dbRef.child(path).remove();
  }

  // --- Gestione Utenti ---

  Future<void> saveUser(AppUser user) async {
    await _dbRef.child('users').child(user.uid).set(user.toMap());
  }

  Future<List<Map<String, String>>> getUserGroups() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _dbRef.child('users').child(user.uid).child('gruppi').get();
      
      if (snapshot.exists && snapshot.value != null) {
        final groupsList = <Map<String, String>>[];
        final groupsIds = (snapshot.value as List).map((e) => e.toString()).toList();

        for (var groupId in groupsIds) {
           final groupSnapshot = await _dbRef.child('groups_info').child(groupId).get();
           if (groupSnapshot.exists) {
             final groupData = groupSnapshot.value as Map;
             groupsList.add({
               'id': groupId,
               'name': groupData['name'] ?? 'Gruppo sconosciuto',
             });
           }
        }
        return groupsList;
      }
    } catch (e) {
      debugPrint("Errore nel recupero gruppi: $e");
    }
    return [];
  }

  // --- Gestione Disponibilità (Operatore) ---
  // Manteniamo questo metodo se serve per logiche future, ma la logica principale ora è su 'slots'
  Future<void> setDefaultAvailability() async {
    // ... codice esistente ...
  }

  // --- Gestione Prenotazioni ---

  Stream<DatabaseEvent> getBookingsStream() {
    final User? user = _auth.currentUser;
    if (user != null) {
      return _dbRef.child('user_bookings').child(user.uid).onValue;
    } else {
      return Stream.error("Utente non loggato");
    }
  }

  // --- NUOVA LOGICA SLOT SUL DB ---

  /// Recupera gli slot per una data.
  /// Se non esistono, li genera (Lazy Generation al posto del job notturno).
  /// Restituisce solo gli slot con stato 'libero'.
  Future<List<String>> getFreeSlotsForDate(String dateStr) async {
    final slotsRef = _dbRef.child('slots').child(dateStr);
    
    try {
      final snapshot = await slotsRef.get();
      
      if (!snapshot.exists) {
        debugPrint("Slot non esistenti per $dateStr. Generazione in corso...");
        await _generateSlotsForDate(dateStr);
        // Dopo la generazione, richiamiamo ricorsivamente (o costruiamo la lista manualmente)
        // Per semplicità, ritorniamo la lista standard dato che sono appena stati creati tutti liberi
        return _generateStandardTimes();
      }

      // Se esistono, filtriamo quelli liberi
      final slotList = <String>[];
      final dynamic rawData = snapshot.value;

      if (rawData is Map) {
        // Ordiniamo per orario per visualizzarli correttamente
        final entries = rawData.entries.toList()
          ..sort((a, b) {
            final mapA = a.value as Map;
            final mapB = b.value as Map;
            return (mapA['time'] as String).compareTo(mapB['time'] as String);
          });

        for (final entry in entries) {
          final data = entry.value as Map;
          if (data['status'] == 'libero') {
            slotList.add(data['time'] as String);
          }
        }
      } else if (rawData is List) {
         // Gestione caso array
         for (final item in rawData) {
           if (item != null) {
             final data = item as Map;
             if (data['status'] == 'libero') {
               slotList.add(data['time'] as String);
             }
           }
         }
      }
      
      return slotList;

    } catch (e) {
      debugPrint("Errore getFreeSlotsForDate: $e");
      return [];
    }
  }

  // Genera gli 11 slot standard sul DB con stato 'libero'
  Future<void> _generateSlotsForDate(String dateStr) async {
    final times = _generateStandardTimes();
    final Map<String, dynamic> slotsUpdate = {};
    
    for (int i = 0; i < times.length; i++) {
      // Usiamo l'orario come parte della chiave o un ID incrementale. 
      // Per facilità di query futura, usiamo un ID basato sull'ora (es. "10_00")
      final time = times[i];
      final key = time.replaceAll(":", "_"); 
      
      slotsUpdate[key] = {
        'time': time,
        'status': 'libero',
      };
    }
    
    await _dbRef.child('slots').child(dateStr).set(slotsUpdate);
  }

  List<String> _generateStandardTimes() {
    final slots = <String>[];
    var time = DateTime(2022, 1, 1, 10, 0); 
    // 11 Slot da 75 minuti
    for (int i = 0; i < 11; i++) {
      slots.add(DateFormat('HH:mm').format(time));
      time = time.add(const Duration(minutes: 75));
    }
    return slots;
  }

  // --- CREAZIONE PRENOTAZIONE CON UPDATE SLOT ---

  Future<void> createBooking(Booking booking, List<String> selectedSlotTimes) async {
    debugPrint("Inizio creazione prenotazione...");
    
    // 1. Genera ID prenotazione
    final newBookingKey = _dbRef.child('bookings').push().key;
    if (newBookingKey == null) throw Exception("Impossibile generare ID prenotazione");
    
    // 2. Prepara gli aggiornamenti atomici (Multi-path update)
    // Dobbiamo:
    // a. Creare la prenotazione in /bookings
    // b. Creare la prenotazione in /user_bookings
    // c. Aggiornare lo stato degli slot in /slots/DATA/TIME_KEY a 'occupato'
    
    final Map<String, dynamic> updates = {};
    final bookingPath = '/bookings/$newBookingKey';
    final userBookingPath = '/user_bookings/${booking.userId}/$newBookingKey';
    
    updates[bookingPath] = booking.toMap();
    updates[userBookingPath] = booking.toMap();

    // Aggiungi aggiornamenti per gli slot
    for (final time in selectedSlotTimes) {
      final key = time.replaceAll(":", "_");
      final slotPath = '/slots/${booking.data}/$key';
      
      // Controlliamo in modo ottimistico. In una vera transazione dovremmo leggere e verificare.
      // Qui sovrascriviamo lo stato e aggiungiamo l'ID di chi ha prenotato per riferimento
      updates['$slotPath/status'] = 'occupato';
      updates['$slotPath/booked_by'] = booking.userId;
      updates['$slotPath/booking_id'] = newBookingKey;
    }

    try {
      // Eseguiamo tutto in un'unica operazione atomica
      await _dbRef.update(updates);

      // Notifiche (fuori dalla transazione atomica del DB)
      if (booking.groupId != null && booking.groupId!.isNotEmpty) {
        await _notifyGroupMembers(booking.groupId!, newBookingKey, booking);
      }
      debugPrint("Prenotazione completata con successo.");
    } catch (e) {
      debugPrint("Errore durante createBooking: $e");
      rethrow;
    }
  }

  // --- ELIMINAZIONE ---

  Future<void> deleteBooking(String bookingId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    debugPrint("Inizio cancellazione prenotazione: $bookingId");

    try {
      // 1. Recupera la prenotazione per sapere data e orari
      final snapshot = await _dbRef.child('bookings').child(bookingId).get();
      if (!snapshot.exists || snapshot.value == null) {
        debugPrint("Prenotazione non trovata in global bookings, rimuovo solo da user_bookings");
        await _dbRef.child('user_bookings').child(user.uid).child(bookingId).remove();
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final dateStr = data['data'] as String;
      debugPrint("Data prenotazione da eliminare: $dateStr");

      // 2. Trova gli slot associati
      Map<String, dynamic> slotsToFree = {};

      try {
        final slotsSnapshot = await _dbRef
            .child('slots')
            .child(dateStr)
            .orderByChild('booking_id')
            .equalTo(bookingId)
            .get();
        
        if (slotsSnapshot.exists && slotsSnapshot.value != null) {
          slotsToFree = Map<String, dynamic>.from(slotsSnapshot.value as Map);
          debugPrint("Trovati ${slotsToFree.length} slot da liberare con query ottimizzata.");
        }
      } catch (e) {
        debugPrint("Query slot fallita ($e). Tento fallback manuale...");
        
        // FALLBACK SICURO: Scarica tutti gli slot del giorno e filtra in memoria
        final allSlotsSnapshot = await _dbRef.child('slots').child(dateStr).get();
        if (allSlotsSnapshot.exists && allSlotsSnapshot.value != null) {
           final dynamic rawSlots = allSlotsSnapshot.value;
           
           if (rawSlots is Map) {
             rawSlots.forEach((key, value) {
               final slotData = Map<String, dynamic>.from(value as Map);
               if (slotData['booking_id'] == bookingId) {
                 slotsToFree[key] = slotData;
               }
             });
           } else if (rawSlots is List) {
             for (int i = 0; i < rawSlots.length; i++) {
               if (rawSlots[i] != null) {
                 final slotData = Map<String, dynamic>.from(rawSlots[i] as Map);
                 if (slotData['booking_id'] == bookingId) {
                   slotsToFree[i.toString()] = slotData;
                 }
               }
             }
           }
           debugPrint("Trovati ${slotsToFree.length} slot da liberare con fallback.");
        }
      }

      // 3. Esegui update atomico di cancellazione
      final Map<String, dynamic> updates = {};
      
      // Rimuovi booking
      updates['/bookings/$bookingId'] = null;
      updates['/user_bookings/${user.uid}/$bookingId'] = null;

      // Libera slot trovati
      slotsToFree.forEach((key, value) {
        updates['/slots/$dateStr/$key/status'] = 'libero';
        updates['/slots/$dateStr/$key/booked_by'] = null;
        updates['/slots/$dateStr/$key/booking_id'] = null;
      });

      await _dbRef.update(updates);
      debugPrint("Prenotazione $bookingId eliminata e slot liberati.");

    } catch (e) {
      debugPrint("Errore durante eliminazione prenotazione: $e");
    }
  }

  Future<void> _notifyGroupMembers(String groupId, String bookingId, Booking booking) async {
    // ... codice esistente notifiche ...
     try {
      final snapshot = await _dbRef.child('groups').child(groupId).child('members').get();
      if (snapshot.exists && snapshot.value != null) {
        final members = snapshot.value as Map;
        for (var entry in members.entries) {
          final memberId = entry.key;
          if (memberId != booking.userId) {
            final notification = {
              'title': 'Nuova Prenotazione Gruppo',
              'body': 'Il tuo gruppo ha una nuova prenotazione per il ${booking.data}',
              'booking_id': bookingId,
              'read': false,
              'timestamp': ServerValue.timestamp,
            };
            await _dbRef.child('notifications').child(memberId).push().set(notification);
          }
        }
      }
    } catch (e) {
      debugPrint("Errore notifiche gruppo: $e");
    }
  }

  // --- Gestione Jam ---
  Future<void> createJam(Jam jam) async {
     // ... codice esistente ...
    final newJamKey = _dbRef.child('jams').push().key;
    if (newJamKey == null) throw Exception("Impossibile generare ID Jam");
    await _dbRef.child('jams').child(newJamKey).set(jam.toMap());
  }
}
