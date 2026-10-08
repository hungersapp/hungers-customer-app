import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/restaurants/domain/restaurant_delivery_range.dart';

import '../../../helpers/discovery_fixtures.dart';

void main() {
  group('RestaurantDeliveryRange.within — multiple restaurants and cities', () {
    final all = [
      restaurantIn(madurai, 'madurai-centre'),
      restaurantIn(madurai, 'madurai-north', dLatKm: 4.6),
      restaurantIn(thanjavur, 'thanjavur'),
      restaurantIn(chennai, 'chennai'),
      restaurantIn(bengaluru, 'bengaluru'),
    ];

    test('a Madurai destination lists only the Madurai restaurants', () {
      final listed = RestaurantDeliveryRange.within(
        restaurants: all,
        destination: destinationIn(madurai),
      );

      expect(listed.map((r) => r.id), ['madurai-centre', 'madurai-north']);
    });

    test('a Chennai destination lists only the Chennai restaurant', () {
      final listed = RestaurantDeliveryRange.within(
        restaurants: all,
        destination: destinationIn(chennai),
      );

      expect(listed.map((r) => r.id), ['chennai']);
    });

    test('a Bengaluru destination (another state) lists only Bengaluru', () {
      final listed = RestaurantDeliveryRange.within(
        restaurants: all,
        destination: destinationIn(bengaluru),
      );

      expect(listed.map((r) => r.id), ['bengaluru']);
    });

    test('a destination between cities that reaches nobody lists nothing', () {
      // Roughly midway between Madurai and Thanjavur: >15 km from both.
      final listed = RestaurantDeliveryRange.within(
        restaurants: all,
        destination: destinationIn(
          const City('Between', 'Tamil Nadu', 10.35, 78.6),
        ),
      );

      expect(listed, isEmpty);
    });

    test('keeps the original order and does not mutate its input', () {
      final input = [
        restaurantIn(madurai, 'b', rating: 3),
        restaurantIn(chennai, 'x'),
        restaurantIn(madurai, 'a', rating: 5),
      ];
      final before = input.map((r) => r.id).toList();

      final listed = RestaurantDeliveryRange.within(
        restaurants: input,
        destination: destinationIn(madurai),
      );

      expect(listed.map((r) => r.id), ['b', 'a']);
      expect(input.map((r) => r.id), before);
    });
  });

  group('the 15 km boundary', () {
    final destination = destinationIn(madurai, dLatKm: 0);

    test('a restaurant just inside 15 km is listed, just outside is not', () {
      final inside = restaurantIn(madurai, 'inside', dLatKm: 14.9);
      final outside = restaurantIn(madurai, 'outside', dLatKm: 15.1);

      // destinationIn(madurai) sits at the madurai centre; restaurants are
      // offset north of it by the given distance.
      final listed = RestaurantDeliveryRange.within(
        restaurants: [inside, outside],
        destination: destination,
      );

      expect(listed.map((r) => r.id), ['inside']);
    });

    test('maxDistanceKm is the 15 km delivery limit', () {
      // The backend prices nothing beyond 15 km of road. The straight line
      // is never longer than the road, so discovery stops at the same figure.
      expect(RestaurantDeliveryRange.maxDistanceKm, 15);
    });
  });

  group('fail-closed: never the nationwide list', () {
    final all = [
      restaurantIn(madurai, 'madurai'),
      restaurantIn(chennai, 'chennai'),
    ];

    test('no destination → nothing is discoverable', () {
      expect(
        RestaurantDeliveryRange.within(restaurants: all, destination: null),
        isEmpty,
      );
    });

    test(
      'a destination without usable coordinates → nothing is discoverable',
      () {
        for (final bad in [
          const City('Null Island', 'X', 0, 0),
          const City('Bad latitude', 'X', 123, 78),
          const City('Bad longitude', 'X', 9.9, 500),
        ]) {
          expect(
            RestaurantDeliveryRange.within(
              restaurants: all,
              destination: destinationIn(bad),
            ),
            isEmpty,
            reason: bad.name,
          );
        }
      },
    );

    test(
      'a restaurant with no usable coordinates is excluded (it cannot be priced)',
      () {
        final broken = [
          testRestaurant(id: 'origin', latitude: 0, longitude: 0),
          testRestaurant(id: 'bad-lat', latitude: 200, longitude: 78),
          restaurantIn(madurai, 'fine'),
        ];

        final listed = RestaurantDeliveryRange.within(
          restaurants: broken,
          destination: destinationIn(madurai),
        );

        expect(listed.map((r) => r.id), ['fine']);
      },
    );
  });

  test('distanceKm reports the restaurant → destination distance', () {
    final km = RestaurantDeliveryRange.distanceKm(
      restaurant: restaurantIn(madurai, 'r', dLatKm: 10),
      destination: destinationIn(madurai),
    );

    // The destination fixture and the restaurant are offset by 10 km of
    // latitude (destination has none), so the distance is 10 km.
    expect(km, closeTo(10, 0.05));
    expect(
      RestaurantDeliveryRange.distanceKm(
        restaurant: testRestaurant(id: 'x', latitude: 0, longitude: 0),
        destination: destinationIn(madurai),
      ),
      isNull,
    );
  });
}
