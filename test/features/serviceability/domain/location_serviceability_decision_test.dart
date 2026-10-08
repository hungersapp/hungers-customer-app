import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/serviceability/domain/entities/active_delivery_zone.dart';
import 'package:customer_app/features/serviceability/domain/location_serviceability_decision.dart';

const _madurai = ActiveDeliveryZone(
  id: 'zone-1',
  centerLatitude: 9.9252,
  centerLongitude: 78.1198,
  radiusKm: 8,
  isActive: true,
);

const _inactive = ActiveDeliveryZone(
  id: 'zone-inactive',
  centerLatitude: 9.9252,
  centerLongitude: 78.1198,
  radiusKm: 8,
  isActive: false,
);

const _chennai = ActiveDeliveryZone(
  id: 'zone-2',
  centerLatitude: 13.0827,
  centerLongitude: 80.2707,
  radiusKm: 6,
  isActive: true,
);

void main() {
  test('inside an active zone is allowed', () {
    expect(
      LocationServiceabilityDecision.evaluate(
        latitude: 9.9252,
        longitude: 78.1198,
        zones: [_madurai],
      ),
      LocationServiceabilityOutcome.insideActiveZone,
    );
  });

  test('outside all active zones is blocked', () {
    expect(
      LocationServiceabilityDecision.evaluate(
        latitude: 12.9716,
        longitude: 77.5946,
        zones: [_madurai],
      ),
      LocationServiceabilityOutcome.outsideAllZones,
    );
  });

  test('inside an inactive zone is blocked', () {
    expect(
      LocationServiceabilityDecision.evaluate(
        latitude: 9.9252,
        longitude: 78.1198,
        zones: [_inactive],
      ),
      LocationServiceabilityOutcome.noActiveZones,
    );
  });

  test('multiple zones with one matching is allowed', () {
    expect(
      LocationServiceabilityDecision.evaluate(
        latitude: 13.0827,
        longitude: 80.2707,
        zones: [_madurai, _chennai],
      ),
      LocationServiceabilityOutcome.insideActiveZone,
    );
  });

  test('no active zones is blocked', () {
    expect(
      LocationServiceabilityDecision.evaluate(
        latitude: 9.9252,
        longitude: 78.1198,
        zones: const [],
      ),
      LocationServiceabilityOutcome.noActiveZones,
    );
  });
}
