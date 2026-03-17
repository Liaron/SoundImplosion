import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/app/features/notifications/notifications_controller.dart';
import 'package:soundimplosion/app/features/notifications/notifications_repository.dart';

class NotificationsPageMobile extends StatefulWidget {
  const NotificationsPageMobile({super.key});

  @override
  State<NotificationsPageMobile> createState() =>
      _NotificationsPageMobileState();
}

class _NotificationsPageMobileState extends State<NotificationsPageMobile> {
  final NotificationsController _controller = NotificationsController();
  final Set<String> _processingInvites = <String>{};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp <= 0) {
      return '';
    }
    return DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  Future<void> _markAllAsRead() async {
    await _controller.markAllAsRead();
  }

  Future<void> _respondToInvite(
    AppNotificationItem notification, {
    required bool accept,
  }) async {
    final groupId = notification.groupId;
    if (groupId == null || groupId.isEmpty) {
      return;
    }

    setState(() {
      _processingInvites.add(notification.id);
    });

    try {
      if (accept) {
        await _controller.acceptGroupInvite(groupId);
      } else {
        await _controller.rejectGroupInvite(groupId);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Invito al gruppo accettato'
                : 'Invito al gruppo rifiutato',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingInvites.remove(notification.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche'),
        actions: [
          if (_controller.unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Segna tutte'),
            ),
        ],
      ),
      body: _controller.notifications.isEmpty
          ? const Center(child: Text('Nessuna notifica disponibile.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _controller.notifications.length,
              itemBuilder: (context, index) {
                final notification = _controller.notifications[index];
                final isProcessing = _processingInvites.contains(notification.id);
                return Card(
                  color: notification.isRead
                      ? null
                      : Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.08),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: notification.isPendingGroupInvite || notification.isRead
                        ? null
                        : () => _controller.markAsRead(notification.id),
                    leading: Icon(
                      notification.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                    ),
                    title: Text(notification.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notification.body),
                        if (notification.isPendingGroupInvite) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isProcessing
                                      ? null
                                      : () => _respondToInvite(
                                          notification,
                                          accept: false,
                                        ),
                                  child: const Text('Rifiuta'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isProcessing
                                      ? null
                                      : () => _respondToInvite(
                                          notification,
                                          accept: true,
                                        ),
                                  child: const Text('Accetta'),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (notification.timestamp > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            _formatTimestamp(notification.timestamp),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    trailing: notification.isPendingGroupInvite
                        ? null
                        : notification.isRead
                        ? null
                        : const Icon(Icons.fiber_new, color: Colors.redAccent),
                  ),
                );
              },
            ),
    );
  }
}
