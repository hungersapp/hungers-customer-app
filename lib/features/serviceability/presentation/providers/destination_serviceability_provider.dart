import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../location/presentation/providers/selected_destination_provider.dart';
import '../../../restaurants/domain/discovery_debug_log.dart';
import '../../../restaurants/domain/restaurant_delivery_range.dart';
import '../../domain/entities/active_delivery_zone.dart';
import '../../domain/location_serviceability_decision.dart';
import 'serviceability_provider.dart';

/// Whether Tukkito serves the customer's selected delivery location.
enum DestinationServiceability {
  /// Nothing has been chosen yet (or nobody is signed in).
  noDestination,

  /// A location is saved but its coordinates cannot be used.
  invalidLocation,

  /// The location's coordinates are inside an active Tukkito zone.
  serviceable,

  /// The location is outside every active zone (or no zone is active).
  notServiceable,

  /// The zones could not be read, so nothing can be said about the location.
  /// Never treated as serviceable.
  unavailable,
}

/// Serviceability of the SELECTED DELIVERY LOCATION, decided from its
/// latitude and longitude — never from a pincode.
///
/// The customer chooses a place (current location, or a searched area); its
/// coordinates are what matter. They are checked against the active
/// `serviceability_zones` with the same rule the platform already uses for
/// customers ([LocationServiceabilityDecision]: distance from the zone centre
/// within the zone's radius). No zone id is sent or trusted: the zones are read
/// from Tukkito's own master data, and the result is only a yes / no.
///
/// A pincode, when the geocoder returned one, is address metadata for the
/// order — it plays no part here, so the customer never has to type one to see
/// restaurants.
///
/// Re-evaluated whenever the selected location changes. Fail-closed: no
/// location, unusable coordinates, no active zone, or a zone read that failed
/// all yield something other than [DestinationServiceability.serviceable].
final destinationServiceabilityProvider =
    FutureProvider<DestinationServiceability>((ref) async {
      final destination = await ref.watch(
        selectedDeliveryDestinationProvider.future,
      );
      if (destination == null) {
        discoveryDebug('serviceability=noDestination');
        return DestinationServiceability.noDestination;
      }
      discoveryDebug(
        'serviceability dest lat=${destination.latitude} '
        'lng=${destination.longitude} city=${destination.city} '
        'selectedByCustomer=${destination.selectedByCustomer} '
        'isLiveGpsDefault=${destination.isLiveGpsDefault}',
      );
      if (!RestaurantDeliveryRange.isUsableDestination(destination)) {
        discoveryDebug('serviceability=invalidLocation');
        return DestinationServiceability.invalidLocation;
      }

      final List<ActiveDeliveryZone> zones;
      try {
        zones = await ref
            .watch(serviceabilityRepositoryProvider)
            .getActiveDeliveryZones();
      } catch (error) {
        discoveryDebug('serviceability=unavailable zone_read_error=$error');
        return DestinationServiceability.unavailable;
      }

      switch (LocationServiceabilityDecision.evaluate(
        latitude: destination.latitude,
        longitude: destination.longitude,
        zones: zones,
      )) {
        case LocationServiceabilityOutcome.insideActiveZone:
          discoveryDebug(
            'serviceability=serviceable zones=${zones.length}',
          );
          return DestinationServiceability.serviceable;
        case LocationServiceabilityOutcome.outsideAllZones:
        case LocationServiceabilityOutcome.noActiveZones:
          discoveryDebug(
            'serviceability=notServiceable zones=${zones.length} '
            'first_empty_stage=serviceability (outside active zones)',
          );
          return DestinationServiceability.notServiceable;
        case LocationServiceabilityOutcome.invalidCoordinates:
          discoveryDebug('serviceability=invalidCoordinates');
          return DestinationServiceability.invalidLocation;
      }
    });

/// [destinationServiceabilityProvider] in the shape the Home status card
/// renders: checking while it is being worked out, then the chooser prompt,
/// "no restaurants available in this location", a retryable error, or nothing
/// (serviceable — the restaurants show instead).
final deliveryServiceabilityProvider = Provider<ServiceabilityState>((ref) {
  return ref
      .watch(destinationServiceabilityProvider)
      .when(
        loading: () =>
            const ServiceabilityState(status: ServiceabilityUiStatus.checking),
        error: (_, _) =>
            const ServiceabilityState(status: ServiceabilityUiStatus.error),
        data: (result) => switch (result) {
          DestinationServiceability.noDestination ||
          DestinationServiceability.invalidLocation =>
            const ServiceabilityState(),
          DestinationServiceability.serviceable => const ServiceabilityState(
            status: ServiceabilityUiStatus.serviceable,
          ),
          DestinationServiceability.notServiceable => const ServiceabilityState(
            status: ServiceabilityUiStatus.notServiceable,
          ),
          DestinationServiceability.unavailable => const ServiceabilityState(
            status: ServiceabilityUiStatus.error,
          ),
        },
      );
});
