import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soundimplosion/services/database_service.dart';

Map<String, dynamic> _safeStringMap(dynamic rawValue) {
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

class GroupListItem {
  const GroupListItem({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.memberNicknames,
    this.pendingInvites = const <GroupPendingInvite>[],
    this.inviteHistory = const <GroupInviteHistoryItem>[],
    this.recentActivity = const <GroupActivityItem>[],
    this.notes = '',
    this.createdAt = 0,
  });

  final String id;
  final String name;
  final String description;
  final String ownerId;
  final Map<String, String> memberNicknames;
  final List<GroupPendingInvite> pendingInvites;
  final List<GroupInviteHistoryItem> inviteHistory;
  final List<GroupActivityItem> recentActivity;
  final String notes;
  final int createdAt;

  bool isOwnedBy(String? userId) => userId != null && ownerId == userId;

  List<String> get memberNames => memberNicknames.values.toList()..sort();

  int get memberCount => memberNicknames.length;
  int get pendingInviteCount =>
      pendingInvites.where((invite) => !invite.isExpired).length;

  List<MapEntry<String, String>> get sortedMembers {
    final members = memberNicknames.entries.toList()
      ..sort((left, right) => left.value.compareTo(right.value));
    return members;
  }

  factory GroupListItem.fromMap(String id, Map<String, dynamic> map) {
    final nicknames = <String, String>{};
    final pendingInvites = <GroupPendingInvite>[];
    final inviteHistory = <GroupInviteHistoryItem>[];
    final recentActivity = <GroupActivityItem>[];
    final rawNicknames = map['member_nicknames'];
    if (rawNicknames is Map) {
      for (final entry in rawNicknames.entries) {
        nicknames[entry.key.toString()] =
            entry.value?.toString() ?? entry.key.toString();
      }
    }
    final rawPendingInvites = map['pending_invites'];
    if (rawPendingInvites is Map) {
      for (final entry in rawPendingInvites.entries) {
        pendingInvites.add(
          GroupPendingInvite.fromRaw(entry.key.toString(), entry.value),
        );
      }
    }
    final rawInviteHistory = map['invite_history'];
    if (rawInviteHistory is Map) {
      for (final entry in rawInviteHistory.entries) {
        inviteHistory.add(
          GroupInviteHistoryItem.fromRaw(entry.key.toString(), entry.value),
        );
      }
      inviteHistory.sort((left, right) => right.timestamp.compareTo(left.timestamp));
    }
    final rawRecentActivity = map['activity'];
    if (rawRecentActivity is Map) {
      for (final entry in rawRecentActivity.entries) {
        recentActivity.add(
          GroupActivityItem.fromRaw(entry.key.toString(), entry.value),
        );
      }
      recentActivity.sort((left, right) => right.timestamp.compareTo(left.timestamp));
    }

    return GroupListItem(
      id: id,
      name: map['name']?.toString() ?? 'Gruppo senza nome',
      description: map['description']?.toString() ?? '',
      ownerId: map['owner_id']?.toString() ?? '',
      memberNicknames: nicknames,
      notes: map['notes']?.toString() ?? '',
      createdAt: GroupActivityItem.parseTimestamp(map['created_at']),
      pendingInvites: pendingInvites,
      inviteHistory: inviteHistory,
      recentActivity: recentActivity,
    );
  }
}

class GroupPendingInvite {
  const GroupPendingInvite({
    required this.uid,
    required this.username,
    this.inviterUid = '',
    this.inviterUsername = '',
    this.invitedAt = 0,
    this.expiresAt = 0,
  });

  final String uid;
  final String username;
  final String inviterUid;
  final String inviterUsername;
  final int invitedAt;
  final int expiresAt;

  bool get isExpired => expiresAt > 0 && DateTime.now().millisecondsSinceEpoch > expiresAt;

  factory GroupPendingInvite.fromRaw(String uid, dynamic rawValue) {
    if (rawValue is Map) {
      final map = _safeStringMap(rawValue);
      return GroupPendingInvite(
        uid: uid,
        username: map['username']?.toString() ?? uid,
        inviterUid: map['inviter_uid']?.toString() ?? '',
        inviterUsername: map['inviter_username']?.toString() ?? '',
        invitedAt: GroupActivityItem.parseTimestamp(map['invited_at'] ?? map['timestamp']),
        expiresAt: GroupActivityItem.parseTimestamp(map['expires_at']),
      );
    }

    return GroupPendingInvite(uid: uid, username: rawValue?.toString() ?? uid);
  }
}

class GroupInviteHistoryItem {
  const GroupInviteHistoryItem({
    required this.id,
    required this.status,
    required this.username,
    required this.timestamp,
    this.actorUsername = '',
  });

  final String id;
  final String status;
  final String username;
  final int timestamp;
  final String actorUsername;

  factory GroupInviteHistoryItem.fromRaw(String id, dynamic rawValue) {
    if (rawValue is Map) {
      final map = _safeStringMap(rawValue);
      return GroupInviteHistoryItem(
        id: id,
        status: map['status']?.toString() ?? 'unknown',
        username: map['username']?.toString() ?? 'Utente',
        actorUsername: map['actor_username']?.toString() ?? '',
        timestamp: GroupActivityItem.parseTimestamp(map['timestamp']),
      );
    }

    return GroupInviteHistoryItem(
      id: id,
      status: 'unknown',
      username: rawValue?.toString() ?? 'Utente',
      timestamp: 0,
    );
  }
}

class GroupActivityItem {
  const GroupActivityItem({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
  });

  final String id;
  final String type;
  final String message;
  final int timestamp;

  static int parseTimestamp(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory GroupActivityItem.fromRaw(String id, dynamic rawValue) {
    if (rawValue is Map) {
      final map = _safeStringMap(rawValue);
      return GroupActivityItem(
        id: id,
        type: map['type']?.toString() ?? 'generic',
        message: map['message']?.toString() ?? 'Attivita di gruppo',
        timestamp: parseTimestamp(map['timestamp']),
      );
    }

    return GroupActivityItem(
      id: id,
      type: 'generic',
      message: rawValue?.toString() ?? 'Attivita di gruppo',
      timestamp: 0,
    );
  }
}

class DiscoveryUserProfile {
  const DiscoveryUserProfile({
    required this.uid,
    required this.username,
    this.city = '',
    this.bio = '',
    this.skillLevel = 'Non specificato',
    this.genres = const <String>[],
    this.instruments = const <String>[],
    this.availability = const <String>[],
  });

  final String uid;
  final String username;
  final String city;
  final String bio;
  final String skillLevel;
  final List<String> genres;
  final List<String> instruments;
  final List<String> availability;

  factory DiscoveryUserProfile.fromMap(Map<String, dynamic> map) {
    List<String> parseStringList(dynamic rawValue) {
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
      if (value.isNotEmpty) {
        return <String>[value];
      }
      return const <String>[];
    }

    return DiscoveryUserProfile(
      uid: map['uid']?.toString() ?? '',
      username: map['username']?.toString() ?? 'Utente',
      city: map['city']?.toString() ?? '',
      bio: map['bio']?.toString() ?? '',
      skillLevel: map['skill_level']?.toString() ?? 'Non specificato',
      genres: parseStringList(map['genres']),
      instruments: parseStringList(map['instruments']),
      availability: parseStringList(map['availability']),
    );
  }
}

abstract class GroupsRepository {
  Stream<List<GroupListItem>> watchUserGroups();
  Future<String> createGroup(String name, {String description = ''});
  Future<void> inviteUserToGroup({
    required String groupId,
    required String nickname,
  });
  Future<void> removeUserFromGroup({
    required String groupId,
    required String targetUserId,
  });
  Future<void> leaveGroup(String groupId);
  Future<void> deleteGroup(String groupId);
  Future<void> revokeGroupInvite({
    required String groupId,
    required String targetUserId,
  });
  Future<void> updateGroupNotes({
    required String groupId,
    required String notes,
  });
  Future<List<DiscoveryUserProfile>> searchUserProfiles({
    String usernameQuery = '',
    String cityQuery = '',
    String instrumentQuery = '',
    String genreQuery = '',
  });
  Future<bool> isCurrentUserAdmin();
}

class FirebaseGroupsRepository implements GroupsRepository {
  FirebaseGroupsRepository({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;

  GroupListItem? _groupFromRawValue(String id, dynamic rawValue) {
    if (rawValue is! Map) {
      return null;
    }

    final map = _safeStringMap(rawValue);
    if (map.isEmpty) {
      return null;
    }

    return GroupListItem.fromMap(id, map);
  }

  @override
  Stream<List<GroupListItem>> watchUserGroups() {
    final controller = StreamController<List<GroupListItem>>();
    final Map<String, GroupListItem> groups = {};
    StreamSubscription<dynamic>? groupIdsSubscription;
    StreamSubscription<dynamic>? allGroupsSubscription;
    final List<StreamSubscription<dynamic>> groupSubscriptions = [];

    void emit() {
      final items = groups.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      controller.add(items);
    }

    () async {
      final isAdmin = await _databaseService.isCurrentUserAdmin();
      if (isAdmin) {
        allGroupsSubscription = _databaseService.getAllGroupsStream().listen((
          event,
        ) {
          groups.clear();
          final value = event.snapshot.value;
          if (value is Map) {
            for (final entry in value.entries) {
              final group = _groupFromRawValue(
                entry.key.toString(),
                entry.value,
              );
              if (group != null) {
                groups[entry.key.toString()] = group;
              }
            }
          } else if (value != null) {
            debugPrint('watchUserGroups: groups_info payload ignorato perche non mappa');
          }
          emit();
        }, onError: controller.addError);
        return;
      }

      groupIdsSubscription = _databaseService.getUserGroupIdsStream().listen((
        event,
      ) async {
        for (final subscription in groupSubscriptions) {
          await subscription.cancel();
        }
        groupSubscriptions.clear();
        groups.clear();

        final rawData = event.snapshot.value;
        final groupIds = <String>[];
        if (rawData is Map) {
          groupIds.addAll(rawData.keys.map((key) => key.toString()));
        } else if (rawData is List) {
          for (int index = 0; index < rawData.length; index++) {
            if (rawData[index] != null) {
              groupIds.add(index.toString());
            }
          }
        }

        for (final groupId in groupIds) {
          final subscription = _databaseService
              .getGroupInfoStream(groupId)
              .listen((groupEvent) {
                final value = groupEvent.snapshot.value;
                if (value == null) {
                  groups.remove(groupId);
                } else {
                  try {
                    final group = _groupFromRawValue(groupId, value);
                    if (group == null) {
                      groups.remove(groupId);
                    } else {
                      groups[groupId] = group;
                    }
                  } catch (error) {
                    debugPrint('watchUserGroups: gruppo ignorato $groupId per errore di parsing: $error');
                  }
                }
                emit();
              }, onError: controller.addError);
          groupSubscriptions.add(subscription);
        }

        emit();
      }, onError: controller.addError);
    }();

    controller.onCancel = () async {
      await allGroupsSubscription?.cancel();
      await groupIdsSubscription?.cancel();
      for (final subscription in groupSubscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  @override
  Future<String> createGroup(String name, {String description = ''}) {
    return _databaseService.createGroup(name, description: description);
  }

  @override
  Future<void> inviteUserToGroup({
    required String groupId,
    required String nickname,
  }) {
    return _databaseService.inviteUserToGroup(
      groupId: groupId,
      nickname: nickname,
    );
  }

  @override
  Future<void> removeUserFromGroup({
    required String groupId,
    required String targetUserId,
  }) {
    return _databaseService.removeUserFromGroup(
      groupId: groupId,
      targetUserId: targetUserId,
    );
  }

  @override
  Future<void> leaveGroup(String groupId) {
    return _databaseService.leaveGroup(groupId);
  }

  @override
  Future<void> deleteGroup(String groupId) {
    return _databaseService.deleteGroup(groupId);
  }

  @override
  Future<void> revokeGroupInvite({
    required String groupId,
    required String targetUserId,
  }) {
    return _databaseService.revokeGroupInvite(
      groupId: groupId,
      targetUserId: targetUserId,
    );
  }

  @override
  Future<void> updateGroupNotes({
    required String groupId,
    required String notes,
  }) {
    return _databaseService.updateGroupNotes(groupId: groupId, notes: notes);
  }

  @override
  Future<List<DiscoveryUserProfile>> searchUserProfiles({
    String usernameQuery = '',
    String cityQuery = '',
    String instrumentQuery = '',
    String genreQuery = '',
  }) async {
    final items = await _databaseService.searchPublicUserProfiles(
      usernameQuery: usernameQuery,
      cityQuery: cityQuery,
      instrumentQuery: instrumentQuery,
      genreQuery: genreQuery,
    );
    return items.map(DiscoveryUserProfile.fromMap).toList();
  }

  @override
  Future<bool> isCurrentUserAdmin() {
    return _databaseService.isCurrentUserAdmin();
  }
}
