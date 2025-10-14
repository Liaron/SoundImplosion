import 'package:flutter/material.dart';

class ContactUsPageWeb extends StatelessWidget {
  const ContactUsPageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contattaci - Web'),
      ),
      body: const Center(
        child: Text(
          'Pagina Contattaci - Web',
          style: TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}
