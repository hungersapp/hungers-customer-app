import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ==========================
        // LOGO
        // ==========================

        Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Image.asset(
              "assets/images/app_logo.png",
              fit: BoxFit.contain,
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ==========================
        // APP NAME
        // ==========================

        const Text(
          "HUNGERS",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: AppColors.secondary,
          ),
        ),

        const SizedBox(height: 10),

        // ==========================
        // WELCOME
        // ==========================

        const Text(
          "Welcome Back 👋",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        // ==========================
        // TAGLINE
        // ==========================

        const Text(
          "Feeding Smiles. Happy Hearts.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }
}