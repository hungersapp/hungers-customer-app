import 'entities/rider_location.dart';

/// Rider-location freshness for the customer map.
///
/// LIVE means a trustworthy fix within 60 seconds. Older than that is
/// stale: the marker is hidden and the customer is told the location is
/// unavailable. This is not an attendance signal.
class RiderLocationFreshness {
  RiderLocationFreshness._();

  static const Duration maxAge = Duration(seconds: 60);

  static bool isFresh(DateTime updatedAt, DateTime now) {
    final age = now.difference(updatedAt);
    return !age.isNegative && age <= maxAge;
  }

  static String updatedLabel(DateTime updatedAt, DateTime now) {
    final seconds = now.difference(updatedAt).inSeconds;
    if (seconds < 0 || seconds > maxAge.inSeconds) {
      return 'Rider location is temporarily unavailable';
    }
    if (seconds < 5) {
      return 'Updated 5 seconds ago';
    }
    return 'Updated $seconds seconds ago';
  }
}

extension RiderLocationFreshnessX on RiderLocation {
  bool isFreshAt(DateTime now) => RiderLocationFreshness.isFresh(updatedAt, now);
}
