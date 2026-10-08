import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../authentication/domain/session_route.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../cart/domain/cart_clear_policy.dart';
import '../../location/presentation/providers/location_provider.dart';
import '../../serviceability/presentation/providers/destination_serviceability_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// How long the brand splash is shown at the least.
  static const Duration _minimumSplash = Duration(seconds: 3);

  /// The longest the splash waits for the location to be initialised (the GPS
  /// read itself gives up after 30 s). Past it, Home opens and reports the
  /// location status instead of the customer staring at the splash.
  static const Duration _locationStartupLimit = Duration(seconds: 40);

  bool _showGetStarted = false;
  bool _didNavigate = false;

  /// True while the startup location flow is running past the brand splash.
  bool _findingLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // The brand splash and the startup work run side by side, so location
    // initialisation does not add to the splash unless it really takes longer.
    final minimumSplash = Future<void>.delayed(_minimumSplash);
    if (kIsWeb) {
      // On web the signed-in session is restored asynchronously; the splash
      // delay has always been what gives it time, so keep that order there.
      await minimumSplash;
      if (!mounted) {
        return;
      }
    }

    await const CartStartupHandler().onAppStart();
    await ref.read(authProvider.notifier).loadCurrentUser();
    if (!mounted) {
      return;
    }

    final sessionUser = ref.read(authProvider).valueOrNull;
    var hasProfile = false;
    if (sessionUser != null) {
      final profile = await ref
          .read(authProvider.notifier)
          .loadCustomerProfile(sessionUser.uid);
      hasProfile = profile != null;
    }
    if (!mounted) {
      return;
    }

    final destination = switch (resolveSessionRoute(
      isAuthenticated: sessionUser != null,
      hasCustomerProfile: hasProfile,
    )) {
      SessionRoute.login => AppRoutes.login,
      SessionRoute.dashboard => AppRoutes.dashboard,
      SessionRoute.zoneRegistration => AppRoutes.zoneRegistration,
    };

    if (destination == AppRoutes.dashboard && sessionUser != null) {
      // Home must open with the right location already in place — never an
      // old address that changes a few seconds later.
      var locationReady = false;
      final location = _initializeLocation(
        sessionUser.uid,
      ).whenComplete(() => locationReady = true);
      await minimumSplash;
      if (mounted && !locationReady) {
        setState(() => _findingLocation = true);
      }
      await location;
    } else {
      await minimumSplash;
    }
    if (!mounted) {
      return;
    }

    if (destination == AppRoutes.login) {
      setState(() {
        _showGetStarted = true;
      });
      return;
    }

    _goTo(destination);
  }

  /// The ONE startup location flow: permission → GPS → address → active
  /// location (as LocationRefreshPolicy allows) → serviceability for it.
  /// The Home screen, serviceability and restaurant discovery then reuse the
  /// same provider state instead of starting their own read.
  ///
  /// Never throws and never blocks past [_locationStartupLimit]: when GPS is
  /// refused or unavailable the active location is left as it was and Home
  /// shows the location status.
  Future<void> _initializeLocation(String userId) async {
    try {
      await ref
          .read(locationSetupProvider.notifier)
          .initializeForStartup(userId)
          .timeout(_locationStartupLimit);
      await ref
          .read(destinationServiceabilityProvider.future)
          .timeout(_locationStartupLimit);
    } catch (_) {
      // Slow or failed: Home handles it (status banner / location selector).
    }
  }

  void _onGetStarted() {
    _goTo(AppRoutes.login);
  }

  void _goTo(String route) {
    if (!mounted || _didNavigate) {
      return;
    }
    _didNavigate = true;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    // Keep aspect via BoxFit.contain; size tuned so the mark reads clearly
    // on common phone widths without crowding the title/tagline.
    final markSize = (size.shortestSide * 0.46).clamp(156.0, 228.0);
    final titleSize = textScaler.scale(40).clamp(32.0, 44.0);
    final taglineSize = textScaler.scale(16).clamp(14.0, 18.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/tukkito_mark.png',
                          width: markSize,
                          height: markSize,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Tukkito',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your Food. Your Choice.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: taglineSize,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        if (_findingLocation) ...[
                          const SizedBox(height: 28),
                          const _FindingLocation(),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_showGetStarted)
                  _GetStartedButton(onPressed: _onGetStarted),
                if (_showGetStarted) const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the location is still being worked out after the brand splash:
/// the customer waits here rather than seeing a wrong location on Home.
class _FindingLocation extends StatelessWidget {
  const _FindingLocation();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textLight,
          ),
        ),
        SizedBox(width: 12),
        Text(
          'Finding your location…',
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.secondary,
              disabledBackgroundColor: AppColors.surface,
              elevation: 0,
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Get Started  →',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
