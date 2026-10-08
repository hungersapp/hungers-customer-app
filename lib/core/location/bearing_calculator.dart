import 'package:geolocator/geolocator.dart';

/// The minimum distance (meters) the rider must have moved between two
/// consecutive fixes before a fallback bearing is computed from them —
/// below this, GPS jitter alone can flip the calculated bearing by
/// hundreds of degrees for a stationary or barely-moving rider.
const double minimumBearingDistanceMeters = 3;

/// geolocator's `Position.heading`/`Position.headingAccuracy` both report
/// exactly `0.0` when the device's course-over-ground is unavailable —
/// documented platform behavior (see [Position.heading]'s own doc
/// comment: "not available on all devices... value is 0.0"). A positive
/// [headingAccuracy] is therefore the signal that `heading` reflects a
/// real GPS-derived course, not the ambiguous "unavailable" sentinel.
bool isHeadingReliable(double? headingAccuracy) {
  return headingAccuracy != null && headingAccuracy > 0;
}

/// Resolves the bearing (degrees, 0-360, clockwise from true north) the
/// rider marker should be rotated to.
///
/// Prefers the device's own GPS-derived course-over-ground
/// ([currentHeading]) when [isHeadingReliable] says it can be trusted.
/// Otherwise, once the rider has moved at least
/// [minimumBearingDistanceMeters] since the previous fix, falls back to
/// the great-circle initial bearing between the two fixes — reusing
/// [Geolocator.bearingBetween]/[Geolocator.distanceBetween] (pure
/// Haversine math, no platform channel involved) rather than
/// reimplementing the same formula. If neither source is usable (no
/// previous fix yet, or the rider hasn't moved enough to reliably imply
/// a direction), returns [fallbackBearing] unchanged rather than
/// guessing — this deliberately never fabricates movement.
double resolveBearing({
  required double currentLatitude,
  required double currentLongitude,
  required double? currentHeading,
  required double? currentHeadingAccuracy,
  required double? previousLatitude,
  required double? previousLongitude,
  required double fallbackBearing,
}) {
  if (currentHeading != null && isHeadingReliable(currentHeadingAccuracy)) {
    return currentHeading % 360;
  }

  if (previousLatitude != null && previousLongitude != null) {
    final movedMeters = Geolocator.distanceBetween(
      previousLatitude,
      previousLongitude,
      currentLatitude,
      currentLongitude,
    );
    if (movedMeters >= minimumBearingDistanceMeters) {
      final bearing = Geolocator.bearingBetween(
        previousLatitude,
        previousLongitude,
        currentLatitude,
        currentLongitude,
      );
      return (bearing + 360) % 360;
    }
  }

  return fallbackBearing;
}

/// Smallest signed turn from [fromDegrees] to [toDegrees] in (-180, 180].
/// Used only for the map marker so a 350° → 10° change is +20°, not a
/// full spin.
double shortestHeadingDelta(double fromDegrees, double toDegrees) {
  final from = ((fromDegrees % 360) + 360) % 360;
  final to = ((toDegrees % 360) + 360) % 360;
  var delta = to - from;
  if (delta > 180) {
    delta -= 360;
  } else if (delta <= -180) {
    delta += 360;
  }
  return delta;
}

/// Visual-only: step [currentDegrees] toward [targetDegrees] along the
/// shortest arc. Turns smaller than [deadbandDegrees] are ignored so
/// GPS heading noise does not twitch the icon. The result is not wrapped
/// back into 0–360 so a 350° → 10° update becomes 370° and the marker
/// interpolates +20° instead of spinning the long way.
double applyShortestHeading({
  required double currentDegrees,
  required double targetDegrees,
  double deadbandDegrees = 8,
}) {
  final delta = shortestHeadingDelta(currentDegrees, targetDegrees);
  if (delta.abs() < deadbandDegrees) {
    return currentDegrees;
  }
  return currentDegrees + delta;
}
