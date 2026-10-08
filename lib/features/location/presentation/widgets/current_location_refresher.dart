import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/providers/auth_provider.dart';
import '../providers/location_provider.dart';

/// Keeps the device GPS reading fresh while Home is open: when it is first
/// shown (unless the splash / login flow already read it), whenever the app
/// resumes, and when the phone moves a meaningful distance.
///
/// What a reading may do to the active location is LocationRefreshPolicy's
/// call — an explicit selection is never changed by it, so returning from a
/// UPI app or a browser cannot move the delivery location.
///
/// One-shot reads join concurrent calls and are throttled. In-app movement
/// uses a single GPS stream with an OS distance filter — never continuous
/// Firestore writes and never rider-style tracking.
class CurrentLocationRefresher extends ConsumerStatefulWidget {
  const CurrentLocationRefresher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CurrentLocationRefresher> createState() =>
      _CurrentLocationRefresherState();
}

class _CurrentLocationRefresherState
    extends ConsumerState<CurrentLocationRefresher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_start);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      ref.read(locationSetupProvider.notifier).stopWatching();
    } catch (_) {
      // Provider already disposed with the widget tree.
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _start() {
    if (!mounted) {
      return;
    }
    // The splash / login flow already read GPS (or was refused): do not read
    // or prompt a second time the moment Home appears.
    if (ref.read(locationSetupProvider.notifier).startupReadAttempted) {
      _watchIfPermitted();
      return;
    }
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      return;
    }

    // A resume must not re-open the permission prompt the customer already
    // declined (the banner's "Allow" does that, on request).
    if (ref.read(deviceLocationStatusProvider) ==
        DeviceLocationStatus.permissionDenied) {
      return;
    }

    await ref
        .read(locationSetupProvider.notifier)
        .refreshCurrentLocation(userId);
    _watchIfPermitted();
  }

  /// Starts the single movement watch once GPS is known to be readable.
  void _watchIfPermitted() {
    if (!mounted) {
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId == null ||
        ref.read(deviceLocationStatusProvider) !=
            DeviceLocationStatus.available) {
      return;
    }
    ref.read(locationSetupProvider.notifier).startWatching(userId);
  }

  @override
  Widget build(BuildContext context) {
    // GPS became readable later (the customer tapped Allow / Retry).
    ref.listen<DeviceLocationStatus>(deviceLocationStatusProvider, (_, next) {
      if (next == DeviceLocationStatus.available) {
        _watchIfPermitted();
      }
    });
    return widget.child;
  }
}
