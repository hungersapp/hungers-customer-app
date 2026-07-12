import 'package:flutter/material.dart';

void main() {
  runApp(const HungersApp());
}

class HungersApp extends StatelessWidget {
  const HungersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'HUNGERS\n❤️ Feeding Smiles. Happy Hearts. ❤️',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}