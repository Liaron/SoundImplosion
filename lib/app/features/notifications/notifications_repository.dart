import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:soundimplosion/services/database_service.dart';

enum NotificationCategory { bookings, jams, groups, system }

class NotificationRouteTarget {
  const NotificationRouteTarget({
    required this.pageIndex,
    this.bookingId,
    this.jamId,
    this.groupId,
  });

  final int pageIndex;
  final String? bookingId;
  final String? jamId;
  final String? groupId;

  bool get hasSpecificTarget =>
      (bookingId?.isNotEmpty ?? false) ||
      (jamId?.isNotEmpty ?? false) ||
      (groupId?.isNotEmpty ?? false);

  String toPayload() {
    return jsonEncode({
      'pageIndex': pageIndex,
      'bookingId': bookingId,
      'jamId': jamId,
      'groupId': groupId,
    });
  }

  static NotificationRouteTarget? fromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return null;
      }

      final map = Map<String, dynamic>.from(decoded);
      final pageIndex = map['pageIndex'];
      if (pageIndex is! int) {
        return null;
      }

      return NotificationRouteTarget(
        pageIndex: pageIndex,
        bookingId: map['bookingId']?.toString(),
        jamId: map['jamId']?.toString(),
        groupId: map['groupId']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

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
    this.proposalStatus,
    this.bookingId,
    this.jamId,
    this.expiresAt = 0,
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
  final String? proposalStatus;
  final String? bookingId;
  final String? jamId;
  final int expiresAt;

  NotificationCategory get category {
    switch (type) {
      case 'booking_created':
      case 'group_booking_modified':
      case 'group_booking_confirmed':
      case 'group_booking_cancelled':
      case 'booking_confirmed':
      case 'booking_cancelled':
      case 'admin_booking_created':
      case 'admin_booking_modified':
      case 'admin_booking_cancelled':
      case 'admin_booking_update_accepted':
      case 'admin_booking_update_rejected':
      case 'admin_booking_update_proposed':
      case 'booking_update_proposal':
        return NotificationCategory.bookings;
      case 'jam_approved':
      case 'jam_rejected':
      case 'group_jam_created':
      case 'group_jam_modified':
      case 'group_jam_approved':
      case 'group_jam_rejected':
      case 'admin_jam_created':
      case 'admin_jam_modified':
      case 'admin_jam_cancelled':
      case 'admin_jam_update_accepted':
      case 'admin_jam_update_rejected':
      case 'admin_jam_update_proposed':
      case 'jam_update_proposal':
        return NotificationCategory.jams;
      case 'group_invite':
      case 'group_invite_accepted':
      case 'group_invite_rejected':
        return NotificationCategory.groups;
      default:
        return NotificationCategory.system;
    }
  }

  NotificationRouteTarget get routeTarget {
    if (type.startsWith('admin_')) {
      return const NotificationRouteTarget(pageIndex: 4); // Admin panel
    }
    switch (category) {
      case NotificationCategory.bookings:
        return NotificationRouteTarget(
          pageIndex: 1,
          bookingId: bookingId ?? id,
        );
      case NotificationCategory.jams:
        return NotificationRouteTarget(pageIndex: 2, jamId: jamId ?? id);
      case NotificationCategory.groups:
        return NotificationRouteTarget(pageIndex: 3, groupId: groupId);
      case NotificationCategory.system:
        return const NotificationRouteTarget(pageIndex: 5);
    }
  }

  String get payload => routeTarget.toPayload();

  bool get isPendingGroupInvite =>
      type == 'group_invite' &&
      inviteStatus == 'pending' &&
      !isExpiredGroupInvite &&
      groupId != null &&
      groupId!.isNotEmpty;
    bool get isPendingBookingUpdateProposal =>
      type == 'booking_update_proposal' &&
      proposalStatus == 'pending' &&
      bookingId != null &&
      bookingId!.isNotEmpty;
    bool get isPendingJamUpdateProposal =>
      type == 'jam_update_proposal' &&
      proposalStatus == 'pending' &&
      jamId != null &&
      jamId!.isNotEmpty;
    bool get isPendingAction =>
      isPendingGroupInvite ||
      isPendingBookingUpdateProposal ||
      isPendingJamUpdateProposal;
  bool get isExpiredGroupInvite =>
      expiresAt > 0 && DateTime.now().millisecondsSinceEpoch > expiresAt;

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
    final proposalStatus = map['proposal_status']?.toString();
    final bookingId = map['booking_id']?.toString() ?? map['subject_id']?.toString();
    final jamId = map['jam_id']?.toString() ?? map['subject_id']?.toString();
    final expiresAt = _parseTimestamp(map['expires_at']);

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
      case 'group_booking_modified':
        title = 'Prenotazione di gruppo modificata';
        body = '${username ?? "Un utente"} ha modificato la prenotazione del $date alle $start.';
        break;
      case 'group_booking_confirmed':
        title = 'Prenotazione di gruppo confermata';
        body = 'La prenotazione di gruppo del $date alle $start e stata confermata.';
        break;
      case 'group_booking_cancelled':
        title = 'Prenotazione di gruppo annullata';
        body = 'La prenotazione di gruppo del $date alle $start e stata annullata.';
        break;
      case 'jam_approved':
        title = 'Jam approvata';
        body = 'La tua jam del $date alle $start e ora pubblicata.';
        break;
      case 'jam_rejected':
        title = 'Jam rifiutata';
        body = 'La tua jam del $date alle $start e stata annullata.';
        break;
      case 'group_jam_created':
        title = 'Nuova jam di gruppo';
        body = '${username ?? "Un utente"} ha creato la jam ${map['titolo']?.toString().trim().isNotEmpty == true ? '"${map['titolo']}" ' : ''}per il $date alle $start.';
        break;
      case 'group_jam_modified':
        title = 'Jam di gruppo modificata';
        body = '${username ?? "Un utente"} ha modificato la jam ${map['titolo']?.toString().trim().isNotEmpty == true ? '"${map['titolo']}" ' : ''}del $date alle $start.';
        break;
      case 'group_jam_approved':
        title = 'Jam di gruppo approvata';
        body = 'La jam di gruppo ${map['titolo']?.toString().trim().isNotEmpty == true ? '"${map['titolo']}" ' : ''}del $date alle $start e ora pubblicata.';
        break;
      case 'group_jam_rejected':
        title = 'Jam di gruppo annullata';
        body = 'La jam di gruppo ${map['titolo']?.toString().trim().isNotEmpty == true ? '"${map['titolo']}" ' : ''}del $date alle $start e stata annullata.';
        break;
      case 'admin_booking_created':
        title = 'Nuova richiesta di prenotazione';
        body = '${username ?? "Un utente"} ha richiesto una prenotazione per il $date alle $start.';
        break;
      case 'admin_booking_modified':
        title = 'Prenotazione modificata';
        body = '${username ?? "Un utente"} ha modificato la prenotazione del $date alle $start.';
        break;
      case 'admin_booking_cancelled':
        title = 'Prenotazione annullata';
        body = '${username ?? "Un utente"} ha annullato la prenotazione del $date alle $start.';
        break;
      case 'admin_booking_update_proposed':
        title = 'Proposta di modifica inviata';
        body = 'Hai inviato una proposta di modifica per la prenotazione del $date alle $start.';
        break;
      case 'admin_booking_update_accepted':
        title = 'Proposta prenotazione accettata';
        body = '${username ?? "L'utente"} ha accettato la proposta di modifica per la prenotazione del $date alle $start.';
        break;
      case 'admin_booking_update_rejected':
        title = 'Proposta prenotazione rifiutata';
        body = '${username ?? "L'utente"} ha rifiutato la proposta di modifica per la prenotazione del $date alle $start.';
        break;
      case 'booking_update_proposal':
        switch (proposalStatus) {
          case 'accepted':
            title = 'Modifica prenotazione accettata';
            body = 'Hai accettato la proposta di modifica per la prenotazione del $date alle $start.';
            break;
          case 'rejected':
            title = 'Modifica prenotazione rifiutata';
            body = 'Hai rifiutato la proposta di modifica per la prenotazione del $date alle $start.';
            break;
          default:
            title = 'Proposta modifica prenotazione';
            body = '${username ?? "Un admin"} propone di modificare la tua prenotazione del $date alle $start.';
        }
        break;
      case 'admin_jam_created':
        title = 'Nuova richiesta di Jam Session';
        body = '${username ?? "Un utente"} ha richiesto una Jam Session per il $date alle $start.';
        break;
      case 'admin_jam_modified':
        title = 'Jam Session modificata';
        body = '${username ?? "Un utente"} ha modificato la Jam Session del $date alle $start.';
        break;
      case 'admin_jam_cancelled':
        title = 'Jam Session annullata';
        body = '${username ?? "Un utente"} ha annullato la Jam Session del $date alle $start.';
        break;
      case 'admin_jam_update_proposed':
        title = 'Proposta di modifica inviata';
        body = 'Hai inviato una proposta di modifica per la jam del $date alle $start.';
        break;
      case 'admin_jam_update_accepted':
        title = 'Proposta jam accettata';
        body = '${username ?? "L'utente"} ha accettato la proposta di modifica per la jam del $date alle $start.';
        break;
      case 'admin_jam_update_rejected':
        title = 'Proposta jam rifiutata';
        body = '${username ?? "L'utente"} ha rifiutato la proposta di modifica per la jam del $date alle $start.';
        break;
      case 'jam_update_proposal':
        switch (proposalStatus) {
          case 'accepted':
            title = 'Modifica jam accettata';
            body = 'Hai accettato la proposta di modifica per la jam del $date alle $start.';
            break;
          case 'rejected':
            title = 'Modifica jam rifiutata';
            body = 'Hai rifiutato la proposta di modifica per la jam del $date alle $start.';
            break;
          default:
            title = 'Proposta modifica jam';
            body = '${username ?? "Un admin"} propone di modificare la tua jam del $date alle $start.';
        }
        break;
      case 'group_invite':
        title = 'Invito a un gruppo';
        body = inviteStatus == 'expired'
            ? 'L\'invito al gruppo ${groupName ?? 'selezionato'} e scaduto.'
            : '${inviterUsername ?? 'Un utente'} ti ha invitato nel gruppo ${groupName ?? 'selezionato'}.';
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
      proposalStatus: proposalStatus,
      bookingId: bookingId,
      jamId: jamId,
      expiresAt: expiresAt,
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
    this.bookingEnabled = true,
    this.jamEnabled = true,
    this.groupEnabled = true,
    this.systemCategoryEnabled = true,
  });

  final bool inAppEnabled;
  final bool systemEnabled;
  final bool bookingEnabled;
  final bool jamEnabled;
  final bool groupEnabled;
  final bool systemCategoryEnabled;

  bool allowsCategory(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.bookings:
        return bookingEnabled;
      case NotificationCategory.jams:
        return jamEnabled;
      case NotificationCategory.groups:
        return groupEnabled;
      case NotificationCategory.system:
        return systemCategoryEnabled;
    }
  }

  NotificationPreferences copyWith({
    bool? inAppEnabled,
    bool? systemEnabled,
    bool? bookingEnabled,
    bool? jamEnabled,
    bool? groupEnabled,
    bool? systemCategoryEnabled,
  }) {
    return NotificationPreferences(
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      systemEnabled: systemEnabled ?? this.systemEnabled,
      bookingEnabled: bookingEnabled ?? this.bookingEnabled,
      jamEnabled: jamEnabled ?? this.jamEnabled,
      groupEnabled: groupEnabled ?? this.groupEnabled,
      systemCategoryEnabled:
          systemCategoryEnabled ?? this.systemCategoryEnabled,
    );
  }
}

