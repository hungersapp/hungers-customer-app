import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:customer_app/features/cart/domain/usecases/add_to_cart_usecase.dart';
import 'package:customer_app/features/cart/domain/usecases/get_cart_items_usecase.dart';
import 'package:customer_app/features/cart/domain/usecases/get_cart_total_usecase.dart';
import 'package:customer_app/features/cart/domain/usecases/remove_cart_item_usecase.dart';
import 'package:customer_app/features/cart/domain/usecases/update_cart_quantity_usecase.dart';

class _InMemoryCartRepository implements CartRepository {
  final Map<String, Map<String, CartEntity>> _store = {};

  @override
  Future<void> addToCart(CartEntity cart) async {
    _store.putIfAbsent(cart.userId, () => {});
    _store[cart.userId]![cart.foodId] = cart;
  }

  @override
  Future<List<CartEntity>> getCartItems(String userId) async {
    return _store[userId]?.values.toList() ?? [];
  }

  @override
  Future<CartEntity?> getCartItem({
    required String userId,
    required String foodId,
  }) async {
    return _store[userId]?[foodId];
  }

  @override
  Future<void> updateQuantity({
    required String userId,
    required String foodId,
    required int quantity,
  }) async {
    final item = _store[userId]?[foodId];
    if (item == null) {
      return;
    }
    _store[userId]![foodId] = item.copyWith(quantity: quantity);
  }

  @override
  Future<void> removeItem({
    required String userId,
    required String foodId,
  }) async {
    _store[userId]?.remove(foodId);
  }

  @override
  Future<void> clearCart(String userId) async {
    _store[userId]?.clear();
  }

  @override
  Future<int> getCartItemCount(String userId) async {
    return _store[userId]?.length ?? 0;
  }

  @override
  Future<double> getCartTotal(String userId) async {
    final items = await getCartItems(userId);
    return items.fold<double>(0, (total, item) => total + item.totalPrice);
  }
}

CartEntity _item({
  required String foodId,
  required String foodName,
  required double price,
  int quantity = 1,
}) {
  return CartEntity(
    id: foodId,
    userId: 'user-1',
    restaurantId: 'a2b',
    restaurantName: 'A2B',
    foodId: foodId,
    foodName: foodName,
    foodImage: '',
    price: price,
    quantity: quantity,
    isVeg: true,
    isAvailable: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('ADD, increase, decrease, remove, and cart total', () async {
    final repository = _InMemoryCartRepository();
    final add = AddToCartUseCase(repository);
    final update = UpdateCartQuantityUseCase(repository);
    final remove = RemoveCartItemUseCase(repository);
    final items = GetCartItemsUseCase(repository);
    final total = GetCartTotalUseCase(repository);

    await add.call(_item(foodId: 'food-a', foodName: 'Mini Meals', price: 160));
    await add.call(_item(foodId: 'food-a', foodName: 'Mini Meals', price: 160));
    await add.call(_item(foodId: 'food-b', foodName: 'Food B', price: 99));

    var cart = await items.call('user-1');
    expect(cart.length, 2);
    expect(cart.firstWhere((item) => item.foodId == 'food-a').quantity, 2);

    await update.call(userId: 'user-1', foodId: 'food-a', quantity: 3);
    await update.call(userId: 'user-1', foodId: 'food-b', quantity: 1);
    expect(await total.call('user-1'), 160 * 3 + 99);

    await update.call(userId: 'user-1', foodId: 'food-a', quantity: 2);
    expect(await total.call('user-1'), 160 * 2 + 99);

    await remove.call(userId: 'user-1', foodId: 'food-b');
    cart = await items.call('user-1');
    expect(cart.length, 1);
    expect(cart.first.foodName, 'Mini Meals');
  });
}
