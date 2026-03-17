import 'package:flutter/material.dart';

class ProfileDetailsPageWeb extends StatelessWidget {
  const ProfileDetailsPageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilo - Web')),
      body: const Center(
        child: Text(
          'Pagina Dettagli Profilo - Web',
          style: TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}
