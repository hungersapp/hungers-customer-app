import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/search/domain/entities/search_result_entity.dart';
import 'package:customer_app/features/search/domain/usecases/search_usecase.dart';

import '../../../helpers/discovery_fixtures.dart';

void main() {
  // Restaurants in three cities; the listable set is what the restaurant
  // repository serves (customer-visible, open, approved).
  final listable = [
    restaurantIn(madurai, 'madurai-near'),
    restaurantIn(madurai, 'madurai-edge', dLatKm: 14.9),
    restaurantIn(madurai, 'madurai-far', dLatKm: 15.1),
    restaurantIn(chennai, 'chennai-1'),
    restaurantIn(bengaluru, 'bengaluru-1'),
  ];

  final matches = [
    restaurantResult('madurai-near'),
    restaurantResult('madurai-edge'),
    restaurantResult('madurai-far'),
    restaurantResult('chennai-1'),
    restaurantResult('bengaluru-1'),
    foodResult('biryani-madurai', restaurantId: 'madurai-near'),
    foodResult('biryani-far', restaurantId: 'madurai-far'),
    foodResult('biryani-chennai', restaurantId: 'chennai-1'),
    foodResult('biryani-bengaluru', restaurantId: 'bengaluru-1'),
  ];

  SearchUseCase build({
    List<SearchResultEntity>? results,
    NationwideRestaurantRepository? restaurants,
    NationwideSearchRepository? search,
  }) {
    return SearchUseCase(
      search ?? NationwideSearchRepository(results ?? matches),
      restaurants ?? NationwideRestaurantRepository(listable),
    );
  }

  List<String> ids(List<SearchResultEntity> results) =>
      results.map((r) => r.id).toList();

  group('search with a selected destination', () {
    test(
      'returns only results from restaurants that can deliver there',
      () async {
        final result = await build().searchAll(
          'biryani',
          destination: destinationIn(madurai),
        );

        expect(ids(result), [
          'madurai-near',
          'madurai-edge',
          'biryani-madurai',
        ]);
      },
    );

    test(
      'follows the destination — Chennai shows Chennai, not Madurai',
      () async {
        final result = await build().searchAll(
          'biryani',
          destination: destinationIn(chennai),
        );

        expect(ids(result), ['chennai-1', 'biryani-chennai']);
      },
    );

    test('restaurant results outside 15 km are excluded', () async {
      final result = await build().searchRestaurants(
        'madurai',
        destination: destinationIn(madurai),
      );

      expect(ids(result), ['madurai-near', 'madurai-edge']);
      expect(ids(result), isNot(contains('madurai-far'))); // 15.1 km
    });

    test('food results from restaurants outside 15 km are excluded', () async {
      final result = await build().searchFoods(
        'biryani',
        destination: destinationIn(madurai),
      );

      // 'biryani-far' is sold by madurai-far (15.1 km); the other cities'
      // foods are hundreds of km away.
      expect(ids(result), ['biryani-madurai']);
    });

    test('the boundary is the shared 15 km rule (14.9 in, 15.1 out)', () async {
      final result = await build().searchAll(
        'x',
        destination: destinationIn(madurai),
      );

      expect(ids(result), contains('madurai-edge'));
      expect(ids(result), isNot(contains('madurai-far')));
    });

    test('a food naming no restaurant is dropped (cannot be placed)', () async {
      final useCase = build(
        results: [
          foodResult('orphan', restaurantId: ''),
          foodResult('ok', restaurantId: 'madurai-near'),
        ],
      );

      final result = await useCase.searchFoods(
        'x',
        destination: destinationIn(madurai),
      );

      expect(ids(result), ['ok']);
    });

    test('category results are kept even without a restaurant id', () async {
      final result = await build(
        results: [
          const SearchResultEntity(
            id: 'cat-pizza',
            title: 'Pizza',
            subtitle: 'Category',
            imageUrl: '',
            type: SearchResultType.category,
          ),
          restaurantResult('chennai-1'),
        ],
      ).searchAll('pizza', destination: destinationIn(madurai));

      expect(ids(result), ['cat-pizza']);
    });

    test('a food whose restaurant is not customer-listable is dropped', () async {
      // 'closed-place' is not in the listable set (closed / hidden / unapproved).
      final useCase = build(
        results: [foodResult('dish', restaurantId: 'closed-place')],
      );

      final result = await useCase.searchFoods(
        'x',
        destination: destinationIn(madurai),
      );

      expect(result, isEmpty);
    });

    test('keeps the datasource order of the surviving results', () async {
      final useCase = build(
        results: [
          foodResult('b', restaurantId: 'madurai-near'),
          restaurantResult('madurai-edge'),
          foodResult('a', restaurantId: 'madurai-near'),
        ],
      );

      final result = await useCase.searchAll(
        'x',
        destination: destinationIn(madurai),
      );

      expect(ids(result), ['b', 'madurai-edge', 'a']);
    });

    test(
      'search is bounded and never reads the nationwide restaurant list',
      () async {
        final search = NationwideSearchRepository(matches);
        final restaurants = NationwideRestaurantRepository(listable);
        final result = await SearchUseCase(
          search,
          restaurants,
        ).searchAll('biryani', destination: destinationIn(madurai));

        expect(result.length, lessThanOrEqualTo(SearchUseCase.resultLimit * 2));
        expect(search.lastLimit, SearchUseCase.resultLimit);
        expect(search.lastGeohash4Cells, isNotEmpty);
        expect(search.lastRestaurantIds, isNotEmpty);
        expect(restaurants.getAllCalls, 0);
        expect(restaurants.discoverableCalls, 1);
      },
    );
  });

  group('fail-closed: no nationwide search results', () {
    test(
      'no destination → empty for restaurants, foods and universal search',
      () async {
        final search = NationwideSearchRepository(matches);
        final restaurants = NationwideRestaurantRepository(listable);
        final useCase = build(search: search, restaurants: restaurants);

        expect(await useCase.searchAll('x', destination: null), isEmpty);
        expect(
          await useCase.searchRestaurants('x', destination: null),
          isEmpty,
        );
        expect(await useCase.searchFoods('x', destination: null), isEmpty);
      },
    );

    test('no destination → nothing is even read', () async {
      final search = NationwideSearchRepository(matches);
      final restaurants = NationwideRestaurantRepository(listable);

      await build(
        search: search,
        restaurants: restaurants,
      ).searchAll('x', destination: null);

      expect(search.calls, 0);
      expect(restaurants.getAllCalls, 0);
    });

    test('a destination without usable coordinates → empty', () async {
      final useCase = build();

      for (final bad in [
        const City('Null Island', 'X', 0, 0),
        const City('Bad latitude', 'X', 123, 78),
      ]) {
        expect(
          await useCase.searchAll('x', destination: destinationIn(bad)),
          isEmpty,
          reason: bad.name,
        );
      }
    });

    test(
      'no listable restaurants at all → empty, not the raw matches',
      () async {
        final useCase = build(restaurants: NationwideRestaurantRepository([]));

        expect(
          await useCase.searchAll('x', destination: destinationIn(madurai)),
          isEmpty,
        );
      },
    );

    test('a destination far from every restaurant → empty', () async {
      final result = await build().searchAll(
        'x',
        destination: destinationIn(const City('Mid Ocean', 'X', 5.0, 85.0)),
      );

      expect(result, isEmpty);
    });
  });

  test('the owning restaurant of a result: itself, or a food\'s seller', () {
    expect(restaurantResult('r1').owningRestaurantId, 'r1');
    expect(foodResult('f', restaurantId: ' r2 ').owningRestaurantId, 'r2');
    expect(foodResult('f', restaurantId: '').owningRestaurantId, '');
  });
}
