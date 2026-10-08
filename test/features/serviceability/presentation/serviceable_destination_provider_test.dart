import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/serviceability/domain/entities/active_delivery_zone.dart';
import 'package:customer_app/features/serviceability/domain/entities/serviceability_result.dart';
import 'package:customer_app/features/serviceability/domain/repositories/serviceability_repository.dart';
import 'package:customer_app/features/serviceability/presentation/providers/destination_serviceability_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceable_destination_provider.dart';

import '../../../helpers/destination_fakes.dart';
import '../../../helpers/discovery_fixtures.dart';

const _userId = 'user-1';

/// The zone read for any location after the first stays pending until the test
/// completes it, so a test can look at the app while a newly chosen place is
/// still being checked.
class _GatedZonesRepository implements ServiceabilityRepository {
  _GatedZonesRepository(this.zones);

  final List<ActiveDeliveryZone> zones;
  final Completer<void> gate = Completer<void>();
  int reads = 0;

  @override
  Future<List<ActiveDeliveryZone>> getActiveDeliveryZones() async {
    reads += 1;
    if (reads > 1) {
      await gate.future;
    }
    return zones;
  }

  @override
  Future<ServiceabilityResult> checkPincode(String pincode) =>
      throw StateError('serviceability must not be decided from a pincode');
}

/// The zone read fails until [recover] is called.
class _FlakyZonesRepository implements ServiceabilityRepository {
  _FlakyZonesRepository(this.zones);

  final List<ActiveDeliveryZone> zones;
  bool failing = true;

  void recover() => failing = false;

  @override
  Future<List<ActiveDeliveryZone>> getActiveDeliveryZones() async {
    if (failing) {
      throw StateError('offline');
    }
    return zones;
  }

  @override
  Future<ServiceabilityResult> checkPincode(String pincode) =>
      throw StateError('serviceability must not be decided from a pincode');
}

ProviderContainer _container({
  required FakeLocationRepository locations,
  required ServiceabilityRepository serviceability,
  String? userId = _userId,
}) {
  final container = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue(userId),
      locationRepositoryProvider.overrideWithValue(locations),
      serviceabilityRepositoryProvider.overrideWithValue(serviceability),
    ],
  );
  addTearDown(container.dispose);
  // Discovery and the Home card keep these alive while a screen is open.
  container.listen(serviceableDeliveryDestinationProvider, (_, _) {});
  container.listen(deliveryServiceabilityProvider, (_, _) {});
  return container;
}

Future<UserLocation?> _authority(ProviderContainer container) async {
  await settleServiceability(container);
  return container.read(serviceableDeliveryDestinationProvider.future);
}

Future<DestinationServiceability> _verdict(ProviderContainer container) =>
    container.read(destinationServiceabilityProvider.future);

