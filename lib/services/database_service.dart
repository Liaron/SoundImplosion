import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:flutter/foundation.dart'; // Per debugPrint
import 'package:intl/intl.dart';

class DatabaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://liaron-soundimplosion-default-rtdb.europe-west1.firebasedatabase.app',
  ).ref();
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'us-central1',
  );

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

  Map<String, dynamic> _asStringKeyedMap(dynamic rawValue) {
    if (rawValue is Map) {
      final result = <String, dynamic>{};
      for (final entry in rawValue.entries) {
        final key = entry.key?.toString().trim() ?? '';
        if (key.isEmpty) {
          continue;
        }
        result[key] = entry.value;
      }
      return result;
    }
    return <String, dynamic>{};
  }

  List<String> _asLowercaseStringList(dynamic rawValue) {
    if (rawValue is List) {
      return rawValue
          .map((item) => item?.toString().trim().toLowerCase() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (rawValue is Map) {
      return rawValue.values
          .map((item) => item?.toString().trim().toLowerCase() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final value = rawValue?.toString().trim().toLowerCase() ?? '';
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  List<String> _asStringList(dynamic rawValue) {
    if (rawValue is List) {
      return rawValue
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (rawValue is Map) {
      return rawValue.values
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final value = rawValue?.toString().trim() ?? '';
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  @visibleForTesting
  static Set<String> extractIndexedUserIds(dynamic rawValue) {
    if (rawValue == null) {
      return const <String>{};
    }

    if (rawValue is String) {
      final trimmedValue = rawValue.trim();
      return trimmedValue.isEmpty ? const <String>{} : <String>{trimmedValue};
    }

    if (rawValue is! Map) {
      return const <String>{};
    }

    final data = Map<String, dynamic>.from(rawValue);
    final looksLikeSinglePayload =
        data.containsKey('uid') ||
        data.containsKey('nickname') ||
        data.containsKey('username');
    if (looksLikeSinglePayload) {
      final uid = data['uid']?.toString().trim() ?? '';
      return uid.isEmpty ? const <String>{} : <String>{uid};
    }

    final userIds = <String>{};
    for (final key in data.keys) {
      final uid = key.toString().trim();
      if (uid.isNotEmpty) {
        userIds.add(uid);
      }
    }
    return userIds;
  }

  bool _isLegacySingleIndexEntry(dynamic rawValue, String uid) {
    if (rawValue is String) {
      return rawValue.trim() == uid;
    }

    if (rawValue is! Map) {
      return false;
    }

    final data = Map<String, dynamic>.from(rawValue);
    if (!(data.containsKey('uid') ||
        data.containsKey('nickname') ||
        data.containsKey('username'))) {
      return false;
    }

    return data['uid']?.toString().trim() == uid;
  }

  String _normalizeNickname(String nickname) => nickname.trim().toLowerCase();
  String _normalizeEmail(String email) => email.trim().toLowerCase();
  String _emailKey(String email) => _normalizeEmail(email).replaceAll('.', ',');
  String _tokenKey(String token) => token.replaceAll('.', '_');
  String _groupInviteNotificationId(String groupId) => 'group_invite_$groupId';

  @visibleForTesting
  static String sanitizeUsernameSeed(String value) {
    final lowercased = value.trim().toLowerCase();
    final collapsed = lowercased.replaceAll(RegExp(r'\s+'), '');
    final sanitized = collapsed.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return sanitized;
  }

  Future<String> generateAvailableUsername({
    required String? preferredName,
    required String? email,
    String? excludingUid,
  }) async {
    final emailLocalPart = email?.split('@').first;
    final baseSeed = sanitizeUsernameSeed(
      preferredName?.trim().isNotEmpty == true
          ? preferredName!
          : (emailLocalPart?.trim().isNotEmpty == true
                ? emailLocalPart!
                : 'user'),
    );
    final baseUsername = baseSeed.isEmpty ? 'user' : baseSeed;

    var counter = 0;
    while (true) {
      final candidate = counter == 0 ? baseUsername : '$baseUsername$counter';
      if (await isNicknameAvailable(candidate, excludingUid: excludingUid)) {
        return candidate;
      }
      counter += 1;
    }
  }

  Future<bool> isEmailAvailable(String email, {String? excludingUid}) async {
    final normalizedEmail = _normalizeEmail(email);
    final emailKey = _emailKey(email);
    if (normalizedEmail.isEmpty) {
      return false;
    }

    final claimSnapshot = await _dbRef
        .child('email_claims')
        .child(emailKey)
        .get();
    final claimedBy = claimSnapshot.value?.toString().trim() ?? '';
    if (claimedBy.isEmpty) {
      return true;
    }

    return claimedBy == excludingUid;
  }

  Future<RegistrationAvailability> checkRegistrationAvailability({
    required String nickname,
    required String email,
    String? excludingUid,
  }) async {
    try {
      final response = await _functions
          .httpsCallable('checkRegistrationAvailability')
          .call({
            'nickname': nickname.trim(),
            'email': email.trim(),
            'excludingUid': excludingUid,
          });
      final data = response.data;
      if (data is Map) {
        final payload = Map<String, dynamic>.from(data);
        return RegistrationAvailability(
          nicknameAvailable: payload['nicknameAvailable'] == true,
          emailAvailable: payload['emailAvailable'] == true,
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (_auth.currentUser == null) {
        throw Exception(
          error.message ?? 'Verifica disponibilita non disponibile',
        );
      }
    }

    final results = await Future.wait([
      isNicknameAvailable(nickname, excludingUid: excludingUid),
      isEmailAvailable(email, excludingUid: excludingUid),
    ]);

    return RegistrationAvailability(
      nicknameAvailable: results[0],
      emailAvailable: results[1],
    );
  }

  Future<bool> isNicknameAvailable(
    String nickname, {
    String? excludingUid,
  }) async {
    final normalizedNickname = _normalizeNickname(nickname);
    if (normalizedNickname.isEmpty) {
      return false;
    }

    final claimSnapshot = await _dbRef
        .child('nickname_claims')
        .child(normalizedNickname)
        .get();
    final claimedBy = claimSnapshot.value?.toString();
    if (claimedBy != null &&
        claimedBy.isNotEmpty &&
        claimedBy != excludingUid) {
      return false;
    }

    final searchSnapshot = await _dbRef
        .child('user_search_index')
        .child(normalizedNickname)
        .get();
    if (!searchSnapshot.exists || searchSnapshot.value == null) {
      return true;
    }

    final indexedUserIds = extractIndexedUserIds(searchSnapshot.value);
    for (final candidateUid in indexedUserIds) {
      if (candidateUid != excludingUid) {
        return false;
      }
    }

    return true;
  }

  Map<String, dynamic> _buildPublicUserProfileData(AppUser user) {
    final instruments = user.strumentiList
        .map((item) => item['nome']?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();

    return {
      'username': user.nickname.trim(),
      'username_lowercase': user.nickname.trim().toLowerCase(),
      'city': user.city,
      'city_lowercase': user.city.toLowerCase(),
      'bio': user.bio,
      'skill_level': user.skillLevel,
      'genres': user.genres,
      'genres_search': user.genres.map((genre) => genre.toLowerCase()).toList(),
      'instruments': instruments,
      'instruments_search': instruments
          .map((instrument) => instrument.toLowerCase())
          .toList(),
      'availability': user.availability,
    };
  }

  bool _profileMatchesFilters(
    Map<String, dynamic> profile, {
    required String usernameFilter,
    required String cityFilter,
    required String instrumentFilter,
    required String genreFilter,
    bool usernameAlreadyMatched = false,
  }) {
    final username =
        profile['username']?.toString() ??
        profile['username_lowercase']?.toString() ??
        '';
    final city = profile['city']?.toString() ?? '';
    final instruments = _asLowercaseStringList(
      profile['instruments_search'] ?? profile['instruments'],
    );
    final genres = _asLowercaseStringList(
      profile['genres_search'] ?? profile['genres'],
    );

    final matchesUsername =
        usernameFilter.isEmpty ||
        usernameAlreadyMatched ||
        username.toLowerCase().contains(usernameFilter);
    final matchesCity =
        cityFilter.isEmpty || city.toLowerCase().contains(cityFilter);
    final matchesInstrument =
        instrumentFilter.isEmpty ||
        instruments.any((item) => item.contains(instrumentFilter));
    final matchesGenre =
        genreFilter.isEmpty || genres.any((item) => item.contains(genreFilter));

    return matchesUsername && matchesCity && matchesInstrument && matchesGenre;
  }

  Future<void> saveUser(AppUser user) async {
    final trimmedNickname = user.nickname.trim();
    final trimmedEmail = user.email?.trim() ?? '';
    if (trimmedNickname.isEmpty) {
      throw Exception('Inserisci uno username valido');
    }
    if (trimmedEmail.isEmpty) {
      throw Exception('Inserisci una email valida');
    }

    final normalizedNickname = _normalizeNickname(trimmedNickname);
    final normalizedEmail = _normalizeEmail(trimmedEmail);
    final emailKey = _emailKey(trimmedEmail);
    final existingSnapshot = await _dbRef.child('users').child(user.uid).get();
    final availability = await checkRegistrationAvailability(
      nickname: trimmedNickname,
      email: trimmedEmail,
      excludingUid: user.uid,
    );
    if (!availability.isAvailable) {
      throw Exception(availability.errorMessage);
    }

    final sanitizedUser = user.copyWith(
      nickname: trimmedNickname,
      email: trimmedEmail,
    );
    final claimRef = _dbRef.child('nickname_claims').child(normalizedNickname);
    final claimResult = await claimRef.runTransaction((Object? currentData) {
      final claimedBy = currentData?.toString().trim() ?? '';
      if (claimedBy.isNotEmpty && claimedBy != user.uid) {
        return Transaction.abort();
      }

      return Transaction.success(user.uid);
    }, applyLocally: false);

    if (!claimResult.committed) {
      throw Exception('Username gia utilizzato');
    }

    final emailClaimRef = _dbRef.child('email_claims').child(emailKey);
    final emailClaimResult = await emailClaimRef.runTransaction((
      Object? currentData,
    ) {
      final claimedBy = currentData?.toString().trim() ?? '';
      if (claimedBy.isNotEmpty && claimedBy != user.uid) {
        return Transaction.abort();
      }

      return Transaction.success(user.uid);
    }, applyLocally: false);

    if (!emailClaimResult.committed) {
      final nicknameClaimSnapshot = await claimRef.get();
      if (nicknameClaimSnapshot.value?.toString().trim() == user.uid) {
        await claimRef.remove();
      }
      throw Exception('Email gia utilizzata');
    }

    final currentIndexRef = _dbRef
        .child('user_search_index')
        .child(normalizedNickname);
    final currentIndexSnapshot = await currentIndexRef.get();
    if (_isLegacySingleIndexEntry(currentIndexSnapshot.value, user.uid)) {
      await currentIndexRef.remove();
    }

    String? previousLowercase;
    String? previousEmailLowercase;
    if (existingSnapshot.exists && existingSnapshot.value != null) {
      final existingData = _asStringKeyedMap(existingSnapshot.value);
      final previousNickname =
          existingData['username']?.toString() ??
          existingData['nickname']?.toString();
      previousLowercase = previousNickname?.toLowerCase();
      previousEmailLowercase = existingData['email']?.toString().toLowerCase();
    }

    try {
      await _dbRef.child('users').child(user.uid).set(sanitizedUser.toMap());
      await _dbRef
          .child('user_public_profiles')
          .child(user.uid)
          .set(_buildPublicUserProfileData(sanitizedUser));
      await currentIndexRef.child(user.uid).set({'username': trimmedNickname});
      await _dbRef
          .child('user_email_index')
          .child(emailKey)
          .child(user.uid)
          .set(true);

      if (previousLowercase != null &&
          previousLowercase.isNotEmpty &&
          previousLowercase != normalizedNickname) {
        final previousIndexRef = _dbRef
            .child('user_search_index')
            .child(previousLowercase);
        final previousIndexSnapshot = await previousIndexRef.get();
        if (_isLegacySingleIndexEntry(previousIndexSnapshot.value, user.uid)) {
          await previousIndexRef.remove();
        } else {
          await previousIndexRef.child(user.uid).remove();
        }

        final previousClaimRef = _dbRef
            .child('nickname_claims')
            .child(previousLowercase);
        final previousClaimSnapshot = await previousClaimRef.get();
        if (previousClaimSnapshot.value?.toString().trim() == user.uid) {
          await previousClaimRef.remove();
        }
      }

      if (previousEmailLowercase != null &&
          previousEmailLowercase.isNotEmpty &&
          previousEmailLowercase != normalizedEmail) {
        final previousEmailKey = _emailKey(previousEmailLowercase);
        await _dbRef
            .child('user_email_index')
            .child(previousEmailKey)
            .child(user.uid)
            .remove();

        final previousEmailClaimRef = _dbRef
            .child('email_claims')
            .child(previousEmailKey);
        final previousEmailClaimSnapshot = await previousEmailClaimRef.get();
        if (previousEmailClaimSnapshot.value?.toString().trim() == user.uid) {
          await previousEmailClaimRef.remove();
        }
      }
    } on FirebaseException catch (error) {
      debugPrint(
        'DB saveUser:firebaseException ${error.code} ${error.message}',
      );
      final claimSnapshot = await claimRef.get();
      if (claimSnapshot.value?.toString().trim() == user.uid) {
        await claimRef.remove();
      }
      final emailClaimSnapshot = await emailClaimRef.get();
      if (emailClaimSnapshot.value?.toString().trim() == user.uid) {
        await emailClaimRef.remove();
      }

      throw Exception(error.message ?? 'Errore durante il salvataggio utente');
    }
  }

  Future<List<Map<String, String>>> getUserGroups() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _dbRef
          .child('users')
          .child(user.uid)
          .child('gruppi')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final groupsList = <Map<String, String>>[];
        List<String> groupsIds = [];

        if (snapshot.value is Map) {
          groupsIds = (snapshot.value as Map).keys
              .map((e) => e.toString())
              .toList();
        } else if (snapshot.value is List) {
          // Fallback in case it was stored as list somehow
          groupsIds = (snapshot.value as List)
              .where((e) => e != null)
              .map((e) => e.toString())
              .toList();
        }

        for (var groupId in groupsIds) {
          final groupSnapshot = await _dbRef
              .child('groups_info')
              .child(groupId)
              .get();
          if (groupSnapshot.exists && groupSnapshot.value is Map) {
            final groupData = _asStringKeyedMap(groupSnapshot.value);
            groupsList.add({
              'id': groupId,
              'name': groupData['name']?.toString() ?? 'Gruppo sconosciuto',
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

  Stream<DatabaseEvent> getApprovedBookingsStream() {
    return _dbRef
        .child('bookings')
        .orderByChild('stato')
        .equalTo(BookingStatus.confermata.name)
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

  Stream<DatabaseEvent> getUserNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error('Utente non loggato');
    }

    return _dbRef.child('user_notifications').child(user.uid).onValue;
  }

  Future<void> markUserNotificationRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    await _dbRef
        .child('user_notifications')
        .child(user.uid)
        .child(notificationId)
        .child('read')
        .set(true);
  }

  Future<void> markAllUserNotificationsRead() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef
        .child('user_notifications')
        .child(user.uid)
        .get();
    if (!snapshot.exists || snapshot.value == null || snapshot.value is! Map) {
      return;
    }

    final updates = <String, dynamic>{};
    final notifications = Map<String, dynamic>.from(snapshot.value as Map);
    for (final notificationId in notifications.keys) {
      updates['/user_notifications/${user.uid}/$notificationId/read'] = true;
    }
    if (updates.isNotEmpty) {
      await _dbRef.update(updates);
    }
  }

  Future<void> deleteUserNotification(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    await _dbRef
        .child('user_notifications')
        .child(user.uid)
        .child(notificationId)
        .remove();
  }

  Future<void> deleteSelectedUserNotifications(
    List<String> notificationIds,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }
    if (notificationIds.isEmpty) {
      return;
    }

    final updates = <String, dynamic>{};
    for (final notificationId in notificationIds) {
      final trimmed = notificationId.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      updates['/user_notifications/${user.uid}/$trimmed'] = null;
    }

    if (updates.isNotEmpty) {
      await _dbRef.update(updates);
    }
  }

  Future<void> acceptBookingUpdateProposal(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef
        .child('user_notifications')
        .child(user.uid)
        .child(notificationId)
        .get();
    if (!snapshot.exists || snapshot.value == null || snapshot.value is! Map) {
      throw Exception('Proposta non trovata');
    }

    final proposal = Map<String, dynamic>.from(snapshot.value as Map);
    if (proposal['type']?.toString() != 'booking_update_proposal' ||
        proposal['proposal_status']?.toString() != 'pending') {
      throw Exception('Proposta non valida');
    }

    final proposerAdminId = proposal['creator_id']?.toString() ?? '';
    final bookingId = proposal['booking_id']?.toString() ?? '';
    final date = proposal['data']?.toString() ?? '';
    final start = proposal['ora_inizio']?.toString() ?? '';
    final end = proposal['ora_fine']?.toString() ?? '';

    await _applyBookingUpdate(
      bookingId: bookingId,
      date: date,
      selectedSlotTimes: _asStringList(proposal['selected_slot_times']),
      groupId: proposal['group_id']?.toString(),
      peopleCount: _parseInt(proposal['numero_utenti']),
      equipment: proposal['attrezzatura']?.toString() ?? '',
      actingUserId: user.uid,
      allowAdmin: false,
      notifyAdmins: false,
      overrideStatus: proposal['target_status']?.toString(),
    );

    await _dbRef.update({
      '/user_notifications/${user.uid}/$notificationId/proposal_status':
          'accepted',
      '/user_notifications/${user.uid}/$notificationId/read': true,
      '/user_notifications/${user.uid}/$notificationId/responded_at':
          ServerValue.timestamp,
    });

    if (proposerAdminId.isNotEmpty && proposerAdminId != user.uid) {
      final responseNotificationId = _dbRef
          .child('user_notifications')
          .child(proposerAdminId)
          .push()
          .key;
      if (responseNotificationId != null) {
        await _dbRef.update({
          '/user_notifications/$proposerAdminId/$responseNotificationId': {
            'type': 'admin_booking_update_accepted',
            'booking_id': bookingId,
            'creator_id': user.uid,
            'username': _currentUsernameFromMap(await _loadUserData(user.uid), user.uid),
            'data': date,
            'ora_inizio': start,
            if (end.isNotEmpty) 'ora_fine': end,
            'timestamp': ServerValue.timestamp,
            'read': false,
          },
        });
      }
    }
  }

  Future<void> rejectBookingUpdateProposal(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef
        .child('user_notifications')
        .child(user.uid)
        .child(notificationId)
        .get();
    if (!snapshot.exists || snapshot.value == null || snapshot.value is! Map) {
      throw Exception('Proposta non trovata');
    }
    final proposal = Map<String, dynamic>.from(snapshot.value as Map);
    final proposerAdminId = proposal['creator_id']?.toString() ?? '';
    final bookingId = proposal['booking_id']?.toString() ?? '';
    final date = proposal['data']?.toString() ?? '';
    final start = proposal['ora_inizio']?.toString() ?? '';
    final end = proposal['ora_fine']?.toString() ?? '';

    await _dbRef.update({
      '/user_notifications/${user.uid}/$notificationId/proposal_status':
          'rejected',
      '/user_notifications/${user.uid}/$notificationId/read': true,
      '/user_notifications/${user.uid}/$notificationId/responded_at':
          ServerValue.timestamp,
    });

    if (proposerAdminId.isNotEmpty && proposerAdminId != user.uid) {
      final responseNotificationId = _dbRef
          .child('user_notifications')
          .child(proposerAdminId)
          .push()
          .key;
      if (responseNotificationId != null) {
        await _dbRef.update({
          '/user_notifications/$proposerAdminId/$responseNotificationId': {
            'type': 'admin_booking_update_rejected',
            'booking_id': bookingId,
            'creator_id': user.uid,
            'username': _currentUsernameFromMap(await _loadUserData(user.uid), user.uid),
            'data': date,
            'ora_inizio': start,
            if (end.isNotEmpty) 'ora_fine': end,
            'timestamp': ServerValue.timestamp,
            'read': false,
          },
        });
      }
    }
  }

  Future<void> acceptJamUpdateProposal(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef
        .child('user_notifications')
        .child(user.uid)
        .child(notificationId)
        .get();
    if (!snapshot.exists || snapshot.value == null || snapshot.value is! Map) {
      throw Exception('Proposta non trovata');
    }

    final proposal = Map<String, dynamic>.from(snapshot.value as Map);
    if (proposal['type']?.toString() != 'jam_update_proposal' ||
        proposal['proposal_status']?.toString() != 'pending') {
      throw Exception('Proposta non valida');
    }

    final proposerAdminId = proposal['creator_id']?.toString() ?? '';
    final jamId = proposal['jam_id']?.toString() ?? '';
    final date = proposal['data']?.toString() ?? '';
    final start = proposal['ora_inizio']?.toString() ?? '';
    final end = proposal['ora_fine']?.toString() ?? '';

    await _applyJamUpdate(
      jamId: jamId,
      date: date,
      selectedSlotTimes: _asStringList(proposal['selected_slot_times']),
      groupId: proposal['group_id']?.toString(),
      title: proposal['titolo']?.toString() ?? '',
      presentPeople: _parseInt(proposal['persone_presenti']),
      requiredPeople: _parseInt(proposal['persone_richieste']),
      description: proposal['descrizione']?.toString() ?? '',
      payment: proposal['pagamento']?.toString() ?? '',
      equipment: proposal['attrezzatura']?.toString() ?? '',
      actingUserId: user.uid,
      allowAdmin: false,
      notifyAdmins: false,
      overrideStatus: proposal['target_status']?.toString(),
    );

    await _dbRef.update({
      '/user_notifications/${user.uid}/$notificationId/proposal_status':
          'accepted',
      '/user_notifications/${user.uid}/$notificationId/read': true,
      '/user_notifications/${user.uid}/$notificationId/responded_at':
          ServerValue.timestamp,
    });

    if (proposerAdminId.isNotEmpty && proposerAdminId != user.uid) {
      final responseNotificationId = _dbRef
          .child('user_notifications')
          .child(proposerAdminId)
          .push()
          .key;
      if (responseNotificationId != null) {
        await _dbRef.update({
          '/user_notifications/$proposerAdminId/$responseNotificationId': {
            'type': 'admin_jam_update_accepted',
            'jam_id': jamId,
            'creator_id': user.uid,
            'username': _currentUsernameFromMap(await _loadUserData(user.uid), user.uid),
            'data': date,
            'ora_inizio': start,
            if (end.isNotEmpty) 'ora_fine': end,
            'timestamp': ServerValue.timestamp,
            'read': false,
          },
        });
      }
    }
  }

  Future<void> rejectJamUpdateProposal(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef
        .child('user_notifications')
        .child(user.uid)
        .child(notificationId)
        .get();
    if (!snapshot.exists || snapshot.value == null || snapshot.value is! Map) {
      throw Exception('Proposta non trovata');
    }
    final proposal = Map<String, dynamic>.from(snapshot.value as Map);
    final proposerAdminId = proposal['creator_id']?.toString() ?? '';
    final jamId = proposal['jam_id']?.toString() ?? '';
    final date = proposal['data']?.toString() ?? '';
    final start = proposal['ora_inizio']?.toString() ?? '';
    final end = proposal['ora_fine']?.toString() ?? '';

    await _dbRef.update({
      '/user_notifications/${user.uid}/$notificationId/proposal_status':
          'rejected',
      '/user_notifications/${user.uid}/$notificationId/read': true,
      '/user_notifications/${user.uid}/$notificationId/responded_at':
          ServerValue.timestamp,
    });

    if (proposerAdminId.isNotEmpty && proposerAdminId != user.uid) {
      final responseNotificationId = _dbRef
          .child('user_notifications')
          .child(proposerAdminId)
          .push()
          .key;
      if (responseNotificationId != null) {
        await _dbRef.update({
          '/user_notifications/$proposerAdminId/$responseNotificationId': {
            'type': 'admin_jam_update_rejected',
            'jam_id': jamId,
            'creator_id': user.uid,
            'username': _currentUsernameFromMap(await _loadUserData(user.uid), user.uid),
            'data': date,
            'ora_inizio': start,
            if (end.isNotEmpty) 'ora_fine': end,
            'timestamp': ServerValue.timestamp,
            'read': false,
          },
        });
      }
    }
  }

  Future<void> deleteAllUserNotifications() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    await _dbRef.child('user_notifications').child(user.uid).remove();
  }

  Future<void> acceptGroupInvite(String groupId) async {
    try {
      await _functions.httpsCallable('acceptGroupInvite').call({
        'groupId': groupId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'Accettazione invito fallita');
    }
  }

  Future<void> rejectGroupInvite(String groupId) async {
    try {
      await _functions.httpsCallable('rejectGroupInvite').call({
        'groupId': groupId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'Rifiuto invito fallito');
    }
  }

  Future<void> cleanupPastSlots() async {
    if (!await _isCurrentUserAdmin()) {
      return;
    }

    try {
      await _functions.httpsCallable('cleanupPastSlots').call();
    } on FirebaseFunctionsException catch (error) {
      debugPrint('cleanupPastSlots fallita: ${error.message}');
    }
  }

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef
        .child('users')
        .child(user.uid)
        .child('preferenze')
        .child('notifications')
        .get();
    if (!snapshot.exists || snapshot.value == null || snapshot.value is! Map) {
      return const <String, dynamic>{};
    }

    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  Future<void> saveNotificationPreferences(
    Map<String, dynamic> preferences,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    await _dbRef
        .child('users')
        .child(user.uid)
        .child('preferenze')
        .child('notifications')
        .update(preferences);
  }

  Future<void> saveDeviceToken(
    String token, {
    String platform = 'unknown',
  }) async {
    final user = _auth.currentUser;
    if (user == null || token.isEmpty) {
      return;
    }

    await _dbRef
        .child('user_devices')
        .child(user.uid)
        .child(_tokenKey(token))
        .set({
          'token': token,
          'platform': platform,
          'updated_at': ServerValue.timestamp,
        });
  }

  Future<void> removeDeviceToken(String uid, String token) async {
    if (uid.isEmpty || token.isEmpty) {
      return;
    }

    await _dbRef
        .child('user_devices')
        .child(uid)
        .child(_tokenKey(token))
        .remove();
  }

  Stream<DatabaseEvent> getCurrentUserSupportChatsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    return _dbRef
        .child('support_chats')
        .orderByChild('user_id')
        .equalTo(user.uid)
        .onValue;
  }

  Stream<DatabaseEvent> getGuestSupportChatStream(String sessionId) {
    final trimmedSessionId = sessionId.trim();
    if (trimmedSessionId.isEmpty) {
      throw Exception('Sessione guest non valida');
    }

    return _dbRef.child('support_chats').child(trimmedSessionId).onValue;
  }

  Stream<DatabaseEvent> getOpenSupportChatsStream() {
    return _dbRef
        .child('support_chats')
        .orderByChild('status')
        .equalTo(SupportChatStatus.open.name)
        .onValue;
  }

  Stream<DatabaseEvent> getSupportChatMessagesStream(String chatId) {
    final trimmedChatId = chatId.trim();
    if (trimmedChatId.isEmpty) {
      throw Exception('Chat non valida');
    }

    return _dbRef.child('support_chat_messages').child(trimmedChatId).onValue;
  }

  Future<void> registerGuestSupportChatDisconnectCleanup(String sessionId) async {
    final trimmedSessionId = sessionId.trim();
    if (trimmedSessionId.isEmpty) {
      return;
    }

    try {
      await _dbRef
          .child('support_chats')
          .child(trimmedSessionId)
          .onDisconnect()
          .remove();
      await _dbRef
          .child('support_chat_messages')
          .child(trimmedSessionId)
          .onDisconnect()
          .remove();
    } catch (_) {
      // Best effort only: explicit cleanup is still performed when the public page disposes.
    }
  }

  Future<String> createSupportChat({
    required String subject,
    required String message,
    String origin = 'app',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw Exception('Inserisci un messaggio');
    }

    final trimmedSubject = subject.trim().isNotEmpty
        ? subject.trim()
        : 'Richiesta assistenza';
    final identity = await _loadCurrentUserIdentity();

    final chatRef = _dbRef.child('support_chats').push();
    final chatId = chatRef.key;
    if (chatId == null || chatId.isEmpty) {
      throw Exception('Impossibile creare la chat');
    }

    final messageRef = _dbRef
        .child('support_chat_messages')
        .child(chatId)
        .push();
    final messageId = messageRef.key;
    if (messageId == null || messageId.isEmpty) {
      throw Exception('Impossibile creare il primo messaggio');
    }

    final timestamp = ServerValue.timestamp;
    await _dbRef.child('support_chats').child(chatId).set({
      'user_id': user.uid,
      'user_nickname': identity['nickname'],
      'user_email': identity['email'],
      'subject': trimmedSubject,
      'status': SupportChatStatus.open.name,
      'origin': origin,
      'created_at': timestamp,
      'updated_at': timestamp,
      'last_message_at': timestamp,
      'last_message_text': _supportChatPreview(trimmedMessage),
      'last_sender_role': 'user',
      'last_sender_id': user.uid,
      'unread_for_admin': true,
      'unread_for_user': false,
    });

    try {
      await _dbRef
          .child('support_chat_messages')
          .child(chatId)
          .child(messageId)
          .set({
            'sender_id': user.uid,
            'sender_role': 'user',
            'sender_display_name': identity['nickname'],
            'text': trimmedMessage,
            'timestamp': timestamp,
          });
    } catch (_) {
      await _dbRef.child('support_chats').child(chatId).remove();
      rethrow;
    }

    return chatId;
  }

  Future<String> createGuestSupportChat({
    required String sessionId,
    String? guestDisplayName,
    required String subject,
    required String message,
    String origin = 'public_web',
  }) async {
    final trimmedSessionId = sessionId.trim();
    final trimmedMessage = message.trim();
    if (trimmedSessionId.isEmpty) {
      throw Exception('Sessione guest non valida');
    }
    if (trimmedMessage.isEmpty) {
      throw Exception('Inserisci un messaggio');
    }

    final trimmedSubject = subject.trim().isNotEmpty
        ? subject.trim()
        : 'Richiesta assistenza pubblica';
    final trimmedGuestName = guestDisplayName?.trim().isNotEmpty == true
        ? guestDisplayName!.trim()
        : 'Visitatore';
    final messageRef = _dbRef
        .child('support_chat_messages')
        .child(trimmedSessionId)
        .push();
    final messageId = messageRef.key;
    if (messageId == null || messageId.isEmpty) {
      throw Exception('Impossibile creare il primo messaggio');
    }

    final timestamp = ServerValue.timestamp;
    await _dbRef.child('support_chats').child(trimmedSessionId).set({
      'user_id': 'guest:$trimmedSessionId',
      'user_nickname': trimmedGuestName,
      'subject': trimmedSubject,
      'status': SupportChatStatus.open.name,
      'origin': origin,
      'public_session_id': trimmedSessionId,
      'created_at': timestamp,
      'updated_at': timestamp,
      'last_message_at': timestamp,
      'last_message_text': _supportChatPreview(trimmedMessage),
      'last_sender_role': 'user',
      'last_sender_id': trimmedSessionId,
      'unread_for_admin': true,
      'unread_for_user': false,
    });

    try {
      await _dbRef
          .child('support_chat_messages')
          .child(trimmedSessionId)
          .child(messageId)
          .set({
            'sender_id': trimmedSessionId,
            'sender_role': 'user',
            'sender_display_name': trimmedGuestName,
            'text': trimmedMessage,
            'timestamp': timestamp,
          });
    } catch (_) {
      await _dbRef.child('support_chats').child(trimmedSessionId).remove();
      rethrow;
    }

    await registerGuestSupportChatDisconnectCleanup(trimmedSessionId);
    return trimmedSessionId;
  }

  Future<void> sendSupportChatMessage({
    required String chatId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final trimmedChatId = chatId.trim();
    final trimmedText = text.trim();
    if (trimmedChatId.isEmpty) {
      throw Exception('Chat non valida');
    }
    if (trimmedText.isEmpty) {
      throw Exception('Inserisci un messaggio');
    }

    final chatSnapshot = await _dbRef.child('support_chats').child(trimmedChatId).get();
    if (!chatSnapshot.exists || chatSnapshot.value is! Map) {
      throw Exception('Chat non trovata');
    }

    final chatData = Map<String, dynamic>.from(chatSnapshot.value as Map);
    final chatOwnerId = chatData['user_id']?.toString() ?? '';
    final chatStatus = chatData['status']?.toString() ?? SupportChatStatus.open.name;
    final isAdmin = await _isCurrentUserAdmin();

    if (!isAdmin && chatOwnerId != user.uid) {
      throw Exception('Permessi insufficienti');
    }
    if (chatStatus != SupportChatStatus.open.name) {
      throw Exception('La chat e chiusa');
    }
    if (isAdmin && chatData['assigned_admin_id']?.toString() != user.uid) {
      throw Exception('Assegna la chat a te stesso prima di rispondere');
    }

    final identity = await _loadCurrentUserIdentity();
    final messageRef = _dbRef
        .child('support_chat_messages')
        .child(trimmedChatId)
        .push();
    final messageId = messageRef.key;
    if (messageId == null || messageId.isEmpty) {
      throw Exception('Impossibile inviare il messaggio');
    }

    final senderRole = isAdmin ? 'admin' : 'user';
    final timestamp = ServerValue.timestamp;
    final updates = <String, dynamic>{
      '/support_chat_messages/$trimmedChatId/$messageId': {
        'sender_id': user.uid,
        'sender_role': senderRole,
        'sender_display_name': identity['nickname'],
        'text': trimmedText,
        'timestamp': timestamp,
      },
      '/support_chats/$trimmedChatId/updated_at': timestamp,
      '/support_chats/$trimmedChatId/last_message_at': timestamp,
      '/support_chats/$trimmedChatId/last_message_text': _supportChatPreview(
        trimmedText,
      ),
      '/support_chats/$trimmedChatId/last_sender_role': senderRole,
      '/support_chats/$trimmedChatId/last_sender_id': user.uid,
      '/support_chats/$trimmedChatId/unread_for_admin': !isAdmin,
      '/support_chats/$trimmedChatId/unread_for_user': isAdmin,
    };

    await _dbRef.update(updates);
  }

  Future<void> sendGuestSupportChatMessage({
    required String sessionId,
    required String text,
  }) async {
    final trimmedSessionId = sessionId.trim();
    final trimmedText = text.trim();
    if (trimmedSessionId.isEmpty) {
      throw Exception('Sessione guest non valida');
    }
    if (trimmedText.isEmpty) {
      throw Exception('Inserisci un messaggio');
    }

    final chatSnapshot = await _dbRef.child('support_chats').child(trimmedSessionId).get();
    if (!chatSnapshot.exists || chatSnapshot.value is! Map) {
      throw Exception('Chat non trovata');
    }

    final chatData = Map<String, dynamic>.from(chatSnapshot.value as Map);
    if (chatData['public_session_id']?.toString() != trimmedSessionId) {
      throw Exception('Sessione guest non valida');
    }
    if (chatData['status']?.toString() != SupportChatStatus.open.name) {
      throw Exception('La chat e chiusa');
    }

    final messageRef = _dbRef
        .child('support_chat_messages')
        .child(trimmedSessionId)
        .push();
    final messageId = messageRef.key;
    if (messageId == null || messageId.isEmpty) {
      throw Exception('Impossibile inviare il messaggio');
    }

    final timestamp = ServerValue.timestamp;
    await _dbRef.update({
      '/support_chat_messages/$trimmedSessionId/$messageId': {
        'sender_id': trimmedSessionId,
        'sender_role': 'user',
        'sender_display_name': chatData['user_nickname']?.toString() ?? 'Visitatore',
        'text': trimmedText,
        'timestamp': timestamp,
      },
      '/support_chats/$trimmedSessionId/updated_at': timestamp,
      '/support_chats/$trimmedSessionId/last_message_at': timestamp,
      '/support_chats/$trimmedSessionId/last_message_text': _supportChatPreview(
        trimmedText,
      ),
      '/support_chats/$trimmedSessionId/last_sender_role': 'user',
      '/support_chats/$trimmedSessionId/last_sender_id': trimmedSessionId,
      '/support_chats/$trimmedSessionId/unread_for_admin': true,
      '/support_chats/$trimmedSessionId/unread_for_user': false,
    });
  }

  Future<void> assignSupportChatToCurrentAdmin(String chatId) async {
    await _ensureCurrentUserIsAdminOrThrow();
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final trimmedChatId = chatId.trim();
    if (trimmedChatId.isEmpty) {
      throw Exception('Chat non valida');
    }

    final chatSnapshot = await _dbRef.child('support_chats').child(trimmedChatId).get();
    if (!chatSnapshot.exists || chatSnapshot.value is! Map) {
      throw Exception('Chat non trovata');
    }

    final chatData = Map<String, dynamic>.from(chatSnapshot.value as Map);
    if (chatData['status']?.toString() != SupportChatStatus.open.name) {
      throw Exception('La chat e chiusa');
    }

    final identity = await _loadCurrentUserIdentity();
    await _dbRef.child('support_chats').child(trimmedChatId).update({
      'assigned_admin_id': user.uid,
      'assigned_admin_nickname': identity['nickname'],
      'updated_at': ServerValue.timestamp,
      'unread_for_admin': false,
    });
  }

  Future<void> releaseSupportChat(String chatId) async {
    await _ensureCurrentUserIsAdminOrThrow();

    final trimmedChatId = chatId.trim();
    if (trimmedChatId.isEmpty) {
      throw Exception('Chat non valida');
    }

    await _dbRef.child('support_chats').child(trimmedChatId).update({
      'assigned_admin_id': null,
      'assigned_admin_nickname': null,
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<void> closeSupportChat(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final trimmedChatId = chatId.trim();
    if (trimmedChatId.isEmpty) {
      throw Exception('Chat non valida');
    }

    final chatSnapshot = await _dbRef.child('support_chats').child(trimmedChatId).get();
    if (!chatSnapshot.exists || chatSnapshot.value is! Map) {
      throw Exception('Chat non trovata');
    }

    final chatData = Map<String, dynamic>.from(chatSnapshot.value as Map);
    final isAdmin = await _isCurrentUserAdmin();
    final chatOwnerId = chatData['user_id']?.toString() ?? '';
    if (!isAdmin && chatOwnerId != user.uid) {
      throw Exception('Permessi insufficienti');
    }

    await _dbRef.child('support_chats').child(trimmedChatId).update({
      'status': SupportChatStatus.closed.name,
      'updated_at': ServerValue.timestamp,
      'unread_for_admin': false,
      'unread_for_user': false,
    });
  }

  Future<void> markSupportChatSeen(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final trimmedChatId = chatId.trim();
    if (trimmedChatId.isEmpty) {
      return;
    }

    final isAdmin = await _isCurrentUserAdmin();
    await _dbRef.child('support_chats').child(trimmedChatId).update({
      isAdmin ? 'unread_for_admin' : 'unread_for_user': false,
    });
  }

  Future<void> markGuestSupportChatSeen(String sessionId) async {
    final trimmedSessionId = sessionId.trim();
    if (trimmedSessionId.isEmpty) {
      return;
    }

    await _dbRef.child('support_chats').child(trimmedSessionId).update({
      'unread_for_user': false,
    });
  }

  Future<void> deleteGuestSupportChat(String sessionId) async {
    final trimmedSessionId = sessionId.trim();
    if (trimmedSessionId.isEmpty) {
      return;
    }

    await _dbRef.update({
      '/support_chats/$trimmedSessionId': null,
      '/support_chat_messages/$trimmedSessionId': null,
    });
  }

  Future<Map<String, String?>> _loadCurrentUserIdentity() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const <String, String?>{'nickname': null, 'email': null};
    }

    final snapshot = await _dbRef.child('users').child(user.uid).get();
    if (snapshot.exists && snapshot.value is Map) {
      final userData = Map<String, dynamic>.from(snapshot.value as Map);
      final nickname = userData['username']?.toString().trim();
      final email = userData['email']?.toString().trim();
      return <String, String?>{
        'nickname': nickname?.isNotEmpty == true ? nickname : user.uid,
        'email': email?.isNotEmpty == true ? email : user.email,
      };
    }

    final fallbackName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.uid;
    return <String, String?>{'nickname': fallbackName, 'email': user.email};
  }

  String _supportChatPreview(String text) {
    final trimmedText = text.trim();
    if (trimmedText.length <= 140) {
      return trimmedText;
    }
    return '${trimmedText.substring(0, 137)}...';
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

  Future<List<Map<String, dynamic>>> getAdminSlotsForDate(
    String dateStr,
  ) async {
    final slotsRef = _dbRef.child('slots').child(dateStr);

    try {
      var snapshot = await slotsRef.get();
      if (!snapshot.exists) {
        await _generateSlotsForDate(dateStr);
        snapshot = await slotsRef.get();
      }

      final slots = <Map<String, dynamic>>[];
      final rawData = snapshot.value;

      if (rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        for (final entry in data.entries) {
          if (entry.value is! Map) {
            continue;
          }
          final slot = Map<String, dynamic>.from(entry.value as Map);
          slot['key'] = entry.key.toString();
          slots.add(slot);
        }
      } else if (rawData is List) {
        for (final item in rawData) {
          if (item is! Map) {
            continue;
          }
          slots.add(Map<String, dynamic>.from(item));
        }
      }

      slots.sort((a, b) {
        final left = a['time']?.toString() ?? '';
        final right = b['time']?.toString() ?? '';
        return left.compareTo(right);
      });

      return slots;
    } catch (e) {
      debugPrint("Errore getAdminSlotsForDate: $e");
      rethrow;
    }
  }

  Future<void> updateAdminSlotStatuses({
    required String dateStr,
    required List<String> slotTimes,
    required bool disabled,
  }) async {
    await _ensureCurrentUserIsAdminOrThrow();
    if (slotTimes.isEmpty) {
      return;
    }

    await getAdminSlotsForDate(dateStr);

    final snapshot = await _dbRef.child('slots').child(dateStr).get();
    if (!snapshot.exists || snapshot.value == null || snapshot.value is! Map) {
      throw Exception('Slot non trovati per la data selezionata');
    }

    final slotsMap = Map<String, dynamic>.from(snapshot.value as Map);
    final updates = <String, dynamic>{};

    for (final slotTime in slotTimes) {
      final slotKey = slotTime.replaceAll(':', '_');
      final rawSlot = slotsMap[slotKey];
      if (rawSlot is! Map) {
        continue;
      }

      final slotData = Map<String, dynamic>.from(rawSlot);
      final currentStatus = slotData['status']?.toString() ?? 'libero';
      final bookingId = slotData['booking_id']?.toString() ?? '';
      final isJam = slotData['is_jam'] == true;
      final isOccupied =
          currentStatus != 'libero' &&
          currentStatus != 'disabilitato' &&
          bookingId.isNotEmpty;
      if (isOccupied || isJam) {
        throw Exception(
          'Lo slot $slotTime non puo essere modificato perche e gia occupato',
        );
      }

      updates['/slots/$dateStr/$slotKey/status'] = disabled
          ? 'disabilitato'
          : 'libero';
      updates['/slots/$dateStr/$slotKey/booked_by'] = null;
      updates['/slots/$dateStr/$slotKey/booking_id'] = null;
      updates['/slots/$dateStr/$slotKey/is_jam'] = null;
    }

    if (updates.isEmpty) {
      return;
    }

    await _dbRef.update(updates);
  }

  Future<void> _generateSlotsForDate(String dateStr) async {
    final times = _generateStandardTimes();
    final updates = <String, dynamic>{};

    for (int i = 0; i < times.length; i++) {
      final time = times[i];
      final key = time.replaceAll(":", "_");

      updates['/slots/$dateStr/$key'] = {'time': time, 'status': 'libero'};
    }

    await _dbRef.update(updates);
  }

  List<String> _generateStandardTimes() {
    final slots = <String>[];
    var time = DateTime(2022, 1, 1, 10, 0);
    final endTime = DateTime(2022, 1, 2);
    while (time.isBefore(endTime)) {
      slots.add(DateFormat('HH:mm').format(time));
      time = time.add(const Duration(minutes: 30));
    }
    return slots;
  }

  // --- CREAZIONE PRENOTAZIONE CON UPDATE SLOT ---

  Future<void> createBooking(
    Booking booking,
    List<String> selectedSlotTimes,
  ) async {
    debugPrint("Inizio creazione prenotazione...");

    final newBookingKey = _dbRef.child('bookings').push().key;
    if (newBookingKey == null) {
      throw Exception("Impossibile generare ID prenotazione");
    }

    final adminIds = await _getAdminUserIds();
    final groupName = booking.groupName?.trim().isNotEmpty == true
        ? booking.groupName!.trim()
        : await _resolveGroupName(booking.groupId);
    final bookingMap = {
      ...booking.toMap(),
      'group_name': groupName.isEmpty ? null : groupName,
    };

    final Map<String, dynamic> updates = {};
    final bookingPath = '/bookings/$newBookingKey';
    final userBookingPath = '/user_bookings/${booking.userId}/$newBookingKey';

    updates[bookingPath] = bookingMap;
    updates[userBookingPath] = bookingMap;
    if (booking.groupId != null && booking.groupId!.isNotEmpty) {
      updates['/group_bookings/${booking.groupId}/$newBookingKey'] = bookingMap;
    }

    await _addAdminNotifications(
      updates,
      adminIds,
      'admin_booking_created',
      booking.data,
      booking.oraInizio,
      end: booking.oraFine,
      subjectId: newBookingKey,
      requesterId: booking.userId,
    );

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
        await _notifyGroupBookingMembers(
          groupId: booking.groupId!,
          bookingId: newBookingKey,
          type: 'booking_created',
          actorUserId: booking.userId,
          date: booking.data,
          start: booking.oraInizio,
          end: booking.oraFine,
          groupName: groupName,
          excludeUserIds: {booking.userId},
          saveGroupNotificationRecord: true,
        );
      }
      debugPrint("Prenotazione completata con successo.");
    } catch (e) {
      debugPrint("Errore durante createBooking: $e");
      rethrow;
    }
  }

  // --- ELIMINAZIONE PRENOTAZIONE ---

  Future<void> deleteBooking(String bookingId) async {
    try {
      final snapshot = await _dbRef.child('bookings').child(bookingId).get();
      if (snapshot.exists && snapshot.value != null) {
        final bookingData = Map<String, dynamic>.from(snapshot.value as Map);
        final date = bookingData['data']?.toString() ?? '';
        final start = bookingData['ora_inizio']?.toString() ?? '';
        final ownerId = bookingData['user_id']?.toString() ?? '';

        final adminIds = await _getAdminUserIds();
        final updates = <String, dynamic>{};
        await _addAdminNotifications(
          updates,
          adminIds,
          'admin_booking_cancelled',
          date,
          start,
          subjectId: bookingId,
          requesterId: ownerId,
        );
        if (updates.isNotEmpty) {
          await _dbRef.update(updates);
        }
      }

      await _functions.httpsCallable('deleteBookingCascade').call({
        'bookingId': bookingId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'Eliminazione prenotazione fallita');
    }
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

    await _applyBookingUpdate(
      bookingId: bookingId,
      date: date,
      selectedSlotTimes: selectedSlotTimes,
      groupId: groupId,
      peopleCount: peopleCount,
      equipment: equipment,
      actingUserId: user.uid,
      allowAdmin: true,
      notifyAdmins: true,
    );
  }

  Future<void> proposeBookingUpdate({
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
    await _ensureCurrentUserIsAdminOrThrow();

    final bookingSnapshot = await _dbRef.child('bookings').child(bookingId).get();
    if (!bookingSnapshot.exists || bookingSnapshot.value == null) {
      throw Exception('Prenotazione non trovata');
    }

    final bookingData = Map<String, dynamic>.from(bookingSnapshot.value as Map);
    final bookingOwnerId = bookingData['user_id']?.toString() ?? '';
    if (bookingOwnerId.isEmpty) {
      throw Exception('Proprietario prenotazione non trovato');
    }

    final orderedSlots = List<String>.from(selectedSlotTimes)..sort();
    if (orderedSlots.isEmpty) {
      throw Exception('Seleziona almeno un orario');
    }

    final proposerName = _currentUsernameFromMap(
      await _loadUserData(user.uid),
      user.uid,
    );
    final groupName = await _resolveGroupName(groupId);
    final notificationId = _dbRef
        .child('user_notifications')
        .child(bookingOwnerId)
        .push()
        .key;
    final senderNotificationId = _dbRef
        .child('user_notifications')
        .child(user.uid)
        .push()
        .key;
    if (notificationId == null || senderNotificationId == null) {
      throw Exception('Impossibile creare la proposta');
    }

    await _dbRef.update({
      '/user_notifications/$bookingOwnerId/$notificationId': {
        'type': 'booking_update_proposal',
        'booking_id': bookingId,
        'creator_id': user.uid,
        'username': proposerName,
        'data': date,
        'ora_inizio': orderedSlots.first,
        'ora_fine': _calculateEndTime(orderedSlots.last),
        'selected_slot_times': orderedSlots,
        'group_id': groupId,
        'group_name': groupName.isEmpty ? null : groupName,
        'numero_utenti': peopleCount,
        'attrezzatura': equipment.trim(),
        'target_status': bookingData['stato']?.toString(),
        'proposal_status': 'pending',
        'timestamp': ServerValue.timestamp,
        'read': false,
      },
      '/user_notifications/${user.uid}/$senderNotificationId': {
        'type': 'admin_booking_update_proposed',
        'booking_id': bookingId,
        'creator_id': user.uid,
        'username': proposerName,
        'data': date,
        'ora_inizio': orderedSlots.first,
        'ora_fine': _calculateEndTime(orderedSlots.last),
        'timestamp': ServerValue.timestamp,
        'read': false,
      },
    });
  }

  Future<void> _applyBookingUpdate({
    required String bookingId,
    required String date,
    required List<String> selectedSlotTimes,
    String? groupId,
    required int peopleCount,
    required String equipment,
    required String actingUserId,
    required bool allowAdmin,
    required bool notifyAdmins,
    String? overrideStatus,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final bookingSnapshot = await _dbRef
        .child('bookings')
        .child(bookingId)
        .get();
    if (!bookingSnapshot.exists || bookingSnapshot.value == null) {
      throw Exception('Prenotazione non trovata');
    }

    final bookingData = Map<String, dynamic>.from(bookingSnapshot.value as Map);
    final bookingOwnerId = bookingData['user_id']?.toString() ?? '';
    final previousDate = bookingData['data']?.toString() ?? '';
    final previousGroupId = bookingData['group_id']?.toString();
    final isAdmin = await _isCurrentUserAdmin();
    if (bookingOwnerId != actingUserId && !(allowAdmin && isAdmin)) {
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

    final targetSlots = Map<String, dynamic>.from(
      targetSlotsSnapshot.value as Map,
    );
    for (final time in orderedSlots) {
      final slotKey = time.replaceAll(':', '_');
      final slotData = Map<String, dynamic>.from(
        (targetSlots[slotKey] as Map?) ?? const {},
      );
      final status = slotData['status']?.toString();
      final bookingIdOnSlot = slotData['booking_id']?.toString();
      if (status != 'libero' && bookingIdOnSlot != bookingId) {
        throw Exception('Uno degli slot selezionati non e piu disponibile');
      }
    }

    final trimmedEquipment = equipment.trim();
    final groupName = await _resolveGroupName(groupId);
    final newEndTime = _calculateEndTime(orderedSlots.last);
    final scheduleChanged =
        previousDate != date ||
        (bookingData['ora_inizio']?.toString() ?? '') != orderedSlots.first ||
        (bookingData['ora_fine']?.toString() ?? '') != newEndTime;
    final nextStatus =
      overrideStatus?.trim().isNotEmpty == true
        ? overrideStatus!.trim()
        : scheduleChanged
        ? BookingStatus.inElaborazione.name
        : bookingData['stato']?.toString() ?? BookingStatus.inElaborazione.name;
    final oldSlots = previousDate.isEmpty
        ? <String, dynamic>{}
        : await _findSlotsByBookingId(previousDate, bookingId);

    final updates = <String, dynamic>{
      '/bookings/$bookingId/data': date,
      '/bookings/$bookingId/ora_inizio': orderedSlots.first,
      '/bookings/$bookingId/ora_fine': newEndTime,
      '/bookings/$bookingId/group_id': groupId,
        '/bookings/$bookingId/group_name': groupName.isEmpty ? null : groupName,
      '/bookings/$bookingId/numero_utenti': peopleCount,
      '/bookings/$bookingId/attrezzatura': trimmedEquipment,
      '/bookings/$bookingId/stato': nextStatus,
      '/user_bookings/$bookingOwnerId/$bookingId/data': date,
      '/user_bookings/$bookingOwnerId/$bookingId/ora_inizio':
          orderedSlots.first,
      '/user_bookings/$bookingOwnerId/$bookingId/ora_fine': newEndTime,
      '/user_bookings/$bookingOwnerId/$bookingId/group_id': groupId,
        '/user_bookings/$bookingOwnerId/$bookingId/group_name':
          groupName.isEmpty ? null : groupName,
      '/user_bookings/$bookingOwnerId/$bookingId/numero_utenti': peopleCount,
      '/user_bookings/$bookingOwnerId/$bookingId/attrezzatura':
          trimmedEquipment,
      '/user_bookings/$bookingOwnerId/$bookingId/stato': nextStatus,
    };

    if (notifyAdmins) {
      final adminIds = await _getAdminUserIds();
      await _addAdminNotifications(
        updates,
        adminIds,
        'admin_booking_modified',
        date,
        orderedSlots.first,
        end: newEndTime,
        subjectId: bookingId,
        requesterId: bookingOwnerId,
      );
    }

    if (previousGroupId != null &&
        previousGroupId.isNotEmpty &&
        previousGroupId != groupId) {
      updates['/group_bookings/$previousGroupId/$bookingId'] = null;
    }

    if (groupId != null && groupId.isNotEmpty) {
      updates['/group_bookings/$groupId/$bookingId/data'] = date;
      updates['/group_bookings/$groupId/$bookingId/ora_inizio'] =
          orderedSlots.first;
      updates['/group_bookings/$groupId/$bookingId/ora_fine'] = newEndTime;
      updates['/group_bookings/$groupId/$bookingId/group_id'] = groupId;
        updates['/group_bookings/$groupId/$bookingId/group_name'] =
          groupName.isEmpty ? null : groupName;
      updates['/group_bookings/$groupId/$bookingId/numero_utenti'] =
          peopleCount;
      updates['/group_bookings/$groupId/$bookingId/attrezzatura'] =
          trimmedEquipment;
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

    if (groupId != null && groupId.isNotEmpty) {
      await _notifyGroupBookingMembers(
        groupId: groupId,
        bookingId: bookingId,
        type: 'group_booking_modified',
        actorUserId: actingUserId,
        date: date,
        start: orderedSlots.first,
        end: newEndTime,
        groupName: groupName,
        excludeUserIds: {actingUserId},
      );
    }
  }

  Future<void> _notifyGroupBookingMembers({
    required String groupId,
    required String bookingId,
    required String type,
    required String actorUserId,
    required String date,
    required String start,
    required String end,
    String? groupName,
    Iterable<String> excludeUserIds = const [],
    bool saveGroupNotificationRecord = false,
  }) async {
    final actorUsername = _currentUsernameFromMap(
      await _loadUserData(actorUserId),
      actorUserId,
    );

    final payload = <String, dynamic>{
      'type': type,
      'booking_id': bookingId,
      'group_id': groupId,
      if (groupName?.trim().isNotEmpty == true) 'group_name': groupName!.trim(),
      'creator_id': actorUserId,
      'username': actorUsername,
      'data': date,
      'ora_inizio': start,
      'ora_fine': end,
      'timestamp': ServerValue.timestamp,
      'read': false,
    };

    await _fanOutGroupNotification(
      groupId: groupId,
      payload: payload,
      excludeUserIds: excludeUserIds,
      groupNotificationPath: saveGroupNotificationRecord
          ? '/group_booking_notifications/$groupId/$bookingId'
          : null,
    );
  }

  Future<void> _notifyGroupJamMembers({
    required String groupId,
    required String jamId,
    required String type,
    required String actorUserId,
    required String date,
    required String start,
    required String end,
    required String title,
    String? groupName,
    Iterable<String> excludeUserIds = const [],
  }) async {
    final actorUsername = _currentUsernameFromMap(
      await _loadUserData(actorUserId),
      actorUserId,
    );

    final payload = <String, dynamic>{
      'type': type,
      'jam_id': jamId,
      'group_id': groupId,
      if (groupName?.trim().isNotEmpty == true) 'group_name': groupName!.trim(),
      'creator_id': actorUserId,
      'username': actorUsername,
      'titolo': title,
      'data': date,
      'ora_inizio': start,
      'ora_fine': end,
      'timestamp': ServerValue.timestamp,
      'read': false,
    };

    await _fanOutGroupNotification(
      groupId: groupId,
      payload: payload,
      excludeUserIds: excludeUserIds,
    );
  }

  Future<void> _fanOutGroupNotification({
    required String groupId,
    required Map<String, dynamic> payload,
    Iterable<String> excludeUserIds = const [],
    String? groupNotificationPath,
  }) async {
    try {
      final groupSnapshot = await _dbRef
          .child('groups_info')
          .child(groupId)
          .get();

      final updates = <String, dynamic>{
        if (groupNotificationPath != null) groupNotificationPath: payload,
      };

      if (groupSnapshot.exists && groupSnapshot.value != null) {
        final groupData = Map<String, dynamic>.from(groupSnapshot.value as Map);
        final excludedIds = excludeUserIds
            .map((userId) => userId.trim())
            .where((userId) => userId.isNotEmpty)
            .toSet();
        final memberIds = <String>{
          ..._extractIds(groupData['members']),
          ..._extractIds(groupData['membri']),
          ..._extractIds(groupData['users']),
          ..._extractIds(groupData['user_ids']),
        }..removeWhere(excludedIds.contains);

        for (final memberId in memberIds) {
          final notificationId = _dbRef
              .child('user_notifications')
              .child(memberId)
              .push()
              .key;
          if (notificationId != null) {
            updates['/user_notifications/$memberId/$notificationId'] = payload;
          }
        }
      }

      if (updates.isNotEmpty) {
        await _dbRef.update(updates);
      }
    } catch (e) {
      debugPrint("Errore notifica gruppo $groupId: $e");
    }
  }

  Future<Map<String, dynamic>> _findSlotsByBookingId(
    String dateStr,
    String bookingId,
  ) async {
    try {
      final slotsSnapshot = await _dbRef
          .child('slots')
          .child(dateStr)
          .orderByChild('booking_id')
          .equalTo(bookingId)
          .get();

      if (slotsSnapshot.exists &&
          slotsSnapshot.value != null &&
          slotsSnapshot.value is Map) {
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
      return rawValue
          .where((item) => item != null)
          .map((item) => item.toString())
          .toSet();
    }

    return <String>{};
  }

  String _currentUsernameFromMap(
    Map<String, dynamic> userData,
    String fallback,
  ) {
    return userData['username']?.toString().trim().isNotEmpty == true
        ? userData['username'].toString().trim()
        : (userData['nickname']?.toString().trim().isNotEmpty == true
              ? userData['nickname'].toString().trim()
              : fallback);
  }

  Map<String, dynamic> _groupActivityEntry({
    required String type,
    required String message,
  }) {
    return {
      'type': type,
      'message': message,
      'timestamp': ServerValue.timestamp,
    };
  }

  Map<String, dynamic> _groupInviteHistoryEntry({
    required String status,
    required String username,
    required String actorUsername,
  }) {
    return {
      'status': status,
      'username': username,
      'actor_username': actorUsername,
      'timestamp': ServerValue.timestamp,
    };
  }

  bool _isPermissionDeniedError(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains('permission denied') ||
        message.contains('permission-denied');
  }

  Future<Map<String, dynamic>> _loadUserData(String uid) async {
    try {
      final snapshot = await _dbRef.child('users').child(uid).get();
      if (!snapshot.exists ||
          snapshot.value == null ||
          snapshot.value is! Map) {
        return <String, dynamic>{};
      }
      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (error) {
      if (_isPermissionDeniedError(error)) {
        debugPrint('Lettura user $uid non autorizzata: uso fallback locale.');
        return <String, dynamic>{};
      }
      rethrow;
    }
  }

  Future<String> _resolveGroupName(String? groupId) async {
    if (groupId == null || groupId.trim().isEmpty) {
      return '';
    }
    try {
      final snapshot = await _dbRef
          .child('groups_info')
          .child(groupId)
          .child('name')
          .get();
      return snapshot.value?.toString() ?? '';
    } catch (error) {
      if (_isPermissionDeniedError(error)) {
        debugPrint(
          'Lettura nome gruppo $groupId non autorizzata: nome gruppo omesso.',
        );
        return '';
      }
      rethrow;
    }
  }

  Future<String> resolveGroupName(String? groupId) =>
      _resolveGroupName(groupId);

  Future<Map<String, String>> getUsernamesByIds(
    Iterable<String> userIds,
  ) async {
    final result = <String, String>{};
    for (final rawId in userIds) {
      final uid = rawId.trim();
      if (uid.isEmpty) {
        continue;
      }
      final userData = await _loadUserData(uid);
      result[uid] = _currentUsernameFromMap(userData, uid);
    }
    return result;
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
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef.child('bookings').child(bookingId).get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Prenotazione non trovata');
    }

    final bookingData = Map<String, dynamic>.from(snapshot.value as Map);
    final ownerId = bookingData['user_id']?.toString() ?? '';
    final groupId = bookingData['group_id']?.toString();
    final ownerNotificationId = _dbRef
        .child('user_notifications')
        .child(ownerId)
        .push()
        .key;
    final updates = <String, dynamic>{
      '/bookings/$bookingId/stato': BookingStatus.confermata.name,
      '/user_bookings/$ownerId/$bookingId/stato': BookingStatus.confermata.name,
      if (ownerNotificationId != null)
        '/user_notifications/$ownerId/$ownerNotificationId': {
        'type': 'booking_confirmed',
        'booking_id': bookingId,
        'data': bookingData['data'],
        'ora_inizio': bookingData['ora_inizio'],
        'ora_fine': bookingData['ora_fine'],
        'timestamp': ServerValue.timestamp,
        'read': false,
      },
    };

    if (groupId != null && groupId.isNotEmpty) {
      updates['/group_bookings/$groupId/$bookingId/stato'] =
          BookingStatus.confermata.name;
    }

    await _dbRef.update(updates);

    if (groupId != null && groupId.isNotEmpty) {
      final groupName = bookingData['group_name']?.toString() ??
          await _resolveGroupName(groupId);
      await _notifyGroupBookingMembers(
        groupId: groupId,
        bookingId: bookingId,
        type: 'group_booking_confirmed',
        actorUserId: user.uid,
        date: bookingData['data']?.toString() ?? '',
        start: bookingData['ora_inizio']?.toString() ?? '',
        end: bookingData['ora_fine']?.toString() ?? '',
        groupName: groupName,
        excludeUserIds: {ownerId},
      );
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    await _ensureCurrentUserIsAdminOrThrow();
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef.child('bookings').child(bookingId).get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Prenotazione non trovata');
    }

    final bookingData = Map<String, dynamic>.from(snapshot.value as Map);
    final ownerId = bookingData['user_id']?.toString() ?? '';
    final groupId = bookingData['group_id']?.toString();
    final date = bookingData['data']?.toString() ?? '';
    final ownerNotificationId = _dbRef
        .child('user_notifications')
        .child(ownerId)
        .push()
        .key;
    final updates = <String, dynamic>{
      '/bookings/$bookingId/stato': BookingStatus.annullata.name,
      '/user_bookings/$ownerId/$bookingId/stato': BookingStatus.annullata.name,
      if (ownerNotificationId != null)
        '/user_notifications/$ownerId/$ownerNotificationId': {
        'type': 'booking_cancelled',
        'booking_id': bookingId,
        'data': bookingData['data'],
        'ora_inizio': bookingData['ora_inizio'],
        'ora_fine': bookingData['ora_fine'],
        'timestamp': ServerValue.timestamp,
        'read': false,
      },
    };

    if (groupId != null && groupId.isNotEmpty) {
      updates['/group_bookings/$groupId/$bookingId/stato'] =
          BookingStatus.annullata.name;
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

    if (groupId != null && groupId.isNotEmpty) {
      final groupName = bookingData['group_name']?.toString() ??
          await _resolveGroupName(groupId);
      await _notifyGroupBookingMembers(
        groupId: groupId,
        bookingId: bookingId,
        type: 'group_booking_cancelled',
        actorUserId: user.uid,
        date: bookingData['data']?.toString() ?? '',
        start: bookingData['ora_inizio']?.toString() ?? '',
        end: bookingData['ora_fine']?.toString() ?? '',
        groupName: groupName,
        excludeUserIds: {ownerId},
      );
    }
  }

  Future<void> createJam(Jam jam, List<String> selectedSlotTimes) async {
    debugPrint("Inizio creazione JAM...");

    final newJamKey = _dbRef.child('jams').push().key;
    if (newJamKey == null) throw Exception("Impossibile generare ID Jam");

    final adminIds = await _getAdminUserIds();

    final Map<String, dynamic> updates = {};

    // 1. Salva la Jam
    final jamPath = '/jams/$newJamKey';
    final creatorData = await _loadUserData(jam.creatorId);
    final creatorUsername = _currentUsernameFromMap(creatorData, jam.creatorId);
    updates[jamPath] = {
      ...jam.toMap(),
      'creator_nickname': (jam.creatorNickname?.trim().isNotEmpty ?? false)
          ? jam.creatorNickname
          : creatorUsername,
      'group_name': jam.groupName?.trim().isNotEmpty == true
          ? jam.groupName
          : await _resolveGroupName(jam.groupId),
      'participant_usernames': const <String, dynamic>{},
    };

    // 2. Aggiorna gli slot come occupati
    for (final time in selectedSlotTimes) {
      final key = time.replaceAll(":", "_");
      final slotPath = '/slots/${jam.data}/$key';

      updates['$slotPath/status'] = 'occupato';
      updates['$slotPath/booked_by'] = jam.creatorId;
      updates['$slotPath/booking_id'] = newJamKey;
      updates['$slotPath/is_jam'] = true;
    }

    await _addAdminNotifications(
      updates,
      adminIds,
      'admin_jam_created',
      jam.data,
      jam.oraInizio,
      end: jam.oraFine,
      subjectId: newJamKey,
      requesterId: jam.creatorId,
    );

    try {
      await _dbRef.update(updates);
      if (jam.groupId != null && jam.groupId!.isNotEmpty) {
        await _notifyGroupJamMembers(
          groupId: jam.groupId!,
          jamId: newJamKey,
          type: 'group_jam_created',
          actorUserId: jam.creatorId,
          date: jam.data,
          start: jam.oraInizio,
          end: jam.oraFine,
          title: jam.titolo,
          groupName: updates[jamPath]['group_name']?.toString(),
          excludeUserIds: {jam.creatorId},
        );
      }
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
    return _dbRef
        .child('jams')
        .orderByChild('stato')
        .equalTo(JamStatus.pubblicata.name)
        .onValue;
  }

  Stream<DatabaseEvent> getOwnJamsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error('Utente non loggato');
    }

    return _dbRef
        .child('jams')
        .orderByChild('creator_id')
        .equalTo(user.uid)
        .onValue;
  }

  Stream<DatabaseEvent> getPendingJamsStream() {
    return _dbRef
        .child('jams')
        .orderByChild('stato')
        .equalTo(JamStatus.inElaborazione.name)
        .onValue;
  }

  Future<void> approveJam(String jamId) async {
    await _ensureCurrentUserIsAdminOrThrow();
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
    final updates = <String, dynamic>{
      '/jams/$jamId/stato': JamStatus.pubblicata.name,
    };
    if (creatorId.isNotEmpty) {
      final creatorNotificationId = _dbRef
          .child('user_notifications')
          .child(creatorId)
          .push()
          .key;
      if (creatorNotificationId != null) {
        updates['/user_notifications/$creatorId/$creatorNotificationId'] = {
        'type': 'jam_approved',
        'jam_id': jamId,
        'data': jamData['data'],
        'ora_inizio': jamData['ora_inizio'],
        'ora_fine': jamData['ora_fine'],
        'timestamp': ServerValue.timestamp,
        'read': false,
        };
      }
    }

    final feedSnapshot = await _dbRef
        .child('feed')
        .orderByChild('jam_id')
        .equalTo(jamId)
        .get();
    if (feedSnapshot.exists && feedSnapshot.value != null) {
      final feedData = Map<String, dynamic>.from(feedSnapshot.value as Map);
      for (final entry in feedData.entries) {
        updates['/feed/${entry.key}/type'] = 'jam_published';
        updates['/feed/${entry.key}/creator_id'] = jamData['creator_id'];
        updates['/feed/${entry.key}/titolo'] = jamData['titolo'];
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
          'titolo': jamData['titolo'],
          'data': jamData['data'],
          'ora_inizio': jamData['ora_inizio'],
          'descrizione': jamData['descrizione'],
        };
      }
    }

    await _dbRef.update(updates);

    final groupId = jamData['group_id']?.toString();
    if (groupId != null && groupId.isNotEmpty) {
      await _notifyGroupJamMembers(
        groupId: groupId,
        jamId: jamId,
        type: 'group_jam_approved',
        actorUserId: user.uid,
        date: jamData['data']?.toString() ?? '',
        start: jamData['ora_inizio']?.toString() ?? '',
        end: jamData['ora_fine']?.toString() ?? '',
        title: jamData['titolo']?.toString() ?? '',
        groupName: jamData['group_name']?.toString(),
        excludeUserIds: {creatorId},
      );
    }
  }

  Future<void> rejectJam(String jamId) async {
    await _ensureCurrentUserIsAdminOrThrow();
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final snapshot = await _dbRef.child('jams').child(jamId).get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Jam non trovata');
    }

    final jamData = Map<String, dynamic>.from(snapshot.value as Map);
    final dateStr = jamData['data']?.toString() ?? '';
    final participantIds = _extractIds(jamData['participants']);
    final creatorId = jamData['creator_id']?.toString() ?? '';
    final updates = <String, dynamic>{
      '/jams/$jamId/stato': JamStatus.annullata.name,
      '/jams/$jamId/participants': null,
      '/jams/$jamId/participant_usernames': null,
    };
    if (creatorId.isNotEmpty) {
      final creatorNotificationId = _dbRef
          .child('user_notifications')
          .child(creatorId)
          .push()
          .key;
      if (creatorNotificationId != null) {
        updates['/user_notifications/$creatorId/$creatorNotificationId'] = {
        'type': 'jam_rejected',
        'jam_id': jamId,
        'data': jamData['data'],
        'ora_inizio': jamData['ora_inizio'],
        'ora_fine': jamData['ora_fine'],
        'timestamp': ServerValue.timestamp,
        'read': false,
        };
      }
    }

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

    final feedSnapshot = await _dbRef
        .child('feed')
        .orderByChild('jam_id')
        .equalTo(jamId)
        .get();
    if (feedSnapshot.exists && feedSnapshot.value != null) {
      final feedData = Map<String, dynamic>.from(feedSnapshot.value as Map);
      for (final entry in feedData.entries) {
        updates['/feed/${entry.key}'] = null;
      }
    }

    await _dbRef.update(updates);

    final groupId = jamData['group_id']?.toString();
    if (groupId != null && groupId.isNotEmpty) {
      await _notifyGroupJamMembers(
        groupId: groupId,
        jamId: jamId,
        type: 'group_jam_rejected',
        actorUserId: user.uid,
        date: jamData['data']?.toString() ?? '',
        start: jamData['ora_inizio']?.toString() ?? '',
        end: jamData['ora_fine']?.toString() ?? '',
        title: jamData['titolo']?.toString() ?? '',
        groupName: jamData['group_name']?.toString(),
        excludeUserIds: {creatorId},
      );
    }
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

    final userData = await _loadUserData(user.uid);
    final username = _currentUsernameFromMap(userData, user.uid);
    await _dbRef.update({
      '/jams/$jamId/persone_presenti': currentPresent + 1,
      '/jams/$jamId/persone_richieste': currentRequired - 1,
      '/jams/$jamId/participants/${user.uid}': true,
      '/jams/$jamId/participant_usernames/${user.uid}': username,
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
      '/jams/$jamId/persone_presenti': currentPresent > 0
          ? currentPresent - 1
          : 0,
      '/jams/$jamId/persone_richieste': currentRequired + 1,
      '/jams/$jamId/participants/${user.uid}': null,
      '/jams/$jamId/participant_usernames/${user.uid}': null,
      '/user_joined_jams/${user.uid}/$jamId': null,
    });
  }

  Future<void> updateJam({
    required String jamId,
    required String date,
    required List<String> selectedSlotTimes,
    String? groupId,
    required String title,
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

    await _applyJamUpdate(
      jamId: jamId,
      date: date,
      selectedSlotTimes: selectedSlotTimes,
      groupId: groupId,
      title: title,
      presentPeople: presentPeople,
      requiredPeople: requiredPeople,
      description: description,
      payment: payment,
      equipment: equipment,
      actingUserId: user.uid,
      allowAdmin: true,
      notifyAdmins: true,
    );
  }

  Future<void> proposeJamUpdate({
    required String jamId,
    required String date,
    required List<String> selectedSlotTimes,
    String? groupId,
    required String title,
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
    await _ensureCurrentUserIsAdminOrThrow();

    final jamSnapshot = await _dbRef.child('jams').child(jamId).get();
    if (!jamSnapshot.exists || jamSnapshot.value == null) {
      throw Exception('Jam non trovata');
    }

    final jamData = Map<String, dynamic>.from(jamSnapshot.value as Map);
    final creatorId = jamData['creator_id']?.toString() ?? '';
    if (creatorId.isEmpty) {
      throw Exception('Creatore jam non trovato');
    }

    final orderedSlots = List<String>.from(selectedSlotTimes)..sort();
    if (orderedSlots.isEmpty) {
      throw Exception('Seleziona almeno un orario');
    }

    final proposerName = _currentUsernameFromMap(
      await _loadUserData(user.uid),
      user.uid,
    );
    final notificationId = _dbRef
        .child('user_notifications')
        .child(creatorId)
        .push()
        .key;
    final senderNotificationId = _dbRef
        .child('user_notifications')
        .child(user.uid)
        .push()
        .key;
    if (notificationId == null || senderNotificationId == null) {
      throw Exception('Impossibile creare la proposta');
    }

    await _dbRef.update({
      '/user_notifications/$creatorId/$notificationId': {
        'type': 'jam_update_proposal',
        'jam_id': jamId,
        'creator_id': user.uid,
        'username': proposerName,
        'data': date,
        'ora_inizio': orderedSlots.first,
        'ora_fine': _calculateEndTime(orderedSlots.last),
        'selected_slot_times': orderedSlots,
        'group_id': groupId,
        'titolo': title.trim(),
        'persone_presenti': presentPeople,
        'persone_richieste': requiredPeople,
        'descrizione': description.trim(),
        'pagamento': payment,
        'attrezzatura': equipment.trim(),
        'target_status': jamData['stato']?.toString(),
        'proposal_status': 'pending',
        'timestamp': ServerValue.timestamp,
        'read': false,
      },
      '/user_notifications/${user.uid}/$senderNotificationId': {
        'type': 'admin_jam_update_proposed',
        'jam_id': jamId,
        'creator_id': user.uid,
        'username': proposerName,
        'data': date,
        'ora_inizio': orderedSlots.first,
        'ora_fine': _calculateEndTime(orderedSlots.last),
        'timestamp': ServerValue.timestamp,
        'read': false,
      },
    });
  }

  Future<void> _applyJamUpdate({
    required String jamId,
    required String date,
    required List<String> selectedSlotTimes,
    String? groupId,
    required String title,
    required int presentPeople,
    required int requiredPeople,
    required String description,
    required String payment,
    required String equipment,
    required String actingUserId,
    required bool allowAdmin,
    required bool notifyAdmins,
    String? overrideStatus,
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
    if (creatorId != actingUserId && !(allowAdmin && isAdmin)) {
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

    final targetSlots = Map<String, dynamic>.from(
      targetSlotsSnapshot.value as Map,
    );
    for (final time in orderedSlots) {
      final slotKey = time.replaceAll(':', '_');
      final slotData = Map<String, dynamic>.from(
        (targetSlots[slotKey] as Map?) ?? const {},
      );
      final status = slotData['status']?.toString();
      final bookingIdOnSlot = slotData['booking_id']?.toString();
      if (status != 'libero' && bookingIdOnSlot != jamId) {
        throw Exception('Uno degli slot selezionati non e piu disponibile');
      }
    }

    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();
    final trimmedEquipment = equipment.trim();
    final groupName = await _resolveGroupName(groupId);
    final newEndTime = _calculateEndTime(orderedSlots.last);
    final scheduleChanged =
        previousDate != date ||
        (jamData['ora_inizio']?.toString() ?? '') != orderedSlots.first ||
        (jamData['ora_fine']?.toString() ?? '') != newEndTime;
    final nextStatus =
      overrideStatus?.trim().isNotEmpty == true
        ? overrideStatus!.trim()
        : scheduleChanged
        ? JamStatus.inElaborazione.name
        : jamData['stato']?.toString() ?? JamStatus.inElaborazione.name;
    final oldSlots = previousDate.isEmpty
        ? <String, dynamic>{}
        : await _findSlotsByBookingId(previousDate, jamId);

    final updates = <String, dynamic>{
      '/jams/$jamId/data': date,
      '/jams/$jamId/ora_inizio': orderedSlots.first,
      '/jams/$jamId/ora_fine': newEndTime,
      '/jams/$jamId/group_id': groupId,
      '/jams/$jamId/group_name': groupName.isEmpty ? null : groupName,
      '/jams/$jamId/titolo': trimmedTitle,
      '/jams/$jamId/persone_presenti': presentPeople,
      '/jams/$jamId/persone_richieste': requiredPeople,
      '/jams/$jamId/descrizione': trimmedDescription,
      '/jams/$jamId/pagamento': payment,
      '/jams/$jamId/attrezzatura': trimmedEquipment,
      '/jams/$jamId/stato': nextStatus,
    };

    if (notifyAdmins) {
      final adminIds = await _getAdminUserIds();
      await _addAdminNotifications(
        updates,
        adminIds,
        'admin_jam_modified',
        date,
        orderedSlots.first,
        end: newEndTime,
        subjectId: jamId,
        requesterId: creatorId,
      );
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
      updates['/slots/$date/$slotKey/booked_by'] = creatorId;
      updates['/slots/$date/$slotKey/booking_id'] = jamId;
      updates['/slots/$date/$slotKey/is_jam'] = true;
    }

    final feedSnapshot = await _dbRef
        .child('feed')
        .orderByChild('jam_id')
        .equalTo(jamId)
        .get();
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

    if (groupId != null && groupId.isNotEmpty) {
      await _notifyGroupJamMembers(
        groupId: groupId,
        jamId: jamId,
        type: 'group_jam_modified',
        actorUserId: actingUserId,
        date: date,
        start: orderedSlots.first,
        end: newEndTime,
        title: trimmedTitle,
        groupName: groupName,
        excludeUserIds: {actingUserId},
      );
    }
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

    final roleSnapshot = await _dbRef
        .child('users')
        .child(user.uid)
        .child('role')
        .get();
    return roleSnapshot.value?.toString() == 'admin';
  }

  Future<void> _ensureCurrentUserIsAdminOrThrow() async {
    if (!await _isCurrentUserAdmin()) {
      throw Exception('Permessi insufficienti');
    }
  }

  Future<List<String>> _getAdminUserIds() async {
    try {
      final snapshot = await _dbRef
          .child('users')
          .orderByChild('role')
          .equalTo('admin')
          .get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final List<String> admins = [];
      for (final child in snapshot.children) {
        if (child.key != null) {
          admins.add(child.key!);
        }
      }
      return admins;
    } catch (error) {
      if (_isPermissionDeniedError(error)) {
        debugPrint(
          'Lettura admin non autorizzata: notifiche admin saltate per questo utente.',
        );
        return [];
      }
      rethrow;
    }
  }

  Future<void> _addAdminNotifications(
    Map<String, dynamic> updates,
    List<String> adminIds,
    String type,
    String date,
    String start, {
    String? end,
    String? subjectId,
    String? requesterId,
  }) async {
    String? username;
    if (requesterId != null && requesterId.isNotEmpty) {
      final namesMap = await getUsernamesByIds([requesterId]);
      username = namesMap[requesterId];
    }

    final timestamp = ServerValue.timestamp;
    for (final adminId in adminIds) {
      final notifId = _dbRef
          .child('user_notifications')
          .child(adminId)
          .push()
          .key;
      if (notifId != null) {
        updates['/user_notifications/$adminId/$notifId'] = {
          'type': type,
          'data': date,
          'ora_inizio': start,
          if (end != null) 'ora_fine': end,
          'timestamp': timestamp,
          'read': false,
          if (subjectId != null) 'subject_id': subjectId,
          if (requesterId != null) 'requester_id': requesterId,
          if (requesterId != null) 'creator_id': requesterId,
          if (username != null) 'username': username,
        };
      }
    }
  }

  Future<List<Map<String, dynamic>>> searchUsersByNickname(
    String nickname,
  ) async {
    final trimmedNickname = nickname.trim();
    if (trimmedNickname.isEmpty) {
      return [];
    }

    final lowercaseNickname = trimmedNickname.toLowerCase();
    final snapshot = await _dbRef
        .child('user_search_index')
        .child(lowercaseNickname)
        .get();
    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final results = <Map<String, dynamic>>[];
    final rawValue = snapshot.value;
    if (rawValue is String) {
      final uid = rawValue.trim();
      if (uid.isNotEmpty) {
        results.add({'uid': uid, 'nickname': trimmedNickname});
      }
    } else if (rawValue is Map) {
      final data = _asStringKeyedMap(rawValue);
      final looksLikeSinglePayload =
          data.containsKey('uid') ||
          data.containsKey('nickname') ||
          data.containsKey('username');

      if (looksLikeSinglePayload) {
        final resolvedUid = data['uid']?.toString() ?? '';
        if (resolvedUid.isNotEmpty) {
          results.add({
            'uid': resolvedUid,
            'nickname':
                data['username']?.toString() ??
                data['nickname']?.toString() ??
                trimmedNickname,
          });
        }
        return results;
      }

      for (final entry in data.entries) {
        final rawPayload = entry.value;
        final payload = rawPayload is Map
            ? _asStringKeyedMap(rawPayload)
            : <String, dynamic>{
                'username': rawPayload?.toString() ?? trimmedNickname,
              };
        results.add({
          'uid': entry.key.toString(),
          'nickname':
              payload['username']?.toString() ??
              payload['nickname']?.toString() ??
              trimmedNickname,
        });
      }
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> searchPublicUserProfiles({
    String usernameQuery = '',
    String cityQuery = '',
    String instrumentQuery = '',
    String genreQuery = '',
    String? excludingUid,
  }) async {
    final usernameFilter = usernameQuery.trim().toLowerCase();
    final cityFilter = cityQuery.trim().toLowerCase();
    final instrumentFilter = instrumentQuery.trim().toLowerCase();
    final genreFilter = genreQuery.trim().toLowerCase();
    if (usernameFilter.isEmpty &&
        cityFilter.isEmpty &&
        instrumentFilter.isEmpty &&
        genreFilter.isEmpty) {
      return [];
    }

    final currentUid = excludingUid ?? _auth.currentUser?.uid;
    final indexedUsernameMatches = usernameFilter.isEmpty
        ? const <Map<String, dynamic>>[]
        : await searchUsersByNickname(usernameQuery);
    final indexedUserIds = indexedUsernameMatches
        .map((item) => item['uid']?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet();
    if (usernameFilter.isNotEmpty && indexedUserIds.isEmpty) {
      return [];
    }

    if (usernameFilter.isNotEmpty) {
      if (cityFilter.isNotEmpty ||
          instrumentFilter.isNotEmpty ||
          genreFilter.isNotEmpty) {
        return [];
      }

      final profiles = indexedUsernameMatches
          .where((item) => item['uid']?.toString() != currentUid)
          .map(
            (item) => <String, dynamic>{
              'uid': item['uid']?.toString() ?? '',
              'username': item['nickname']?.toString().trim().isNotEmpty == true
                  ? item['nickname'].toString().trim()
                  : usernameQuery.trim(),
              'city': '',
              'bio': '',
              'skill_level': 'Non specificato',
              'genres': const <String>[],
              'instruments': const <String>[],
              'availability': const <String>[],
            },
          )
          .where((item) => item['uid']?.toString().isNotEmpty == true)
          .toList();

      profiles.sort((a, b) {
        final left = a['username']?.toString() ?? '';
        final right = b['username']?.toString() ?? '';
        return left.compareTo(right);
      });
      return profiles;
    }

    final snapshots = await Future.wait([
      _dbRef.child('user_public_profiles').get(),
    ]);
    final publicProfilesSnapshot = snapshots[0];

    final profiles = <Map<String, dynamic>>[];
    final rawPublicProfiles =
        publicProfilesSnapshot.exists && publicProfilesSnapshot.value != null
        ? _asStringKeyedMap(publicProfilesSnapshot.value)
        : const <String, dynamic>{};
    final candidateUserIds = <String>{...rawPublicProfiles.keys};

    for (final uid in candidateUserIds) {
      try {
        if (uid == currentUid) {
          continue;
        }

        final publicProfile = _asStringKeyedMap(rawPublicProfiles[uid]);
        final profile = <String, dynamic>{'uid': uid, ...publicProfile};
        if (profile.isEmpty) {
          continue;
        }

        if (_profileMatchesFilters(
          profile,
          usernameFilter: usernameFilter,
          cityFilter: cityFilter,
          instrumentFilter: instrumentFilter,
          genreFilter: genreFilter,
        )) {
          profiles.add({'uid': uid, ...profile});
        }
      } catch (error) {
        debugPrint('Ricerca profili: record utente ignorato per $uid: $error');
      }
    }

    profiles.sort((a, b) {
      final left = a['username']?.toString() ?? '';
      final right = b['username']?.toString() ?? '';
      return left.compareTo(right);
    });
    return profiles;
  }

  Future<String> createGroup(String name, {String description = ''}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final trimmedName = name.trim();
    final trimmedDescription = description.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Inserisci un nome gruppo');
    }

    final userData = await _loadUserData(user.uid);
    final nickname = _currentUsernameFromMap(userData, user.uid);

    final groupId = _dbRef.child('groups_info').push().key;
    if (groupId == null) {
      throw Exception('Impossibile creare il gruppo');
    }

    final activityId = _dbRef
        .child('groups_info')
        .child(groupId)
        .child('activity')
        .push()
        .key;

    await _dbRef.update({
      '/groups_info/$groupId': {
        'name': trimmedName,
        'description': trimmedDescription,
        'notes': '',
        'owner_id': user.uid,
        'created_at': ServerValue.timestamp,
        'members': {user.uid: true},
        'member_nicknames': {user.uid: nickname},
        if (activityId != null)
          'activity': {
            activityId: _groupActivityEntry(
              type: 'group_created',
              message: '$nickname ha creato il gruppo.',
            ),
          },
      },
      '/users/${user.uid}/gruppi/$groupId': true,
    });

    return groupId;
  }

  Future<void> removeUserFromGroup({
    required String groupId,
    required String targetUserId,
  }) async {
    try {
      await _functions.httpsCallable('removeUserFromGroup').call({
        'groupId': groupId,
        'targetUserId': targetUserId,
      });
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'not-found') {
        throw Exception(error.message ?? 'Rimozione membro fallita');
      }
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final groupSnapshot = await _dbRef
        .child('groups_info')
        .child(groupId)
        .get();
    if (!groupSnapshot.exists || groupSnapshot.value == null) {
      throw Exception('Gruppo non trovato');
    }

    final groupData = _asStringKeyedMap(groupSnapshot.value);
    final ownerId = groupData['owner_id']?.toString() ?? '';
    final isAdmin = await _isCurrentUserAdmin();
    if (ownerId != user.uid && !isAdmin) {
      throw Exception('Solo il proprietario del gruppo puo rimuovere membri');
    }

    if (targetUserId == ownerId) {
      throw Exception('Il proprietario non puo essere rimosso dal gruppo');
    }

    final members = _extractIds(groupData['members']);
    if (!members.contains(targetUserId)) {
      throw Exception('Utente non presente nel gruppo');
    }

    final activityId = _dbRef
        .child('groups_info')
        .child(groupId)
        .child('activity')
        .push()
        .key;

    final updates = <String, dynamic>{
      '/groups_info/$groupId/members/$targetUserId': null,
      '/groups_info/$groupId/member_nicknames/$targetUserId': null,
      '/users/$targetUserId/gruppi/$groupId': null,
    };
    if (activityId != null) {
      updates['/groups_info/$groupId/activity/$activityId'] =
          _groupActivityEntry(
            type: 'member_removed',
            message: 'Un membro e stato rimosso dal gruppo.',
          );
    }
    await _dbRef.update(updates);
  }

  Future<void> leaveGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final groupSnapshot = await _dbRef
        .child('groups_info')
        .child(groupId)
        .get();
    if (!groupSnapshot.exists || groupSnapshot.value == null) {
      throw Exception('Gruppo non trovato');
    }

    final groupData = Map<String, dynamic>.from(groupSnapshot.value as Map);
    final ownerId = groupData['owner_id']?.toString() ?? '';
    if (ownerId == user.uid) {
      throw Exception('Il proprietario non puo uscire dal proprio gruppo');
    }

    final members = _extractIds(groupData['members']);
    if (!members.contains(user.uid)) {
      throw Exception('Non fai parte di questo gruppo');
    }

    final userData = await _loadUserData(user.uid);
    final username = _currentUsernameFromMap(userData, user.uid);
    final activityId = _dbRef
        .child('groups_info')
        .child(groupId)
        .child('activity')
        .push()
        .key;
    final updates = <String, dynamic>{
      '/groups_info/$groupId/members/${user.uid}': null,
      '/groups_info/$groupId/member_nicknames/${user.uid}': null,
      '/users/${user.uid}/gruppi/$groupId': null,
    };
    if (activityId != null) {
      updates['/groups_info/$groupId/activity/$activityId'] =
          _groupActivityEntry(
            type: 'member_left',
            message: '$username ha lasciato il gruppo.',
          );
    }
    await _dbRef.update(updates);
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      await _functions.httpsCallable('deleteGroupCascade').call({
        'groupId': groupId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'Eliminazione gruppo fallita');
    }
  }

  Future<void> revokeGroupInvite({
    required String groupId,
    required String targetUserId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final groupSnapshot = await _dbRef
        .child('groups_info')
        .child(groupId)
        .get();
    if (!groupSnapshot.exists || groupSnapshot.value == null) {
      throw Exception('Gruppo non trovato');
    }

    final groupData = Map<String, dynamic>.from(groupSnapshot.value as Map);
    final ownerId = groupData['owner_id']?.toString() ?? '';
    final isAdmin = await _isCurrentUserAdmin();
    if (ownerId != user.uid && !isAdmin) {
      throw Exception('Solo il proprietario del gruppo puo revocare inviti');
    }

    final groupName = groupData['name']?.toString() ?? 'Gruppo';
    final actorData = await _loadUserData(user.uid);
    final targetData = await _loadUserData(targetUserId);
    final actorUsername = _currentUsernameFromMap(actorData, user.uid);
    final targetUsername = _currentUsernameFromMap(targetData, targetUserId);
    final notificationId = _groupInviteNotificationId(groupId);
    final activityId = _dbRef
        .child('groups_info')
        .child(groupId)
        .child('activity')
        .push()
        .key;
    final historyId = _dbRef
        .child('groups_info')
        .child(groupId)
        .child('invite_history')
        .push()
        .key;
    final updates = <String, dynamic>{
      '/groups_info/$groupId/pending_invites/$targetUserId': null,
      '/group_invites/$targetUserId/$groupId': null,
      '/user_notifications/$targetUserId/$notificationId': null,
    };
    if (historyId != null) {
      updates['/groups_info/$groupId/invite_history/$historyId'] =
          _groupInviteHistoryEntry(
            status: 'revoked',
            username: targetUsername,
            actorUsername: actorUsername,
          );
    }
    if (activityId != null) {
      updates['/groups_info/$groupId/activity/$activityId'] = _groupActivityEntry(
        type: 'invite_revoked',
        message:
            '$actorUsername ha revocato l\'invito di $targetUsername in $groupName.',
      );
    }
    await _dbRef.update(updates);
  }

  Future<void> updateGroupNotes({
    required String groupId,
    required String notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final groupSnapshot = await _dbRef
        .child('groups_info')
        .child(groupId)
        .get();
    if (!groupSnapshot.exists || groupSnapshot.value == null) {
      throw Exception('Gruppo non trovato');
    }

    final groupData = Map<String, dynamic>.from(groupSnapshot.value as Map);
    final ownerId = groupData['owner_id']?.toString() ?? '';
    final isAdmin = await _isCurrentUserAdmin();
    if (ownerId != user.uid && !isAdmin) {
      throw Exception('Solo il proprietario del gruppo puo aggiornare le note');
    }

    final actorData = await _loadUserData(user.uid);
    final actorUsername = _currentUsernameFromMap(actorData, user.uid);
    final activityId = _dbRef
        .child('groups_info')
        .child(groupId)
        .child('activity')
        .push()
        .key;
    final updates = <String, dynamic>{
      '/groups_info/$groupId/notes': notes.trim(),
    };
    if (activityId != null) {
      updates['/groups_info/$groupId/activity/$activityId'] =
          _groupActivityEntry(
            type: 'notes_updated',
            message: '$actorUsername ha aggiornato le note del gruppo.',
          );
    }
    await _dbRef.update(updates);
  }

  Future<List<Map<String, dynamic>>> getSlotsForDate(String dateStr) async {
    final slotsRef = _dbRef.child('slots').child(dateStr);

    try {
      var snapshot = await slotsRef.get();
      if (!snapshot.exists) {
        await _generateSlotsForDate(dateStr);
        snapshot = await slotsRef.get();
      }

      final slots = <Map<String, dynamic>>[];
      final rawData = snapshot.value;

      if (rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        for (final entry in data.entries) {
          if (entry.value is! Map) {
            continue;
          }
          final slot = Map<String, dynamic>.from(entry.value as Map);
          slot['key'] = entry.key.toString();
          slots.add(slot);
        }
      } else if (rawData is List) {
        for (final item in rawData) {
          if (item is! Map) {
            continue;
          }
          slots.add(Map<String, dynamic>.from(item));
        }
      }

      slots.sort((a, b) {
        final left = a['time']?.toString() ?? '';
        final right = b['time']?.toString() ?? '';
        return left.compareTo(right);
      });

      return slots;
    } catch (e) {
      debugPrint("Errore getSlotsForDate: $e");
      rethrow;
    }
  }

  Future<void> inviteUserToGroup({
    required String groupId,
    required String nickname,
  }) async {
    try {
      await _functions.httpsCallable('inviteUserToGroup').call({
        'groupId': groupId,
        'nickname': nickname.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'Invio invito fallito');
    }
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _calculateEndTime(String startSlot) {
    final totalMinutes = _timeToMinutes(startSlot) + 30;
    final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // ELIMINA JAM
  Future<void> deleteJam(String jamId) async {
    try {
      final snapshot = await _dbRef.child('jams').child(jamId).get();
      if (snapshot.exists && snapshot.value != null) {
        final jamData = Map<String, dynamic>.from(snapshot.value as Map);
        final date = jamData['data']?.toString() ?? '';
        final start = jamData['ora_inizio']?.toString() ?? '';
        final creatorId = jamData['creator_id']?.toString() ?? '';

        final adminIds = await _getAdminUserIds();
        final updates = <String, dynamic>{};
        await _addAdminNotifications(
          updates,
          adminIds,
          'admin_jam_cancelled',
          date,
          start,
          subjectId: jamId,
          requesterId: creatorId,
        );
        if (updates.isNotEmpty) {
          await _dbRef.update(updates);
        }
      }

      await _functions.httpsCallable('deleteJamCascade').call({'jamId': jamId});
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'Eliminazione jam fallita');
    }
  }

  // --- GESTIONE FEED ---

  Stream<DatabaseEvent> getFeedStream() {
    return _dbRef.child('feed').orderByChild('timestamp').onValue;
  }

  Future<void> deleteCurrentUserProfileData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final uid = user.uid;
    final userSnapshot = await _dbRef.child('users').child(uid).get();
    final userData = userSnapshot.exists && userSnapshot.value != null
        ? Map<String, dynamic>.from(userSnapshot.value as Map)
        : <String, dynamic>{};
    final nickname =
        userData['username']?.toString() ??
        userData['nickname']?.toString() ??
        '';
    final email = userData['email']?.toString() ?? '';
    final normalizedNickname = nickname.isEmpty
        ? ''
        : _normalizeNickname(nickname);
    final normalizedEmail = email.isEmpty ? '' : _normalizeEmail(email);
    final emailKey = email.isEmpty ? '' : _emailKey(email);

    final ownedGroupsSnapshot = await _dbRef
        .child('groups_info')
        .orderByChild('owner_id')
        .equalTo(uid)
        .get();
    final ownedGroupIds = <String>[];
    if (ownedGroupsSnapshot.exists && ownedGroupsSnapshot.value is Map) {
      final rawGroups = Map<String, dynamic>.from(
        ownedGroupsSnapshot.value as Map,
      );
      ownedGroupIds.addAll(rawGroups.keys.map((key) => key.toString()));
    }

    for (final groupId in ownedGroupIds) {
      await deleteGroup(groupId);
    }

    final membershipSnapshot = await _dbRef
        .child('users')
        .child(uid)
        .child('gruppi')
        .get();
    if (membershipSnapshot.exists && membershipSnapshot.value is Map) {
      final rawMemberships = Map<String, dynamic>.from(
        membershipSnapshot.value as Map,
      );
      for (final groupId in rawMemberships.keys.map((key) => key.toString())) {
        if (ownedGroupIds.contains(groupId)) {
          continue;
        }

        await _dbRef.update({
          '/groups_info/$groupId/members/$uid': null,
          '/groups_info/$groupId/member_nicknames/$uid': null,
          '/users/$uid/gruppi/$groupId': null,
        });
      }
    }

    final incomingInvitesSnapshot = await _dbRef
        .child('group_invites')
        .child(uid)
        .get();
    final incomingInviteGroupIds = <String>{};
    if (incomingInvitesSnapshot.exists &&
        incomingInvitesSnapshot.value is Map) {
      final rawInvites = Map<String, dynamic>.from(
        incomingInvitesSnapshot.value as Map,
      );
      incomingInviteGroupIds.addAll(
        rawInvites.keys.map((key) => key.toString()),
      );
    }

    final userBookingsSnapshot = await _dbRef
        .child('user_bookings')
        .child(uid)
        .get();
    if (userBookingsSnapshot.exists && userBookingsSnapshot.value is Map) {
      final rawBookings = Map<String, dynamic>.from(
        userBookingsSnapshot.value as Map,
      );
      for (final bookingId in rawBookings.keys.map((key) => key.toString())) {
        await deleteBooking(bookingId);
      }
    }

    final ownedJamsSnapshot = await _dbRef
        .child('jams')
        .orderByChild('creator_id')
        .equalTo(uid)
        .get();
    if (ownedJamsSnapshot.exists && ownedJamsSnapshot.value is Map) {
      final rawJams = Map<String, dynamic>.from(ownedJamsSnapshot.value as Map);
      for (final jamId in rawJams.keys.map((key) => key.toString())) {
        await deleteJam(jamId);
      }
    }

    final joinedJamsSnapshot = await _dbRef
        .child('user_joined_jams')
        .child(uid)
        .get();
    if (joinedJamsSnapshot.exists && joinedJamsSnapshot.value is Map) {
      final rawJoinedJams = Map<String, dynamic>.from(
        joinedJamsSnapshot.value as Map,
      );
      for (final jamId in rawJoinedJams.keys.map((key) => key.toString())) {
        try {
          await leaveJam(jamId);
        } catch (_) {
          // Ignore stale relations during account cleanup.
        }
      }
    }

    final updates = <String, dynamic>{
      '/users/$uid': null,
      '/user_public_profiles/$uid': null,
      '/user_bookings/$uid': null,
      '/user_joined_jams/$uid': null,
      '/user_notifications/$uid': null,
      '/group_invites/$uid': null,
    };

    for (final groupId in incomingInviteGroupIds) {
      updates['/groups_info/$groupId/pending_invites/$uid'] = null;
    }

    if (normalizedNickname.isNotEmpty) {
      updates['/user_search_index/$normalizedNickname/$uid'] = null;
      updates['/nickname_claims/$normalizedNickname'] = null;
    }
    if (normalizedEmail.isNotEmpty) {
      updates['/user_email_index/$emailKey/$uid'] = null;
      updates['/email_claims/$emailKey'] = null;
    }

    await _dbRef.update(updates);
  }

  Future<void> deleteCurrentUserAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    try {
      await _functions.httpsCallable('deleteCurrentUserAccount').call();
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'Eliminazione account fallita');
    }
  }
}

class RegistrationAvailability {
  const RegistrationAvailability({
    required this.nicknameAvailable,
    required this.emailAvailable,
  });

  final bool nicknameAvailable;
  final bool emailAvailable;

  bool get isAvailable => nicknameAvailable && emailAvailable;

  String get errorMessage {
    if (!nicknameAvailable && !emailAvailable) {
      return 'Email e username gia utilizzati';
    }
    if (!nicknameAvailable) {
      return 'Username gia utilizzato';
    }
    return 'Email gia utilizzata';
  }
}
