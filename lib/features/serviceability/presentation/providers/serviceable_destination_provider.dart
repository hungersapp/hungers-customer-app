import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../location/domain/entities/user_location.dart';
import '../../../location/presentation/providers/selected_destination_provider.dart';
import 'destination_serviceability_provider.dart';

/// The delivery destination every discovery surface is based on: the
/// customer's SELECTED delivery location, but only when Tukkito serves it.
///
/// Home sections, categories, search and recommended foods all read this one
/// provider, so they can never disagree about where the customer is
/// browsing for. It is `null` — and discovery therefore returns nothing,
/// never a nationwide list — when:
///
///  * nobody is signed in, or no location has been chosen;
///  * the location has no usable coordinates;
///  * its coordinates are not inside an active Tukkito zone, or the zones
///    could not be read ([destinationServiceabilityProvider]).
///
/// Serviceability is decided from the location's latitude and longitude, not
/// from a pincode, and it is worked out for THIS location: a newly chosen
/// place is never judged by (or shows the restaurants of) the previous one.
///
/// Which restaurants can then deliver there is the existing
/// `RestaurantDeliveryRange` (distance from the location's coordinates).
final serviceableDeliveryDestinationProvider = FutureProvider<UserLocation?>((
  ref,
) async {
  final serviceability = await ref.watch(
    destinationServiceabilityProvider.future,
  );
  if (serviceability != DestinationServiceability.serviceable) {
    return null;
  }
  return ref.watch(selectedDeliveryDestinationProvider.future);
});
