import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/search_restaurant_provider.dart';
import 'package:customer_app/features/search/presentation/providers/search_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';

import '../../../helpers/destination_fakes.dart';
import '../../../helpers/discovery_fixtures.dart';

const _userId = 'user-1';

/// The debounce in [SearchNotifier] is 400 ms.
const _debounce = Duration(milliseconds: 450);

class _Harness {
  _Harness({
    required this.container,
    required this.locations,
    required this.search,
  });

  final ProviderContainer container;
  final FakeLocationRepository locations;
  final NationwideSearchRepository search;

  /// Types [query] and waits for the debounced search to finish.
  Future<void> type(String query) async {
    // The destination's serviceability check runs in the background in the
    // app; let it finish before the search reads the destination.
    await settleServiceability(container);
    await container.read(searchProvider.notifier).search(query);
    await Future<void>.delayed(_debounce);
    await pumpEventQueue();
  }

  List<String> get shownIds =>
      (container.read(searchProvider).valueOrNull ?? const [])
          .map((r) => r.id)
          .toList();

  /// The customer picks a different delivery address.
  Future<void> selectDestination(UserLocation? destination) async {
    locations.stored = destination;
    container.invalidate(userLocationProvider(_userId));
    await settleServiceability(container);
    await pumpEventQueue();
  }
}

