import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/support_chat/support_chat_controller.dart';
import 'package:soundimplosion/app/features/support_chat/support_chat_repository.dart';
import 'package:soundimplosion/models/models.dart';

class SupportChatPanel extends StatefulWidget {
  const SupportChatPanel({
    super.key,
    this.embedded = false,
    this.compact = false,
    this.origin = 'app',
    this.repository,
  });

  final bool embedded;
  final bool compact;
  final String origin;
  final SupportChatRepository? repository;

  @override
  State<SupportChatPanel> createState() => _SupportChatPanelState();
}

class _SupportChatPanelState extends State<SupportChatPanel> {
  late final SupportChatController _controller;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = SupportChatController(repository: widget.repository);
    _controller.initialize();
  }

  @override
  void dispose() {
    if (_controller.isGuestSession) {
      _controller.deleteEphemeralChat();
    }
    _messageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createChat() async {
    final guestNameController = TextEditingController();
    final subjectController = TextEditingController();
    final firstMessageController = TextEditingController();
    try {
      final created = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Nuova richiesta assistenza'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.isGuestSession) ...[
                    TextField(
                      controller: guestNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        hintText: 'Come vuoi farti chiamare?',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Oggetto',
                      hintText: 'Es. Problema con prenotazione',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: firstMessageController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Messaggio',
                      alignLabelWithHint: true,
                      hintText: 'Descrivi il problema o la richiesta.',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Apri chat'),
              ),
            ],
          );
        },
      );

      if (created != true) {
        return;
      }

      await _controller.createChat(
        subject: subjectController.text,
        initialMessage: firstMessageController.text,
        origin: widget.origin,
        guestDisplayName: guestNameController.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Richiesta inviata all\'assistenza.')),
      );
    } catch (error) {
      _showError(error);
    } finally {
      guestNameController.dispose();
      subjectController.dispose();
      firstMessageController.dispose();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _messageController.clear();
    try {
      await _controller.sendMessage(text);
    } catch (error) {
      _messageController.text = text;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
      _showError(error);
    }
  }

  Future<void> _closeSelectedChat({required bool userDeleting}) async {
    final selectedChat = _controller.selectedChat;
    if (selectedChat == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(userDeleting ? 'Eliminare la richiesta?' : 'Chiudere la chat?'),
          content: Text(
            userDeleting
                ? 'La richiesta verra rimossa dalla tua lista conversazioni.'
                : 'La chat verra chiusa e non apparira piu tra quelle aperte.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(userDeleting ? 'Elimina' : 'Chiudi'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _controller.closeSelectedChat();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            userDeleting
                ? 'Richiesta rimossa correttamente.'
                : 'Chat chiusa correttamente.',
          ),
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('Operazione non riuscita: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final selectedChat = _controller.selectedChat;
        final selectedChatMessages = _controller.messages;
        final colorScheme = Theme.of(context).colorScheme;
        final narrow = widget.compact || MediaQuery.of(context).size.width < 900;

        final shell = Container(
          decoration: widget.embedded
              ? null
              : BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                  ),
                ),
          child: narrow
              ? Column(
                  children: [
                    Expanded(
                      child: _buildListSection(selectedChat),
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    Expanded(
                      child: _buildThreadSection(
                        selectedChat,
                        selectedChatMessages,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: _buildListSection(selectedChat),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    Expanded(
                      child: _buildThreadSection(
                        selectedChat,
                        selectedChatMessages,
                      ),
                    ),
                  ],
                ),
        );

        if (widget.embedded) {
          return shell;
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: shell,
        );
      },
    );
  }

  Widget _buildListSection(SupportChatConversation? selectedChat) {
    final colorScheme = Theme.of(context).colorScheme;
    final chats = _controller.chats;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _controller.isAdmin ? 'Chat aperte' : 'Le tue richieste',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _controller.isAdmin
                          ? 'Tutti i ticket aperti verso l\'assistenza.'
                          : (_controller.isGuestSession
                                ? 'Chat temporanea del sito pubblico. Rimane attiva finche resti sulla pagina.'
                                : 'Ogni chat corrisponde a una richiesta di supporto diversa.'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!_controller.isAdmin)
                if (!_controller.isGuestSession || chats.isEmpty)
                  FilledButton.icon(
                    onPressed: _controller.isSubmitting ? null : _createChat,
                    icon: const Icon(Icons.add_comment_outlined),
                    label: Text(_controller.isGuestSession ? 'Apri chat' : 'Nuova'),
                  ),
            ],
          ),
        ),
        Expanded(
          child: chats.isEmpty
              ? _buildEmptyState(
                  icon: _controller.isAdmin
                      ? Icons.support_agent
                      : Icons.forum_outlined,
                  message: _controller.isAdmin
                      ? 'Nessuna chat aperta in questo momento.'
                      : (_controller.isGuestSession
                            ? 'Puoi iniziare subito una chat con l\'assistenza.'
                            : 'Non hai ancora richieste aperte.'),
                  action: !_controller.isAdmin
                      ? FilledButton(
                          onPressed:
                              _controller.isSubmitting ? null : _createChat,
                          child: Text(
                            _controller.isGuestSession
                                ? 'Scrivi all\'assistenza'
                                : 'Apri una nuova richiesta',
                          ),
                        )
                      : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: chats.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final isSelected = chat.id == selectedChat?.id;
                    final hasUnread = _controller.isAdmin
                        ? chat.unreadForAdmin
                        : chat.unreadForUser;
                    return Card(
                      margin: EdgeInsets.zero,
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.08)
                          : null,
                      child: ListTile(
                        onTap: () => _controller.selectChat(chat.id),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        title: Text(
                          chat.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _controller.isAdmin
                                    ? '${chat.userNickname} • ${_formatTimestamp(chat.lastMessageAt)}'
                                    : _formatTimestamp(chat.lastMessageAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                chat.lastMessageText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (chat.hasAssignment)
                                    _StatusChip(
                                      label: 'Assegnata a ${chat.assignedAdminNickname ?? 'admin'}',
                                      backgroundColor: colorScheme.secondary
                                          .withValues(alpha: 0.12),
                                      foregroundColor: colorScheme.secondary,
                                    ),
                                  if (hasUnread)
                                    _StatusChip(
                                      label: 'Non letta',
                                      backgroundColor: colorScheme.primary
                                          .withValues(alpha: 0.12),
                                      foregroundColor: colorScheme.primary,
                                    ),
                                  if (_controller.isAdmin && chat.isGuestConversation)
                                    _StatusChip(
                                      label: 'Pubblica',
                                      backgroundColor: colorScheme.tertiary
                                          .withValues(alpha: 0.12),
                                      foregroundColor: colorScheme.tertiary,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: !_controller.isAdmin
                            ? IconButton(
                                tooltip: _controller.isGuestSession
                                    ? 'Termina chat'
                                    : 'Elimina richiesta',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: isSelected
                                    ? () => _closeSelectedChat(userDeleting: true)
                                    : null,
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildThreadSection(
    SupportChatConversation? selectedChat,
    List<SupportChatMessage> selectedChatMessages,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (selectedChat == null) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline,
        iconSize: 52,
        message: _controller.isAdmin
            ? 'Seleziona una chat per gestirla.'
            : 'Seleziona una richiesta oppure aprine una nuova.',
        messageStyle: Theme.of(context).textTheme.titleMedium,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedChat.subject,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _controller.isAdmin
                              ? 'Utente: ${selectedChat.userNickname}${selectedChat.userEmail?.trim().isNotEmpty == true ? ' • ${selectedChat.userEmail}' : ''}'
                          : (_controller.isGuestSession
                            ? 'Chat temporanea del sito pubblico. Verra eliminata quando lasci la pagina.'
                            : 'Stato: ${selectedChat.isOpen ? 'aperta' : 'chiusa'}'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: selectedChat.isOpen ? 'Aperta' : 'Chiusa',
                    backgroundColor: selectedChat.isOpen
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : colorScheme.error.withValues(alpha: 0.12),
                    foregroundColor: selectedChat.isOpen
                        ? colorScheme.primary
                        : colorScheme.error,
                  ),
                  if (selectedChat.hasAssignment)
                    _StatusChip(
                      label:
                          'In carico a ${selectedChat.assignedAdminNickname ?? 'admin'}',
                      backgroundColor:
                          colorScheme.secondary.withValues(alpha: 0.12),
                      foregroundColor: colorScheme.secondary,
                    ),
                  if (_controller.isAdmin && selectedChat.isOpen)
                    _controller.isAssignedToCurrentAdmin
                        ? OutlinedButton.icon(
                            onPressed: _controller.isSubmitting
                                ? null
                                : () async {
                                    try {
                                      await _controller.releaseSelectedChat();
                                    } catch (error) {
                                      _showError(error);
                                    }
                                  },
                            icon: const Icon(Icons.lock_open_outlined),
                            label: const Text('Rilascia'),
                          )
                        : FilledButton.icon(
                            onPressed: _controller.isSubmitting
                                ? null
                                : () async {
                                    try {
                                      await _controller.assignSelectedChatToMe();
                                    } catch (error) {
                                      _showError(error);
                                    }
                                  },
                            icon: const Icon(Icons.assignment_ind_outlined),
                            label: const Text('Assegna a me'),
                          ),
                  if (_controller.isAdmin)
                    TextButton.icon(
                      onPressed: _controller.isSubmitting
                          ? null
                          : () => _closeSelectedChat(userDeleting: false),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Chiudi chat'),
                    ),
                  if (!_controller.isAdmin)
                    TextButton.icon(
                      onPressed: _controller.isSubmitting
                          ? null
                          : () => _closeSelectedChat(userDeleting: true),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        _controller.isGuestSession
                            ? 'Termina chat'
                            : 'Elimina richiesta',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        Expanded(
          child: selectedChatMessages.isEmpty
              ? const Center(child: Text('Nessun messaggio ancora.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: selectedChatMessages.length,
                  itemBuilder: (context, index) {
                    final message = selectedChatMessages[index];
                    final isMine = message.senderId == _controller.currentUserId;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: widget.compact ? 320 : 520,
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMine
                              ? colorScheme.primary.withValues(alpha: 0.14)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.senderDisplayName,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(message.text),
                            const SizedBox(height: 8),
                            Text(
                              _formatTimestamp(message.timestamp),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        _buildComposer(selectedChat),
      ],
    );
  }

  Widget _buildComposer(SupportChatConversation selectedChat) {
    final canReply = _controller.canReply;
    final colorScheme = Theme.of(context).colorScheme;

    if (!selectedChat.isOpen) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _controller.isGuestSession
              ? 'La chat temporanea e terminata.'
              : 'Questa chat e chiusa.',
        ),
      );
    }

    if (!canReply) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Assegna la chat a te stesso per poter rispondere come admin.',
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              enabled: !_controller.isSubmitting,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Scrivi un messaggio...',
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _controller.isSubmitting ? null : _sendMessage,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Invia'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    Widget? action,
    TextStyle? messageStyle,
    double iconSize = 44,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: iconSize, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: messageStyle,
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 12),
                    action,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp <= 0) {
      return 'Ora';
    }

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    if (sameDay) {
      return '$hour:$minute';
    }
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
