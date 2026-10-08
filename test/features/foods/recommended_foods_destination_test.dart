import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/domain/entities/food_review_status.dart';
import 'package:customer_app/features/foods/domain/repositories/food_repository.dart';
import 'package:customer_app/features/foods/domain/usecases/get_recommended_foods_usecase.dart';
import 'package:customer_app/features/foods/presentation/providers/food_provider.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';

import '../../helpers/destination_fakes.dart';
import '../../helpers/discovery_fixtures.dart';

const _userId = 'user-1';

FoodEntity _recommended(String id, {required String restaurantId}) {
  return FoodEntity(
    id: id,
    restaurantId: restaurantId,
    name: id,
    description: '',
    price: 100,
    imageUrl: '',
    category: 'meals',
    isVeg: true,
    isAvailable: true,
    isRecommended: true,
    rating: 4.5,
    status: FoodReviewStatus.approved,
  );
}

/// Serves each restaurant's recommended foods and records which restaurants
/// were asked for, so a test can see when nothing was read.
class _FoodRepository implements FoodRepository {
  _FoodRepository(this.byRestaurant);

  final Map<String, List<FoodEntity>> byRestaurant;
  final List<String> recommendedReads = [];

  @override
  Future<List<FoodEntity>> getRecommendedFoods(String restaurantId) async {
    recommendedReads.add(restaurantId);
    return byRestaurant[restaurantId] ?? const [];
  }

  @override
  Future<FoodEntity> getFoodById(String foodId) => throw UnimplementedError();

  @override
  Future<FoodEntity?> getFoodDocumentById(String foodId) async => null;

  @override
  Future<List<FoodEntity>> getCustomerFoodsByCategoryName(
    String categoryName, {
    List<String> restaurantIds = const [],
    int limit = 30,
    String? startAfterName,
  }) async => const [];

  @override
  Future<List<FoodEntity>> getFoodsByCategory({
    required String restaurantId,
    required String category,
  }) async => const [];

  @override
  Future<List<FoodEntity>> getFoodsByRestaurant(String restaurantId) async =>
      const [];
}

