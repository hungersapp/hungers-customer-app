import 'entities/active_delivery_zone.dart';
import 'geo_distance.dart';
import 'zone_polygon.dart';

enum LocationServiceabilityOutcome {
  insideActiveZone,
  outsideAllZones,
  noActiveZones,
  invalidCoordinates,
}

/// GPS + active zone boundary. Does not use pincode.
class LocationServiceabilityDecision {
  LocationServiceabilityDecision._();

  /// True when the coordinate is inside the zone: within its radius, or,
  /// for a Custom Polygon zone, inside its polygon (the radius is then not
  /// consulted). Same rule as the backend's placeOrder gate.
  static bool isWithinZoneRadius({
    required ActiveDeliveryZone zone,
    required double latitude,
    required double longitude,
  }) {
    if (!zone.isActive) {
      return false;
    }
    if (zone.usesPolygon) {
      return ZonePolygon.contains(zone.polygon, latitude, longitude);
    }
    if (zone.radiusKm <= 0) {
      return false;
    }
    final distance = GeoDistance.calculateDistanceKm(
      latitude1: zone.centerLatitude,
      longitude1: zone.centerLongitude,
      latitude2: latitude,
      longitude2: longitude,
    );
    if (distance == null) {
      return false;
    }
    return distance <= zone.radiusKm;
  }

  static LocationServiceabilityOutcome evaluate({
    required double latitude,
    required double longitude,
    required Iterable<ActiveDeliveryZone> zones,
  }) {
    if (!GeoDistance.isValidLatitude(latitude) ||
        !GeoDistance.isValidLongitude(longitude)) {
      return LocationServiceabilityOutcome.invalidCoordinates;
    }

    final active = zones.where((zone) => zone.isActive).toList();
    if (active.isEmpty) {
      return LocationServiceabilityOutcome.noActiveZones;
    }

    for (final zone in active) {
      if (isWithinZoneRadius(
        zone: zone,
        latitude: latitude,
        longitude: longitude,
      )) {
        return LocationServiceabilityOutcome.insideActiveZone;
      }
    }
    return LocationServiceabilityOutcome.outsideAllZones;
  }
}
