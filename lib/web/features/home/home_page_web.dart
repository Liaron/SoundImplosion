import 'package:flutter/material.dart';

class HomePageWeb extends StatelessWidget {
  const HomePageWeb({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text('Home - Web', style: TextStyle(fontSize: 32)),
      ),
    );
  }
}
