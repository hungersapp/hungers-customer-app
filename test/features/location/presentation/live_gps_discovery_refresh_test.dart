import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/discoverable_restaurants_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';

import '../../../helpers/destination_fakes.dart';
import '../../../helpers/discovery_fixtures.dart';

const _userId = 'user-1';

void main() {
  UserLocation gpsAt(City city) =>
      destinationIn(city, selected: false, pincode: '625001');

  test(
    'a meaningful GPS move refreshes geohash discovery without nationwide fallback',
    () async {
      final locations = FakeLocationRepository(gpsAt(madurai));
      final restaurants = NationwideRestaurantRepository([
        restaurantIn(madurai, 'madurai-1'),
        restaurantIn(chennai, 'chennai-1'),
      ]);
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(_userId),
          locationRepositoryProvider.overrideWithValue(locations),
          deviceLocationServiceProvider.overrideWithValue(
            FakeGps(gpsAt(madurai)),
          ),
          restaurantRepositoryProvider.overrideWithValue(restaurants),
          serviceabilityRepositoryProvider.overrideWithValue(
            FakeServiceabilityRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await settleServiceability(container);
      final first = await container.read(
        discoverableRestaurantsProvider.future,
      );
      expect(first.map((r) => r.id), ['madurai-1']);
      expect(restaurants.getAllCalls, 0);
      expect(restaurants.discoverableCalls, greaterThan(0));
      expect(restaurants.lastGeohash4Cells, isNotEmpty);

      await container
          .read(locationSetupProvider.notifier)
          .applyDeviceLocation(_userId, gpsAt(chennai));
      await container.read(userLocationProvider(_userId).future);

      await settleServiceability(container);
      final next = await container.read(discoverableRestaurantsProvider.future);
      expect(next.map((r) => r.id), ['chennai-1']);
      expect(restaurants.getAllCalls, 0);
      expect(locations.saves.last.city, 'Chennai');
      expect(locations.saves.last.selectedByCustomer, isFalse);
    },
  );

  test(
    'repeated GPS readings of the same place do not rewrite Firestore',
    () async {
      final start = gpsAt(madurai);
      final locations = FakeLocationRepository(start);
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(_userId),
          locationRepositoryProvider.overrideWithValue(locations),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(locationSetupProvider.notifier);
      await notifier.applyDeviceLocation(_userId, start);
      await notifier.applyDeviceLocation(
        _userId,
        destinationIn(
          madurai,
          selected: false,
          pincode: '625001',
          dLatKm: 0.05,
        ),
      );

      expect(locations.saves, isEmpty);
    },
  );

  test('a GPS watch never writes over an explicitly selected saved address, '
      'however far the phone moves', () async {
    final home = explicitly(
      destinationIn(madurai, selected: true),
      LocationSource.savedHome,
    );
    final locations = FakeLocationRepository(home);
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue(_userId),
        locationRepositoryProvider.overrideWithValue(locations),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(locationSetupProvider.notifier);
    for (final reading in [
      destinationIn(madurai, selected: false, dLatKm: 3),
      gpsAt(chennai),
      gpsAt(bengaluru),
    ]) {
      await notifier.applyDeviceLocation(_userId, reading);
    }

    expect(locations.saves, isEmpty);
    expect(locations.stored, home);
  });

  test('a GPS watch replaces a LEGACY address (saved before the source was '
      'recorded) and keeps it as a saved shortcut', () async {
    final legacyHome = destinationIn(madurai, selected: true);
    final locations = FakeLocationRepository(legacyHome);
    final saved = FakeSavedAddressRepository();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue(_userId),
        locationRepositoryProvider.overrideWithValue(locations),
        savedAddressRepositoryProvider.overrideWithValue(saved),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(locationSetupProvider.notifier)
        .applyDeviceLocation(_userId, gpsAt(chennai));

    expect(locations.saves, hasLength(1));
    expect(locations.stored!.city, 'Chennai');
    expect(locations.stored!.latitude, chennai.latitude);
    expect(locations.stored!.source, LocationSource.deviceGps);
    expect(locations.stored!.selectedByCustomer, isFalse);
    // Nothing of the Home address is mixed into the GPS reading.
    expect(locations.stored!.doorNumber, isEmpty);
    expect(locations.stored!.street, isEmpty);
    // …and the address itself is still one tap away.
    expect(saved.book.home?.doorNumber, '12A');
  });

  test(
    'startWatching subscribes once and applies a streamed GPS move',
    () async {
      final controller = StreamController<UserLocation>.broadcast();
      addTearDown(controller.close);
      final gps = FakeGps(gpsAt(madurai))..moves = controller.stream;
      final locations = FakeLocationRepository(gpsAt(madurai));
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(_userId),
          locationRepositoryProvider.overrideWithValue(locations),
          deviceLocationServiceProvider.overrideWithValue(gps),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(locationSetupProvider.notifier);
      notifier.startWatching(_userId);
      notifier.startWatching(_userId);
      expect(gps.watchStartCount, 1);

      controller.add(gpsAt(chennai));
      await Future<void>.delayed(Duration.zero);
      await pumpEventQueue();

      expect(locations.saves, isNotEmpty);
      expect(locations.saves.last.city, 'Chennai');
      expect(container.read(currentGpsLocationProvider)?.city, 'Chennai');
    },
  );
}
