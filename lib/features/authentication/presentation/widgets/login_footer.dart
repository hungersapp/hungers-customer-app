import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class LoginFooter extends StatelessWidget {
  const LoginFooter({
    super.key,
    required this.onCreateAccount,
    this.loading = false,
  });

  final VoidCallback onCreateAccount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'New Customer?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Create your account with mobile OTP. We will check Tukkito availability in your area.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: loading ? null : onCreateAccount,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Create Account',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
