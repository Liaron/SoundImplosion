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

  Future<List<String>> getFreeSlotsForDate(String dateStr) async {
    final slotsRef = _dbRef.child('slots').child(dateStr);
    
    try {
      final snapshot = await slotsRef.get();
      
      if (!snapshot.exists) {
        debugPrint("Slot non esistenti per $dateStr. Generazione in corso...");
        await _generateSlotsForDate(dateStr);
        return _generateStandardTimes();
      }

      final slotList = <String>[];
      final dynamic rawData = snapshot.value;

      if (rawData is Map) {
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

  Future<void> _generateSlotsForDate(String dateStr) async {
    final times = _generateStandardTimes();
    final Map<String, dynamic> slotsUpdate = {};
    
    for (int i = 0; i < times.length; i++) {
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
    for (int i = 0; i < 11; i++) {
      slots.add(DateFormat('HH:mm').format(time));
      time = time.add(const Duration(minutes: 75));
    }
    return slots;
  }

  // --- CREAZIONE PRENOTAZIONE CON UPDATE SLOT ---

  Future<void> createBooking(Booking booking, List<String> selectedSlotTimes) async {
    debugPrint("Inizio creazione prenotazione...");
    
    final newBookingKey = _dbRef.child('bookings').push().key;
    if (newBookingKey == null) throw Exception("Impossibile generare ID prenotazione");
    
    final Map<String, dynamic> updates = {};
    final bookingPath = '/bookings/$newBookingKey';
    final userBookingPath = '/user_bookings/${booking.userId}/$newBookingKey';
    
    updates[bookingPath] = booking.toMap();
    updates[userBookingPath] = booking.toMap();

    for (final time in selectedSlotTimes) {
      final key = time.replaceAll(":", "_");
      final slotPath = '/slots/${booking.data}/$key';
      
      updates['$slotPath/status'] = 'occupato';
      updates['$slotPath/booked_by'] = booking.userId;
      updates['$slotPath/booking_id'] = newBookingKey;
    }

    try {
      await _dbRef.update(updates);

      if (booking.groupId != null && booking.groupId!.isNotEmpty) {
        await _notifyGroupMembers(booking.groupId!, newBookingKey, booking);
      }
      debugPrint("Prenotazione completata con successo.");
    } catch (e) {
      debugPrint("Errore durante createBooking: $e");
      rethrow;
    }
  }

  // --- ELIMINAZIONE PRENOTAZIONE ---

  Future<void> deleteBooking(String bookingId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    debugPrint("Inizio cancellazione prenotazione: $bookingId");

    try {
      final snapshot = await _dbRef.child('bookings').child(bookingId).get();
      if (!snapshot.exists || snapshot.value == null) {
        debugPrint("Prenotazione non trovata in global bookings, rimuovo solo da user_bookings");
        await _dbRef.child('user_bookings').child(user.uid).child(bookingId).remove();
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final dateStr = data['data'] as String;

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
        }
      } catch (e) {
        debugPrint("Query slot fallita ($e). Tento fallback manuale...");
        
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
        }
      }

      final Map<String, dynamic> updates = {};
      
      updates['/bookings/$bookingId'] = null;
      updates['/user_bookings/${user.uid}/$bookingId'] = null;

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

  // --- GESTIONE JAM ---

  Future<void> createJam(Jam jam, List<String> selectedSlotTimes) async {
    debugPrint("Inizio creazione JAM...");
    
    final newJamKey = _dbRef.child('jams').push().key;
    if (newJamKey == null) throw Exception("Impossibile generare ID Jam");

    final Map<String, dynamic> updates = {};
    
    final jamPath = '/jams/$newJamKey';
    updates[jamPath] = jam.toMap();

    for (final time in selectedSlotTimes) {
      final key = time.replaceAll(":", "_");
      final slotPath = '/slots/${jam.data}/$key';
      
      updates['$slotPath/status'] = 'occupato'; 
      updates['$slotPath/booked_by'] = jam.creatorId;
      updates['$slotPath/booking_id'] = newJamKey; // Usiamo l'ID Jam come riferimento
      updates['$slotPath/is_jam'] = true;
    }

    try {
      await _dbRef.update(updates);
      debugPrint("Jam creata con successo.");
    } catch (e) {
      debugPrint("Errore durante createJam: $e");
      rethrow;
    }
  }

  Stream<DatabaseEvent> getJamsStream() {
    return _dbRef.child('jams').onValue;
  }

  // ELIMINA JAM
  Future<void> deleteJam(String jamId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    debugPrint("Inizio cancellazione JAM: $jamId");

    try {
      // 1. Recupera la Jam
      final snapshot = await _dbRef.child('jams').child(jamId).get();
      if (!snapshot.exists || snapshot.value == null) {
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final dateStr = data['data'] as String;
      final creatorId = data['creator_id'] as String;

      // Verifica che solo il creatore possa cancellare
      if (creatorId != user.uid) {
        throw Exception("Solo il creatore può eliminare questa Jam.");
      }

      // 2. Trova gli slot associati alla Jam
      Map<String, dynamic> slotsToFree = {};

      try {
        final slotsSnapshot = await _dbRef
            .child('slots')
            .child(dateStr)
            .orderByChild('booking_id')
            .equalTo(jamId)
            .get();
        
        if (slotsSnapshot.exists && slotsSnapshot.value != null) {
          slotsToFree = Map<String, dynamic>.from(slotsSnapshot.value as Map);
        }
      } catch (e) {
        debugPrint("Query slot fallita ($e). Tento fallback manuale...");
        
        final allSlotsSnapshot = await _dbRef.child('slots').child(dateStr).get();
        if (allSlotsSnapshot.exists && allSlotsSnapshot.value != null) {
           final dynamic rawSlots = allSlotsSnapshot.value;
           if (rawSlots is Map) {
             rawSlots.forEach((key, value) {
               final slotData = Map<String, dynamic>.from(value as Map);
               if (slotData['booking_id'] == jamId) {
                 slotsToFree[key] = slotData;
               }
             });
           } else if (rawSlots is List) {
             for (int i = 0; i < rawSlots.length; i++) {
               if (rawSlots[i] != null) {
                 final slotData = Map<String, dynamic>.from(rawSlots[i] as Map);
                 if (slotData['booking_id'] == jamId) {
                   slotsToFree[i.toString()] = slotData;
                 }
               }
             }
           }
        }
      }

      // 3. Esegui update atomico
      final Map<String, dynamic> updates = {};
      
      // Rimuovi Jam
      updates['/jams/$jamId'] = null;

      // Libera slot e rimuovi flag is_jam
      slotsToFree.forEach((key, value) {
        updates['/slots/$dateStr/$key/status'] = 'libero';
        updates['/slots/$dateStr/$key/booked_by'] = null;
        updates['/slots/$dateStr/$key/booking_id'] = null;
        updates['/slots/$dateStr/$key/is_jam'] = null;
      });

      await _dbRef.update(updates);
      debugPrint("Jam $jamId eliminata e slot liberati.");

    } catch (e) {
      debugPrint("Errore durante eliminazione jam: $e");
      rethrow;
    }
  }
}
