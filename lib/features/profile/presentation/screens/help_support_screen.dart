import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/validators/indian_mobile.dart';
import '../../../authentication/providers/auth_provider.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _message;
  String _category = 'order_support';
  bool _submitting = false;

  static const _categories = <String, String>{
    'order_support': 'Order support',
    'payment_support': 'Payment support',
    'customer': 'Account',
    'general': 'General',
  };

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentAuthUserProvider);
    _name = TextEditingController(text: user?.name?.trim() ?? '');
    _mobile = TextEditingController(
      text: IndianMobile.normalize(user?.mobileNumber ?? '') ?? '',
    );
    _email = TextEditingController(text: user?.email?.trim() ?? '');
    _message = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('submitSupportEnquiry');
      await callable.call(<String, dynamic>{
        'name': _name.text.trim(),
        'mobileNumber': _mobile.text.trim(),
        'email': _email.text.trim(),
        'category': _category,
        'message': _message.text.trim(),
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks. We received your message.')),
      );
      Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to send your message.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send your message.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.lg,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            TextFormField(
              controller: _name,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter your name.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _mobile,
              enabled: !_submitting,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                border: OutlineInputBorder(),
              ),
              validator: (value) => IndianMobile.validate(value ?? ''),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              enabled: !_submitting,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: [
                for (final entry in _categories.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
              decoration: const InputDecoration(
                labelText: 'Topic',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _message,
              enabled: !_submitting,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 10) {
                  return 'Add a bit more detail so we can help.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textLight,
                minimumSize: const Size(0, 48),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.textLight,
                      ),
                    )
                  : const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
