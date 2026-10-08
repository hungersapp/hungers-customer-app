import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/location/data/services/device_location_service.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/repositories/location_repository.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/featured_restaurant_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/nearby_restaurant_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/popular_restaurant_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_list_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';

import '../../../helpers/destination_fakes.dart';
import '../../../helpers/discovery_fixtures.dart';

const _userId = 'user-1';

/// Stands in for `users/{uid}.location`.
class _FakeLocationRepository implements LocationRepository {
  _FakeLocationRepository(this.stored);

  UserLocation? stored;
  final List<UserLocation> saves = [];

  @override
  Future<UserLocation?> getUserLocation(String userId) async => stored;

  @override
  Future<void> saveUserLocation({
    required String userId,
    required UserLocation location,
    bool clearStaleAddressDetails = false,
  }) async {
    saves.add(location);
    stored = location;
  }

  @override
  Future<String?> getDeliveryPincode(String userId) async => stored?.pincode;

  @override
  Future<void> saveDeliveryPincode({
    required String userId,
    required String pincode,
  }) async {}
}

/// Stands in for the phone's GPS + reverse geocoding.
class _FakeGps implements DeviceLocationService {
  _FakeGps(this.location);

  UserLocation location;

  @override
  Future<UserLocation> getCurrentUserLocation() async => location;

  @override
  Future<void> ensurePermission() async {}

  @override
  Future<({double latitude, double longitude})> getCurrentCoordinates() =>
      throw UnimplementedError();

  @override
  Future<({String city, String state, String? pincode, String area})>
  reverseGeocode({required double latitude, required double longitude}) =>
      throw UnimplementedError();

  @override
  Future<List<UserLocation>> searchPlaces(String query) =>
      throw UnimplementedError();

  @override
  Future<UserLocation> searchArea(String query) => throw UnimplementedError();

  @override
  Stream<UserLocation> watchSignificantMoves({
    int distanceFilterMeters = 200,
  }) => const Stream.empty();
}

