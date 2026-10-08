import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/domain/entities/food_review_status.dart';
import 'package:customer_app/features/foods/domain/repositories/food_repository.dart';
import 'package:customer_app/features/foods/presentation/providers/food_provider.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/presentation/providers/featured_restaurant_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/nearby_restaurant_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/popular_restaurant_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_list_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/search_restaurant_provider.dart';
import 'package:customer_app/features/search/presentation/providers/search_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/destination_serviceability_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';

import '../../../helpers/destination_fakes.dart';
import '../../../helpers/discovery_fixtures.dart';

const _userId = 'user-1';
const _category = 'Meals';

/// Restaurants in three cities, each with a pincode Tukkito may or may not
/// serve. [featured] restaurants also appear in the Featured section.
RestaurantEntity _restaurant(
  City city,
  String id, {
  double rating = 4.0,
  double dLatKm = 0,
  bool featured = false,
}) {
  return testRestaurant(
    id: id,
    latitude: city.latitude + dLatKm / kmPerLatitudeDegree,
    longitude: city.longitude,
    rating: rating,
    isFeatured: featured,
  );
}

/// One food per restaurant, in the [_category] and recommended — what the
/// datasource returns before any scoping.
class _CityFoods implements FoodRepository {
  _CityFoods(this.restaurantIds);

  final List<String> restaurantIds;

  FoodEntity _food(String restaurantId) => FoodEntity(
    id: 'food-$restaurantId',
    restaurantId: restaurantId,
    name: 'Meals at $restaurantId',
    description: '',
    price: 100,
    imageUrl: '',
    category: _category,
    isVeg: true,
    isAvailable: true,
    isRecommended: true,
    rating: 4.5,
    status: FoodReviewStatus.approved,
  );

  @override
  Future<List<FoodEntity>> getCustomerFoodsByCategoryName(
    String categoryName, {
    List<String> restaurantIds = const [],
    int limit = 30,
    String? startAfterName,
  }) async => restaurantIds.map(_food).toList();

  @override
  Future<List<FoodEntity>> getRecommendedFoods(String restaurantId) async =>
      restaurantIds.contains(restaurantId) ? [_food(restaurantId)] : const [];

  @override
  Future<FoodEntity> getFoodById(String foodId) => throw UnimplementedError();

  @override
  Future<FoodEntity?> getFoodDocumentById(String foodId) async => null;

  @override
  Future<List<FoodEntity>> getFoodsByCategory({
    required String restaurantId,
    required String category,
  }) async => const [];

  @override
  Future<List<FoodEntity>> getFoodsByRestaurant(String restaurantId) async =>
      const [];
}

/// What a customer would see, surface by surface.
class _Shown {
  const _Shown({
    required this.homeList,
    required this.popular,
    required this.nearby,
    required this.featured,
    required this.category,
    required this.recommended,
    required this.searchRestaurants,
  });

  final List<String> homeList;
  final List<String> popular;
  final List<String> nearby;
  final List<String> featured;
  final List<String> category;
  final List<String> recommended;
  final List<String> searchRestaurants;

  Map<String, List<String>> toMap() => {
    'homeList': homeList,
    'popular': popular,
    'nearby': nearby,
    'featured': featured,
    'category': category,
    'recommended': recommended,
    'searchRestaurants': searchRestaurants,
  };

  static _Shown nothing() => const _Shown(
    homeList: [],
    popular: [],
    nearby: [],
    featured: [],
    category: [],
    recommended: [],
    searchRestaurants: [],
  );

  /// What every surface shows for a destination near [city] whose restaurants
  /// are [ids] (the first one is the featured one).
  static _Shown forRestaurants(List<String> ids) => _Shown(
    homeList: ids,
    popular: ids,
    nearby: ids,
    featured: [ids.first],
    category: [for (final id in ids) 'food-$id'],
    recommended: [for (final id in ids) 'food-$id'],
    searchRestaurants: ids,
  );
}

