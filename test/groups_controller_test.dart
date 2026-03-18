import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/groups/groups_controller.dart';
import 'package:soundimplosion/app/features/groups/groups_repository.dart';

void main() {
  test('GroupsController loads groups from repository', () async {
    final repository = FakeGroupsRepository(
      items: [
        const GroupListItem(
          id: 'group-1',
          name: 'Band One',
          description: 'Desc',
          ownerId: 'user-1',
          memberNicknames: {'user-1': 'Mario'},
        ),
      ],
    );
    final controller = GroupsController(
      repository: repository,
      auth: FakeFirebaseAuth(user: FakeUser(uid: 'user-1')),
    );

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(controller.groups, hasLength(1));
    expect(controller.currentUserId, 'user-1');
    expect(controller.isAdmin, isFalse);

    controller.dispose();
  });

  test('GroupsController exposes admin role from repository', () async {
    final repository = FakeGroupsRepository(items: const [], isAdmin: true);
    final controller = GroupsController(
      repository: repository,
      auth: FakeFirebaseAuth(user: FakeUser(uid: 'admin-1')),
    );

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(controller.isAdmin, isTrue);

    controller.dispose();
  });

  test('GroupsController delegates create and invite actions', () async {
    final repository = FakeGroupsRepository(items: const []);
    final controller = GroupsController(
      repository: repository,
      auth: FakeFirebaseAuth(user: FakeUser(uid: 'user-1')),
    );

    await controller.createGroup('Band Two', description: 'New description');
    await controller.inviteUserToGroup(groupId: 'group-1', nickname: 'Luigi');
    await controller.removeUserFromGroup(
      groupId: 'group-1',
      targetUserId: 'user-2',
    );
    await controller.leaveGroup('group-1');
    await controller.deleteGroup('group-1');

    expect(repository.createdGroupNames, ['Band Two']);
    expect(repository.createdGroupDescriptions, ['New description']);
    expect(repository.invites, [
      {'groupId': 'group-1', 'nickname': 'Luigi'},
    ]);
    expect(repository.removedUsers, [
      {'groupId': 'group-1', 'targetUserId': 'user-2'},
    ]);
    expect(repository.leftGroupIds, ['group-1']);
    expect(repository.deletedGroupIds, ['group-1']);

    controller.dispose();
  });
}

class FakeGroupsRepository implements GroupsRepository {
  FakeGroupsRepository({required this.items, this.isAdmin = false});

  final List<GroupListItem> items;
  final bool isAdmin;
  final List<String> createdGroupNames = [];
  final List<String> createdGroupDescriptions = [];
  final List<Map<String, String>> invites = [];
  final List<Map<String, String>> removedUsers = [];
  final List<String> leftGroupIds = [];
  final List<String> deletedGroupIds = [];
  final List<Map<String, String>> revokedInvites = [];
  final List<Map<String, String>> updatedNotes = [];

  @override
  Future<void> createGroup(String name, {String description = ''}) async {
    createdGroupNames.add(name);
    createdGroupDescriptions.add(description);
  }

  @override
  Future<void> inviteUserToGroup({
    required String groupId,
    required String nickname,
  }) async {
    invites.add({'groupId': groupId, 'nickname': nickname});
  }

  @override
  Future<void> removeUserFromGroup({
    required String groupId,
    required String targetUserId,
  }) async {
    removedUsers.add({'groupId': groupId, 'targetUserId': targetUserId});
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    leftGroupIds.add(groupId);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    deletedGroupIds.add(groupId);
  }

  @override
  Future<void> revokeGroupInvite({
    required String groupId,
    required String targetUserId,
  }) async {
    revokedInvites.add({'groupId': groupId, 'targetUserId': targetUserId});
  }

  @override
  Future<void> updateGroupNotes({
    required String groupId,
    required String notes,
  }) async {
    updatedNotes.add({'groupId': groupId, 'notes': notes});
  }

  @override
  Future<List<DiscoveryUserProfile>> searchUserProfiles({
    String usernameQuery = '',
    String cityQuery = '',
    String instrumentQuery = '',
    String genreQuery = '',
  }) async {
    return const [];
  }

  @override
  Stream<List<GroupListItem>> watchUserGroups() {
    return Stream<List<GroupListItem>>.value(items);
  }

  @override
  Future<bool> isCurrentUserAdmin() async => isAdmin;
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  FakeFirebaseAuth({required this.user});

  final User? user;

  @override
  User? get currentUser => user;
}

class FakeUser extends Fake implements User {
  FakeUser({required this.uid});

  @override
  final String uid;
}
