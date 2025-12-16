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
    // ... implementazione precedente
  }

  Future<void> _notifyGroupMembers(String groupId, String bookingId, Booking booking) async {
    // ... implementazione precedente
  }

  // --- GESTIONE JAM ---

  Future<void> createJam(Jam jam, List<String> selectedSlotTimes) async {
    debugPrint("Inizio creazione JAM...");
    
    final newJamKey = _dbRef.child('jams').push().key;
    if (newJamKey == null) throw Exception("Impossibile generare ID Jam");

    final Map<String, dynamic> updates = {};
    
    // 1. Salva la Jam
    final jamPath = '/jams/$newJamKey';
    updates[jamPath] = jam.toMap();

    // 2. Pubblica nel feed
    final newFeedKey = _dbRef.child('feed').push().key;
    final feedPath = '/feed/$newFeedKey';
    updates[feedPath] = {
      'type': 'jam_published',
      'timestamp': ServerValue.timestamp,
      'jam_id': newJamKey,
      'creator_id': jam.creatorId,
      'data': jam.data,
      'ora_inizio': jam.oraInizio,
      'descrizione': jam.descrizione,
    };

    // 3. Aggiorna gli slot come occupati
    for (final time in selectedSlotTimes) {
      final key = time.replaceAll(":", "_");
      final slotPath = '/slots/${jam.data}/$key';
      
      updates['$slotPath/status'] = 'occupato'; 
      updates['$slotPath/booked_by'] = jam.creatorId;
      updates['$slotPath/booking_id'] = newJamKey; 
      updates['$slotPath/is_jam'] = true;
    }

    try {
      await _dbRef.update(updates);
      debugPrint("Jam creata e pubblicata nel feed.");
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
      final snapshot = await _dbRef.child('jams').child(jamId).get();
      if (!snapshot.exists || snapshot.value == null) {
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final dateStr = data['data'] as String;
      final creatorId = data['creator_id'] as String;

      if (creatorId != user.uid) {
        throw Exception("Solo il creatore può eliminare questa Jam.");
      }

      final Map<String, dynamic> updates = {};

      // 1. Trova e rimuovi il post dal feed
      try {
        final feedSnapshot = await _dbRef.child('feed').orderByChild('jam_id').equalTo(jamId).get();
        if (feedSnapshot.exists && feedSnapshot.value != null) {
          final feedData = Map<String, dynamic>.from(feedSnapshot.value as Map);
          feedData.forEach((key, value) {
            updates['/feed/$key'] = null;
          });
        }
      } catch (e) {
        debugPrint("Query feed fallita ($e). Tento fallback...");
        final allFeedSnapshot = await _dbRef.child('feed').get();
        if (allFeedSnapshot.exists && allFeedSnapshot.value != null) {
          final allFeed = Map<String, dynamic>.from(allFeedSnapshot.value as Map);
          allFeed.forEach((key, value) {
            final feedItem = Map<String, dynamic>.from(value as Map);
            if (feedItem['jam_id'] == jamId) {
              updates['/feed/$key'] = null;
            }
          });
        }
      }

      // 2. Trova e libera gli slot
      Map<String, dynamic> slotsToFree = {};
      try {
        final slotsSnapshot = await _dbRef.child('slots').child(dateStr).orderByChild('booking_id').equalTo(jamId).get();
        if (slotsSnapshot.exists && slotsSnapshot.value != null) {
          slotsToFree = Map<String, dynamic>.from(slotsSnapshot.value as Map);
        }
      } catch (e) {
        final allSlotsSnapshot = await _dbRef.child('slots').child(dateStr).get();
        if (allSlotsSnapshot.exists && allSlotsSnapshot.value != null) {
           final allSlots = Map<String, dynamic>.from(allSlotsSnapshot.value as Map);
           allSlots.forEach((key, value) {
             final slotData = Map<String, dynamic>.from(value as Map);
             if (slotData['booking_id'] == jamId) {
               slotsToFree[key] = slotData;
             }
           });
        }
      }
      slotsToFree.forEach((key, value) {
        updates['/slots/$dateStr/$key/status'] = 'libero';
        updates['/slots/$dateStr/$key/booked_by'] = null;
        updates['/slots/$dateStr/$key/booking_id'] = null;
        updates['/slots/$dateStr/$key/is_jam'] = null;
      });

      // 3. Rimuovi la Jam
      updates['/jams/$jamId'] = null;

      await _dbRef.update(updates);
      debugPrint("Jam $jamId e post feed eliminati, slot liberati.");

    } catch (e) {
      debugPrint("Errore durante eliminazione jam: $e");
      rethrow;
    }
  }

  // --- GESTIONE FEED ---

  Stream<DatabaseEvent> getFeedStream() {
    return _dbRef.child('feed').orderByChild('timestamp').onValue;
  }

}
