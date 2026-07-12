import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../app/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
 State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // TODO:
    // Firebase Initialize
    // Remote Config
    // App Version Check
    // Login Session Check

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Temporary Navigation
    // Replace with Login Screen after Login UI completed

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.login,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                //=============================
                // LOGO
                //=============================

                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      "assets/images/app_logo.png",
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                //=============================
                // APP NAME
                //=============================

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

                //=============================
                // TAG LINE
                //=============================

                const Text(
                  "😊Feeding Smiles... Happy Hearts...❤️",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 60),

                //=============================
                // LOADING
                //=============================

                const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),

                const SizedBox(height: 25),

                const Text(
                  "Loading...",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}