abstract class NotificationsRepository {
  Stream<List<AppNotificationItem>> watchNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String notificationId);
  Future<void> deleteSelectedNotifications(List<String> notificationIds);
  Future<void> deleteAllNotifications();
  Future<void> acceptGroupInvite(String groupId);
  Future<void> rejectGroupInvite(String groupId);
  Future<void> acceptBookingUpdateProposal(String notificationId);
  Future<void> rejectBookingUpdateProposal(String notificationId);
  Future<void> acceptJamUpdateProposal(String notificationId);
  Future<void> rejectJamUpdateProposal(String notificationId);
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
  Future<void> deleteNotification(String notificationId) {
    return _databaseService.deleteUserNotification(notificationId);
  }

  @override
  Future<void> deleteSelectedNotifications(List<String> notificationIds) {
    return _databaseService.deleteSelectedUserNotifications(notificationIds);
  }

  @override
  Future<void> deleteAllNotifications() {
    return _databaseService.deleteAllUserNotifications();
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
  Future<void> acceptBookingUpdateProposal(String notificationId) {
    return _databaseService.acceptBookingUpdateProposal(notificationId);
  }

  @override
  Future<void> rejectBookingUpdateProposal(String notificationId) {
    return _databaseService.rejectBookingUpdateProposal(notificationId);
  }

  @override
  Future<void> acceptJamUpdateProposal(String notificationId) {
    return _databaseService.acceptJamUpdateProposal(notificationId);
  }

  @override
  Future<void> rejectJamUpdateProposal(String notificationId) {
    return _databaseService.rejectJamUpdateProposal(notificationId);
  }

  @override
  Future<NotificationPreferences> loadPreferences() async {
    final map = await _databaseService.getNotificationPreferences();
    return NotificationPreferences(
      inAppEnabled: map['in_app_enabled'] != false,
      systemEnabled: map['system_enabled'] != false,
      bookingEnabled: map['booking_enabled'] != false,
      jamEnabled: map['jam_enabled'] != false,
      groupEnabled: map['group_enabled'] != false,
      systemCategoryEnabled: map['system_category_enabled'] != false,
    );
  }

  @override
  Future<void> savePreferences(NotificationPreferences preferences) {
    return _databaseService.saveNotificationPreferences({
      'in_app_enabled': preferences.inAppEnabled,
      'system_enabled': preferences.systemEnabled,
      'booking_enabled': preferences.bookingEnabled,
      'jam_enabled': preferences.jamEnabled,
      'group_enabled': preferences.groupEnabled,
      'system_category_enabled': preferences.systemCategoryEnabled,
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
