import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:soundimplosion/models/models.dart';
import 'package:soundimplosion/services/database_service.dart';

abstract class SupportChatRepository {
  String? get currentUserId;
  bool get isGuestSession;

  Future<void> initializeSession();
  Future<bool> isCurrentUserAdmin();
  Stream<List<SupportChatConversation>> watchVisibleChats({
    required bool isAdmin,
  });
  Stream<List<SupportChatMessage>> watchMessages(String chatId);
  Future<String> createChat({
    required String subject,
    required String message,
    String origin,
    String? guestDisplayName,
  });
  Future<void> sendMessage({required String chatId, required String text});
  Future<void> assignToCurrentAdmin(String chatId);
  Future<void> releaseChat(String chatId);
  Future<void> closeChat(String chatId);
  Future<void> markChatSeen(String chatId);
  Future<void> deleteEphemeralChat();
}

class FirebaseSupportChatRepository implements SupportChatRepository {
  FirebaseSupportChatRepository({
    DatabaseService? databaseService,
    FirebaseAuth? auth,
    this.guestSessionId,
  }) : _databaseService = databaseService ?? DatabaseService(),
       _auth = auth ?? FirebaseAuth.instance;

  final DatabaseService _databaseService;
  final FirebaseAuth _auth;
  final String? guestSessionId;

  @override
  String? get currentUserId => _auth.currentUser?.uid ?? guestSessionId;

  @override
  bool get isGuestSession =>
      guestSessionId?.trim().isNotEmpty == true && _auth.currentUser == null;

  @override
  Future<void> initializeSession() async {
    if (!isGuestSession) {
      return;
    }

    await _databaseService.registerGuestSupportChatDisconnectCleanup(
      guestSessionId!,
    );
  }

  @override
  Future<bool> isCurrentUserAdmin() {
    if (isGuestSession) {
      return Future<bool>.value(false);
    }
    return _databaseService.isCurrentUserAdmin();
  }

  @override
  Stream<List<SupportChatConversation>> watchVisibleChats({
    required bool isAdmin,
  }) {
    final source = isAdmin
        ? _databaseService.getOpenSupportChatsStream()
        : (isGuestSession
              ? _databaseService.getGuestSupportChatStream(guestSessionId!)
              : _databaseService.getCurrentUserSupportChatsStream());
    return source.map((event) {
      final chats = (isGuestSession && !isAdmin
              ? _parseGuestChat(event.snapshot, guestSessionId!)
              : _parseChats(event.snapshot))
          .where((chat) => isAdmin ? chat.isOpen : true)
          .toList()
        ..sort((a, b) {
          final aTimestamp = a.lastMessageAt > 0 ? a.lastMessageAt : a.updatedAt;
          final bTimestamp = b.lastMessageAt > 0 ? b.lastMessageAt : b.updatedAt;
          return bTimestamp.compareTo(aTimestamp);
        });
      return chats;
    });
  }

  @override
  Stream<List<SupportChatMessage>> watchMessages(String chatId) {
    return _databaseService.getSupportChatMessagesStream(chatId).map((event) {
      final messages = _parseMessages(event.snapshot, chatId)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  @override
  Future<String> createChat({
    required String subject,
    required String message,
    String origin = 'app',
    String? guestDisplayName,
  }) {
    if (isGuestSession) {
      return _databaseService.createGuestSupportChat(
        sessionId: guestSessionId!,
        guestDisplayName: guestDisplayName,
        subject: subject,
        message: message,
        origin: origin,
      );
    }

    return _databaseService.createSupportChat(
      subject: subject,
      message: message,
      origin: origin,
    );
  }

  @override
  Future<void> sendMessage({required String chatId, required String text}) {
    if (isGuestSession) {
      return _databaseService.sendGuestSupportChatMessage(
        sessionId: guestSessionId!,
        text: text,
      );
    }
    return _databaseService.sendSupportChatMessage(chatId: chatId, text: text);
  }

  @override
  Future<void> assignToCurrentAdmin(String chatId) {
    return _databaseService.assignSupportChatToCurrentAdmin(chatId);
  }

  @override
  Future<void> releaseChat(String chatId) {
    return _databaseService.releaseSupportChat(chatId);
  }

  @override
  Future<void> closeChat(String chatId) {
    if (isGuestSession) {
      return _databaseService.deleteGuestSupportChat(guestSessionId!);
    }
    return _databaseService.closeSupportChat(chatId);
  }

  @override
  Future<void> markChatSeen(String chatId) {
    if (isGuestSession) {
      return _databaseService.markGuestSupportChatSeen(guestSessionId!);
    }
    return _databaseService.markSupportChatSeen(chatId);
  }

  @override
  Future<void> deleteEphemeralChat() async {
    if (!isGuestSession) {
      return;
    }
    await _databaseService.deleteGuestSupportChat(guestSessionId!);
  }

  List<SupportChatConversation> _parseChats(DataSnapshot snapshot) {
    final items = <SupportChatConversation>[];
    final rawData = snapshot.value;

    if (rawData is Map) {
      final data = Map<String, dynamic>.from(rawData);
      for (final entry in data.entries) {
        if (entry.value is! Map) {
          continue;
        }
        items.add(
          SupportChatConversation.fromMap(
            entry.key,
            Map<String, dynamic>.from(entry.value as Map),
          ),
        );
      }
      return items;
    }

    if (rawData is List) {
      for (var index = 0; index < rawData.length; index += 1) {
        final value = rawData[index];
        if (value is! Map) {
          continue;
        }
        items.add(
          SupportChatConversation.fromMap(
            index.toString(),
            Map<String, dynamic>.from(value),
          ),
        );
      }
    }

    return items;
  }

  List<SupportChatConversation> _parseGuestChat(
    DataSnapshot snapshot,
    String chatId,
  ) {
    if (!snapshot.exists || snapshot.value is! Map) {
      return const <SupportChatConversation>[];
    }

    return <SupportChatConversation>[
      SupportChatConversation.fromMap(
        chatId,
        Map<String, dynamic>.from(snapshot.value as Map),
      ),
    ];
  }

  List<SupportChatMessage> _parseMessages(DataSnapshot snapshot, String chatId) {
    final items = <SupportChatMessage>[];
    final rawData = snapshot.value;

    if (rawData is Map) {
      final data = Map<String, dynamic>.from(rawData);
      for (final entry in data.entries) {
        if (entry.value is! Map) {
          continue;
        }
        items.add(
          SupportChatMessage.fromMap(
            entry.key,
            chatId,
            Map<String, dynamic>.from(entry.value as Map),
          ),
        );
      }
      return items;
    }

    if (rawData is List) {
      for (var index = 0; index < rawData.length; index += 1) {
        final value = rawData[index];
        if (value is! Map) {
          continue;
        }
        items.add(
          SupportChatMessage.fromMap(
            index.toString(),
            chatId,
            Map<String, dynamic>.from(value),
          ),
        );
      }
    }

    return items;
  }
}