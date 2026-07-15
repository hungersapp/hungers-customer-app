import 'package:flutter/material.dart';

import 'app_pages.dart';
import 'app_routes.dart';
import 'app_theme.dart';

class HungersApp extends StatelessWidget {
  const HungersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUNGERS',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      initialRoute: AppRoutes.splash,

      routes: AppPages.routes,
    );
  }
}