import 'package:flutter/material.dart';

class BookNowPageWeb extends StatelessWidget {
  const BookNowPageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prenota Ora - Web'),
      ),
      body: const Center(
        child: Text(
          'Pagina Prenota Ora - Web',
          style: TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}