void main() {
  final restaurants = NationwideRestaurantRepository([
    restaurantIn(madurai, 'madurai-near'),
    restaurantIn(madurai, 'madurai-edge', dLatKm: 14.9),
    restaurantIn(madurai, 'madurai-far', dLatKm: 15.1),
    restaurantIn(chennai, 'chennai-1'),
  ]);

  _FoodRepository foods() => _FoodRepository({
    'madurai-near': [_recommended('meals-near', restaurantId: 'madurai-near')],
    'madurai-edge': [_recommended('meals-edge', restaurantId: 'madurai-edge')],
    'madurai-far': [_recommended('meals-far', restaurantId: 'madurai-far')],
    'chennai-1': [_recommended('meals-chennai', restaurantId: 'chennai-1')],
  });

  List<String> ids(List<FoodEntity> foods) => foods.map((f) => f.id).toList();

  group('GetRecommendedFoodsUseCase', () {
    test('a restaurant that can deliver keeps its recommended foods', () async {
      final useCase = GetRecommendedFoodsUseCase(foods(), restaurants);

      final result = await useCase(
        'madurai-near',
        destination: destinationIn(madurai),
      );

      expect(ids(result), ['meals-near']);
    });

    test(
      'the recommendation list itself is untouched (same order/content)',
      () async {
        final repository = _FoodRepository({
          'madurai-near': [
            _recommended('c', restaurantId: 'madurai-near'),
            _recommended('a', restaurantId: 'madurai-near'),
            _recommended('b', restaurantId: 'madurai-near'),
          ],
        });

        final result = await GetRecommendedFoodsUseCase(
          repository,
          restaurants,
        )('madurai-near', destination: destinationIn(madurai));

        expect(ids(result), ['c', 'a', 'b']);
      },
    );

    test(
      'a restaurant outside 15 km is excluded (15.1 out, 14.9 in)',
      () async {
        final useCase = GetRecommendedFoodsUseCase(foods(), restaurants);
        final destination = destinationIn(madurai);

        expect(await useCase('madurai-far', destination: destination), isEmpty);
        expect(ids(await useCase('madurai-edge', destination: destination)), [
          'meals-edge',
        ]);
      },
    );

    test('a restaurant in another city is excluded', () async {
      final result = await GetRecommendedFoodsUseCase(foods(), restaurants)(
        'chennai-1',
        destination: destinationIn(madurai),
      );

      expect(result, isEmpty);
    });

    test('an ineligible restaurant\'s foods are not even read', () async {
      final repository = foods();

      await GetRecommendedFoodsUseCase(repository, restaurants)(
        'madurai-far',
        destination: destinationIn(madurai),
      );

      expect(repository.recommendedReads, isEmpty);
    });

    test('no destination → empty, and nothing is read', () async {
      final repository = foods();
      final restaurantRepository = NationwideRestaurantRepository([
        restaurantIn(madurai, 'madurai-near'),
      ]);

      final result = await GetRecommendedFoodsUseCase(
        repository,
        restaurantRepository,
      )('madurai-near', destination: null);

      expect(result, isEmpty);
      expect(repository.recommendedReads, isEmpty);
    });

    test('a destination without usable coordinates → empty', () async {
      final repository = foods();

      final result = await GetRecommendedFoodsUseCase(repository, restaurants)(
        'madurai-near',
        destination: destinationIn(const City('Null Island', 'X', 0, 0)),
      );

      expect(result, isEmpty);
      expect(repository.recommendedReads, isEmpty);
    });

    test('an unknown / non-listable restaurant → empty', () async {
      final repository = foods();

      final result = await GetRecommendedFoodsUseCase(repository, restaurants)(
        'closed-place',
        destination: destinationIn(madurai),
      );

      expect(result, isEmpty);
      expect(repository.recommendedReads, isEmpty);
    });
  });

  group('recommendedFoodsProvider follows the selected destination', () {
    ProviderContainer build({
      required FakeLocationRepository locations,
      FakeGps? gps,
      String? userId = _userId,
    }) {
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(userId),
          locationRepositoryProvider.overrideWithValue(locations),
          if (gps != null) deviceLocationServiceProvider.overrideWithValue(gps),
          restaurantRepositoryProvider.overrideWithValue(restaurants),
          foodRepositoryProvider.overrideWithValue(foods()),
          serviceabilityRepositoryProvider.overrideWithValue(
            FakeServiceabilityRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<List<String>> recommended(
      ProviderContainer c,
      String restaurantId,
    ) async {
      // The destination's serviceability check runs in the background in the
      // app; let it finish before reading.
      await settleServiceability(c);
      return ids(await c.read(recommendedFoodsProvider(restaurantId).future));
    }

    test('is destination-scoped', () async {
      final container = build(
        locations: FakeLocationRepository(destinationIn(madurai)),
      );

      expect(await recommended(container, 'madurai-near'), ['meals-near']);
      expect(await recommended(container, 'madurai-far'), isEmpty);
      expect(await recommended(container, 'chennai-1'), isEmpty);
    });

    test('no destination → empty (no nationwide recommendations)', () async {
      final container = build(locations: FakeLocationRepository(null));

      expect(await recommended(container, 'madurai-near'), isEmpty);
      expect(await recommended(container, 'chennai-1'), isEmpty);
    });

    test('signed out → empty', () async {
      final container = build(
        locations: FakeLocationRepository(destinationIn(madurai)),
        userId: null,
      );

      expect(await recommended(container, 'madurai-near'), isEmpty);
    });

    test(
      'changing the selected destination refreshes the recommendations',
      () async {
        final locations = FakeLocationRepository(destinationIn(madurai));
        final container = build(locations: locations);
        container.listen(recommendedFoodsProvider('chennai-1'), (_, _) {});
        expect(await recommended(container, 'chennai-1'), isEmpty);

        locations.stored = destinationIn(chennai);
        container.invalidate(userLocationProvider(_userId));

        expect(await recommended(container, 'chennai-1'), ['meals-chennai']);
      },
    );

    test(
      'a GPS refresh from another city does not change recommendations for an '
      'explicitly selected destination',
      () async {
        final locations = FakeLocationRepository(
          explicitly(destinationIn(madurai)),
        );
        final container = build(
          locations: locations,
          gps: FakeGps(
            destinationIn(chennai, selected: false, pincode: '600001'),
          ),
        );
        container.listen(recommendedFoodsProvider('chennai-1'), (_, _) {});
        container.listen(recommendedFoodsProvider('madurai-near'), (_, _) {});
        expect(await recommended(container, 'madurai-near'), ['meals-near']);
        expect(await recommended(container, 'chennai-1'), isEmpty);

        await container
            .read(locationSetupProvider.notifier)
            .refreshCurrentLocation(_userId);
        await pumpEventQueue();

        expect(locations.saves, isEmpty);
        expect(await recommended(container, 'madurai-near'), ['meals-near']);
        expect(await recommended(container, 'chennai-1'), isEmpty);
      },
    );

    test('login from another city does not change recommendations for an '
        'explicitly selected destination', () async {
      final locations = FakeLocationRepository(
        explicitly(destinationIn(madurai)),
      );
      final container = build(
        locations: locations,
        gps: FakeGps(
          destinationIn(chennai, selected: false, pincode: '600001'),
        ),
      );
      expect(await recommended(container, 'chennai-1'), isEmpty);

      await container
          .read(locationSetupProvider.notifier)
          .setupLocationAfterLogin(_userId);
      await pumpEventQueue();

      expect(locations.saves, isEmpty);
      expect(await recommended(container, 'chennai-1'), isEmpty);
      expect(await recommended(container, 'madurai-near'), ['meals-near']);
    });
  });
}
