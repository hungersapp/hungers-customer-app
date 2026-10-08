import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/domain/usecases/get_all_restaurants.dart';
import 'package:customer_app/features/restaurants/domain/usecases/get_featured_restaurants.dart';
import 'package:customer_app/features/restaurants/domain/usecases/get_nearby_restaurants.dart';
import 'package:customer_app/features/restaurants/domain/usecases/get_popular_restaurants.dart';

import '../../../helpers/discovery_fixtures.dart';

void main() {
  final nationwide = [
    restaurantIn(madurai, 'madurai-a', rating: 4.1),
    restaurantIn(chennai, 'chennai-a', rating: 4.9),
    restaurantIn(madurai, 'madurai-b', rating: 4.6, dLatKm: 4.6),
    restaurantIn(bengaluru, 'bengaluru-a', rating: 4.8),
    restaurantIn(thanjavur, 'thanjavur-a', rating: 4.7),
  ];

  group('GetAllRestaurants', () {
    test(
      'returns only restaurants that can deliver to the destination',
      () async {
        final repository = NationwideRestaurantRepository(nationwide);
        final useCase = GetAllRestaurants(repository: repository);

        final result = await useCase(destination: destinationIn(madurai));

        expect(result.map((r) => r.id), ['madurai-a', 'madurai-b']);
        expect(repository.getAllCalls, 0);
        expect(repository.discoverableCalls, 1);
        expect(repository.lastGeohash4Cells, isNotEmpty);
      },
    );

    test('no destination → empty, never the nationwide list', () async {
      final useCase = GetAllRestaurants(
        repository: NationwideRestaurantRepository(nationwide),
      );

      expect(await useCase(destination: null), isEmpty);
    });
  });

  group('GetFeaturedRestaurants', () {
    test('scopes the featured list to the destination', () async {
      final featured = [
        restaurantIn(madurai, 'madurai-star').copyWithFeatured(),
        restaurantIn(chennai, 'chennai-star').copyWithFeatured(),
      ];
      final useCase = GetFeaturedRestaurants(
        repository: NationwideRestaurantRepository(featured),
      );

      final result = await useCase(destination: destinationIn(chennai));

      expect(result.map((r) => r.id), ['chennai-star']);
    });
  });

  group('GetNearbyRestaurants', () {
    test('lists only reachable restaurants, closest first', () async {
      final restaurants = [
        restaurantIn(madurai, 'far', dLatKm: 12),
        restaurantIn(madurai, 'near', dLatKm: 1),
        restaurantIn(madurai, 'mid', dLatKm: 6),
        restaurantIn(chennai, 'other-city'),
      ];
      final useCase = GetNearbyRestaurants(
        repository: NationwideRestaurantRepository(restaurants),
      );

      final result = await useCase(destination: destinationIn(madurai));

      expect(result.map((r) => r.id), ['near', 'mid', 'far']);
    });

    test('no destination → empty', () async {
      final useCase = GetNearbyRestaurants(
        repository: NationwideRestaurantRepository(nationwide),
      );

      expect(await useCase(destination: null), isEmpty);
    });
  });

  group('GetPopularRestaurants', () {
    test('ranks the restaurants that can deliver by rating', () async {
      final useCase = GetPopularRestaurants(
        repository: NationwideRestaurantRepository(nationwide),
      );

      final result = await useCase(destination: destinationIn(madurai));

      expect(result.map((r) => r.id), ['madurai-b', 'madurai-a']);
    });

    test('filters BEFORE the top-20 cut: a national top 20 elsewhere must not '
        'leave a Madurai customer with an empty list', () async {
      // 25 better-rated restaurants in Chennai would fill the national
      // top 20 entirely; the 3 Madurai ones rate lower.
      final restaurants = [
        for (var i = 0; i < 25; i++)
          restaurantIn(chennai, 'chennai-$i', rating: 5.0),
        restaurantIn(madurai, 'madurai-1', rating: 4.2),
        restaurantIn(madurai, 'madurai-2', rating: 4.4),
        restaurantIn(madurai, 'madurai-3', rating: 3.9),
      ];
      final repository = NationwideRestaurantRepository(restaurants);
      final useCase = GetPopularRestaurants(repository: repository);

      final result = await useCase(destination: destinationIn(madurai));

      expect(result.map((r) => r.id), ['madurai-2', 'madurai-1', 'madurai-3']);
      // It does not go through the repository's nationwide top-20 query.
      expect(repository.popularCalls, 0);
    });

    test('still caps the local list at 20', () async {
      final restaurants = [
        for (var i = 0; i < 30; i++)
          restaurantIn(madurai, 'm-$i', rating: 3.0 + i / 100),
      ];
      final useCase = GetPopularRestaurants(
        repository: NationwideRestaurantRepository(restaurants),
      );

      final result = await useCase(destination: destinationIn(madurai));

      expect(result, hasLength(GetPopularRestaurants.limit));
      expect(result.first.id, 'm-29'); // highest rated
    });

    test('equal ratings keep the repository order (deterministic)', () async {
      final restaurants = [
        restaurantIn(madurai, 'first', rating: 4.5),
        restaurantIn(madurai, 'second', rating: 4.5),
        restaurantIn(madurai, 'third', rating: 4.5),
      ];
      final useCase = GetPopularRestaurants(
        repository: NationwideRestaurantRepository(restaurants),
      );

      final result = await useCase(destination: destinationIn(madurai));

      expect(result.map((r) => r.id), ['first', 'second', 'third']);
    });

    test('no destination → empty', () async {
      final useCase = GetPopularRestaurants(
        repository: NationwideRestaurantRepository(nationwide),
      );

      expect(await useCase(destination: null), isEmpty);
    });
  });
}

extension on RestaurantEntity {
  /// The same restaurant flagged featured (fixtures build non-featured ones).
  RestaurantEntity copyWithFeatured() => testRestaurant(
    id: id,
    latitude: latitude,
    longitude: longitude,
    rating: rating,
    isFeatured: true,
  );
}
