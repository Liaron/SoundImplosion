import 'package:firebase_auth/firebase_auth.dart';
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
      return Map<String, dynamic>.from(rawValue);
    }
    return <String, dynamic>{};
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
    debugPrint('DB saveUser:nicknameClaim:start nickname=$normalizedNickname');
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
    debugPrint('DB saveUser:nicknameClaim:done');

    final emailClaimRef = _dbRef.child('email_claims').child(emailKey);
    debugPrint('DB saveUser:emailClaim:start email=$normalizedEmail');
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
    debugPrint('DB saveUser:emailClaim:done');

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
      debugPrint('DB saveUser:userWrite:start uid=${user.uid}');
      await _dbRef.child('users').child(user.uid).set(sanitizedUser.toMap());
      debugPrint('DB saveUser:userWrite:done');
      debugPrint('DB saveUser:nicknameIndexWrite:start');
      await currentIndexRef.child(user.uid).set({'username': trimmedNickname});
      debugPrint('DB saveUser:nicknameIndexWrite:done');
      debugPrint('DB saveUser:emailIndexWrite:start');
      await _dbRef
          .child('user_email_index')
          .child(emailKey)
          .child(user.uid)
          .set(true);
      debugPrint('DB saveUser:emailIndexWrite:done');

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

  Future<void> acceptGroupInvite(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final inviteSnapshot = await _dbRef
        .child('group_invites')
        .child(user.uid)
        .child(groupId)
        .get();
    if (!inviteSnapshot.exists || inviteSnapshot.value == null) {
      throw Exception('Invito non disponibile');
    }

    final inviteData = Map<String, dynamic>.from(inviteSnapshot.value as Map);
    if (inviteData['status']?.toString() != 'pending') {
      throw Exception('Invito non piu disponibile');
    }

    final groupSnapshot = await _dbRef
        .child('groups_info')
        .child(groupId)
        .get();
    if (!groupSnapshot.exists || groupSnapshot.value == null) {
      await _dbRef.update({
        '/group_invites/${user.uid}/$groupId': null,
        '/user_notifications/${user.uid}/${_groupInviteNotificationId(groupId)}':
            null,
      });
      throw Exception('Gruppo non trovato');
    }

    final groupData = Map<String, dynamic>.from(groupSnapshot.value as Map);
    final currentUserSnapshot = await _dbRef.child('users').child(user.uid).get();
    final currentUserData =
        currentUserSnapshot.exists && currentUserSnapshot.value is Map
        ? Map<String, dynamic>.from(currentUserSnapshot.value as Map)
        : <String, dynamic>{};

    final targetUsername =
        inviteData['invited_username']?.toString() ??
        currentUserData['username']?.toString() ??
        currentUserData['nickname']?.toString() ??
        user.displayName ??
        user.uid;
    final ownerId = groupData['owner_id']?.toString() ?? '';
    final notificationId = _groupInviteNotificationId(groupId);

    final updates = <String, dynamic>{
      '/groups_info/$groupId/members/${user.uid}': true,
      '/groups_info/$groupId/member_nicknames/${user.uid}': targetUsername,
      '/groups_info/$groupId/pending_invites/${user.uid}': null,
      '/users/${user.uid}/gruppi/$groupId': true,
      '/group_invites/${user.uid}/$groupId': null,
      '/user_notifications/${user.uid}/$notificationId/invite_status':
          'accepted',
      '/user_notifications/${user.uid}/$notificationId/read': true,
      '/user_notifications/${user.uid}/$notificationId/responded_at':
          ServerValue.timestamp,
    };

    if (ownerId.isNotEmpty && ownerId != user.uid) {
      updates['/user_notifications/$ownerId/group_invite_accepted_${groupId}_${user.uid}'] =
          {
            'type': 'group_invite_accepted',
            'group_id': groupId,
            'group_name': groupData['name']?.toString() ?? '',
            'user_id': user.uid,
            'username': targetUsername,
            'timestamp': ServerValue.timestamp,
            'creator_id': user.uid,
            'read': false,
          };
    }

    await _dbRef.update(updates);
  }

  Future<void> rejectGroupInvite(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final inviteSnapshot = await _dbRef
        .child('group_invites')
        .child(user.uid)
        .child(groupId)
        .get();
    if (!inviteSnapshot.exists || inviteSnapshot.value == null) {
      throw Exception('Invito non disponibile');
    }

    final inviteData = Map<String, dynamic>.from(inviteSnapshot.value as Map);
    if (inviteData['status']?.toString() != 'pending') {
      throw Exception('Invito non piu disponibile');
    }

    final currentUserSnapshot = await _dbRef.child('users').child(user.uid).get();
    final currentUserData =
        currentUserSnapshot.exists && currentUserSnapshot.value is Map
        ? Map<String, dynamic>.from(currentUserSnapshot.value as Map)
        : <String, dynamic>{};
    final targetUsername =
        inviteData['invited_username']?.toString() ??
        currentUserData['username']?.toString() ??
        currentUserData['nickname']?.toString() ??
        user.displayName ??
        user.uid;
    final ownerId = inviteData['inviter_uid']?.toString() ?? '';
    final notificationId = _groupInviteNotificationId(groupId);

    final updates = <String, dynamic>{
      '/groups_info/$groupId/pending_invites/${user.uid}': null,
      '/group_invites/${user.uid}/$groupId': null,
      '/user_notifications/${user.uid}/$notificationId/invite_status':
          'rejected',
      '/user_notifications/${user.uid}/$notificationId/read': true,
      '/user_notifications/${user.uid}/$notificationId/responded_at':
          ServerValue.timestamp,
    };

    if (ownerId.isNotEmpty && ownerId != user.uid) {
      updates['/user_notifications/$ownerId/group_invite_rejected_${groupId}_${user.uid}'] =
          {
            'type': 'group_invite_rejected',
            'group_id': groupId,
            'group_name': inviteData['group_name']?.toString() ?? '',
            'user_id': user.uid,
            'username': targetUsername,
            'timestamp': ServerValue.timestamp,
            'creator_id': user.uid,
            'read': false,
          };
    }

    await _dbRef.update(updates);
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
    for (int i = 0; i < 11; i++) {
      slots.add(DateFormat('HH:mm').format(time));
      time = time.add(const Duration(minutes: 75));
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

    final Map<String, dynamic> updates = {};
    final bookingPath = '/bookings/$newBookingKey';
    final userBookingPath = '/user_bookings/${booking.userId}/$newBookingKey';

    updates[bookingPath] = booking.toMap();
    updates[userBookingPath] = booking.toMap();
    if (booking.groupId != null && booking.groupId!.isNotEmpty) {
      updates['/group_bookings/${booking.groupId}/$newBookingKey'] = booking
          .toMap();
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

  Future<Set<String>> _getGroupMemberIds(String groupId) async {
    if (groupId.isEmpty) {
      return <String>{};
    }

    final groupSnapshot = await _dbRef
        .child('groups_info')
        .child(groupId)
        .get();
    if (!groupSnapshot.exists || groupSnapshot.value == null) {
      return <String>{};
    }

    final groupData = Map<String, dynamic>.from(groupSnapshot.value as Map);
    return <String>{
      ..._extractIds(groupData['members']),
      ..._extractIds(groupData['membri']),
      ..._extractIds(groupData['users']),
      ..._extractIds(groupData['user_ids']),
      ..._extractIds(groupData['member_nicknames']),
    };
  }

  Future<Map<String, dynamic>> _buildBookingDeletionUpdates(
    String bookingId, {
    Map<String, dynamic>? bookingDataOverride,
    Set<String>? notificationMemberIds,
  }) async {
    final bookingData =
        bookingDataOverride ?? await _loadBookingData(bookingId);
    if (bookingData == null) {
      return <String, dynamic>{};
    }

    final bookingOwnerId = bookingData['user_id']?.toString();
    final bookingDate = bookingData['data']?.toString();
    final groupId = bookingData['group_id']?.toString();
    if (bookingOwnerId == null ||
        bookingOwnerId.isEmpty ||
        bookingDate == null ||
        bookingDate.isEmpty) {
      throw Exception('Prenotazione non valida o incompleta');
    }

    final updates = <String, dynamic>{
      '/bookings/$bookingId': null,
      '/user_bookings/$bookingOwnerId/$bookingId': null,
    };

    if (groupId != null && groupId.isNotEmpty) {
      updates['/group_bookings/$groupId/$bookingId'] = null;
      updates['/group_booking_notifications/$groupId/$bookingId'] = null;

      final memberIds =
          notificationMemberIds ?? await _getGroupMemberIds(groupId);
      for (final memberId in memberIds) {
        updates['/user_notifications/$memberId/$bookingId'] = null;
      }
    }

    final slotsToFree = await _findSlotsByBookingId(bookingDate, bookingId);
    for (final key in slotsToFree.keys) {
      updates['/slots/$bookingDate/$key/status'] = 'libero';
      updates['/slots/$bookingDate/$key/booked_by'] = null;
      updates['/slots/$bookingDate/$key/booking_id'] = null;
      updates['/slots/$bookingDate/$key/is_jam'] = null;
    }

    return updates;
  }

  Future<Map<String, dynamic>?> _loadBookingData(String bookingId) async {
    final bookingSnapshot = await _dbRef
        .child('bookings')
        .child(bookingId)
        .get();
    if (!bookingSnapshot.exists || bookingSnapshot.value == null) {
      return null;
    }

    return Map<String, dynamic>.from(bookingSnapshot.value as Map);
  }

  // --- ELIMINAZIONE PRENOTAZIONE ---

  Future<void> deleteBooking(String bookingId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("Utente non loggato");
    }

    debugPrint("Inizio cancellazione prenotazione: $bookingId");

    final bookingSnapshot = await _dbRef
        .child('bookings')
        .child(bookingId)
        .get();
    if (!bookingSnapshot.exists || bookingSnapshot.value == null) {
      return;
    }

    final bookingData = Map<String, dynamic>.from(bookingSnapshot.value as Map);
    final bookingOwnerId = bookingData['user_id'] as String?;

    if (bookingOwnerId == null) {
      throw Exception("Prenotazione non valida o incompleta");
    }

    if (bookingOwnerId != user.uid) {
      throw Exception("Puoi eliminare solo le tue prenotazioni.");
    }

    final updates = await _buildBookingDeletionUpdates(
      bookingId,
      bookingDataOverride: bookingData,
    );

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
    final newEndTime = _calculateEndTime(orderedSlots.last);
    final scheduleChanged =
        previousDate != date ||
        (bookingData['ora_inizio']?.toString() ?? '') != orderedSlots.first ||
        (bookingData['ora_fine']?.toString() ?? '') != newEndTime;
    final nextStatus = scheduleChanged
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
      '/bookings/$bookingId/numero_utenti': peopleCount,
      '/bookings/$bookingId/attrezzatura': trimmedEquipment,
      '/bookings/$bookingId/stato': nextStatus,
      '/user_bookings/$bookingOwnerId/$bookingId/data': date,
      '/user_bookings/$bookingOwnerId/$bookingId/ora_inizio':
          orderedSlots.first,
      '/user_bookings/$bookingOwnerId/$bookingId/ora_fine': newEndTime,
      '/user_bookings/$bookingOwnerId/$bookingId/group_id': groupId,
      '/user_bookings/$bookingOwnerId/$bookingId/numero_utenti': peopleCount,
      '/user_bookings/$bookingOwnerId/$bookingId/attrezzatura':
          trimmedEquipment,
      '/user_bookings/$bookingOwnerId/$bookingId/stato': nextStatus,
    };

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
  }

  Future<void> _notifyGroupMembers(
    String groupId,
    String bookingId,
    Booking booking,
  ) async {
    try {
      final groupSnapshot = await _dbRef
          .child('groups_info')
          .child(groupId)
          .get();

      final notificationPayload = {
        'type': 'booking_created',
        'booking_id': bookingId,
        'group_id': groupId,
        'creator_id': booking.userId,
        'data': booking.data,
        'ora_inizio': booking.oraInizio,
        'ora_fine': booking.oraFine,
        'timestamp': ServerValue.timestamp,
        'read': false,
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
          updates['/user_notifications/$memberId/$bookingId'] =
              notificationPayload;
        }
      }

      await _dbRef.update(updates);
    } catch (e) {
      debugPrint("Errore notifica gruppo $groupId per booking $bookingId: $e");
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
      '/user_notifications/$ownerId/$bookingId': {
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
      '/user_notifications/$ownerId/$bookingId': {
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
      updates['/user_notifications/$creatorId/$jamId'] = {
        'type': 'jam_approved',
        'jam_id': jamId,
        'data': jamData['data'],
        'ora_inizio': jamData['ora_inizio'],
        'ora_fine': jamData['ora_fine'],
        'timestamp': ServerValue.timestamp,
        'read': false,
      };
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
    final creatorId = jamData['creator_id']?.toString() ?? '';
    final updates = <String, dynamic>{
      '/jams/$jamId/stato': JamStatus.annullata.name,
      '/jams/$jamId/participants': null,
    };
    if (creatorId.isNotEmpty) {
      updates['/user_notifications/$creatorId/$jamId'] = {
        'type': 'jam_rejected',
        'jam_id': jamId,
        'data': jamData['data'],
        'ora_inizio': jamData['ora_inizio'],
        'ora_fine': jamData['ora_fine'],
        'timestamp': ServerValue.timestamp,
        'read': false,
      };
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
      '/jams/$jamId/persone_presenti': currentPresent > 0
          ? currentPresent - 1
          : 0,
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
    final oldSlots = previousDate.isEmpty
        ? <String, dynamic>{}
        : await _findSlotsByBookingId(previousDate, jamId);
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
      final data = Map<String, dynamic>.from(rawValue);
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
            ? Map<String, dynamic>.from(rawPayload)
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

  Future<void> createGroup(String name, {String description = ''}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utente non loggato');
    }

    final trimmedName = name.trim();
    final trimmedDescription = description.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Inserisci un nome gruppo');
    }

    final userSnapshot = await _dbRef.child('users').child(user.uid).get();
    final userData = userSnapshot.exists && userSnapshot.value != null
        ? Map<String, dynamic>.from(userSnapshot.value as Map)
        : <String, dynamic>{};
    final nickname =
        userData['username']?.toString() ??
        userData['nickname']?.toString() ??
        user.uid;

    final groupId = _dbRef.child('groups_info').push().key;
    if (groupId == null) {
      throw Exception('Impossibile creare il gruppo');
    }

    await _dbRef.update({
      '/groups_info/$groupId': {
        'name': trimmedName,
        'description': trimmedDescription,
        'owner_id': user.uid,
        'created_at': ServerValue.timestamp,
        'members': {user.uid: true},
        'member_nicknames': {user.uid: nickname},
      },
      '/users/${user.uid}/gruppi/$groupId': true,
    });
  }

  Future<void> removeUserFromGroup({
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
      throw Exception('Solo il proprietario del gruppo puo rimuovere membri');
    }

    if (targetUserId == ownerId) {
      throw Exception('Il proprietario non puo essere rimosso dal gruppo');
    }

    final members = _extractIds(groupData['members']);
    if (!members.contains(targetUserId)) {
      throw Exception('Utente non presente nel gruppo');
    }

    await _dbRef.update({
      '/groups_info/$groupId/members/$targetUserId': null,
      '/groups_info/$groupId/member_nicknames/$targetUserId': null,
      '/users/$targetUserId/gruppi/$groupId': null,
    });
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

    await _dbRef.update({
      '/groups_info/$groupId/members/${user.uid}': null,
      '/groups_info/$groupId/member_nicknames/${user.uid}': null,
      '/users/${user.uid}/gruppi/$groupId': null,
    });
  }

  Future<void> deleteGroup(String groupId) async {
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
      throw Exception(
        'Solo il proprietario o un admin puo eliminare il gruppo',
      );
    }

    final memberIds = <String>{
      ..._extractIds(groupData['members']),
      ..._extractIds(groupData['member_nicknames']),
    };
    final pendingInviteIds = _extractIds(groupData['pending_invites']);

    final groupBookingsSnapshot = await _dbRef
        .child('group_bookings')
        .child(groupId)
        .get();

    final updates = <String, dynamic>{
      '/groups_info/$groupId': null,
      '/group_bookings/$groupId': null,
      '/group_booking_notifications/$groupId': null,
    };

    if (groupBookingsSnapshot.exists && groupBookingsSnapshot.value is Map) {
      final rawBookings = Map<String, dynamic>.from(
        groupBookingsSnapshot.value as Map,
      );
      for (final entry in rawBookings.entries) {
        final rawBooking = entry.value;
        if (rawBooking is! Map) {
          continue;
        }

        final bookingUpdates = await _buildBookingDeletionUpdates(
          entry.key.toString(),
          bookingDataOverride: Map<String, dynamic>.from(rawBooking),
          notificationMemberIds: memberIds,
        );
        updates.addAll(bookingUpdates);
      }
    }

    for (final memberId in memberIds) {
      updates['/users/$memberId/gruppi/$groupId'] = null;
    }
    for (final invitedUserId in pendingInviteIds) {
      updates['/group_invites/$invitedUserId/$groupId'] = null;
      updates['/user_notifications/$invitedUserId/${_groupInviteNotificationId(groupId)}'] =
          null;
    }

    await _dbRef.update(updates);
  }

  Future<void> inviteUserToGroup({
    required String groupId,
    required String nickname,
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
    final targetNickname =
        targetUser['nickname']?.toString() ?? nickname.trim();
    if (targetUid.isEmpty) {
      throw Exception('Utente non valido');
    }

    final members = _extractIds(groupData['members']);
    if (members.contains(targetUid)) {
      throw Exception('Questo utente e gia nel gruppo');
    }
    final pendingInvites = _extractIds(groupData['pending_invites']);
    if (pendingInvites.contains(targetUid)) {
      throw Exception('Questo utente ha gia un invito pendente');
    }

    final inviterSnapshot = await _dbRef.child('users').child(user.uid).get();
    final inviterData =
        inviterSnapshot.exists && inviterSnapshot.value is Map
        ? Map<String, dynamic>.from(inviterSnapshot.value as Map)
        : <String, dynamic>{};
    final inviterUsername =
        inviterData['username']?.toString() ??
        inviterData['nickname']?.toString() ??
        user.displayName ??
        user.uid;
    final groupName = groupData['name']?.toString() ?? 'Gruppo';
    final notificationId = _groupInviteNotificationId(groupId);

    await _dbRef.update({
      '/groups_info/$groupId/pending_invites/$targetUid': targetNickname,
      '/group_invites/$targetUid/$groupId': {
        'group_id': groupId,
        'group_name': groupName,
        'inviter_uid': user.uid,
        'inviter_username': inviterUsername,
        'invited_username': targetNickname,
        'status': 'pending',
        'timestamp': ServerValue.timestamp,
      },
      '/user_notifications/$targetUid/$notificationId': {
        'type': 'group_invite',
        'group_id': groupId,
        'group_name': groupName,
        'inviter_uid': user.uid,
        'inviter_username': inviterUsername,
        'invited_username': targetNickname,
        'invite_status': 'pending',
        'timestamp': ServerValue.timestamp,
        'creator_id': user.uid,
        'read': false,
      },
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
      final participantIds = _extractIds(data['participants']);
      final isAdmin = await _isCurrentUserAdmin();

      if (creatorId != user.uid && !isAdmin) {
        throw Exception("Solo il creatore può eliminare questa Jam.");
      }

      final Map<String, dynamic> updates = {};

      // 1. Trova e rimuovi il post dal feed
      try {
        final feedSnapshot = await _dbRef
            .child('feed')
            .orderByChild('jam_id')
            .equalTo(jamId)
            .get();
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
          final allFeed = Map<String, dynamic>.from(
            allFeedSnapshot.value as Map,
          );
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
        final slotsSnapshot = await _dbRef
            .child('slots')
            .child(dateStr)
            .orderByChild('booking_id')
            .equalTo(jamId)
            .get();
        if (slotsSnapshot.exists && slotsSnapshot.value != null) {
          if (slotsSnapshot.value is Map) {
            slotsToFree = Map<String, dynamic>.from(slotsSnapshot.value as Map);
          } else if (slotsSnapshot.value is List) {
            // Handle potential list return (though unlikely with string keys)
            final list = slotsSnapshot.value as List;
            for (int i = 0; i < list.length; i++) {
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
        final allSlotsSnapshot = await _dbRef
            .child('slots')
            .child(dateStr)
            .get();
        if (allSlotsSnapshot.exists && allSlotsSnapshot.value != null) {
          final allSlots = Map<String, dynamic>.from(
            allSlotsSnapshot.value as Map,
          );
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

      for (final participantId in participantIds) {
        updates['/user_joined_jams/$participantId/$jamId'] = null;
      }

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
    if (incomingInvitesSnapshot.exists && incomingInvitesSnapshot.value is Map) {
      final rawInvites = Map<String, dynamic>.from(
        incomingInvitesSnapshot.value as Map,
      );
      incomingInviteGroupIds.addAll(rawInvites.keys.map((key) => key.toString()));
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
