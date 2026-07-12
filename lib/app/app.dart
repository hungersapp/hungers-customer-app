import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HungersApp extends StatelessWidget {
  const HungersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUNGERS',
      debugShowCheckedModeBanner: false,

      // ==========================================================
      // THEME
      // ==========================================================
      theme: AppTheme.lightTheme,

      // ==========================================================
      // HOME
      // (Temporary - Splash Screen வரும் வரை)
      // ==========================================================
      home: const Scaffold(
        body: Center(
          child: Text(
            '❤️ HUNGERS ❤️\nFeeding Smiles. Happy Hearts.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}