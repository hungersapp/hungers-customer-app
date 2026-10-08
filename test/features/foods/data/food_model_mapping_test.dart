import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/foods/data/models/food_model.dart';

void main() {
  group('FoodModel.fromMap name mapping', () {
    test('uses name from the Food entity source field', () {
      final food = FoodModel.fromMap({
        'restaurantId': 'a2b',
        'name': 'Mini Meals',
        'price': 160,
        'rating': 4.5,
        'isVeg': true,
      }, 'food-a');

      expect(food.name, 'Mini Meals');
      expect(food.name, isNot(equals('')));
    });

    test('maps foodName when name is missing', () {
      final food = FoodModel.fromMap({
        'restaurantId': 'a2b',
        'foodName': 'Food B',
        'price': 99,
      }, 'food-b');

      expect(food.name, 'Food B');
    });

    test('maps food_name when camelCase name is missing', () {
      final food = FoodModel.fromMap({
        'restaurantId': 'a2b',
        'food_name': 'Ghee Roast Dosa',
        'price': 99,
      }, 'food-b');

      expect(food.name, 'Ghee Roast Dosa');
    });

    test('maps nested localized name maps', () {
      final food = FoodModel.fromMap({
        'name': {'en': 'Filter Coffee', 'ta': 'Filter Coffee'},
        'price': 40,
      }, 'food-c');

      expect(food.name, 'Filter Coffee');
    });

    test('maps itemName-style fields when name is missing', () {
      final food = FoodModel.fromMap({
        'restaurantId': 'a2b',
        'itemName': 'Food B',
        'price': 99,
      }, 'food-b');

      expect(food.name, 'Food B');
    });

    test('does not invent a hardcoded food name', () {
      final food = FoodModel.fromMap({'price': 99}, 'food-empty');

      expect(food.name, isEmpty);
      expect(food.name, isNot(equals('Mini Meals')));
    });

    test('maps price, rating, isVeg, and imageUrl from the document', () {
      final food = FoodModel.fromMap({
        'name': 'Mini Meals',
        'price': 160,
        'offerPrice': 140,
        'rating': 4.2,
        'isVeg': true,
        'imageUrl': 'https://example.com/meals.png',
      }, 'food-a');

      expect(food.finalPrice, 140);
      expect(food.rating, 4.2);
      expect(food.isVeg, isTrue);
      expect(food.imageUrl, 'https://example.com/meals.png');
      expect(food.offerLabel, '13% OFF');
    });

    test('maps approved review status for customer visibility', () {
      final approved = FoodModel.fromMap({
        'restaurantId': 'a2b',
        'name': 'Idli',
        'status': 'approved',
        'isAvailable': true,
      }, 'food-ok');
      final pending = FoodModel.fromMap({
        'restaurantId': 'a2b',
        'name': 'Draft',
        'status': 'submitted',
        'isAvailable': true,
      }, 'food-pending');
      final legacy = FoodModel.fromMap({
        'restaurantId': 'a2b',
        'name': 'Legacy',
        'isAvailable': true,
      }, 'food-legacy');

      expect(approved.isCustomerVisibleFood, isTrue);
      expect(pending.isCustomerVisibleFood, isFalse);
      expect(legacy.isCustomerVisibleFood, isFalse);
    });

    test('maps ratingCount from ratingCount or totalRatings', () {
      final counted = FoodModel.fromMap({
        'restaurantId': 'a2b',
        'name': 'Idli',
        'rating': 4.8,
        'ratingCount': 128,
      }, 'food-rated');
      final fallback = FoodModel.fromMap({
        'restaurantId': 'a2b',
        'name': 'Dosa',
        'rating': 4.2,
        'totalRatings': 45,
      }, 'food-legacy-count');

      expect(counted.ratingCount, 128);
      expect(fallback.ratingCount, 45);
    });
  });
}
