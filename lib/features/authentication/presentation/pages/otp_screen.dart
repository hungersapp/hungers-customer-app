import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/tukkito_app_logo.dart';
import '../../providers/auth_provider.dart';
import 'post_otp_navigation.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _syncCooldown();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      _syncCooldown();
    });
  }

  void _syncCooldown() {
    final remaining =
        ref.read(authProvider.notifier).resendCooldownRemaining.inSeconds;
    if (remaining != _cooldownSeconds) {
      setState(() {
        _cooldownSeconds = remaining;
      });
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP.')),
      );
      return;
    }

    try {
      final user = await ref.read(authProvider.notifier).verifyPhoneOtp(_otp);
      if (!mounted) {
        return;
      }
      await continueAfterPhoneAuth(
        context: context,
        ref: ref,
        user: user,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authProvider.notifier).resendPhoneOtp();
      if (!mounted) {
        return;
      }
      _syncCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new OTP has been sent.')),
      );
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
    final phone = ref.read(authProvider.notifier).otpSession?.phoneE164 ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      body: SafeArea(
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
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () {
                            ref.read(authProvider.notifier).clearOtpSession();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                      ),
                      const TukkitoAppLogo(size: 90),
                      const SizedBox(height: 24),
                      const Text(
                        'OTP Verification',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        phone.isEmpty
                            ? 'Enter the 6-digit OTP sent to your mobile number.'
                            : 'Enter the 6-digit OTP sent to $phone',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < 6; i++)
                            SizedBox(
                              width: 44,
                              child: TextField(
                                controller: _controllers[i],
                                focusNode: _focusNodes[i],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) {
                                  if (value.isNotEmpty && i < 5) {
                                    _focusNodes[i + 1].requestFocus();
                                  }
                                  if (value.isEmpty && i > 0) {
                                    _focusNodes[i - 1].requestFocus();
                                  }
                                },
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: loading ? null : _verify,
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
                                  'Verify',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: loading || _cooldownSeconds > 0 ? null : _resend,
                        child: Text(
                          _cooldownSeconds > 0
                              ? 'Resend OTP in $_cooldownSeconds s'
                              : 'Resend OTP',
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(authProvider.notifier).clearOtpSession();
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.login,
                          );
                        },
                        child: const Text('Change mobile number'),
                      ),
                    ],
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
