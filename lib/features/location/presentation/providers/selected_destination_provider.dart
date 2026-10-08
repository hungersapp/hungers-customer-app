import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/providers/auth_provider.dart';
import '../../domain/entities/user_location.dart';
import 'location_provider.dart';

/// The customer's ACTIVE location — `users/{uid}.location` — which
/// serviceability and restaurant discovery are scoped to.
///
/// It is the phone's GPS position, or a place the customer chose (which holds
/// until the phone travels away from where it was chosen — see
/// LocationRefreshPolicy). It re-resolves whenever the active location
/// changes (a customer's choice, or GPS taking over), so everything that
/// watches it refreshes together. `null` when signed out or when nothing is
/// saved yet.
final selectedDeliveryDestinationProvider = FutureProvider<UserLocation?>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return null;
  }
  return ref.watch(userLocationProvider(userId).future);
});
