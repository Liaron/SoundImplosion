import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soundimplosion/app/features/support_chat/support_chat_repository.dart';
import 'package:soundimplosion/models/models.dart';

class SupportChatController extends ChangeNotifier {
  SupportChatController({SupportChatRepository? repository})
    : _repository = repository ?? FirebaseSupportChatRepository();

  final SupportChatRepository _repository;

  bool isLoading = true;
  bool isSubmitting = false;
  bool isAdmin = false;
  Object? error;
  List<SupportChatConversation> chats = const <SupportChatConversation>[];
  List<SupportChatMessage> messages = const <SupportChatMessage>[];
  String? selectedChatId;
  String? _preferredChatId;

  StreamSubscription<List<SupportChatConversation>>? _chatSubscription;
  StreamSubscription<List<SupportChatMessage>>? _messageSubscription;

  String? get currentUserId => _repository.currentUserId;
  bool get isGuestSession => _repository.isGuestSession;
  SupportChatConversation? get selectedChat {
    final chatId = selectedChatId;
    if (chatId == null) {
      return null;
    }

    for (final chat in chats) {
      if (chat.id == chatId) {
        return chat;
      }
    }
    return null;
  }

  bool get isAssignedToCurrentAdmin =>
      isAdmin && selectedChat?.assignedAdminId == currentUserId;

  bool get canReply {
    final chat = selectedChat;
    if (chat == null || !chat.isOpen) {
      return false;
    }
    if (!isAdmin) {
      return true;
    }
    return chat.assignedAdminId == currentUserId;
  }

  Future<void> initialize({String? initialChatId}) async {
    isLoading = true;
    error = null;
    _preferredChatId = initialChatId?.trim().isNotEmpty == true
        ? initialChatId!.trim()
        : null;
    notifyListeners();

    try {
      await _repository.initializeSession();
      isAdmin = await _repository.isCurrentUserAdmin();
      await _chatSubscription?.cancel();
      _chatSubscription = _repository
          .watchVisibleChats(isAdmin: isAdmin)
          .listen(_handleChatsUpdated, onError: _handleStreamError);
    } catch (streamError) {
      error = streamError;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectChat(String? chatId) async {
    if (selectedChatId == chatId) {
      if (chatId != null) {
        await _repository.markChatSeen(chatId);
      }
      return;
    }

    selectedChatId = chatId;
    messages = const <SupportChatMessage>[];
    notifyListeners();
    await _bindMessages(chatId);
  }

  Future<String> createChat({
    required String subject,
    required String initialMessage,
    String origin = 'app',
    String? guestDisplayName,
  }) async {
    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      final chatId = await _repository.createChat(
        subject: subject,
        message: initialMessage,
        origin: origin,
        guestDisplayName: guestDisplayName,
      );
      await selectChat(chatId);
      return chatId;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    final chatId = selectedChatId;
    if (chatId == null) {
      throw Exception('Seleziona una chat');
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      await _repository.sendMessage(chatId: chatId, text: text);
      await _repository.markChatSeen(chatId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> assignSelectedChatToMe() async {
    final chatId = selectedChatId;
    if (chatId == null) {
      return;
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      await _repository.assignToCurrentAdmin(chatId);
      await _repository.markChatSeen(chatId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> releaseSelectedChat() async {
    final chatId = selectedChatId;
    if (chatId == null) {
      return;
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      await _repository.releaseChat(chatId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> closeSelectedChat() async {
    final chatId = selectedChatId;
    if (chatId == null) {
      return;
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      await _repository.closeChat(chatId);
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> deleteEphemeralChat() {
    return _repository.deleteEphemeralChat();
  }

  void _handleChatsUpdated(List<SupportChatConversation> items) {
    chats = items;
    isLoading = false;
    error = null;

    final currentSelection = selectedChatId;
    final preferredChatId = _preferredChatId;
    final stillExists = currentSelection != null &&
        items.any((chat) => chat.id == currentSelection);
    final preferredExists = preferredChatId != null &&
        items.any((chat) => chat.id == preferredChatId);
    final nextSelection = preferredExists
        ? preferredChatId
        : (stillExists ? currentSelection : (items.isNotEmpty ? items.first.id : null));

    if (preferredExists && nextSelection == preferredChatId) {
      _preferredChatId = null;
    }

    if (nextSelection != selectedChatId) {
      selectedChatId = nextSelection;
      unawaited(_bindMessages(nextSelection));
    } else if (nextSelection != null) {
      unawaited(_repository.markChatSeen(nextSelection));
    }

    notifyListeners();
  }

  void _handleStreamError(Object streamError) {
    error = streamError;
    isLoading = false;
    notifyListeners();
  }

  Future<void> _bindMessages(String? chatId) async {
    await _messageSubscription?.cancel();
    messages = const <SupportChatMessage>[];

    if (chatId == null) {
      notifyListeners();
      return;
    }

    _messageSubscription = _repository.watchMessages(chatId).listen(
      (items) {
        messages = items;
        notifyListeners();
      },
      onError: (Object streamError) {
        error = streamError;
        notifyListeners();
      },
    );
    await _repository.markChatSeen(chatId);
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }
}