void main() {
  final nationwide = NationwideRestaurantRepository([
    restaurantIn(madurai, 'madurai-1', rating: 4.5),
    restaurantIn(madurai, 'madurai-2', rating: 4.0),
    restaurantIn(chennai, 'chennai-1', rating: 4.9),
    restaurantIn(bengaluru, 'bengaluru-1', rating: 4.8),
  ]);

  ProviderContainer build({
    required _FakeLocationRepository locations,
    _FakeGps? gps,
    String? userId = _userId,
  }) {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue(userId),
        locationRepositoryProvider.overrideWithValue(locations),
        savedAddressRepositoryProvider.overrideWithValue(
          FakeSavedAddressRepository(),
        ),
        if (gps != null) deviceLocationServiceProvider.overrideWithValue(gps),
        restaurantRepositoryProvider.overrideWithValue(nationwide),
        serviceabilityRepositoryProvider.overrideWithValue(
          FakeServiceabilityRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Keep the discovery providers alive like the Home section does.
    for (final provider in [
      popularRestaurantProvider,
      nearbyRestaurantProvider,
      featuredRestaurantProvider,
      restaurantListProvider,
    ]) {
      container.listen(provider, (_, _) {});
    }
    return container;
  }

  Future<List<String>> popularIds(ProviderContainer c) async {
    // The destination's serviceability check runs in the background in the
    // app; let it finish before reading.
    await settleServiceability(c);
    return (await c.read(
      popularRestaurantProvider.future,
    )).map((r) => r.id).toList();
  }

  test(
    'discovery lists only restaurants that can deliver to the destination',
    () async {
      final container = build(
        locations: _FakeLocationRepository(destinationIn(madurai)),
      );

      expect(await popularIds(container), ['madurai-1', 'madurai-2']);
      expect(
        (await container.read(
          nearbyRestaurantProvider.future,
        )).map((r) => r.id),
        everyElement(startsWith('madurai')),
      );
    },
  );

  test(
    'the Home restaurant list is destination-scoped once serviceable',
    () async {
      final container = build(
        locations: _FakeLocationRepository(destinationIn(chennai)),
      );
      // The pincode gate is driven by the destination's own pincode.
      await settleServiceability(container);

      final listed = await container.read(restaurantListProvider.future);

      expect(listed.map((r) => r.id), ['chennai-1']);
    },
  );

  test(
    'no destination saved → nothing is discoverable (no nationwide fallback)',
    () async {
      final container = build(locations: _FakeLocationRepository(null));

      expect(await popularIds(container), isEmpty);
      expect(await container.read(nearbyRestaurantProvider.future), isEmpty);
    },
  );

  test('signed out → nothing is discoverable', () async {
    final container = build(
      locations: _FakeLocationRepository(destinationIn(madurai)),
      userId: null,
    );

    expect(await popularIds(container), isEmpty);
  });

  test(
    'selecting a new address reloads discovery for the new destination',
    () async {
      final locations = _FakeLocationRepository(destinationIn(madurai));
      final container = build(locations: locations);
      expect(await popularIds(container), ['madurai-1', 'madurai-2']);

      // The customer saves an address in another city (address editor →
      // SaveUserLocationUseCase → invalidate userLocationProvider).
      locations.stored = destinationIn(chennai);
      container.invalidate(userLocationProvider(_userId));

      expect(await popularIds(container), ['chennai-1']);
    },
  );

  group(
    'GPS never moves an EXPLICITLY selected destination — discovery included',
    () {
      test(
        'a GPS refresh from another city leaves discovery unchanged',
        () async {
          // Madurai explicitly selected; the phone is in Bengaluru.
          final locations = _FakeLocationRepository(
            explicitly(destinationIn(madurai)),
          );
          final container = build(
            locations: locations,
            gps: _FakeGps(
              destinationIn(bengaluru, selected: false, pincode: '560001'),
            ),
          );
          expect(await popularIds(container), ['madurai-1', 'madurai-2']);

          await container
              .read(locationSetupProvider.notifier)
              .refreshCurrentLocation(_userId);

          // Nothing was written to the destination; discovery still Madurai, and
          // Bengaluru's restaurant never appears.
          expect(locations.saves, isEmpty);
          expect(await popularIds(container), ['madurai-1', 'madurai-2']);
          expect(container.read(currentGpsLocationProvider)?.city, 'Bengaluru');
        },
      );

      test('login from another city leaves discovery unchanged', () async {
        final locations = _FakeLocationRepository(
          explicitly(destinationIn(madurai)),
        );
        final container = build(
          locations: locations,
          gps: _FakeGps(
            destinationIn(chennai, selected: false, pincode: '600001'),
          ),
        );
        expect(await popularIds(container), ['madurai-1', 'madurai-2']);

        await container
            .read(locationSetupProvider.notifier)
            .setupLocationAfterLogin(_userId);

        expect(locations.saves, isEmpty);
        expect(await popularIds(container), ['madurai-1', 'madurai-2']);
      });

      test(
        'changing the in-memory GPS reading alone changes nothing',
        () async {
          final locations = _FakeLocationRepository(destinationIn(madurai));
          final container = build(locations: locations);
          expect(await popularIds(container), ['madurai-1', 'madurai-2']);

          container.read(currentGpsLocationProvider.notifier).state =
              destinationIn(bengaluru, selected: false);

          expect(await popularIds(container), ['madurai-1', 'madurai-2']);
          expect(locations.saves, isEmpty);
        },
      );
    },
  );

  group('after travelling, discovery follows the CURRENT location', () {
    test(
      'a LEGACY Home address in Madurai gives way to GPS in Bengaluru, and '
      'Bengaluru\'s restaurants are discovered from the GPS coordinates',
      () async {
        // Saved before the source was recorded: never an explicit selection.
        final locations = _FakeLocationRepository(destinationIn(madurai));
        final container = build(
          locations: locations,
          gps: _FakeGps(
            destinationIn(bengaluru, selected: false, pincode: '560001'),
          ),
        );
        expect(await popularIds(container), ['madurai-1', 'madurai-2']);

        await container
            .read(locationSetupProvider.notifier)
            .refreshCurrentLocation(_userId);

        expect(locations.saves, hasLength(1));
        expect(locations.saves.single.latitude, bengaluru.latitude);
        expect(locations.saves.single.longitude, bengaluru.longitude);
        expect(await popularIds(container), ['bengaluru-1']);
      },
    );

    test('…and on login too', () async {
      final locations = _FakeLocationRepository(destinationIn(madurai));
      final container = build(
        locations: locations,
        gps: _FakeGps(
          destinationIn(chennai, selected: false, pincode: '600001'),
        ),
      );
      expect(await popularIds(container), ['madurai-1', 'madurai-2']);

      await container
          .read(locationSetupProvider.notifier)
          .setupLocationAfterLogin(_userId);

      expect(await popularIds(container), ['chennai-1']);
    });
  });

  test(
    'an UNSELECTED current-location default does follow the phone',
    () async {
      // Nothing was ever selected: the saved location is just the GPS default.
      final locations = _FakeLocationRepository(
        destinationIn(madurai, selected: false),
      );
      final container = build(
        locations: locations,
        gps: _FakeGps(
          destinationIn(bengaluru, selected: false, pincode: '560001'),
        ),
      );
      expect(await popularIds(container), ['madurai-1', 'madurai-2']);

      await container
          .read(locationSetupProvider.notifier)
          .refreshCurrentLocation(_userId);

      expect(locations.saves, hasLength(1));
      expect(await popularIds(container), ['bengaluru-1']);
    },
  );
}
