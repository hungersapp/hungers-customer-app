import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class LoginFooter extends StatelessWidget {
  const LoginFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 30),

        //=====================================
        // Create Account
        //=====================================

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "New to Hungers?",
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),

            TextButton(
              onPressed: () {
                // TODO : Navigate Registration Screen
              },
              child: const Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 15),

        //=====================================
        // Terms & Privacy
        //=====================================

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 25),
          child: Text(
            "By continuing, you agree to our Terms of Service and Privacy Policy.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 25),

        //=====================================
        // App Version
        //=====================================

        const Text(
          "HUNGERS v1.0.0",
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 15),
      ],
    );
  }
}