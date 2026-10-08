import '../../location/domain/entities/user_location.dart';
import '../../serviceability/domain/geo_distance.dart';
import 'entities/restaurant_entity.dart';

/// Scopes restaurant DISCOVERY to the customer's selected delivery
/// destination.
///
/// Before this, discovery showed every customer-visible, open restaurant in
/// the country as soon as a pincode had passed the serviceability check — even
/// though the customer could not actually order from most of them. This rule
/// lists only restaurants the customer can order from at the destination: those
/// no farther from it than the platform's maximum delivery distance.
///
/// WHAT THIS IS, AND IS NOT. It reuses the range rule that ordering already
/// enforces — [maxDistanceKm] is the platform's 15 km delivery limit, which
/// `placeOrder` applies to the ROAD distance. Discovery uses the
/// straight-line (Haversine) distance, which is never longer than the road, so
/// a restaurant beyond this line can never be ordered from; one inside it may
/// still be refused at checkout when the road route exceeds 15 km. It is NOT zone matching: it does not resolve the
/// destination to a Tukkito zone, does not look at pincodes, and does not
/// decide serviceability (that stays with the existing pincode gate). Zone-based
/// discovery is a later phase; until then this is the strongest scoping the
/// current data supports, and it is deliberately fail-closed.
class RestaurantDeliveryRange {
  RestaurantDeliveryRange._();

  /// Farthest a restaurant may be from the delivery destination and still be
  /// discoverable. Keep equal to the backend's maximum commercial delivery
  /// distance (delivery_rate_config.ts, 15 km).
  static const double maxDistanceKm = 15;

  /// Restaurant → destination distance, or null when either side has no usable
  /// coordinates (missing, out of range, or the (0,0) placeholder).
  static double? distanceKm({
    required RestaurantEntity restaurant,
    required UserLocation destination,
  }) {
    if (!_hasUsableCoordinates(restaurant.latitude, restaurant.longitude) ||
        !_hasUsableCoordinates(destination.latitude, destination.longitude)) {
      return null;
    }
    return GeoDistance.calculateDistanceKm(
      latitude1: destination.latitude,
      longitude1: destination.longitude,
      latitude2: restaurant.latitude,
      longitude2: restaurant.longitude,
    );
  }

  /// True when [destination] can be measured against restaurants at all: it
  /// exists and has usable coordinates (in range, not the (0,0) placeholder).
  static bool isUsableDestination(UserLocation? destination) {
    return destination != null &&
        _hasUsableCoordinates(destination.latitude, destination.longitude);
  }

  static bool isWithinRange({
    required RestaurantEntity restaurant,
    required UserLocation destination,
  }) {
    final km = distanceKm(restaurant: restaurant, destination: destination);
    return km != null && km <= maxDistanceKm;
  }

  /// The restaurants that can deliver to [destination], in their original
  /// order.
  ///
  /// Fail-closed: with no destination (nothing selected, no GPS, permission
  /// denied) or one without usable coordinates, NOTHING is discoverable —
  /// returning the unrestricted list would reintroduce the nationwide feed.
  /// A restaurant whose own coordinates are unusable is excluded too, since it
  /// cannot be priced or ordered from either.
  static List<RestaurantEntity> within({
    required Iterable<RestaurantEntity> restaurants,
    required UserLocation? destination,
  }) {
    if (destination == null ||
        !_hasUsableCoordinates(destination.latitude, destination.longitude)) {
      return const [];
    }
    return restaurants
        .where(
          (restaurant) =>
              isWithinRange(restaurant: restaurant, destination: destination),
        )
        .toList();
  }

  static bool _hasUsableCoordinates(double latitude, double longitude) {
    if (!GeoDistance.isValidLatitude(latitude) ||
        !GeoDistance.isValidLongitude(longitude)) {
      return false;
    }
    return !(latitude == 0 && longitude == 0);
  }
}
