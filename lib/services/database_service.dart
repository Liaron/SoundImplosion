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
    final existingSnapshot = await _dbRef.child('users').child(user.uid).get();
    final updates = <String, dynamic>{
      '/users/${user.uid}': user.toMap(),
      '/user_search_index/${user.nickname.toLowerCase()}/${user.uid}': {
        'nickname': user.nickname,
      },
    };

    if (existingSnapshot.exists && existingSnapshot.value != null) {
      final existingData = Map<String, dynamic>.from(existingSnapshot.value as Map);
      final previousNickname = existingData['nickname']?.toString();
      final previousLowercase = previousNickname?.toLowerCase();
      if (previousLowercase != null && previousLowercase.isNotEmpty && previousLowercase != user.nickname.toLowerCase()) {
        updates['/user_search_index/$previousLowercase/${user.uid}'] = null;
      }
    }

    await _dbRef.update(updates);
  }

  Future<List<Map<String, String>>> getUserGroups() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _dbRef.child('users').child(user.uid).child('gruppi').get();
      
      if (snapshot.exists && snapshot.value != null) {
        final groupsList = <Map<String, String>>[];
        List<String> groupsIds = [];

        if (snapshot.value is Map) {
          groupsIds = (snapshot.value as Map).keys.map((e) => e.toString()).toList();
        } else if (snapshot.value is List) {
           // Fallback in case it was stored as list somehow
           groupsIds = (snapshot.value as List).where((e) => e != null).map((e) => e.toString()).toList();
        }

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

  Stream<DatabaseEvent> getPendingBookingsStream() {
    return _dbRef
        .child('bookings')
        .orderByChild('stato')
        .equalTo(BookingStatus.inElaborazione.name)
        .onValue;
  }

  Stream<DatabaseEvent> getUserGroupIdsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error('Utente non loggato');
    }

    return _dbRef.child('users').child(user.uid).child('gruppi').onValue;
  }

  Stream<DatabaseEvent> getGroupBookingsStream(String groupId) {
    return _dbRef.child('group_bookings').child(groupId).onValue;
  }

  Stream<DatabaseEvent> getGroupInfoStream(String groupId) {
    return _dbRef.child('groups_info').child(groupId).onValue;
  }

  Stream<DatabaseEvent> getAllGroupsStream() {
    return _dbRef.child('groups_info').onValue;
  }

  Future<bool> isCurrentUserAdmin() {
    return _isCurrentUserAdmin();
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
    if (booking.groupId != null && booking.groupId!.isNotEmpty) {
      updates['/group_bookings/${booking.groupId}/$newBookingKey'] = booking.toMap();
    }

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
    if (user == null) {
      throw Exception("Utente non loggato");
    }

    debugPrint("Inizio cancellazione prenotazione: $bookingId");

    final bookingSnapshot = await _dbRef.child('bookings').child(bookingId).get();
    if (!bookingSnapshot.exists || bookingSnapshot.value == null) {
      return;
    }

    final bookingData = Map<String, dynamic>.from(bookingSnapshot.value as Map);
    final bookingOwnerId = bookingData['user_id'] as String?;
    final bookingDate = bookingData['data'] as String?;
    final groupId = bookingData['group_id'] as String?;

    if (bookingOwnerId == null || bookingDate == null) {
      throw Exception("Prenotazione non valida o incompleta");
    }

    if (bookingOwnerId != user.uid) {
      throw Exception("Puoi eliminare solo le tue prenotazioni.");
    }

    final updates = <String, dynamic>{
      '/bookings/$bookingId': null,
      '/user_bookings/$bookingOwnerId/$bookingId': null,
    };

    if (groupId != null && groupId.isNotEmpty) {
      updates['/group_bookings/$groupId/$bookingId'] = null;
    }

    final slotsToFree = await _findSlotsByBookingId(bookingDate, bookingId);
    for (final key in slotsToFree.keys) {
      updates['/slots/$bookingDate/$key/status'] = 'libero';
      updates['/slots/$bookingDate/$key/booked_by'] = null;
      updates['/slots/$bookingDate/$key/booking_id'] = null;
      updates['/slots/$bookingDate/$key/is_jam'] = null;
    }

    if (groupId != null && groupId.isNotEmpty) {
      updates['/group_booking_notifications/$groupId/$bookingId'] = null;
    }

    await _dbRef.update(updates);
    debugPrint("Prenotazione $bookingId eliminata, slot liberati.");
  }

  Future<void> updateBooking({
    required String bookingId,
    required String date,
    required List<String> selectedSlotTimes,
    String? groupId,
    required int peopleCount,
    required String equipment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final bookingSnapshot = await _dbRef.child('bookings').child(bookingId).get();
    if (!bookingSnapshot.exists || bookingSnapshot.value == null) {
      throw Exception('Prenotazione non trovata');
    }

    final bookingData = Map<String, dynamic>.from(bookingSnapshot.value as Map);
    final bookingOwnerId = bookingData['user_id']?.toString() ?? '';
    final previousDate = bookingData['data']?.toString() ?? '';
    final previousGroupId = bookingData['group_id']?.toString();
    final isAdmin = await _isCurrentUserAdmin();
    if (bookingOwnerId != user.uid && !isAdmin) {
      throw Exception('Puoi modificare solo le tue prenotazioni');
    }

    if (selectedSlotTimes.isEmpty) {
      throw Exception('Seleziona almeno un orario');
    }

    final orderedSlots = List<String>.from(selectedSlotTimes)..sort();
    await _ensureSlotsExistForDate(date);
    final targetSlotsSnapshot = await _dbRef.child('slots').child(date).get();
    if (!targetSlotsSnapshot.exists || targetSlotsSnapshot.value == null) {
      throw Exception('Disponibilita non trovata');
    }

    final targetSlots = Map<String, dynamic>.from(targetSlotsSnapshot.value as Map);
    for (final time in orderedSlots) {
      final slotKey = time.replaceAll(':', '_');
      final slotData = Map<String, dynamic>.from((targetSlots[slotKey] as Map?) ?? const {});
      final status = slotData['status']?.toString();
      final bookingIdOnSlot = slotData['booking_id']?.toString();
      if (status != 'libero' && bookingIdOnSlot != bookingId) {
        throw Exception('Uno degli slot selezionati non e piu disponibile');
      }
    }

    final trimmedEquipment = equipment.trim();
    final newEndTime = _calculateEndTime(orderedSlots.last);
    final scheduleChanged =
        previousDate != date ||
        (bookingData['ora_inizio']?.toString() ?? '') != orderedSlots.first ||
        (bookingData['ora_fine']?.toString() ?? '') != newEndTime;
    final nextStatus = scheduleChanged
        ? BookingStatus.inElaborazione.name
        : bookingData['stato']?.toString() ?? BookingStatus.inElaborazione.name;
    final oldSlots = previousDate.isEmpty ? <String, dynamic>{} : await _findSlotsByBookingId(previousDate, bookingId);
    final updates = <String, dynamic>{
      '/bookings/$bookingId/data': date,
      '/bookings/$bookingId/ora_inizio': orderedSlots.first,
      '/bookings/$bookingId/ora_fine': newEndTime,
      '/bookings/$bookingId/group_id': groupId,
      '/bookings/$bookingId/numero_utenti': peopleCount,
      '/bookings/$bookingId/attrezzatura': trimmedEquipment,
      '/bookings/$bookingId/stato': nextStatus,
      '/user_bookings/$bookingOwnerId/$bookingId/data': date,
      '/user_bookings/$bookingOwnerId/$bookingId/ora_inizio': orderedSlots.first,
      '/user_bookings/$bookingOwnerId/$bookingId/ora_fine': newEndTime,
      '/user_bookings/$bookingOwnerId/$bookingId/group_id': groupId,
      '/user_bookings/$bookingOwnerId/$bookingId/numero_utenti': peopleCount,
      '/user_bookings/$bookingOwnerId/$bookingId/attrezzatura': trimmedEquipment,
      '/user_bookings/$bookingOwnerId/$bookingId/stato': nextStatus,
    };

    if (previousGroupId != null && previousGroupId.isNotEmpty && previousGroupId != groupId) {
      updates['/group_bookings/$previousGroupId/$bookingId'] = null;
    }

    if (groupId != null && groupId.isNotEmpty) {
      updates['/group_bookings/$groupId/$bookingId/data'] = date;
      updates['/group_bookings/$groupId/$bookingId/ora_inizio'] = orderedSlots.first;
      updates['/group_bookings/$groupId/$bookingId/ora_fine'] = newEndTime;
      updates['/group_bookings/$groupId/$bookingId/group_id'] = groupId;
      updates['/group_bookings/$groupId/$bookingId/numero_utenti'] = peopleCount;
      updates['/group_bookings/$groupId/$bookingId/attrezzatura'] = trimmedEquipment;
      updates['/group_bookings/$groupId/$bookingId/user_id'] = bookingOwnerId;
      updates['/group_bookings/$groupId/$bookingId/stato'] = nextStatus;
    }

    for (final key in oldSlots.keys) {
      updates['/slots/$previousDate/$key/status'] = 'libero';
      updates['/slots/$previousDate/$key/booked_by'] = null;
      updates['/slots/$previousDate/$key/booking_id'] = null;
      updates['/slots/$previousDate/$key/is_jam'] = null;
    }

    for (final time in orderedSlots) {
      final slotKey = time.replaceAll(':', '_');
      updates['/slots/$date/$slotKey/status'] = 'occupato';
      updates['/slots/$date/$slotKey/booked_by'] = bookingOwnerId;
      updates['/slots/$date/$slotKey/booking_id'] = bookingId;
      updates['/slots/$date/$slotKey/is_jam'] = null;
    }

    await _dbRef.update(updates);
  }

  Future<void> _notifyGroupMembers(String groupId, String bookingId, Booking booking) async {
    try {
      final groupSnapshot = await _dbRef.child('groups_info').child(groupId).get();

      final notificationPayload = {
        'type': 'booking_created',
        'booking_id': bookingId,
        'group_id': groupId,
        'creator_id': booking.userId,
        'data': booking.data,
        'ora_inizio': booking.oraInizio,
        'ora_fine': booking.oraFine,
        'timestamp': ServerValue.timestamp,
      };

      final updates = <String, dynamic>{
        '/group_booking_notifications/$groupId/$bookingId': notificationPayload,
      };

      if (groupSnapshot.exists && groupSnapshot.value != null) {
        final groupData = Map<String, dynamic>.from(groupSnapshot.value as Map);
        final memberIds = <String>{
          ..._extractIds(groupData['members']),
          ..._extractIds(groupData['membri']),
          ..._extractIds(groupData['users']),
          ..._extractIds(groupData['user_ids']),
        }..remove(booking.userId);

        for (final memberId in memberIds) {
          updates['/user_notifications/$memberId/$bookingId'] = notificationPayload;
        }
      }

      await _dbRef.update(updates);
    } catch (e) {
      debugPrint("Errore notifica gruppo $groupId per booking $bookingId: $e");
    }
  }

  Future<Map<String, dynamic>> _findSlotsByBookingId(String dateStr, String bookingId) async {
    try {
      final slotsSnapshot = await _dbRef
          .child('slots')
          .child(dateStr)
          .orderByChild('booking_id')
          .equalTo(bookingId)
          .get();

      if (slotsSnapshot.exists && slotsSnapshot.value != null && slotsSnapshot.value is Map) {
        return Map<String, dynamic>.from(slotsSnapshot.value as Map);
      }
    } catch (e) {
      debugPrint("Query slot per booking $bookingId fallita: $e");
    }

    final allSlotsSnapshot = await _dbRef.child('slots').child(dateStr).get();
    final slotsToFree = <String, dynamic>{};

    if (allSlotsSnapshot.exists && allSlotsSnapshot.value != null) {
      final allSlots = Map<String, dynamic>.from(allSlotsSnapshot.value as Map);
      allSlots.forEach((key, value) {
        final slotData = Map<String, dynamic>.from(value as Map);
        if (slotData['booking_id'] == bookingId) {
          slotsToFree[key] = slotData;
        }
      });
    }

    return slotsToFree;
  }

  Set<String> _extractIds(dynamic rawValue) {
    if (rawValue == null) {
      return <String>{};
    }

    if (rawValue is Map) {
      return rawValue.keys.map((key) => key.toString()).toSet();
    }

    if (rawValue is List) {
      return rawValue.where((item) => item != null).map((item) => item.toString()).toSet();
    }

    return <String>{};
  }

  int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // --- GESTIONE JAM ---

  Future<void> confirmBooking(String bookingId) async {
    await _ensureCurrentUserIsAdminOrThrow();

    final snapshot = await _dbRef.child('bookings').child(bookingId).get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Prenotazione non trovata');
    }

    final bookingData = Map<String, dynamic>.from(snapshot.value as Map);
    final ownerId = bookingData['user_id']?.toString() ?? '';
    final groupId = bookingData['group_id']?.toString();
    final updates = <String, dynamic>{
      '/bookings/$bookingId/stato': BookingStatus.confermata.name,
      '/user_bookings/$ownerId/$bookingId/stato': BookingStatus.confermata.name,
    };

    if (groupId != null && groupId.isNotEmpty) {
      updates['/group_bookings/$groupId/$bookingId/stato'] = BookingStatus.confermata.name;
    }

    await _dbRef.update(updates);
  }

  Future<void> cancelBooking(String bookingId) async {
    await _ensureCurrentUserIsAdminOrThrow();

    final snapshot = await _dbRef.child('bookings').child(bookingId).get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Prenotazione non trovata');
    }

    final bookingData = Map<String, dynamic>.from(snapshot.value as Map);
    final ownerId = bookingData['user_id']?.toString() ?? '';
    final groupId = bookingData['group_id']?.toString();
    final date = bookingData['data']?.toString() ?? '';
    final updates = <String, dynamic>{
      '/bookings/$bookingId/stato': BookingStatus.annullata.name,
      '/user_bookings/$ownerId/$bookingId/stato': BookingStatus.annullata.name,
    };

    if (groupId != null && groupId.isNotEmpty) {
      updates['/group_bookings/$groupId/$bookingId/stato'] = BookingStatus.annullata.name;
    }

    if (date.isNotEmpty) {
      final slotsToFree = await _findSlotsByBookingId(date, bookingId);
      for (final key in slotsToFree.keys) {
        updates['/slots/$date/$key/status'] = 'libero';
        updates['/slots/$date/$key/booked_by'] = null;
        updates['/slots/$date/$key/booking_id'] = null;
        updates['/slots/$date/$key/is_jam'] = null;
      }
    }

    await _dbRef.update(updates);
  }

  Future<void> createJam(Jam jam, List<String> selectedSlotTimes) async {
    debugPrint("Inizio creazione JAM...");
    
    final newJamKey = _dbRef.child('jams').push().key;
    if (newJamKey == null) throw Exception("Impossibile generare ID Jam");

    final Map<String, dynamic> updates = {};
    
    // 1. Salva la Jam
    final jamPath = '/jams/$newJamKey';
    updates[jamPath] = jam.toMap();

    // 2. Aggiorna gli slot come occupati
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
      debugPrint("Jam creata in stato di approvazione.");
    } catch (e) {
      debugPrint("Errore durante createJam: $e");
      rethrow;
    }
  }

  Stream<DatabaseEvent> getJamsStream() {
    return _dbRef.child('jams').onValue;
  }

  Stream<DatabaseEvent> getPublishedJamsStream() {
    return _dbRef.child('jams').orderByChild('stato').equalTo(JamStatus.pubblicata.name).onValue;
  }

  Stream<DatabaseEvent> getOwnJamsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error('Utente non loggato');
    }

    return _dbRef.child('jams').orderByChild('creator_id').equalTo(user.uid).onValue;
  }

  Stream<DatabaseEvent> getPendingJamsStream() {
    return _dbRef.child('jams').orderByChild('stato').equalTo(JamStatus.inElaborazione.name).onValue;
  }

  Future<void> approveJam(String jamId) async {
    await _ensureCurrentUserIsAdminOrThrow();

    final snapshot = await _dbRef.child('jams').child(jamId).get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Jam non trovata');
    }

    final jamData = Map<String, dynamic>.from(snapshot.value as Map);
    final updates = <String, dynamic>{
      '/jams/$jamId/stato': JamStatus.pubblicata.name,
    };

    final feedSnapshot = await _dbRef.child('feed').orderByChild('jam_id').equalTo(jamId).get();
    if (feedSnapshot.exists && feedSnapshot.value != null) {
      final feedData = Map<String, dynamic>.from(feedSnapshot.value as Map);
      for (final entry in feedData.entries) {
        updates['/feed/${entry.key}/type'] = 'jam_published';
        updates['/feed/${entry.key}/creator_id'] = jamData['creator_id'];
        updates['/feed/${entry.key}/data'] = jamData['data'];
        updates['/feed/${entry.key}/ora_inizio'] = jamData['ora_inizio'];
        updates['/feed/${entry.key}/descrizione'] = jamData['descrizione'];
      }
    } else {
      final newFeedKey = _dbRef.child('feed').push().key;
      if (newFeedKey != null) {
        updates['/feed/$newFeedKey'] = {
          'type': 'jam_published',
          'timestamp': ServerValue.timestamp,
          'jam_id': jamId,
          'creator_id': jamData['creator_id'],
          'data': jamData['data'],
          'ora_inizio': jamData['ora_inizio'],
          'descrizione': jamData['descrizione'],
        };
      }
    }

    await _dbRef.update(updates);
  }

  Future<void> rejectJam(String jamId) async {
    await _ensureCurrentUserIsAdminOrThrow();

    final snapshot = await _dbRef.child('jams').child(jamId).get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Jam non trovata');
    }

    final jamData = Map<String, dynamic>.from(snapshot.value as Map);
    final dateStr = jamData['data']?.toString() ?? '';
    final participantIds = _extractIds(jamData['participants']);
    final updates = <String, dynamic>{
      '/jams/$jamId/stato': JamStatus.annullata.name,
      '/jams/$jamId/participants': null,
    };

    if (dateStr.isNotEmpty) {
      final slotsToFree = await _findSlotsByBookingId(dateStr, jamId);
      for (final key in slotsToFree.keys) {
        updates['/slots/$dateStr/$key/status'] = 'libero';
        updates['/slots/$dateStr/$key/booked_by'] = null;
        updates['/slots/$dateStr/$key/booking_id'] = null;
        updates['/slots/$dateStr/$key/is_jam'] = null;
      }
    }

    for (final participantId in participantIds) {
      updates['/user_joined_jams/$participantId/$jamId'] = null;
    }

    final feedSnapshot = await _dbRef.child('feed').orderByChild('jam_id').equalTo(jamId).get();
    if (feedSnapshot.exists && feedSnapshot.value != null) {
      final feedData = Map<String, dynamic>.from(feedSnapshot.value as Map);
      for (final entry in feedData.entries) {
        updates['/feed/${entry.key}'] = null;
      }
    }

    await _dbRef.update(updates);
  }

  Future<List<Map<String, dynamic>>> getPublishedJamsOnce() async {
    try {
      final snapshot = await _dbRef
          .child('jams')
          .orderByChild('stato')
          .equalTo(JamStatus.pubblicata.name)
          .get();
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final dynamic rawData = snapshot.value;
      List<Map<String, dynamic>> jams = [];

      if (rawData is Map) {
        jams = rawData.entries.map((entry) {
          final jamData = Map<String, dynamic>.from(entry.value as Map);
          jamData['key'] = entry.key;
          return jamData;
        }).toList();
      } else if (rawData is List) {
        for (int i = 0; i < rawData.length; i++) {
          if (rawData[i] != null) {
            final jamData = Map<String, dynamic>.from(rawData[i] as Map);
            jamData['key'] = i.toString();
            jams.add(jamData);
          }
        }
      }
    return jams;

    } catch (e) {
      debugPrint("Errore getPublishedJamsOnce: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> getJamById(String jamId) async {
    try {
      final snapshot = await _dbRef.child('jams').child(jamId).get();
      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final jamData = Map<String, dynamic>.from(snapshot.value as Map);
      jamData['key'] = jamId;
      return jamData;
    } catch (e) {
      debugPrint('Errore getJamById($jamId): $e');
      return null;
    }
  }

  Future<void> joinJam(String jamId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef.child('jams').child(jamId).get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Jam non trovata');
    }

    final jamData = Map<String, dynamic>.from(snapshot.value as Map);
    final creatorId = jamData['creator_id']?.toString() ?? '';
    if (creatorId == user.uid) {
      throw Exception('Sei gia il creatore di questa jam');
    }

    final participants = _extractIds(jamData['participants']);
    if (participants.contains(user.uid)) {
      throw Exception('Stai gia partecipando a questa jam');
    }

    final currentPresent = _parseInt(jamData['persone_presenti']);
    final currentRequired = _parseInt(jamData['persone_richieste']);
    if (currentRequired <= 0) {
      throw Exception('Questa jam e al completo');
    }

    await _dbRef.update({
      '/jams/$jamId/persone_presenti': currentPresent + 1,
      '/jams/$jamId/persone_richieste': currentRequired - 1,
      '/jams/$jamId/participants/${user.uid}': true,
      '/user_joined_jams/${user.uid}/$jamId': true,
    });
  }

  Future<void> leaveJam(String jamId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef.child('jams').child(jamId).get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Jam non trovata');
    }

    final jamData = Map<String, dynamic>.from(snapshot.value as Map);
    final creatorId = jamData['creator_id']?.toString() ?? '';
    if (creatorId == user.uid) {
      throw Exception('Il creatore non puo uscire dalla propria jam');
    }

    final participants = _extractIds(jamData['participants']);
    if (!participants.contains(user.uid)) {
      throw Exception('Non stai partecipando a questa jam');
    }

    final currentPresent = _parseInt(jamData['persone_presenti']);
    final currentRequired = _parseInt(jamData['persone_richieste']);
    await _dbRef.update({
      '/jams/$jamId/persone_presenti': currentPresent > 0 ? currentPresent - 1 : 0,
      '/jams/$jamId/persone_richieste': currentRequired + 1,
      '/jams/$jamId/participants/${user.uid}': null,
      '/user_joined_jams/${user.uid}/$jamId': null,
    });
  }

  Future<void> updateJam({
    required String jamId,
    required String date,
    required List<String> selectedSlotTimes,
    String? groupId,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String payment,
    required String equipment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef.child('jams').child(jamId).get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Jam non trovata');
    }

    final jamData = Map<String, dynamic>.from(snapshot.value as Map);
    final creatorId = jamData['creator_id']?.toString() ?? '';
    final previousDate = jamData['data']?.toString() ?? '';
    final isAdmin = await _isCurrentUserAdmin();
    if (creatorId != user.uid && !isAdmin) {
      throw Exception('Solo il creatore puo modificare questa jam');
    }

    if (selectedSlotTimes.isEmpty) {
      throw Exception('Seleziona almeno un orario');
    }

    final orderedSlots = List<String>.from(selectedSlotTimes)..sort();
    await _ensureSlotsExistForDate(date);
    final targetSlotsSnapshot = await _dbRef.child('slots').child(date).get();
    if (!targetSlotsSnapshot.exists || targetSlotsSnapshot.value == null) {
      throw Exception('Disponibilita non trovata');
    }

    final targetSlots = Map<String, dynamic>.from(targetSlotsSnapshot.value as Map);
    for (final time in orderedSlots) {
      final slotKey = time.replaceAll(':', '_');
      final slotData = Map<String, dynamic>.from((targetSlots[slotKey] as Map?) ?? const {});
      final status = slotData['status']?.toString();
      final bookingIdOnSlot = slotData['booking_id']?.toString();
      if (status != 'libero' && bookingIdOnSlot != jamId) {
        throw Exception('Uno degli slot selezionati non e piu disponibile');
      }
    }

    final trimmedDescription = description.trim();
    final trimmedEquipment = equipment.trim();
    final newEndTime = _calculateEndTime(orderedSlots.last);
    final scheduleChanged =
        previousDate != date ||
        (jamData['ora_inizio']?.toString() ?? '') != orderedSlots.first ||
        (jamData['ora_fine']?.toString() ?? '') != newEndTime;
    final nextStatus = scheduleChanged
        ? JamStatus.inElaborazione.name
        : jamData['stato']?.toString() ?? JamStatus.inElaborazione.name;
    final oldSlots = previousDate.isEmpty ? <String, dynamic>{} : await _findSlotsByBookingId(previousDate, jamId);
    final updates = <String, dynamic>{
      '/jams/$jamId/data': date,
      '/jams/$jamId/ora_inizio': orderedSlots.first,
      '/jams/$jamId/ora_fine': newEndTime,
      '/jams/$jamId/group_id': groupId,
      '/jams/$jamId/persone_presenti': presentPeople,
      '/jams/$jamId/persone_richieste': requiredPeople,
      '/jams/$jamId/descrizione': trimmedDescription,
      '/jams/$jamId/pagamento': payment,
      '/jams/$jamId/attrezzatura': trimmedEquipment,
      '/jams/$jamId/stato': nextStatus,
    };

    for (final key in oldSlots.keys) {
      updates['/slots/$previousDate/$key/status'] = 'libero';
      updates['/slots/$previousDate/$key/booked_by'] = null;
      updates['/slots/$previousDate/$key/booking_id'] = null;
      updates['/slots/$previousDate/$key/is_jam'] = null;
    }

    for (final time in orderedSlots) {
      final slotKey = time.replaceAll(':', '_');
      updates['/slots/$date/$slotKey/status'] = 'occupato';
      updates['/slots/$date/$slotKey/booked_by'] = creatorId;
      updates['/slots/$date/$slotKey/booking_id'] = jamId;
      updates['/slots/$date/$slotKey/is_jam'] = true;
    }

    final feedSnapshot = await _dbRef.child('feed').orderByChild('jam_id').equalTo(jamId).get();
    if (feedSnapshot.exists && feedSnapshot.value != null) {
      final feedData = Map<String, dynamic>.from(feedSnapshot.value as Map);
      for (final entry in feedData.entries) {
        if (scheduleChanged) {
          updates['/feed/${entry.key}'] = null;
        } else {
          updates['/feed/${entry.key}/data'] = date;
          updates['/feed/${entry.key}/ora_inizio'] = orderedSlots.first;
          updates['/feed/${entry.key}/descrizione'] = trimmedDescription;
        }
      }
    }

    await _dbRef.update(updates);
  }

  Future<void> _ensureSlotsExistForDate(String dateStr) async {
    final snapshot = await _dbRef.child('slots').child(dateStr).get();
    if (!snapshot.exists) {
      await _generateSlotsForDate(dateStr);
    }
  }

  Future<bool> _isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    final roleSnapshot = await _dbRef.child('users').child(user.uid).child('role').get();
    return roleSnapshot.value?.toString() == 'admin';
  }

  Future<void> _ensureCurrentUserIsAdminOrThrow() async {
    if (!await _isCurrentUserAdmin()) {
      throw Exception('Permessi insufficienti');
    }
  }

  Future<List<Map<String, dynamic>>> searchUsersByNickname(String nickname) async {
    final trimmedNickname = nickname.trim();
    if (trimmedNickname.isEmpty) {
      return [];
    }

    final lowercaseNickname = trimmedNickname.toLowerCase();
    final snapshot = await _dbRef.child('user_search_index').child(lowercaseNickname).get();
    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final results = <Map<String, dynamic>>[];
    if (snapshot.value is Map) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      for (final entry in data.entries) {
        final payload = Map<String, dynamic>.from(entry.value as Map);
        results.add({
          'uid': entry.key,
          'nickname': payload['nickname']?.toString() ?? trimmedNickname,
        });
      }
    }

    return results;
  }

  Future<void> createGroup(String name) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Inserisci un nome gruppo');
    }

    final userSnapshot = await _dbRef.child('users').child(user.uid).get();
    final userData = userSnapshot.exists && userSnapshot.value != null
        ? Map<String, dynamic>.from(userSnapshot.value as Map)
        : <String, dynamic>{};
    final nickname = userData['nickname']?.toString() ?? user.uid;

    final groupId = _dbRef.child('groups_info').push().key;
    if (groupId == null) {
      throw Exception('Impossibile creare il gruppo');
    }

    await _dbRef.update({
      '/groups_info/$groupId': {
        'name': trimmedName,
        'owner_id': user.uid,
        'created_at': ServerValue.timestamp,
        'members': {
          user.uid: true,
        },
        'member_nicknames': {
          user.uid: nickname,
        },
      },
      '/users/${user.uid}/gruppi/$groupId': true,
    });
  }

  Future<void> inviteUserToGroup({
    required String groupId,
    required String nickname,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final groupSnapshot = await _dbRef.child('groups_info').child(groupId).get();
    if (!groupSnapshot.exists || groupSnapshot.value == null) {
      throw Exception('Gruppo non trovato');
    }

    final groupData = Map<String, dynamic>.from(groupSnapshot.value as Map);
    final isAdmin = await _isCurrentUserAdmin();
    if (groupData['owner_id']?.toString() != user.uid && !isAdmin) {
      throw Exception('Solo il proprietario del gruppo puo invitare membri');
    }

    final matches = await searchUsersByNickname(nickname);
    if (matches.isEmpty) {
      throw Exception('Nessun utente trovato con questo username');
    }

    final targetUser = matches.first;
    final targetUid = targetUser['uid']?.toString() ?? '';
    final targetNickname = targetUser['nickname']?.toString() ?? nickname.trim();
    if (targetUid.isEmpty) {
      throw Exception('Utente non valido');
    }

    final members = _extractIds(groupData['members']);
    if (members.contains(targetUid)) {
      throw Exception('Questo utente e gia nel gruppo');
    }

    await _dbRef.update({
      '/groups_info/$groupId/members/$targetUid': true,
      '/groups_info/$groupId/member_nicknames/$targetUid': targetNickname,
      '/users/$targetUid/gruppi/$groupId': true,
    });
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _calculateEndTime(String startSlot) {
    final totalMinutes = _timeToMinutes(startSlot) + 75;
    final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
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
      final isAdmin = await _isCurrentUserAdmin();

      if (creatorId != user.uid && !isAdmin) {
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
          if (slotsSnapshot.value is Map) {
             slotsToFree = Map<String, dynamic>.from(slotsSnapshot.value as Map);
          } else if (slotsSnapshot.value is List) {
             // Handle potential list return (though unlikely with string keys)
             final list = slotsSnapshot.value as List;
             for (int i=0; i < list.length; i++) {
               if (list[i] != null) {
                 // Try to recover original key if possible, but here we likely only have value
                 // Ideally we shouldn't get here for slots with "HH_mm" keys.
                 // But if we do, we can't reliably reconstruct the key unless it's inside the value.
                 // The code below iterates over slotsToFree keys.
                 // If we can't get the key, we can't update.
                 // So we assume Map.
               }
             }
          }
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
