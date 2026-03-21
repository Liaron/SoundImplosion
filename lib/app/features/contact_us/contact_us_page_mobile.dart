import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/support_chat/support_chat_panel.dart';

class ContactUsPageMobile extends StatelessWidget {
  const ContactUsPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return const SupportChatPanel(embedded: true);
  }
}
