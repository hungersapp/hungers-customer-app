import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/tukkito_app_logo.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_off : Icons.visibility,
          color: AppColors.textSecondary,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFF8F2),
                Colors.white,
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          ),
                        ),
                        const Hero(
                          tag: 'hungers_logo',
                          child: TukkitoAppLogo(size: 90),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Reset Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Create a new password to secure your account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _newPasswordController,
                          obscureText: _hideNew,
                          decoration: _inputDecoration(
                            hint: 'New Password',
                            obscure: _hideNew,
                            onToggle: () {
                              setState(() => _hideNew = !_hideNew);
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _hideConfirm,
                          decoration: _inputDecoration(
                            hint: 'Confirm Password',
                            obscure: _hideConfirm,
                            onToggle: () {
                              setState(() => _hideConfirm = !_hideConfirm);
                            },
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Reset Password
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Update Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
