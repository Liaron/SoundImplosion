import 'dart:math';

import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/support_chat/support_chat_panel.dart';
import 'package:soundimplosion/app/features/support_chat/support_chat_repository.dart';

class PublicSupportChatLauncher extends StatefulWidget {
  const PublicSupportChatLauncher({
    super.key,
  });

  @override
  State<PublicSupportChatLauncher> createState() =>
      _PublicSupportChatLauncherState();
}

class _PublicSupportChatLauncherState extends State<PublicSupportChatLauncher> {
  late final String _guestSessionId = _buildGuestSessionId();
  late final FirebaseSupportChatRepository _guestRepository =
      FirebaseSupportChatRepository(guestSessionId: _guestSessionId);

  @override
  void dispose() {
    _guestRepository.deleteEphemeralChat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _openDialog(context),
      icon: const Icon(Icons.support_agent),
      label: const Text('Chat assistenza'),
    );
  }

  Future<void> _openDialog(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final compact = width < 900;
    final dialogWidth = compact ? (width - 24).clamp(320.0, 460.0) : 960.0;
    final dialogHeight = compact ? (height - 24).clamp(520.0, 720.0) : 760.0;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: colorScheme.surface,
              elevation: 24,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: dialogWidth,
                height: dialogHeight,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chat assistenza',
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Scrivici dal sito e ricevi supporto in tempo reale.',
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Chiudi',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    Expanded(
                      child: SupportChatPanel(
                        embedded: true,
                        compact: compact,
                        origin: 'public_web',
                        repository: _guestRepository,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _buildGuestSessionId() {
    final random = Random();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final entropy = List<String>.generate(
      4,
      (_) => random.nextInt(1 << 32).toRadixString(36),
    ).join();
    return 'guest_$timestamp$entropy';
  }
}