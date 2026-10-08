import '../../../core/geo/geohash.dart';
import '../../location/domain/entities/user_location.dart';
import 'restaurant_delivery_range.dart';

/// Builds the geohash4 cell list for a selected delivery destination.
///
/// Empty when the destination cannot be measured — callers must fail closed
/// rather than falling back to a nationwide query.
class RestaurantDiscoveryQuery {
  RestaurantDiscoveryQuery._();

  static List<String> geohash4CellsFor(UserLocation? destination) {
    if (!RestaurantDeliveryRange.isUsableDestination(destination)) {
      return const [];
    }
    return GeoHash.coveringCells(
      latitude: destination!.latitude,
      longitude: destination.longitude,
    );
  }
}
