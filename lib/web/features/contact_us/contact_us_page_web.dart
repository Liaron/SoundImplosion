import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/support_chat/support_chat_panel.dart';

class ContactUsPageWeb extends StatelessWidget {
  const ContactUsPageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: SupportChatPanel(embedded: true),
    );
  }
}
