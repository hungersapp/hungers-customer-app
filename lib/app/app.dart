import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/restaurants/presentation/providers/restaurant_details_provider.dart';
import 'app_pages.dart';
import 'app_routes.dart';
import 'app_theme.dart';

class HungersApp extends ConsumerWidget {
  const HungersApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Tukkito',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      initialRoute: AppRoutes.splash,
      routes: AppPages.routes,
      onGenerateRoute: (settings) => AppPages.onGenerateRoute(
        settings,
        lastViewedRestaurant: ref.read(lastViewedRestaurantProvider),
      ),
      onUnknownRoute: AppPages.onUnknownRoute,
    );
  }
}