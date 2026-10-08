import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/cart/domain/cart_quantity.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';

CartEntity _item({
  required String foodId,
  required String foodName,
  required int quantity,
}) {
  return CartEntity(
    id: foodId,
    userId: 'user-1',
    restaurantId: 'a2b',
    restaurantName: 'A2B',
    foodId: foodId,
    foodName: foodName,
    foodImage: '',
    price: 99,
    quantity: quantity,
    isVeg: true,
    isAvailable: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('CartQuantity', () {
    test('each foodId keeps its own quantity', () {
      final items = [
        _item(foodId: 'food-a', foodName: 'Mini Meals', quantity: 2),
        _item(foodId: 'food-b', foodName: 'Food B', quantity: 1),
      ];

      expect(CartQuantity.forFood(items, 'food-a'), 2);
      expect(CartQuantity.forFood(items, 'food-b'), 1);
      expect(CartQuantity.forFood(items, 'food-c'), 0);
    });

    test('indexByFoodId does not use a single global quantity', () {
      final items = [
        _item(foodId: 'food-a', foodName: 'Mini Meals', quantity: 2),
        _item(foodId: 'food-b', foodName: 'Food B', quantity: 1),
      ];

      final index = CartQuantity.indexByFoodId(items);

      expect(index['food-a'], 2);
      expect(index['food-b'], 1);
      expect(index.length, 2);
    });

    test('falls back to item.id when foodId is empty', () {
      final items = [
        CartEntity(
          id: 'food-a',
          userId: 'user-1',
          restaurantId: 'a2b',
          restaurantName: 'A2B',
          foodId: '',
          foodName: 'Mini Meals',
          foodImage: '',
          price: 160,
          quantity: 2,
          isVeg: true,
          isAvailable: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      expect(CartQuantity.forFood(items, 'food-a'), 2);
    });

    test('quantity zero means the food is not in cart', () {
      expect(CartQuantity.forFood(const [], 'food-a'), 0);
    });
  });
}
