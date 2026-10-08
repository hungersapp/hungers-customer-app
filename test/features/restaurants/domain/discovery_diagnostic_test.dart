import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/core/geo/geohash.dart';
import 'package:customer_app/features/location/domain/discovery_location_kind.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/restaurants/domain/discovery_diagnostic.dart';
import 'package:customer_app/features/restaurants/domain/restaurant_discovery_query.dart';
import 'package:customer_app/features/serviceability/domain/entities/active_delivery_zone.dart';
import 'package:customer_app/features/serviceability/domain/location_serviceability_decision.dart';

import '../../../helpers/discovery_fixtures.dart';

UserLocation _gpsAt(City city) => destinationIn(city, selected: false);

void main() {
  test('a nearby listable restaurant with geohash4 is discovered', () {
    final destination = _gpsAt(madurai);
    final restaurant = RestaurantPublicProbe(
      restaurantId: 'madurai-kitchen',
      latitude: madurai.latitude,
      longitude: madurai.longitude,
      geohash: GeoHash.encode(madurai.latitude, madurai.longitude),
      geohash4: GeoHash.cell4(madurai.latitude, madurai.longitude),
    );

    final report = DiscoveryDiagnostic.analyze(
      destination: destination,
      serviceable: true,
      catalog: [restaurant],
    );

    expect(report.locationKind, DiscoveryLocationKind.currentLocation);
    expect(report.isLiveGpsDefault, isTrue);
    expect(report.selectedByCustomer, isFalse);
    expect(report.geohash4Cells, isNotEmpty);
    expect(report.rawDocumentsReturned, 1);
    expect(report.finalCount, 1);
    expect(report.firstEmptyStage, DiscoveryEmptyStage.none);
  });

  test(
    'Restaurant excluded because geohash4 is missing; production backfill required.',
    () {
      final destination = _gpsAt(madurai);
      final restaurant = RestaurantPublicProbe(
        restaurantId: 'madurai-kitchen',
        latitude: madurai.latitude,
        longitude: madurai.longitude,
        geohash: null,
        geohash4: null,
      );

      final report = DiscoveryDiagnostic.analyze(
        destination: destination,
        serviceable: true,
        catalog: [restaurant],
      );

      expect(report.finalCount, 0);
      expect(
        report.firstEmptyStage,
        DiscoveryEmptyStage.firestoreGeohashQueryEmpty,
      );
      expect(
        report.missingGeohash4Message,
        'Restaurant excluded because geohash4 is missing; production backfill required.',
      );

      final probe = DiscoveryDiagnostic.inspectRestaurant(
        restaurant: restaurant,
        destination: destination,
        customerDestinationServiceable: true,
      );
      expect(probe.missingGeohash4, isTrue);
      expect(probe.geohash4InCustomerCells, isFalse);
      expect(probe.computedGeohash4InCustomerCells, isTrue);
      expect(probe.distanceKm, 0);
      expect(probe.wouldPass15km, isTrue);
      expect(probe.isCustomerVisible, isTrue);
      expect(probe.isOpen, isTrue);
    },
  );

  test(
    'closed or invisible restaurants drop after the geohash query matches',
    () {
      final destination = _gpsAt(madurai);
      final cell = GeoHash.cell4(madurai.latitude, madurai.longitude);
      final report = DiscoveryDiagnostic.analyze(
        destination: destination,
        serviceable: true,
        catalog: [
          RestaurantPublicProbe(
            restaurantId: 'closed',
            latitude: madurai.latitude,
            longitude: madurai.longitude,
            geohash4: cell,
            isOpen: false,
          ),
        ],
      );
      expect(report.rawDocumentsReturned, 1);
      expect(report.removedNotOpen, 1);
      expect(report.finalCount, 0);
      expect(
        report.firstEmptyStage,
        DiscoveryEmptyStage.visibilityOrOpenFilter,
      );
    },
  );

  test(
    '15 km filter is not the first empty stage when geohash4 is missing',
    () {
      final destination = _gpsAt(madurai);
      final report = DiscoveryDiagnostic.analyze(
        destination: destination,
        serviceable: true,
        catalog: [
          RestaurantPublicProbe(
            restaurantId: 'madurai-kitchen',
            latitude: madurai.latitude,
            longitude: madurai.longitude,
          ),
        ],
      );
      expect(report.firstEmptyStage, isNot(DiscoveryEmptyStage.outside15km));
      expect(
        report.firstEmptyStage,
        DiscoveryEmptyStage.firestoreGeohashQueryEmpty,
      );
    },
  );

  test(
    'a far restaurant with its own geohash4 never matches customer cells',
    () {
      final destination = _gpsAt(madurai);
      final chennaiCell = GeoHash.cell4(chennai.latitude, chennai.longitude);
      final report = DiscoveryDiagnostic.analyze(
        destination: destination,
        serviceable: true,
        catalog: [
          RestaurantPublicProbe(
            restaurantId: 'chennai-kitchen',
            latitude: chennai.latitude,
            longitude: chennai.longitude,
            geohash4: chennaiCell,
          ),
        ],
      );
      expect(report.rawDocumentsReturned, 0);
      expect(
        report.firstEmptyStage,
        DiscoveryEmptyStage.firestoreGeohashQueryEmpty,
      );
      expect(report.missingGeohash4Message, isNull);
    },
  );

  test('unserviceable destination stops before geohash queries', () {
    final destination = _gpsAt(madurai);
    final report = DiscoveryDiagnostic.analyze(
      destination: destination,
      serviceable: false,
      catalog: [
        RestaurantPublicProbe(
          restaurantId: 'madurai-kitchen',
          latitude: madurai.latitude,
          longitude: madurai.longitude,
          geohash4: GeoHash.cell4(madurai.latitude, madurai.longitude),
        ),
      ],
    );
    expect(report.firstEmptyStage, DiscoveryEmptyStage.notServiceable);
    expect(report.rawDocumentsReturned, 0);
  });

  test('pincode serviceability is not used; zones are coordinate-based', () {
    const zone = ActiveDeliveryZone(
      id: 'madurai-zone',
      centerLatitude: 9.9252,
      centerLongitude: 78.1198,
      radiusKm: 20,
      isActive: true,
    );
    expect(
      LocationServiceabilityDecision.evaluate(
        latitude: madurai.latitude,
        longitude: madurai.longitude,
        zones: const [zone],
      ),
      LocationServiceabilityOutcome.insideActiveZone,
    );
    expect(
      RestaurantDiscoveryQuery.geohash4CellsFor(_gpsAt(madurai)),
      contains(GeoHash.cell4(madurai.latitude, madurai.longitude)),
    );
  });
}
