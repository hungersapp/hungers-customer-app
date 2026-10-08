import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/tukkito_app_logo.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Hero(
          tag: 'hungers_logo',
          child: TukkitoAppLogo(size: 120),
        ),
        const SizedBox(height: 24),
        const Text(
          'Welcome to Tukkito',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.secondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Sign in with your mobile number to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 36),
      ],
    );
  }
}
