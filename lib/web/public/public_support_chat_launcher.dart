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
    final width = MediaQuery.of(context).size.width;
    final compact = width < 720;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 24,
            vertical: compact ? 12 : 24,
          ),
          child: SizedBox(
            width: compact ? 420 : 480,
            height: compact ? 620 : 700,
            child: SupportChatPanel(
              embedded: true,
              compact: true,
              origin: 'public_web',
              repository: _guestRepository,
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