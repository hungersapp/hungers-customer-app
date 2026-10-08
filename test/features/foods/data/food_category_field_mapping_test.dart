import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/foods/data/models/food_model.dart';
import 'package:customer_app/features/foods/domain/entities/food_review_status.dart';

void main() {
  test(
    'foods.category maps as a display name string, not a document id field',
    () {
      final food = FoodModel.fromMap({
        'restaurantId': 'r1',
        'name': 'Pepperoni',
        'category': 'Pizza',
        'price': 250,
        'status': FoodReviewStatus.approved.firestoreValue,
        'isAvailable': true,
      }, 'food-1');

      expect(food.category, 'Pizza');
      expect(food.category, isNot(equals(food.id)));
      expect(food.isCustomerVisibleFood, isTrue);
    },
  );

  test('unapproved or unavailable foods are not customer-visible', () {
    final pending = FoodModel.fromMap({
      'restaurantId': 'r1',
      'name': 'Draft Pizza',
      'category': 'Pizza',
      'status': 'submitted',
      'isAvailable': true,
    }, 'food-2');
    final unavailable = FoodModel.fromMap({
      'restaurantId': 'r1',
      'name': 'Sold Out',
      'category': 'Pizza',
      'status': FoodReviewStatus.approved.firestoreValue,
      'isAvailable': false,
    }, 'food-3');

    expect(pending.isCustomerVisibleFood, isFalse);
    expect(unavailable.isCustomerVisibleFood, isFalse);
  });
}