void main() {
  final madurai0 = destinationIn(madurai);
  final maduraiZone = zoneAround(madurai);

  group('a location inside an active zone is served — by its coordinates', () {
    test('the destination itself is what discovery gets', () async {
      final container = _container(
        locations: FakeLocationRepository(madurai0),
        serviceability: FakeServiceabilityRepository(zones: [maduraiZone]),
      );

      expect(await _authority(container), madurai0);
      expect(await _verdict(container), DestinationServiceability.serviceable);
      expect(
        container.read(deliveryServiceabilityProvider).status,
        ServiceabilityUiStatus.serviceable,
      );
    });

    test(
      'works for any place in India — nothing is hardcoded to a region',
      () async {
        for (final city in [
          const City('Srinagar', 'Jammu and Kashmir', 34.0837, 74.7973),
          const City('Guwahati', 'Assam', 26.1445, 91.7362),
          const City('Kochi', 'Kerala', 9.9312, 76.2673),
          const City('Bhuj', 'Gujarat', 23.2420, 69.6669),
        ]) {
          final destination = destinationIn(city);
          final container = _container(
            locations: FakeLocationRepository(destination),
            serviceability: FakeServiceabilityRepository(
              zones: [zoneAround(city)],
            ),
          );

          expect(await _authority(container), destination, reason: city.name);
        }
      },
    );

    test('the pincode plays no part: none, or an unrelated one, changes '
        'nothing — and the pincode check is never used', () async {
      for (final pincode in [null, '999999', '625001']) {
        final serviceability = FakeServiceabilityRepository(
          zones: [maduraiZone],
        );
        final destination = destinationIn(madurai, pincode: pincode);
        final container = _container(
          locations: FakeLocationRepository(destination),
          serviceability: serviceability,
        );

        expect(await _authority(container), destination, reason: '$pincode');
        expect(serviceability.pincodeChecks, 0);
      }
    });
  });

  group('fail-closed: nothing may be discovered', () {
    test('outside every active zone → not served, and nothing is offered '
        'even though the pincode looks valid', () async {
      final container = _container(
        locations: FakeLocationRepository(
          destinationIn(chennai, pincode: '625001'),
        ),
        serviceability: FakeServiceabilityRepository(zones: [maduraiZone]),
      );

      expect(await _authority(container), isNull);
      expect(
        await _verdict(container),
        DestinationServiceability.notServiceable,
      );
      expect(
        container.read(deliveryServiceabilityProvider).status,
        ServiceabilityUiStatus.notServiceable,
      );
    });

    test('an inactive zone does not serve anyone', () async {
      final container = _container(
        locations: FakeLocationRepository(madurai0),
        serviceability: FakeServiceabilityRepository(
          zones: [
            ActiveDeliveryZone(
              id: 'off',
              centerLatitude: madurai.latitude,
              centerLongitude: madurai.longitude,
              radiusKm: 50,
              isActive: false,
            ),
          ],
        ),
      );

      expect(await _authority(container), isNull);
    });

    test('no active zone at all → not served', () async {
      final container = _container(
        locations: FakeLocationRepository(madurai0),
        serviceability: FakeServiceabilityRepository(zones: const []),
      );

      expect(await _authority(container), isNull);
      expect(
        await _verdict(container),
        DestinationServiceability.notServiceable,
      );
    });

    test('the zones cannot be read → nothing, and a retryable error (not a '
        'coverage answer, never a nationwide fallback)', () async {
      final container = _container(
        locations: FakeLocationRepository(madurai0),
        serviceability: FakeServiceabilityRepository(
          readError: StateError('offline'),
        ),
      );

      expect(await _authority(container), isNull);
      expect(await _verdict(container), DestinationServiceability.unavailable);
      expect(
        container.read(deliveryServiceabilityProvider).status,
        ServiceabilityUiStatus.error,
      );
    });

    test(
      'retrying after the zones become readable serves the location',
      () async {
        final serviceability = _FlakyZonesRepository([maduraiZone]);
        final container = _container(
          locations: FakeLocationRepository(madurai0),
          serviceability: serviceability,
        );
        expect(await _authority(container), isNull);

        serviceability.recover();
        // "Retry" on the Home card.
        container.invalidate(destinationServiceabilityProvider);

        expect(await _authority(container), madurai0);
      },
    );

    test(
      'no location chosen yet → the customer is asked to choose one',
      () async {
        final container = _container(
          locations: FakeLocationRepository(null),
          serviceability: FakeServiceabilityRepository(),
        );

        expect(await _authority(container), isNull);
        expect(
          await _verdict(container),
          DestinationServiceability.noDestination,
        );
        expect(
          container.read(deliveryServiceabilityProvider).status,
          ServiceabilityUiStatus.initial,
        );
      },
    );

    test('signed out → nothing', () async {
      final container = _container(
        locations: FakeLocationRepository(madurai0),
        serviceability: FakeServiceabilityRepository(),
        userId: null,
      );

      expect(await _authority(container), isNull);
      expect(
        await _verdict(container),
        DestinationServiceability.noDestination,
      );
    });

    test(
      'unusable coordinates → nothing, and the zones are not even read',
      () async {
        for (final bad in [
          const City('Null Island', 'X', 0, 0),
          const City('Bad latitude', 'X', 123, 78),
          const City('Bad longitude', 'X', 9.9, 500),
        ]) {
          final serviceability = FakeServiceabilityRepository();
          final container = _container(
            locations: FakeLocationRepository(destinationIn(bad)),
            serviceability: serviceability,
          );

          expect(await _authority(container), isNull, reason: bad.name);
          expect(
            await _verdict(container),
            DestinationServiceability.invalidLocation,
            reason: bad.name,
          );
          expect(serviceability.zoneReads, 0, reason: bad.name);
        }
      },
    );
  });

  group('a newly chosen place is judged on its OWN coordinates', () {
    test('choosing an unserved place yields nothing — it never goes back to '
        'the previous place; choosing a served one serves it', () async {
      final locations = FakeLocationRepository(madurai0);
      final container = _container(
        locations: locations,
        serviceability: FakeServiceabilityRepository(zones: [maduraiZone]),
      );
      expect(await _authority(container), madurai0);

      locations.stored = destinationIn(chennai);
      container.invalidate(userLocationProvider(_userId));
      expect(await _authority(container), isNull);

      final backInMadurai = destinationIn(madurai, dLatKm: 2);
      locations.stored = backInMadurai;
      container.invalidate(userLocationProvider(_userId));
      expect(await _authority(container), backInMadurai);
    });

    test(
      'while the new place is being checked, the previous place\'s '
      'restaurants are not offered; once served, the new place is used',
      () async {
        final locations = FakeLocationRepository(madurai0);
        final serviceability = _GatedZonesRepository([
          maduraiZone,
          zoneAround(chennai),
        ]);
        final container = _container(
          locations: locations,
          serviceability: serviceability,
        );
        expect(await _authority(container), madurai0);

        final chennai0 = destinationIn(chennai);
        locations.stored = chennai0;
        container.invalidate(userLocationProvider(_userId));
        await pumpEventQueue();

        // Still checking: the Home card says so, and discovery has not resolved
        // to Madurai's location.
        expect(
          container.read(deliveryServiceabilityProvider).status,
          ServiceabilityUiStatus.checking,
        );
        expect(
          container.read(serviceableDeliveryDestinationProvider).isLoading,
          isTrue,
        );

        serviceability.gate.complete();
        await pumpEventQueue();

        expect(
          await container.read(serviceableDeliveryDestinationProvider.future),
          chennai0,
        );
      },
    );
  });
}
