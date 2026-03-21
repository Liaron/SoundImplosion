import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/book/bookings_scaffold_mobile.dart';
import 'package:soundimplosion/app/features/groups/groups_page_mobile.dart';
import 'package:soundimplosion/app/features/jam/jam_session_page_mobile.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/app/features/contact_us/contact_us_page_mobile.dart';
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
  final Set<String> _processingProposals = <String>{};
  final Set<String> _selectedNotificationIds = <String>{};

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

  bool _isDeletable(AppNotificationItem notification) {
    return !notification.isPendingAction;
  }

  bool get _isSelectionMode => _selectedNotificationIds.isNotEmpty;

  void _toggleSelection(AppNotificationItem notification) {
    if (!_isDeletable(notification)) {
      return;
    }

    setState(() {
      if (_selectedNotificationIds.contains(notification.id)) {
        _selectedNotificationIds.remove(notification.id);
      } else {
        _selectedNotificationIds.add(notification.id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedNotificationIds.clear();
    });
  }

  Future<void> _deleteSingle(AppNotificationItem notification) async {
    if (!_isDeletable(notification)) {
      return;
    }

    await _controller.deleteNotification(notification.id);
  }

  Future<void> _deleteSelected() async {
    if (_selectedNotificationIds.isEmpty) {
      return;
    }
    await _controller.deleteSelectedNotifications(_selectedNotificationIds.toList());
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedNotificationIds.clear();
    });
  }

  Future<void> _deleteAll() async {
    final deletableIds = _controller.notifications
        .where(_isDeletable)
        .map((notification) => notification.id)
        .toList();
    if (deletableIds.isEmpty) {
      return;
    }

    await _controller.deleteSelectedNotifications(deletableIds);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedNotificationIds.clear();
    });
  }

  Future<void> _confirmDelete({
    required String title,
    required String content,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await onConfirm();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifiche eliminate')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    }
  }

  Future<void> _openNotification(AppNotificationItem notification) async {
    if (!notification.isRead) {
      await _controller.markAsRead(notification.id);
    }

    if (!mounted) {
      return;
    }

    final target = notification.routeTarget;
    switch (target.pageIndex) {
      case 1:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookingsScaffoldMobile(
              initialBookingIdToOpen: target.bookingId,
            ),
          ),
        );
        break;
      case 2:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JamSessionPageMobile(
              initialJamToOpen: target.jamId == null
                  ? null
                  : <String, dynamic>{'jam_id': target.jamId},
            ),
          ),
        );
        break;
      case 3:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                GroupsPageMobile(initialGroupIdToOpen: target.groupId),
          ),
        );
        break;
      case 7:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ContactUsPageMobile(initialChatId: target.chatId),
          ),
        );
        break;
      default:
        break;
    }
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

  Future<void> _respondToProposal(
    AppNotificationItem notification, {
    required bool accept,
  }) async {
    setState(() {
      _processingProposals.add(notification.id);
    });

    try {
      if (notification.isPendingBookingUpdateProposal) {
        if (accept) {
          await _controller.acceptBookingUpdateProposal(notification.id);
        } else {
          await _controller.rejectBookingUpdateProposal(notification.id);
        }
      } else if (notification.isPendingJamUpdateProposal) {
        if (accept) {
          await _controller.acceptJamUpdateProposal(notification.id);
        } else {
          await _controller.rejectJamUpdateProposal(notification.id);
        }
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Proposta accettata' : 'Proposta rifiutata',
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
          _processingProposals.remove(notification.id);
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_isSelectionMode) ...[
                  IconButton(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.close),
                  ),
                  Text('${_selectedNotificationIds.length} selezionate'),
                  IconButton(
                    onPressed: () => _confirmDelete(
                      title: 'Elimina selezionate',
                      content: 'Vuoi eliminare le notifiche selezionate?',
                      onConfirm: _deleteSelected,
                    ),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ] else ...[
                  const Spacer(),
                  Row(
                    children: [
                      if (_controller.notifications.any(_isDeletable))
                        IconButton(
                          onPressed: () => _confirmDelete(
                            title: 'Elimina tutte',
                            content:
                                'Vuoi eliminare tutte le notifiche eliminabili? Gli inviti pendenti resteranno disponibili.',
                            onConfirm: _deleteAll,
                          ),
                          icon: const Icon(Icons.delete_sweep_outlined),
                        ),
                      if (_controller.unreadCount > 0)
                        TextButton(
                          onPressed: _markAllAsRead,
                          child: const Text('Segna lette'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _controller.notifications.isEmpty
          ? const Center(child: Text('Nessuna notifica disponibile.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _controller.notifications.length,
              itemBuilder: (context, index) {
                final notification = _controller.notifications[index];
                final isProcessing = _processingInvites.contains(notification.id);
                final isProcessingProposal = _processingProposals.contains(
                  notification.id,
                );
                return Card(
                  color: notification.isRead
                      ? null
                      : Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.08),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onLongPress: _isDeletable(notification)
                        ? () => _toggleSelection(notification)
                        : null,
                    onTap: _isSelectionMode
                        ? (_isDeletable(notification)
                              ? () => _toggleSelection(notification)
                              : null)
                      : notification.isPendingAction
                        ? null
                        : () => _openNotification(notification),
                    selected: _selectedNotificationIds.contains(notification.id),
                    leading: Icon(
                      _selectedNotificationIds.contains(notification.id)
                          ? Icons.check_circle
                          : notification.isRead
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
                        if (notification.isPendingBookingUpdateProposal ||
                            notification.isPendingJamUpdateProposal) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isProcessingProposal
                                      ? null
                                      : () => _respondToProposal(
                                          notification,
                                          accept: false,
                                        ),
                                  child: const Text('Rifiuta'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isProcessingProposal
                                      ? null
                                      : () => _respondToProposal(
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
                    trailing: _isSelectionMode
                        ? null
                      : notification.isPendingAction
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                _confirmDelete(
                                  title: 'Elimina notifica',
                                  content: 'Vuoi eliminare questa notifica?',
                                  onConfirm: () => _deleteSingle(notification),
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.delete_outline),
                                  title: Text('Elimina'),
                                ),
                              ),
                            ],
                            child: const Icon(Icons.more_vert),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
