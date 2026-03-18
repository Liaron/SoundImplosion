import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soundimplosion/app/features/groups/groups_repository.dart';
import 'package:soundimplosion/services/app_telemetry_service.dart';

class GroupsController extends ChangeNotifier {
  GroupsController({GroupsRepository? repository, FirebaseAuth? auth})
    : _repository = repository ?? FirebaseGroupsRepository(),
      _auth = auth ?? FirebaseAuth.instance;

  final GroupsRepository _repository;
  final FirebaseAuth _auth;

  bool isLoading = true;
  bool isSubmitting = false;
  bool isSearchingProfiles = false;
  bool isAdmin = false;
  Object? error;
  List<GroupListItem> groups = [];
  List<DiscoveryUserProfile> discoveryResults = [];

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
      await AppTelemetryService.instance.logCreateGroup(
        hasDescription: description.trim().isNotEmpty,
      );
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
      await AppTelemetryService.instance.logInviteGroup();
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

  Future<void> revokeGroupInvite({
    required String groupId,
    required String targetUserId,
  }) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.revokeGroupInvite(
        groupId: groupId,
        targetUserId: targetUserId,
      );
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> updateGroupNotes({
    required String groupId,
    required String notes,
  }) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.updateGroupNotes(groupId: groupId, notes: notes);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> searchUserProfiles({
    String usernameQuery = '',
    String cityQuery = '',
    String instrumentQuery = '',
    String genreQuery = '',
  }) async {
    isSearchingProfiles = true;
    notifyListeners();
    try {
      discoveryResults = await _repository.searchUserProfiles(
        usernameQuery: usernameQuery,
        cityQuery: cityQuery,
        instrumentQuery: instrumentQuery,
        genreQuery: genreQuery,
      );
    } finally {
      isSearchingProfiles = false;
      notifyListeners();
    }
  }

  void clearDiscoveryResults() {
    discoveryResults = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
