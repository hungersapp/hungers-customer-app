import 'package:flutter/material.dart';

import '../features/authentication/presentation/pages/login_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final Map<String, WidgetBuilder> routes = {
    AppRoutes.splash: (_) => const SplashScreen(),
    AppRoutes.login: (_) => const LoginScreen(),
  };
}