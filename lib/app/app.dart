import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_pages.dart';
import 'app_routes.dart';

class HungersApp extends StatelessWidget {
  const HungersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUNGERS',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,

      // Initial Route
      initialRoute: AppRoutes.splash,

      // Application Routes
      routes: AppPages.routes,
    );
  }
}