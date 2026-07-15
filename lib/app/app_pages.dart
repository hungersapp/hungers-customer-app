import 'package:flutter/material.dart';

import '../features/authentication/presentation/pages/login_screen.dart';
import '../features/authentication/presentation/pages/registration_screen.dart';
import '../features/authentication/presentation/pages/forgotpassword_screen.dart';
import '../features/authentication/presentation/pages/otp_screen.dart';
import '../features/authentication/presentation/pages/reset_password_screen.dart';
import '../features/dashboard/presentation/pages/dashboard_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final Map<String, WidgetBuilder> routes = {
    AppRoutes.splash: (_) => const SplashScreen(),
    AppRoutes.login: (_) => const LoginScreen(),

    AppRoutes.registration: (_) => const RegistrationScreen(),
    AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
    AppRoutes.otp: (_) => const OtpScreen(),
    AppRoutes.resetPassword: (_) => const ResetPasswordScreen(),

    AppRoutes.dashboard: (_) => const DashboardScreen(),
  };
}