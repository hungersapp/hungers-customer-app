import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/tukkito_app_logo.dart';
import '../../providers/auth_provider.dart';
import '../../../../core/validators/password_validator.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState
    extends ConsumerState<RegistrationScreen> {

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  InputDecoration field(
    String hint,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: AppColors.primary,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(16),
        ),
        borderSide: BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
    );
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (_name.text.trim().isEmpty) {
      _show("Please enter your name");
      return;
    }

    if (_email.text.trim().isEmpty) {
      _show("Please enter email");
      return;
    }

    if (_mobile.text.trim().isEmpty) {
      _show("Please enter mobile number");
      return;
    }

    final passwordError =
    PasswordValidator.validate(_password.text);

if (passwordError != null) {
  _show(passwordError);
  return;
}

    if (_password.text != _confirm.text) {
      _show("Passwords do not match");
      return;
    }

    await ref.read(authProvider.notifier).register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          mobileNumber: _mobile.text.trim(),
          password: _password.text,
        );

    if (!mounted) return;

    final authState = ref.read(authProvider);

    authState.when(
      data: (user) {
        if (user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Registration Successful",
              ),
            ),
          );

          Navigator.pushReplacementNamed(
            context,
            AppRoutes.login,
          );
        }
      },
      loading: () {},
      error: (error, stackTrace) {
        _show(error.toString());
      },
    );
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final loading = authState.isLoading;

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
                constraints: const BoxConstraints(
                  maxWidth: 420,
                ),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                            ),
                          ),
                        ),

                        Hero(
                          tag: 'hungers_logo',
                          child: const TukkitoAppLogo(size: 90),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Create your Tukkito account and start ordering.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 28),

                        TextField(
                          controller: _name,
                          decoration: field(
                            'Full Name',
                            Icons.person_outline,
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _email,
                          keyboardType:
                              TextInputType.emailAddress,
                          decoration: field(
                            'Email Address',
                            Icons.email_outlined,
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _mobile,
                          keyboardType: TextInputType.phone,
                          decoration: field(
                            'Mobile Number',
                            Icons.phone_outlined,
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _password,
                          obscureText: _hidePassword,
                          decoration: field(
                            'Password',
                            Icons.lock_outline,
                            suffix: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hidePassword =
                                      !_hidePassword;
                                });
                              },
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _confirm,
                          obscureText: _hideConfirm,
                          decoration: field(
                            'Confirm Password',
                            Icons.lock_outline,
                            suffix: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hideConfirm =
                                      !_hideConfirm;
                                });
                              },
                              icon: Icon(
                                _hideConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                loading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppColors.primary,
                              foregroundColor: Colors.white,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                        16),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context),
                          child: const Text(
                            'Already have an account? Login',
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
