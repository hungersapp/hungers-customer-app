import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          //=====================================
          // Email / Mobile
          //=====================================

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "Email / Mobile Number",
              hintText: "Enter Email or Mobile Number",
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),

          const SizedBox(height: 18),

          //=====================================
          // Password
          //=====================================

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: "Password",
              hintText: "Enter Password",
              prefixIcon: const Icon(Icons.lock_outline),

              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          //=====================================
          // Forgot Password
          //=====================================

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // TODO
              },
              child: const Text(
                "Forgot Password?",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          //=====================================
          // Login Button
          //=====================================

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                // TODO Login
              },
              child: const Text(
                "LOGIN",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 25),

          //=====================================
          // OR Divider
          //=====================================

          Row(
            children: [
              const Expanded(child: Divider()),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "OR",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Expanded(child: Divider()),
            ],
          ),

          const SizedBox(height: 25),

          //=====================================
          // Google Button
          //=====================================

          SizedBox(
            width: double.infinity,
            height: 55,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO Google Login
              },
              icon: const Icon(Icons.g_mobiledata, size: 30),
              label: const Text(
                "Continue with Google",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}