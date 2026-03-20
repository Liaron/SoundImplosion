import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/home/auth_form_card.dart';

class AuthPageMobile extends StatelessWidget {
  const AuthPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: const AuthFormCard(maxWidth: 420, showSurface: false),
        ),
      ),
    );
  }
}
