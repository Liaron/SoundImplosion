import 'package:firebase_database/firebase_database.dart';
import 'package:soundimplosion/services/database_service.dart';

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.title,
    required this.body,
    this.isRead = false,
    this.groupId,
    this.groupName,
    this.inviterUsername,
    this.username,
    this.inviteStatus,
  });

  final String id;
  final String type;
  final int timestamp;
  final String title;
  final String body;
  final bool isRead;
  final String? groupId;
  final String? groupName;
  final String? inviterUsername;
  final String? username;
  final String? inviteStatus;

  bool get isPendingGroupInvite =>
      type == 'group_invite' &&
      inviteStatus == 'pending' &&
      groupId != null &&
      groupId!.isNotEmpty;

  factory AppNotificationItem.fromMap(String id, Map<String, dynamic> map) {
    final type = map['type']?.toString() ?? 'generic';
    final date = map['data']?.toString() ?? '';
    final start = map['ora_inizio']?.toString() ?? '';
    final end = map['ora_fine']?.toString() ?? '';
    final groupId = map['group_id']?.toString();
    final groupName = map['group_name']?.toString();
    final inviterUsername = map['inviter_username']?.toString();
    final username = map['username']?.toString();
    final inviteStatus = map['invite_status']?.toString();

    String title;
    String body;
    switch (type) {
      case 'booking_created':
        title = 'Nuova prenotazione di gruppo';
        body =
            'Nuova prenotazione per $date $start${end.isNotEmpty ? ' - $end' : ''}';
        break;
      case 'booking_confirmed':
        title = 'Prenotazione confermata';
        body = 'La tua prenotazione del $date alle $start e stata confermata.';
        break;
      case 'booking_cancelled':
        title = 'Prenotazione annullata';
        body = 'La tua prenotazione del $date alle $start e stata annullata.';
        break;
      case 'jam_approved':
        title = 'Jam approvata';
        body = 'La tua jam del $date alle $start e ora pubblicata.';
        break;
      case 'jam_rejected':
        title = 'Jam rifiutata';
        body = 'La tua jam del $date alle $start e stata annullata.';
        break;
      case 'group_invite':
        title = 'Invito a un gruppo';
        body =
            '${inviterUsername ?? 'Un utente'} ti ha invitato nel gruppo ${groupName ?? 'selezionato'}.';
        break;
      case 'group_invite_accepted':
        title = 'Invito gruppo accettato';
        body =
            "${username ?? 'Un utente'} ha accettato l'invito al gruppo ${groupName ?? 'selezionato'}.";
        break;
      case 'group_invite_rejected':
        title = 'Invito gruppo rifiutato';
        body =
            "${username ?? 'Un utente'} ha rifiutato l'invito al gruppo ${groupName ?? 'selezionato'}.";
        break;
      default:
        title = 'Nuova notifica';
        body = map['message']?.toString() ?? 'Hai una nuova notifica.';
    }

    return AppNotificationItem(
      id: id,
      type: type,
      timestamp: _parseTimestamp(map['timestamp']),
      title: title,
      body: body,
      isRead: map['read'] == true,
      groupId: groupId,
      groupName: groupName,
      inviterUsername: inviterUsername,
      username: username,
      inviteStatus: inviteStatus,
    );
  }

  static int _parseTimestamp(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    this.inAppEnabled = true,
    this.systemEnabled = true,
  });

  final bool inAppEnabled;
  final bool systemEnabled;

  NotificationPreferences copyWith({bool? inAppEnabled, bool? systemEnabled}) {
    return NotificationPreferences(
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      systemEnabled: systemEnabled ?? this.systemEnabled,
    );
  }
}

abstract class NotificationsRepository {
  Stream<List<AppNotificationItem>> watchNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> acceptGroupInvite(String groupId);
  Future<void> rejectGroupInvite(String groupId);
  Future<NotificationPreferences> loadPreferences();
  Future<void> savePreferences(NotificationPreferences preferences);
}

class FirebaseNotificationsRepository implements NotificationsRepository {
  FirebaseNotificationsRepository({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;

  @override
  Stream<List<AppNotificationItem>> watchNotifications() {
    return _databaseService.getUserNotificationsStream().map((event) {
      return _parseNotifications(event.snapshot);
    });
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return _databaseService.markUserNotificationRead(notificationId);
  }

  @override
  Future<void> markAllAsRead() {
    return _databaseService.markAllUserNotificationsRead();
  }

  @override
  Future<void> acceptGroupInvite(String groupId) {
    return _databaseService.acceptGroupInvite(groupId);
  }

  @override
  Future<void> rejectGroupInvite(String groupId) {
    return _databaseService.rejectGroupInvite(groupId);
  }

  @override
  Future<NotificationPreferences> loadPreferences() async {
    final map = await _databaseService.getNotificationPreferences();
    return NotificationPreferences(
      inAppEnabled: map['in_app_enabled'] != false,
      systemEnabled: map['system_enabled'] != false,
    );
  }

  @override
  Future<void> savePreferences(NotificationPreferences preferences) {
    return _databaseService.saveNotificationPreferences({
      'in_app_enabled': preferences.inAppEnabled,
      'system_enabled': preferences.systemEnabled,
    });
  }

  List<AppNotificationItem> _parseNotifications(DataSnapshot snapshot) {
    final items = <AppNotificationItem>[];
    final rawData = snapshot.value;

    if (rawData is Map) {
      final data = Map<String, dynamic>.from(rawData);
      for (final entry in data.entries) {
        if (entry.value is! Map) {
          continue;
        }
        items.add(
          AppNotificationItem.fromMap(
            entry.key.toString(),
            Map<String, dynamic>.from(entry.value as Map),
          ),
        );
      }
    } else if (rawData is List) {
      for (int index = 0; index < rawData.length; index++) {
        final item = rawData[index];
        if (item is! Map) {
          continue;
        }
        items.add(
          AppNotificationItem.fromMap(
            index.toString(),
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }
}