void main() {
  final allRestaurants = <RestaurantEntity>[
    _restaurant(madurai, 'madurai-1', rating: 4.6, featured: true),
    _restaurant(madurai, 'madurai-2', rating: 4.2, dLatKm: 3),
    _restaurant(chennai, 'chennai-1', rating: 4.9, featured: true),
    _restaurant(bengaluru, 'bengaluru-1', rating: 4.8, featured: true),
  ];
  final allIds = allRestaurants.map((r) => r.id).toList();

  // Pincodes per city: only some are served by Tukkito.
  const maduraiPin = '625001';
  const chennaiPin = '600001';
  const bengaluruPin = '560001';

  // Matches for the live Search screen path: every keyword hit nationwide.
  final searchMatches = [
    for (final id in allIds) restaurantResult(id),
    for (final id in allIds) foodResult('food-$id', restaurantId: id),
  ];

  ProviderContainer build({
    required FakeLocationRepository locations,
    FakeServiceabilityRepository? serviceability,
    FakeGps? gps,
    NationwideSearchRepository? search,
  }) {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue(_userId),
        locationRepositoryProvider.overrideWithValue(locations),
        savedAddressRepositoryProvider.overrideWithValue(
          FakeSavedAddressRepository(),
        ),
        if (gps != null) deviceLocationServiceProvider.overrideWithValue(gps),
        restaurantRepositoryProvider.overrideWithValue(
          NationwideRestaurantRepository(allRestaurants),
        ),
        foodRepositoryProvider.overrideWithValue(_CityFoods(allIds)),
        searchRepositoryProvider.overrideWithValue(
          search ?? NationwideSearchRepository(searchMatches),
        ),
        getCategoriesUseCaseProvider.overrideWithValue(emptyCategoriesUseCase),
        serviceabilityRepositoryProvider.overrideWithValue(
          serviceability ?? FakeServiceabilityRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Home keeps these alive while it is on screen.
    for (final provider in [
      restaurantListProvider,
      popularRestaurantProvider,
      nearbyRestaurantProvider,
      featuredRestaurantProvider,
    ]) {
      container.listen(provider, (_, _) {});
    }
    return container;
  }

  List<String> ids(Iterable<RestaurantEntity> restaurants) =>
      restaurants.map((r) => r.id).toList();

  Future<_Shown> discover(ProviderContainer c) async {
    await settleServiceability(c);
    final recommended = <String>[];
    for (final id in allIds) {
      recommended.addAll(
        (await c.read(recommendedFoodsProvider(id).future)).map((f) => f.id),
      );
    }
    return _Shown(
      homeList: ids(await c.read(restaurantListProvider.future)),
      popular: ids(await c.read(popularRestaurantProvider.future)),
      nearby: ids(await c.read(nearbyRestaurantProvider.future)),
      featured: ids(await c.read(featuredRestaurantProvider.future)),
      category: (await c.read(
        customerCategoryFoodsProvider(_category).future,
      )).map((item) => item.food.id).toList(),
      recommended: recommended,
      // '-' is in every restaurant name, so this is the nationwide match.
      searchRestaurants: ids(
        await c.read(searchRestaurantProvider('-').future),
      ),
    );
  }

  /// The live Search screen path (debounced), as the customer types.
  Future<List<String>> typeInSearch(ProviderContainer c) async {
    await settleServiceability(c);
    await c.read(searchProvider.notifier).search('meals');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await pumpEventQueue();
    return (c.read(searchProvider).valueOrNull ?? const [])
        .map((r) => r.id)
        .toList();
  }

  /// The customer picks a place in the location chooser (current location or
  /// search), exactly as the chooser saves it.
  Future<void> choosePlace(
    ProviderContainer c,
    FakeLocationRepository locations,
    UserLocation place,
  ) async {
    // The one path every customer choice takes in the app.
    await c
        .read(locationSetupProvider.notifier)
        .selectLocation(
          userId: _userId,
          location: place,
          source: LocationSource.manualSelection,
        );
    await settleServiceability(c);
  }

  UserLocation gpsReading(City city, String pincode) =>
      destinationIn(city, selected: false, pincode: pincode);

  group('current location selected → the restaurants serving it', () {
    test('every surface lists only the restaurants that serve the current '
        'location', () async {
      final container = build(
        // The GPS-derived default, seeded from the phone's location.
        locations: FakeLocationRepository(gpsReading(madurai, maduraiPin)),
      );

      final shown = await discover(container);

      expect(
        shown.toMap(),
        _Shown.forRestaurants(['madurai-1', 'madurai-2']).toMap(),
      );
      expect(
        container.read(deliveryServiceabilityProvider).status,
        ServiceabilityUiStatus.serviceable,
      );
    });
  });

  group('search-selected location → the restaurants serving it', () {
    test('choosing another city changes every surface to that city, with no '
        'restaurants left over from the old one', () async {
      final locations = FakeLocationRepository(gpsReading(madurai, maduraiPin));
      final container = build(locations: locations);
      expect((await discover(container)).homeList, ['madurai-1', 'madurai-2']);

      // Search "Chennai", confirm the pin: no door / street asked.
      await choosePlace(container, locations, gpsReading(chennai, chennaiPin));

      expect(
        (await discover(container)).toMap(),
        _Shown.forRestaurants(['chennai-1']).toMap(),
      );
      // Saved as the customer's choice, without door or street.
      expect(locations.stored!.selectedByCustomer, isTrue);
      expect(locations.stored!.doorNumber, isEmpty);
      expect(locations.stored!.street, isEmpty);
      expect(locations.stored!.city, 'Chennai');
    });

    test('the live Search screen path follows the chosen place too', () async {
      final locations = FakeLocationRepository(gpsReading(madurai, maduraiPin));
      final container = build(locations: locations);
      expect(
        await typeInSearch(container),
        containsAll(['madurai-1', 'food-madurai-1']),
      );

      await choosePlace(
        container,
        locations,
        gpsReading(bengaluru, bengaluruPin),
      );

      // The query on screen re-runs for the new place.
      await pumpEventQueue();
      expect(
        (container.read(searchProvider).valueOrNull ?? const [])
            .map((r) => r.id)
            .toList(),
        ['bengaluru-1', 'food-bengaluru-1'],
      );
    });
  });

  group('an explicitly selected destination is never moved by GPS', () {
    Future<
      ({
        ProviderContainer container,
        FakeLocationRepository locations,
        FakeGps gps,
      })
    >
    chennaiChosenWhilePhoneIsInMadurai() async {
      final locations = FakeLocationRepository(gpsReading(madurai, maduraiPin));
      final gps = FakeGps(gpsReading(madurai, maduraiPin));
      final container = build(locations: locations, gps: gps);
      await choosePlace(container, locations, gpsReading(chennai, chennaiPin));
      expect(locations.stored!.source, LocationSource.manualSelection);
      expect(locations.stored!.isExplicitSelection, isTrue);
      expect((await discover(container)).homeList, ['chennai-1']);
      locations.saves.clear();
      return (container: container, locations: locations, gps: gps);
    }

    test('a GPS refresh from another city does not overwrite it', () async {
      final (:container, :locations, gps: _) =
          await chennaiChosenWhilePhoneIsInMadurai();

      await container
          .read(locationSetupProvider.notifier)
          .refreshCurrentLocation(_userId);
      await settleServiceability(container);

      expect(locations.saves, isEmpty);
      expect(locations.stored!.city, 'Chennai');
      // The phone's position is known, but only for hints.
      expect(container.read(currentGpsLocationProvider)?.city, 'Madurai');
      expect(
        (await discover(container)).toMap(),
        _Shown.forRestaurants(['chennai-1']).toMap(),
      );
    });

    test('login does not replace it either', () async {
      final (:container, :locations, gps: _) =
          await chennaiChosenWhilePhoneIsInMadurai();

      await container
          .read(locationSetupProvider.notifier)
          .setupLocationAfterLogin(_userId);
      await settleServiceability(container);

      expect(locations.saves, isEmpty);
      expect(locations.stored!.city, 'Chennai');
      expect((await discover(container)).homeList, ['chennai-1']);
    });

    test('the phone travelling to yet another city does not replace it — only '
        'the customer does', () async {
      final (:container, :locations, :gps) =
          await chennaiChosenWhilePhoneIsInMadurai();

      gps.location = gpsReading(bengaluru, bengaluruPin);
      final notifier = container.read(locationSetupProvider.notifier);
      await notifier.initializeForStartup(_userId);
      await notifier.setupLocationAfterLogin(_userId);
      await notifier.applyDeviceLocation(
        _userId,
        gpsReading(bengaluru, bengaluruPin),
      );
      await settleServiceability(container);

      expect(locations.saves, isEmpty);
      expect(locations.stored!.city, 'Chennai');
      expect((await discover(container)).homeList, ['chennai-1']);

      // "Use Current Location": now the customer asks for GPS.
      await notifier.useCurrentLocation(_userId);
      await settleServiceability(container);

      expect(locations.stored!.city, 'Bengaluru');
      expect(locations.stored!.source, LocationSource.deviceGps);
      expect(
        (await discover(container)).toMap(),
        _Shown.forRestaurants(['bengaluru-1']).toMap(),
      );
    });
  });

  // Test 10: GPS → serviceability → zone → restaurant discovery.
  group('Test 10: the current GPS location flows into serviceability, the '
      'zone check and restaurant discovery', () {
    test('a legacy Madurai address + the phone in Bengaluru: Bengaluru\'s '
        'coordinates are what is checked against the zones and what '
        'restaurants are discovered for', () async {
      final locations = FakeLocationRepository(destinationIn(madurai));
      final serviceability = FakeServiceabilityRepository(
        zones: [zoneAround(bengaluru)],
      );
      final container = build(
        locations: locations,
        gps: FakeGps(gpsReading(bengaluru, bengaluruPin)),
        serviceability: serviceability,
      );
      // Madurai is outside the only active zone.
      expect(
        await container.read(destinationServiceabilityProvider.future),
        DestinationServiceability.notServiceable,
      );
      expect((await discover(container)).toMap(), _Shown.nothing().toMap());

      await container
          .read(locationSetupProvider.notifier)
          .initializeForStartup(_userId);
      await settleServiceability(container);

      // GPS → active location.
      expect(locations.stored!.latitude, bengaluru.latitude);
      expect(locations.stored!.longitude, bengaluru.longitude);
      expect(locations.stored!.source, LocationSource.deviceGps);
      // → serviceability, decided from those coordinates against the zones…
      expect(
        await container.read(destinationServiceabilityProvider.future),
        DestinationServiceability.serviceable,
      );
      expect(serviceability.zoneReads, greaterThan(0));
      expect(serviceability.pincodeChecks, 0);
      // → discovery for exactly that place.
      expect(
        (await discover(container)).toMap(),
        _Shown.forRestaurants(['bengaluru-1']).toMap(),
      );
    });

    test(
      'the phone somewhere Tukkito does not serve: GPS still becomes the '
      'active location, and serviceability says no — nothing is bypassed',
      () async {
        final locations = FakeLocationRepository(destinationIn(madurai));
        final container = build(
          locations: locations,
          gps: FakeGps(gpsReading(chennai, chennaiPin)),
          serviceability: FakeServiceabilityRepository(
            zones: [zoneAround(madurai)],
          ),
        );
        expect((await discover(container)).homeList, isNotEmpty);

        await container
            .read(locationSetupProvider.notifier)
            .initializeForStartup(_userId);
        await settleServiceability(container);

        expect(locations.stored!.city, 'Chennai');
        expect(
          await container.read(destinationServiceabilityProvider.future),
          DestinationServiceability.notServiceable,
        );
        expect((await discover(container)).toMap(), _Shown.nothing().toMap());
      },
    );
  });

  group('a location Tukkito does not serve', () {
    // Tukkito operates around Madurai only: it is a zone, not a pincode list.
    final servedOnlyMadurai = [zoneAround(madurai)];

    test('every surface is empty and Home says no restaurants are available — '
        'nothing from another city or the previous place', () async {
      final locations = FakeLocationRepository(gpsReading(madurai, maduraiPin));
      final container = build(
        locations: locations,
        serviceability: FakeServiceabilityRepository(zones: servedOnlyMadurai),
      );
      expect((await discover(container)).homeList, isNotEmpty);

      // Chennai is chosen, but Tukkito does not serve its pincode.
      await choosePlace(container, locations, gpsReading(chennai, chennaiPin));

      expect((await discover(container)).toMap(), _Shown.nothing().toMap());
      expect(
        container.read(deliveryServiceabilityProvider).status,
        ServiceabilityUiStatus.notServiceable,
      );
    });

    test('the live Search screen path returns nothing for it', () async {
      final locations = FakeLocationRepository(gpsReading(chennai, chennaiPin));
      final search = NationwideSearchRepository(searchMatches);
      final container = build(
        locations: locations,
        search: search,
        serviceability: FakeServiceabilityRepository(zones: servedOnlyMadurai),
      );

      expect(await typeInSearch(container), isEmpty);
      // Not even the keyword query is run for a location nobody serves.
      expect(search.calls, 0);
    });

    test('current GPS does not silently take the customer back to a served '
        'place', () async {
      final locations = FakeLocationRepository(gpsReading(madurai, maduraiPin));
      final container = build(
        locations: locations,
        gps: FakeGps(gpsReading(madurai, maduraiPin)),
        serviceability: FakeServiceabilityRepository(zones: servedOnlyMadurai),
      );
      await choosePlace(container, locations, gpsReading(chennai, chennaiPin));
      locations.saves.clear();

      await container
          .read(locationSetupProvider.notifier)
          .setupLocationAfterLogin(_userId);
      await settleServiceability(container);

      expect(locations.saves, isEmpty);
      expect(locations.stored!.city, 'Chennai');
      expect((await discover(container)).toMap(), _Shown.nothing().toMap());
    });
  });

  group('no usable destination → empty, never a nationwide list', () {
    test('no destination chosen', () async {
      final container = build(locations: FakeLocationRepository(null));

      expect((await discover(container)).toMap(), _Shown.nothing().toMap());
      expect(await typeInSearch(container), isEmpty);
    });

    test('invalid coordinates, even with a served pincode', () async {
      for (final bad in [
        const City('Null Island', 'X', 0, 0),
        const City('Bad latitude', 'X', 123, 78),
        const City('Bad longitude', 'X', 9.9, 500),
      ]) {
        final container = build(
          locations: FakeLocationRepository(
            destinationIn(bad, pincode: maduraiPin),
          ),
        );

        expect(
          (await discover(container)).toMap(),
          _Shown.nothing().toMap(),
          reason: bad.name,
        );
        expect(await typeInSearch(container), isEmpty, reason: bad.name);
      }
    });

    test(
      'the location is served or not by its COORDINATES, not its pincode',
      () async {
        // Chennai coordinates (Tukkito does not operate there) carrying a
        // Madurai pincode are still not served...
        final chennaiWithServedPin = build(
          locations: FakeLocationRepository(
            destinationIn(chennai, pincode: maduraiPin),
          ),
          serviceability: FakeServiceabilityRepository(
            zones: [zoneAround(madurai)],
          ),
        );
        expect(
          (await discover(chennaiWithServedPin)).toMap(),
          _Shown.nothing().toMap(),
        );

        // ...and Madurai coordinates (served) with a nonsense pincode are.
        final maduraiWithOddPin = build(
          locations: FakeLocationRepository(
            destinationIn(madurai, pincode: '999999'),
          ),
          serviceability: FakeServiceabilityRepository(
            zones: [zoneAround(madurai)],
          ),
        );
        expect(
          (await discover(maduraiWithOddPin)).toMap(),
          _Shown.forRestaurants(['madurai-1', 'madurai-2']).toMap(),
        );
      },
    );

    test('the customer never has to supply a pincode: a location without one '
        'is served and lists its restaurants', () async {
      final serviceability = FakeServiceabilityRepository();
      final container = build(
        locations: FakeLocationRepository(
          destinationIn(madurai, pincode: null),
        ),
        serviceability: serviceability,
      );

      expect(
        (await discover(container)).toMap(),
        _Shown.forRestaurants(['madurai-1', 'madurai-2']).toMap(),
      );
      expect(await typeInSearch(container), isNotEmpty);
      // The pincode callable plays no part in discovery.
      expect(serviceability.pincodeChecks, 0);
    });

    test('a location outside every active zone lists nothing, without any '
        'pincode check', () async {
      final serviceability = FakeServiceabilityRepository(
        zones: [zoneAround(madurai)],
      );
      final container = build(
        locations: FakeLocationRepository(
          destinationIn(bengaluru, pincode: bengaluruPin),
        ),
        serviceability: serviceability,
      );

      expect((await discover(container)).toMap(), _Shown.nothing().toMap());
      expect(serviceability.pincodeChecks, 0);
    });

    test('no active zone at all, or a zone read that fails → nothing (never a '
        'nationwide list)', () async {
      for (final serviceability in [
        FakeServiceabilityRepository(zones: const []),
        FakeServiceabilityRepository(readError: StateError('offline')),
      ]) {
        final container = build(
          locations: FakeLocationRepository(
            destinationIn(madurai, pincode: maduraiPin),
          ),
          serviceability: serviceability,
        );

        expect((await discover(container)).toMap(), _Shown.nothing().toMap());
      }
    });
  });
}
