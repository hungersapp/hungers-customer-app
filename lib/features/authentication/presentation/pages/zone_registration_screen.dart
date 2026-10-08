import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../location/presentation/helpers/post_login_location_flow.dart';
import '../../../location/presentation/widgets/location_permission_dialog.dart';
import '../../domain/new_customer_registration_result.dart';
import '../../providers/auth_provider.dart';
import '../../providers/new_customer_registration_provider.dart';

class ZoneRegistrationScreen extends ConsumerStatefulWidget {
  const ZoneRegistrationScreen({super.key});

  @override
  ConsumerState<ZoneRegistrationScreen> createState() =>
      _ZoneRegistrationScreenState();
}

class _ZoneRegistrationScreenState
    extends ConsumerState<ZoneRegistrationScreen> {
  NewCustomerRegistrationResult? _result;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runGate();
    });
  }

  Future<void> _runGate() async {
    final user = ref.read(authProvider).valueOrNull ??
        ref.read(currentAuthUserProvider);
    if (user == null) {
      if (!mounted) {
        return;
      }
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    setState(() {
      _checking = true;
      _result = null;
    });

    final result = await ref.read(
      registerNewCustomerIfServiceableUseCaseProvider,
    )(user);

    if (!mounted) {
      return;
    }

    setState(() {
      _checking = false;
      _result = result;
    });

    if (result.status == NewCustomerRegistrationStatus.created ||
        result.status == NewCustomerRegistrationStatus.existingCustomer) {
      await handlePostLoginNavigation(
        context: context,
        ref: ref,
        userId: user.uid,
      );
    }
  }

  Future<void> _openLocationHelp() async {
    final status = _result?.status;
    if (status == NewCustomerRegistrationStatus.locationPermissionDenied) {
      await showLocationPermissionDialog(context);
      return;
    }
    if (status == NewCustomerRegistrationStatus.locationServicesDisabled) {
      await showLocationServiceDisabledDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _checking
                      ? const _CheckingView()
                      : _ResultView(
                          result: _result,
                          onRetry: _runGate,
                          onEnableLocation: _openLocationHelp,
                          onSignOut: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.login,
                                (route) => false,
                              );
                            }
                          },
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

class _CheckingView extends StatelessWidget {
  const _CheckingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text(
          'Checking Tukkito availability in your area...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.onRetry,
    required this.onEnableLocation,
    required this.onSignOut,
  });

  final NewCustomerRegistrationResult? result;
  final VoidCallback onRetry;
  final VoidCallback onEnableLocation;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final copy = _copyFor(result?.status);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(copy.icon, size: 48, color: copy.color),
        const SizedBox(height: 16),
        Text(
          copy.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (copy.message != null) ...[
          const SizedBox(height: 10),
          Text(
            copy.message!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onRetry,
            child: const Text('Try Again'),
          ),
        ),
        if (copy.showLocationAction) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onEnableLocation,
            child: const Text('Enable Location'),
          ),
        ],
        TextButton(
          onPressed: onSignOut,
          child: const Text('Use a different number'),
        ),
      ],
    );
  }

  _Copy _copyFor(NewCustomerRegistrationStatus? status) {
    switch (status) {
      case NewCustomerRegistrationStatus.outsideZone:
      case NewCustomerRegistrationStatus.noActiveZones:
        return const _Copy(
          icon: Icons.location_off_rounded,
          color: AppColors.warning,
          title: 'Tukkito is not available in your current location yet.',
          message: "We're expanding to more locations soon.",
        );
      case NewCustomerRegistrationStatus.locationPermissionDenied:
        return const _Copy(
          icon: Icons.location_disabled_rounded,
          color: AppColors.error,
          title:
              'Location access is required to check Tukkito availability in your area.',
          showLocationAction: true,
        );
      case NewCustomerRegistrationStatus.locationServicesDisabled:
        return const _Copy(
          icon: Icons.gps_off_rounded,
          color: AppColors.error,
          title: 'Please turn on location services to continue.',
          showLocationAction: true,
        );
      case NewCustomerRegistrationStatus.gpsUnavailable:
        return const _Copy(
          icon: Icons.gps_off_rounded,
          color: AppColors.error,
          title: 'Unable to obtain your current location. Please try again.',
        );
      case NewCustomerRegistrationStatus.serviceabilityUnavailable:
        return const _Copy(
          icon: Icons.wifi_off_rounded,
          color: AppColors.error,
          title: 'Tukkito could not confirm delivery coverage right now.',
          message: 'Please try again in a moment.',
        );
      case NewCustomerRegistrationStatus.created:
      case NewCustomerRegistrationStatus.existingCustomer:
      case null:
        return const _Copy(
          icon: Icons.hourglass_top_rounded,
          color: AppColors.info,
          title: 'Checking Tukkito availability in your area...',
        );
    }
  }
}

class _Copy {
  const _Copy({
    required this.icon,
    required this.color,
    required this.title,
    this.message,
    this.showLocationAction = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? message;
  final bool showLocationAction;
}
