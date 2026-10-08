import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/validators/indian_mobile.dart';
import '../../providers/auth_provider.dart';
import '../widgets/login_footer.dart';
import '../widgets/login_header.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final session = await ref.read(authProvider.notifier).sendPhoneOtp(
            _mobileController.text,
          );
      if (!mounted) {
        return;
      }
      if (session.isAutoVerified && session.autoVerifiedUser != null) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.zoneRegistration,
        );
        return;
      }
      Navigator.pushNamed(context, AppRoutes.otp);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF8F2), Colors.white],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 3,
                  shadowColor: Colors.black12,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const LoginHeader(),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Already have an account?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) =>
                                IndianMobile.validate(value ?? ''),
                            decoration: InputDecoration(
                              hintText: '10-digit mobile number',
                              counterText: '',
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 12, right: 8),
                                child: Text(
                                  '+91',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 56,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: loading ? null : _sendOtp,
                              child: loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Send OTP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'By continuing, you agree to receive an OTP from Tukkito.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          LoginFooter(
                            loading: loading,
                            onCreateAccount: _sendOtp,
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
      ),
    );
  }
}
