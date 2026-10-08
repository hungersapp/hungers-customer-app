import '../../../core/location/bearing_calculator.dart';
import '../../serviceability/domain/geo_distance.dart';

/// Visual-only: hold the bike marker unless the rider has clearly moved.
/// Not a distance, proximity, or delivery-validation rule.
const double riderMarkerStationaryHoldMeters = 15;

/// Visual-only: ignore heading twitches smaller than this while updating
/// rotation along the shortest 0°/360° arc.
const double riderMarkerHeadingDeadbandDegrees = 8;

class _RiderMarkerFix {
  const _RiderMarkerFix({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.headingAccuracy,
  });

  final double latitude;
  final double longitude;
  final double? heading;
  final double? headingAccuracy;
}

/// Filters raw `delivery_jobs/{orderId}.riderLocation` into a display
/// pose for the customer map bike marker.
///
/// Raw GPS stays on [rawLatitude]/[rawLongitude]. Display lat/lng and
/// heading are for marker rendering only — never for routes, distance,
/// or backend writes.
class RiderMarkerVisual {
  double _heading = 0;
  _RiderMarkerFix? _raw;
  _RiderMarkerFix? _display;

  double get heading => _heading;

  double? get displayLatitude => (_display ?? _raw)?.latitude;

  double? get displayLongitude => (_display ?? _raw)?.longitude;

  double? get rawLatitude => _raw?.latitude;

  double? get rawLongitude => _raw?.longitude;

  void reset() {
    _heading = 0;
    _raw = null;
    _display = null;
  }

  void apply({
    required double latitude,
    required double longitude,
    double? heading,
    double? headingAccuracy,
  }) {
    final location = _RiderMarkerFix(
      latitude: latitude,
      longitude: longitude,
      heading: heading,
      headingAccuracy: headingAccuracy,
    );
    final previousRaw = _raw;
    final previousDisplay = _display ?? previousRaw;
    final movementMeters = _movementMeters(previousDisplay, location);
    final jumped =
        movementMeters != null &&
        movementMeters >= riderMarkerStationaryHoldMeters;
    final shouldMoveMarker = previousDisplay == null || jumped;

    _raw = location;
    if (shouldMoveMarker) {
      _heading = _visualHeadingForAcceptedMove(
        location: location,
        previousDisplay: previousDisplay,
        movementMeters: movementMeters,
      );
      _display = location;
    }
  }

  /// Heading for an accepted visual move only. Stationary GPS ticks never
  /// reach here, so noise cannot spin the icon. Prefers a reliable GPS
  /// course unless it points opposite the actual displacement.
  double _visualHeadingForAcceptedMove({
    required _RiderMarkerFix location,
    required _RiderMarkerFix? previousDisplay,
    required double? movementMeters,
  }) {
    final fromGps = resolveBearing(
      currentLatitude: location.latitude,
      currentLongitude: location.longitude,
      currentHeading: location.heading,
      currentHeadingAccuracy: location.headingAccuracy,
      previousLatitude: previousDisplay?.latitude,
      previousLongitude: previousDisplay?.longitude,
      fallbackBearing: _heading,
    );
    var target = fromGps;
    if (previousDisplay != null &&
        movementMeters != null &&
        movementMeters >= riderMarkerStationaryHoldMeters) {
      final fromTrack = resolveBearing(
        currentLatitude: location.latitude,
        currentLongitude: location.longitude,
        currentHeading: null,
        currentHeadingAccuracy: null,
        previousLatitude: previousDisplay.latitude,
        previousLongitude: previousDisplay.longitude,
        fallbackBearing: _heading,
      );
      if (isHeadingReliable(location.headingAccuracy) &&
          location.heading != null &&
          shortestHeadingDelta(fromTrack, fromGps).abs() > 90) {
        target = fromTrack;
      }
    }
    return applyShortestHeading(
      currentDegrees: _heading,
      targetDegrees: target,
      deadbandDegrees: riderMarkerHeadingDeadbandDegrees,
    );
  }

  static double? _movementMeters(
    _RiderMarkerFix? from,
    _RiderMarkerFix to,
  ) {
    if (from == null) {
      return null;
    }
    final km = GeoDistance.calculateDistanceKm(
      latitude1: from.latitude,
      longitude1: from.longitude,
      latitude2: to.latitude,
      longitude2: to.longitude,
    );
    if (km == null) {
      return null;
    }
    return km * 1000;
  }
}
