import 'package:flutter/material.dart';
import 'package:soundimplosion/services/firebase_auth.dart';

class HomePageMobile extends StatefulWidget {
  const HomePageMobile({super.key});

  @override
  State<HomePageMobile> createState() => _HomePageMobileState();
}

class _HomePageMobileState extends State<HomePageMobile> {
  final AuthService _authService = AuthService();

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: Text('Questa è la homepage mobile'),
      ),
    );
  }
}
