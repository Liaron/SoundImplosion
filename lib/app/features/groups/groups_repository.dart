import 'dart:async';

import 'package:soundimplosion/services/database_service.dart';

class GroupListItem {
  const GroupListItem({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberNicknames,
  });

  final String id;
  final String name;
  final String ownerId;
  final Map<String, String> memberNicknames;

  bool isOwnedBy(String? userId) => userId != null && ownerId == userId;

  List<String> get memberNames => memberNicknames.values.toList()..sort();

  factory GroupListItem.fromMap(String id, Map<String, dynamic> map) {
    final nicknames = <String, String>{};
    final rawNicknames = map['member_nicknames'];
    if (rawNicknames is Map) {
      for (final entry in rawNicknames.entries) {
        nicknames[entry.key.toString()] = entry.value?.toString() ?? entry.key.toString();
      }
    }

    return GroupListItem(
      id: id,
      name: map['name']?.toString() ?? 'Gruppo senza nome',
      ownerId: map['owner_id']?.toString() ?? '',
      memberNicknames: nicknames,
    );
  }
}

abstract class GroupsRepository {
  Stream<List<GroupListItem>> watchUserGroups();
  Future<void> createGroup(String name);
  Future<void> inviteUserToGroup({required String groupId, required String nickname});
  Future<bool> isCurrentUserAdmin();
}

class FirebaseGroupsRepository implements GroupsRepository {
  FirebaseGroupsRepository({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;

  @override
  Stream<List<GroupListItem>> watchUserGroups() {
    final controller = StreamController<List<GroupListItem>>();
    final Map<String, GroupListItem> groups = {};
    StreamSubscription<dynamic>? groupIdsSubscription;
    StreamSubscription<dynamic>? allGroupsSubscription;
    final List<StreamSubscription<dynamic>> groupSubscriptions = [];

    void emit() {
      final items = groups.values.toList()..sort((a, b) => a.name.compareTo(b.name));
      controller.add(items);
    }

    () async {
      final isAdmin = await _databaseService.isCurrentUserAdmin();
      if (isAdmin) {
        allGroupsSubscription = _databaseService.getAllGroupsStream().listen(
          (event) {
            groups.clear();
            final value = event.snapshot.value;
            if (value is Map) {
              for (final entry in value.entries) {
                groups[entry.key.toString()] = GroupListItem.fromMap(
                  entry.key.toString(),
                  Map<String, dynamic>.from(entry.value as Map),
                );
              }
            }
            emit();
          },
          onError: controller.addError,
        );
        return;
      }

      groupIdsSubscription = _databaseService.getUserGroupIdsStream().listen(
        (event) async {
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
            final subscription = _databaseService.getGroupInfoStream(groupId).listen(
              (groupEvent) {
                final value = groupEvent.snapshot.value;
                if (value == null) {
                  groups.remove(groupId);
                } else {
                  groups[groupId] = GroupListItem.fromMap(groupId, Map<String, dynamic>.from(value as Map));
                }
                emit();
              },
              onError: controller.addError,
            );
            groupSubscriptions.add(subscription);
          }

          emit();
        },
        onError: controller.addError,
      );
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
  Future<void> createGroup(String name) {
    return _databaseService.createGroup(name);
  }

  @override
  Future<void> inviteUserToGroup({required String groupId, required String nickname}) {
    return _databaseService.inviteUserToGroup(groupId: groupId, nickname: nickname);
  }

  @override
  Future<bool> isCurrentUserAdmin() {
    return _databaseService.isCurrentUserAdmin();
  }
}