void main() {
  final listable = [
    restaurantIn(madurai, 'Madurai Meals'),
    restaurantIn(chennai, 'Chennai Meals'),
    restaurantIn(bengaluru, 'Bengaluru Meals'),
  ];

  // Every keyword match in the country — the datasource knows nothing of the
  // customer's destination.
  final matches = [
    restaurantResult('Madurai Meals'),
    restaurantResult('Chennai Meals'),
    restaurantResult('Bengaluru Meals'),
    foodResult('meals-madurai', restaurantId: 'Madurai Meals'),
    foodResult('meals-chennai', restaurantId: 'Chennai Meals'),
    foodResult('meals-bengaluru', restaurantId: 'Bengaluru Meals'),
  ];

  _Harness build({
    required FakeLocationRepository locations,
    FakeGps? gps,
    String? userId = _userId,
  }) {
    final search = NationwideSearchRepository(matches);
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue(userId),
        locationRepositoryProvider.overrideWithValue(locations),
        savedAddressRepositoryProvider.overrideWithValue(
          FakeSavedAddressRepository(),
        ),
        if (gps != null) deviceLocationServiceProvider.overrideWithValue(gps),
        restaurantRepositoryProvider.overrideWithValue(
          NationwideRestaurantRepository(listable),
        ),
        searchRepositoryProvider.overrideWithValue(search),
        getCategoriesUseCaseProvider.overrideWithValue(emptyCategoriesUseCase),
        serviceabilityRepositoryProvider.overrideWithValue(
          FakeServiceabilityRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    // The search screen watches this for as long as it is open.
    container.listen(searchProvider, (_, _) {});
    return _Harness(container: container, locations: locations, search: search);
  }

  group('Search is scoped to the selected delivery destination', () {
    test('returns only restaurants and foods that can deliver there', () async {
      final h = build(
        locations: FakeLocationRepository(destinationIn(madurai)),
      );

      await h.type('meals');

      expect(h.shownIds, ['Madurai Meals', 'meals-madurai']);
    });

    test(
      'no destination → empty, and the datasource is never queried',
      () async {
        final h = build(locations: FakeLocationRepository(null));

        await h.type('meals');

        expect(h.shownIds, isEmpty);
        expect(h.search.calls, 0);
      },
    );

    test('signed out → empty', () async {
      final h = build(
        locations: FakeLocationRepository(destinationIn(madurai)),
        userId: null,
      );

      await h.type('meals');

      expect(h.shownIds, isEmpty);
    });

    test('changing the selected destination refreshes the search', () async {
      final h = build(
        locations: FakeLocationRepository(destinationIn(madurai)),
      );
      await h.type('meals');
      expect(h.shownIds, ['Madurai Meals', 'meals-madurai']);

      // The customer saves an address in Chennai. Nobody retypes the query.
      await h.selectDestination(destinationIn(chennai));

      expect(h.shownIds, ['Chennai Meals', 'meals-chennai']);
      expect(h.search.queries, ['meals', 'meals']);
    });

    test(
      'a destination change does not run a search nobody asked for',
      () async {
        final h = build(
          locations: FakeLocationRepository(destinationIn(madurai)),
        );

        // Nothing typed yet.
        await h.selectDestination(destinationIn(chennai));
        expect(h.search.calls, 0);

        // Typed, then cleared.
        await h.type('meals');
        h.container.read(searchProvider.notifier).clearSearch();
        final callsBefore = h.search.calls;
        await h.selectDestination(destinationIn(bengaluru));

        expect(h.search.calls, callsBefore);
        expect(h.shownIds, isEmpty);
      },
    );
  });

  group('GPS never moves an explicitly selected search destination', () {
    test('a GPS refresh from another city changes nothing', () async {
      final locations = FakeLocationRepository(
        explicitly(destinationIn(madurai)),
      );
      final h = build(
        locations: locations,
        gps: FakeGps(
          destinationIn(bengaluru, selected: false, pincode: '560001'),
        ),
      );
      await h.type('meals');
      expect(h.shownIds, ['Madurai Meals', 'meals-madurai']);

      await h.container
          .read(locationSetupProvider.notifier)
          .refreshCurrentLocation(_userId);
      await pumpEventQueue();

      // The reading moved (the phone is in Bengaluru) but the destination and
      // the search did not — no write, no re-run.
      expect(h.container.read(currentGpsLocationProvider)?.city, 'Bengaluru');
      expect(locations.saves, isEmpty);
      expect(h.shownIds, ['Madurai Meals', 'meals-madurai']);
      expect(h.search.queries, ['meals']);
    });

    test('login from another city changes nothing', () async {
      final locations = FakeLocationRepository(
        explicitly(destinationIn(madurai)),
      );
      final h = build(
        locations: locations,
        gps: FakeGps(
          destinationIn(chennai, selected: false, pincode: '600001'),
        ),
      );
      await h.type('meals');

      await h.container
          .read(locationSetupProvider.notifier)
          .setupLocationAfterLogin(_userId);
      await pumpEventQueue();

      expect(locations.saves, isEmpty);
      expect(h.shownIds, ['Madurai Meals', 'meals-madurai']);
      expect(h.search.queries, ['meals']);
    });

    test('a Chennai destination selected from Madurai is kept', () async {
      // The customer selected Chennai while their phone is in Madurai; the
      // phone's position must not pull search back to Madurai.
      final h = build(
        locations: FakeLocationRepository(explicitly(destinationIn(chennai))),
        gps: FakeGps(destinationIn(madurai, selected: false)),
      );
      await h.type('meals');

      await h.container
          .read(locationSetupProvider.notifier)
          .refreshCurrentLocation(_userId);
      await pumpEventQueue();

      expect(h.shownIds, ['Chennai Meals', 'meals-chennai']);
    });
  });

  test('after travelling to another city, search follows the current '
      'location instead of a legacy address saved back home', () async {
    final locations = FakeLocationRepository(destinationIn(madurai));
    final h = build(
      locations: locations,
      gps: FakeGps(
        destinationIn(bengaluru, selected: false, pincode: '560001'),
      ),
    );
    await h.type('meals');
    expect(h.shownIds, ['Madurai Meals', 'meals-madurai']);

    await h.container
        .read(locationSetupProvider.notifier)
        .refreshCurrentLocation(_userId);
    await pumpEventQueue();

    expect(locations.stored!.city, 'Bengaluru');
    expect(h.shownIds, ['Bengaluru Meals', 'meals-bengaluru']);
  });

  test(
    'an UNSELECTED current-location default does follow the phone',
    () async {
      // Nothing was ever selected: the saved location is only the GPS default,
      // so when it follows the phone, search follows it too.
      final locations = FakeLocationRepository(
        destinationIn(madurai, selected: false),
      );
      final h = build(
        locations: locations,
        gps: FakeGps(
          destinationIn(bengaluru, selected: false, pincode: '560001'),
        ),
      );
      await h.type('meals');
      expect(h.shownIds, ['Madurai Meals', 'meals-madurai']);

      await h.container
          .read(locationSetupProvider.notifier)
          .refreshCurrentLocation(_userId);
      await pumpEventQueue();

      expect(locations.saves, hasLength(1));
      expect(h.shownIds, ['Bengaluru Meals', 'meals-bengaluru']);
    },
  );

  group('the restaurant-only search provider is scoped the same way', () {
    test(
      'lists only restaurants that can deliver to the destination',
      () async {
        final h = build(
          locations: FakeLocationRepository(destinationIn(madurai)),
        );

        await settleServiceability(h.container);
        final found = await h.container.read(
          searchRestaurantProvider('meals').future,
        );

        expect(found.map((r) => r.id), ['Madurai Meals']);
      },
    );

    test('no destination → empty, never the nationwide matches', () async {
      final h = build(locations: FakeLocationRepository(null));

      await settleServiceability(h.container);
      final found = await h.container.read(
        searchRestaurantProvider('meals').future,
      );

      expect(found, isEmpty);
    });

    test('reloads when the destination changes', () async {
      final h = build(
        locations: FakeLocationRepository(destinationIn(madurai)),
      );
      h.container.listen(searchRestaurantProvider('meals'), (_, _) {});
      await settleServiceability(h.container);
      expect(
        (await h.container.read(
          searchRestaurantProvider('meals').future,
        )).map((r) => r.id),
        ['Madurai Meals'],
      );

      await h.selectDestination(destinationIn(chennai));

      expect(
        (await h.container.read(
          searchRestaurantProvider('meals').future,
        )).map((r) => r.id),
        ['Chennai Meals'],
      );
    });
  });
}
