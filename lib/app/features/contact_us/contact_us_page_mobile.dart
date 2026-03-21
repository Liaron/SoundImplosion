import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/support_chat/support_chat_panel.dart';

class ContactUsPageMobile extends StatelessWidget {
  const ContactUsPageMobile({super.key, this.initialChatId});

  final String? initialChatId;

  @override
  Widget build(BuildContext context) {
    return SupportChatPanel(embedded: true, initialChatId: initialChatId);
  }
}
