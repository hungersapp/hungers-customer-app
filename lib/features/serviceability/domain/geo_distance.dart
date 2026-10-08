import 'dart:math' as math;

/// Deterministic geographic distance. No maps, network, or Firebase.
class GeoDistance {
  GeoDistance._();

  static const double earthRadiusKm = 6371.0;

  static bool isValidLatitude(double value) => value >= -90 && value <= 90;

  static bool isValidLongitude(double value) => value >= -180 && value <= 180;

  /// Haversine distance in kilometers. Returns null for invalid coordinates.
  static double? calculateDistanceKm({
    required double latitude1,
    required double longitude1,
    required double latitude2,
    required double longitude2,
  }) {
    if (!isValidLatitude(latitude1) ||
        !isValidLatitude(latitude2) ||
        !isValidLongitude(longitude1) ||
        !isValidLongitude(longitude2)) {
      return null;
    }

    if (latitude1 == latitude2 && longitude1 == longitude2) {
      return 0;
    }

    final lat1 = _toRadians(latitude1);
    final lat2 = _toRadians(latitude2);
    final dLat = _toRadians(latitude2 - latitude1);
    final dLng = _toRadians(longitude2 - longitude1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Display label used by Home restaurant cards and category food cards.
  static String? formatKmLabel(double? km) {
    if (km == null) {
      return null;
    }
    if (km < 0.1) {
      return '< 0.1 km';
    }
    if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    }
    return '${km.round()} km';
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
