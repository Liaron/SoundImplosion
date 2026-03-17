import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soundimplosion/app/features/groups/groups_repository.dart';

class GroupsController extends ChangeNotifier {
  GroupsController({GroupsRepository? repository, FirebaseAuth? auth})
    : _repository = repository ?? FirebaseGroupsRepository(),
      _auth = auth ?? FirebaseAuth.instance;

  final GroupsRepository _repository;
  final FirebaseAuth _auth;

  bool isLoading = true;
  bool isSubmitting = false;
  bool isAdmin = false;
  Object? error;
  List<GroupListItem> groups = [];

  String? get currentUserId => _auth.currentUser?.uid;

  StreamSubscription<List<GroupListItem>>? _subscription;

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    notifyListeners();

    isAdmin = await _repository.isCurrentUserAdmin();

    _subscription = _repository.watchUserGroups().listen(
      (items) {
        groups = items;
        isLoading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object streamError) {
        error = streamError;
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> createGroup(String name, {String description = ''}) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.createGroup(name, description: description);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> inviteUserToGroup({
    required String groupId,
    required String nickname,
  }) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.inviteUserToGroup(groupId: groupId, nickname: nickname);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> removeUserFromGroup({
    required String groupId,
    required String targetUserId,
  }) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.removeUserFromGroup(
        groupId: groupId,
        targetUserId: targetUserId,
      );
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> leaveGroup(String groupId) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.leaveGroup(groupId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> deleteGroup(String groupId) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.deleteGroup(groupId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
