import 'package:flutter/material.dart';

class AboutUsPageWeb extends StatelessWidget {
  const AboutUsPageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi Siamo - Web')),
      body: const Center(
        child: Text('Pagina Chi Siamo - Web', style: TextStyle(fontSize: 32)),
      ),
    );
  }
}
