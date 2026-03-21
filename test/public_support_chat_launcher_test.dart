import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/app/features/support_chat/support_chat_repository.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/web/public/public_support_chat_launcher.dart';

void main() {
  testWidgets('opens the public support chat dialog from the launcher', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          floatingActionButton: PublicSupportChatLauncher(
            guestSessionId: 'guest_test_session',
            repositoryFactory: (_) => _FakeGuestSupportChatRepository(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Chat assistenza'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.text('Scrivici dal sito e ricevi supporto in tempo reale.'),
      findsOneWidget,
    );
    expect(
      find.text('Puoi iniziare subito una chat con l\'assistenza.'),
      findsOneWidget,
    );
  });
}

class _FakeGuestSupportChatRepository implements SupportChatRepository {
  final StreamController<List<SupportChatConversation>> _chatController =
      StreamController<List<SupportChatConversation>>.broadcast();
  final StreamController<List<SupportChatMessage>> _messageController =
      StreamController<List<SupportChatMessage>>.broadcast();
  bool _disposed = false;

  @override
  String? get currentUserId => 'guest_test_session';

  @override
  bool get isGuestSession => true;

  @override
  Future<void> initializeSession() async {}

  @override
  Future<bool> isCurrentUserAdmin() async => false;

  @override
  Stream<List<SupportChatConversation>> watchVisibleChats({
    required bool isAdmin,
  }) {
    return Stream<List<SupportChatConversation>>.multi((emitter) {
      emitter.add(const <SupportChatConversation>[]);
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
  }) async => 'guest_test_session';

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
  Future<void> deleteEphemeralChat() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _chatController.close();
    await _messageController.close();
  }
}
