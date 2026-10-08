import 'package:equatable/equatable.dart';

import 'geo_distance.dart';

/// One corner of a zone boundary, as stored in
/// `serviceability_zones.customPolygon`.
class ZonePoint extends Equatable {
  const ZonePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  /// Reads `[{latitude, longitude}]`. Anything that is not a coordinate is
  /// dropped.
  static List<ZonePoint> listFrom(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final points = <ZonePoint>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final latitude = item['latitude'];
      final longitude = item['longitude'];
      if (latitude is num &&
          longitude is num &&
          latitude.isFinite &&
          longitude.isFinite &&
          GeoDistance.isValidLatitude(latitude.toDouble()) &&
          GeoDistance.isValidLongitude(longitude.toDouble())) {
        points.add(
          ZonePoint(
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
          ),
        );
      }
    }
    return points;
  }

  @override
  List<Object?> get props => [latitude, longitude];
}

/// Point-in-polygon for a Custom Polygon zone. Same rule as the backend
/// (`geo_shapes.ts`): ray casting, a point on an edge is inside, and fewer
/// than three distinct points contain nothing.
class ZonePolygon {
  ZonePolygon._();

  static const int minPoints = 3;

  static bool isUsable(List<ZonePoint> points) {
    return points.length >= minPoints && points.toSet().length >= minPoints;
  }

  static bool contains(
    List<ZonePoint> points,
    double latitude,
    double longitude,
  ) {
    if (!isUsable(points) ||
        !GeoDistance.isValidLatitude(latitude) ||
        !GeoDistance.isValidLongitude(longitude)) {
      return false;
    }
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final a = points[i];
      final b = points[j];
      if (_onSegment(a, b, latitude, longitude)) {
        return true;
      }
      final crosses = (a.latitude > latitude) != (b.latitude > latitude);
      if (crosses &&
          longitude <
              (b.longitude - a.longitude) *
                      (latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool _onSegment(
    ZonePoint a,
    ZonePoint b,
    double latitude,
    double longitude,
  ) {
    const tolerance = 1e-12;
    final cross =
        (b.longitude - a.longitude) * (latitude - a.latitude) -
        (b.latitude - a.latitude) * (longitude - a.longitude);
    if (cross.abs() > tolerance) {
      return false;
    }
    final minLatitude = a.latitude < b.latitude ? a.latitude : b.latitude;
    final maxLatitude = a.latitude > b.latitude ? a.latitude : b.latitude;
    final minLongitude = a.longitude < b.longitude ? a.longitude : b.longitude;
    final maxLongitude = a.longitude > b.longitude ? a.longitude : b.longitude;
    return latitude >= minLatitude - tolerance &&
        latitude <= maxLatitude + tolerance &&
        longitude >= minLongitude - tolerance &&
        longitude <= maxLongitude + tolerance;
  }
}
