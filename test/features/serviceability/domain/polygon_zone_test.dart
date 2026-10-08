import 'package:customer_app/features/serviceability/domain/entities/active_delivery_zone.dart';
import 'package:customer_app/features/serviceability/domain/location_serviceability_decision.dart';
import 'package:customer_app/features/serviceability/domain/zone_polygon.dart';
import 'package:flutter_test/flutter_test.dart';

const _square = [
  ZonePoint(latitude: 20.0, longitude: 70.0),
  ZonePoint(latitude: 20.0, longitude: 70.1),
  ZonePoint(latitude: 20.1, longitude: 70.1),
  ZonePoint(latitude: 20.1, longitude: 70.0),
];

ActiveDeliveryZone _polygonZone({double radiusKm = 0}) {
  return ActiveDeliveryZone(
    id: 'POLY',
    centerLatitude: 20.05,
    centerLongitude: 70.05,
    radiusKm: radiusKm,
    isActive: true,
    usesPolygon: true,
    polygon: _square,
  );
}

void main() {
  test('a polygon contains its interior and its edges, and nothing else', () {
    expect(ZonePolygon.contains(_square, 20.05, 70.05), isTrue);
    expect(ZonePolygon.contains(_square, 20.0, 70.05), isTrue);
    expect(ZonePolygon.contains(_square, 19.99, 70.05), isFalse);
    expect(ZonePolygon.contains(_square.sublist(0, 2), 20.0, 70.05), isFalse);
  });

  test('a polygon zone with no radius is serviceable inside its polygon', () {
    expect(
      LocationServiceabilityDecision.evaluate(
        latitude: 20.05,
        longitude: 70.05,
        zones: [_polygonZone()],
      ),
      LocationServiceabilityOutcome.insideActiveZone,
    );
  });

  test('a polygon zone is not widened by its radius', () {
    expect(
      LocationServiceabilityDecision.evaluate(
        latitude: 20.2,
        longitude: 70.05,
        zones: [_polygonZone(radiusKm: 50)],
      ),
      LocationServiceabilityOutcome.outsideAllZones,
    );
  });

  test('a radius zone still needs a positive radius', () {
    const circle = ActiveDeliveryZone(
      id: 'CIRCLE',
      centerLatitude: 20.05,
      centerLongitude: 70.05,
      radiusKm: 0,
      isActive: true,
    );
    expect(
      LocationServiceabilityDecision.isWithinZoneRadius(
        zone: circle,
        latitude: 20.05,
        longitude: 70.05,
      ),
      isFalse,
    );
  });

  test('stored points that are not coordinates are dropped', () {
    expect(
      ZonePoint.listFrom([
        {'latitude': 20.0, 'longitude': 70.0},
        {'latitude': 200.0, 'longitude': 70.0},
        'nope',
      ]),
      const [ZonePoint(latitude: 20.0, longitude: 70.0)],
    );
    expect(ZonePoint.listFrom(null), isEmpty);
  });
}
