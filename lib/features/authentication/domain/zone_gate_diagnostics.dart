import 'package:flutter/foundation.dart';

/// Development-only failure categories for the new-customer zone gate.
///
/// Do not log OTP, tokens, coordinates, or other customer data.
abstract final class ZoneGateDiagnostics {
  static const locationPermission = 'location_permission';
  static const locationServices = 'location_services';
  static const locationFetch = 'location_fetch';
  static const serviceabilityRead = 'serviceability_read';
  static const zoneCalculation = 'zone_calculation';

  static void log(String category) {
    assert(() {
      debugPrint('zone_gate category=$category');
      return true;
    }());
  }
}
