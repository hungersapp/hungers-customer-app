import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/indian_pincode.dart';

class PincodeEntryCard extends StatefulWidget {
  const PincodeEntryCard({
    super.key,
    this.initialPincode,
    this.autofocus = false,
    required this.onSubmit,
  });

  final String? initialPincode;
  final bool autofocus;
  final ValueChanged<String> onSubmit;

  @override
  State<PincodeEntryCard> createState() => _PincodeEntryCardState();
}

class _PincodeEntryCardState extends State<PincodeEntryCard> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPincode ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text;
    final error = IndianPincode.validate(raw);
    setState(() {
      _error = error;
    });
    if (error != null) {
      return;
    }
    widget.onSubmit(IndianPincode.normalize(raw)!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: AppColors.surface,
        elevation: 1,
        shadowColor: AppColors.shadow,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter your delivery pincode',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We will check whether Tukkito delivers to your area.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '6-digit pincode',
                  counterText: '',
                  errorText: _error,
                  prefixIcon: const Icon(Icons.pin_drop_outlined),
                ),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() {
                      _error = null;
                    });
                  }
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submit,
                child: const Text('Check availability'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showPincodeEntrySheet({
  required BuildContext context,
  String? initialPincode,
  required ValueChanged<String> onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: PincodeEntryCard(
          initialPincode: initialPincode,
          autofocus: true,
          onSubmit: (pincode) {
            Navigator.of(sheetContext).pop();
            onSubmit(pincode);
          },
        ),
      );
    },
  );
}
