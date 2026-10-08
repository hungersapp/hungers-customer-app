import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../authentication/domain/customer_profile_name.dart';
import '../../../authentication/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  static const double _contentMaxWidth = 920;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentAuthUserProvider);
    _nameController = TextEditingController(text: user?.name?.trim() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    _saving = true;
    setState(() {});
    try {
      await ref
          .read(authProvider.notifier)
          .updateCustomerProfileName(_nameController.text);
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Name saved.')),
      );
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? 'Invalid name.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message
                : 'Unable to save your name. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAuthUserProvider);
    final mobile = user?.mobileNumber?.trim() ?? '';
    final email = user?.email?.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: EditProfileScreen._contentMaxWidth,
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Material(
                  color: AppColors.surface,
                  elevation: 1,
                  shadowColor: AppColors.shadow,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _save(),
                          validator: (value) =>
                              CustomerProfileName.validate(value ?? ''),
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: mobile,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Mobile number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: email,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.5,
                    ),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.textLight,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
