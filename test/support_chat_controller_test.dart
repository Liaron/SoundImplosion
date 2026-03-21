import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/support_chat/support_chat_controller.dart';
import 'package:soundimplosion/app/features/support_chat/support_chat_repository.dart';
import 'package:soundimplosion/models/models.dart';

void main() {
  group('SupportChatController', () {
    test('initialize selects first visible chat', () async {
      final repository = _FakeSupportChatRepository(
        isAdmin: false,
        chats: [
          _chat(id: 'chat-1', subject: 'Prima richiesta'),
          _chat(id: 'chat-2', subject: 'Seconda richiesta'),
        ],
      );
      final controller = SupportChatController(repository: repository);

      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(controller.isAdmin, isFalse);
      expect(controller.selectedChatId, 'chat-1');
      expect(controller.canReply, isTrue);

      controller.dispose();
      await repository.dispose();
    });

    test('initialize prefers requested chat when available', () async {
      final repository = _FakeSupportChatRepository(
        isAdmin: true,
        chats: [
          _chat(id: 'chat-1', subject: 'Prima richiesta'),
          _chat(id: 'chat-2', subject: 'Seconda richiesta'),
        ],
      );
      final controller = SupportChatController(repository: repository);

      await controller.initialize(initialChatId: 'chat-2');
      await Future<void>.delayed(Duration.zero);

      expect(controller.selectedChatId, 'chat-2');

      controller.dispose();
      await repository.dispose();
    });

    test('admin must assign chat before replying', () async {
      final repository = _FakeSupportChatRepository(
        isAdmin: true,
        chats: [_chat(id: 'chat-1', assignedAdminId: null)],
      );
      final controller = SupportChatController(repository: repository);

      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(controller.canReply, isFalse);

      repository.emitChats([
        _chat(
          id: 'chat-1',
          assignedAdminId: repository.currentUserId,
          assignedAdminNickname: 'Admin Test',
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(controller.canReply, isTrue);

      controller.dispose();
      await repository.dispose();
    });

    test('createChat selects created conversation', () async {
      final repository = _FakeSupportChatRepository(
        isAdmin: false,
        chats: const <SupportChatConversation>[],
      );
      final controller = SupportChatController(repository: repository);

      await controller.initialize();
      await Future<void>.delayed(Duration.zero);
      await controller.createChat(
        subject: 'Nuovo ticket',
        initialMessage: 'Ho bisogno di aiuto',
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.selectedChatId, 'created-chat');
      expect(controller.chats, hasLength(1));

      controller.dispose();
      await repository.dispose();
    });
  });
}

class _FakeSupportChatRepository implements SupportChatRepository {
  _FakeSupportChatRepository({
    required this.isAdmin,
    required List<SupportChatConversation> chats,
  }) : _currentChats = chats {
    _chatController.add(_currentChats);
  }

  final bool isAdmin;

  final StreamController<List<SupportChatConversation>> _chatController =
      StreamController<List<SupportChatConversation>>.broadcast();
  final StreamController<List<SupportChatMessage>> _messageController =
      StreamController<List<SupportChatMessage>>.broadcast();

  List<SupportChatConversation> _currentChats;

  @override
  String? get currentUserId => 'admin-1';

  @override
  bool get isGuestSession => false;

  @override
  Future<void> initializeSession() async {}

  @override
  Future<bool> isCurrentUserAdmin() async => isAdmin;

  @override
  Stream<List<SupportChatConversation>> watchVisibleChats({
    required bool isAdmin,
  }) {
    return Stream<List<SupportChatConversation>>.multi((emitter) {
      emitter.add(_currentChats);
      final subscription = _chatController.stream.listen(
        emitter.add,
        onError: emitter.addError,
      );
      emitter.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<SupportChatMessage>> watchMessages(String chatId) {
    return Stream<List<SupportChatMessage>>.multi((emitter) {
      emitter.add(const <SupportChatMessage>[]);
      final subscription = _messageController.stream.listen(
        emitter.add,
        onError: emitter.addError,
      );
      emitter.onCancel = subscription.cancel;
    });
  }

  @override
  Future<String> createChat({
    required String subject,
    required String message,
    String origin = 'app',
    String? guestDisplayName,
  }) async {
    final created = _chat(id: 'created-chat', subject: subject);
    _currentChats = [created, ..._currentChats];
    _chatController.add(_currentChats);
    return created.id;
  }

  @override
  Future<void> sendMessage({required String chatId, required String text}) async {}

  @override
  Future<void> assignToCurrentAdmin(String chatId) async {}

  @override
  Future<void> releaseChat(String chatId) async {}

  @override
  Future<void> closeChat(String chatId) async {}

  @override
  Future<void> markChatSeen(String chatId) async {}

  @override
  Future<void> deleteEphemeralChat() async {}

  void emitChats(List<SupportChatConversation> chats) {
    _currentChats = chats;
    _chatController.add(chats);
  }

  Future<void> dispose() async {
    await _chatController.close();
    await _messageController.close();
  }
}

SupportChatConversation _chat({
  required String id,
  String subject = 'Supporto',
  String? assignedAdminId,
  String? assignedAdminNickname,
}) {
  return SupportChatConversation(
    id: id,
    userId: 'user-1',
    userNickname: 'Utente Test',
    userEmail: 'utente@test.it',
    subject: subject,
    status: SupportChatStatus.open,
    createdAt: 1,
    updatedAt: 2,
    lastMessageAt: 2,
    lastMessageText: 'Messaggio iniziale',
    lastSenderRole: 'user',
    lastSenderId: 'user-1',
    assignedAdminId: assignedAdminId,
    assignedAdminNickname: assignedAdminNickname,
    unreadForAdmin: true,
    unreadForUser: false,
  );
}
