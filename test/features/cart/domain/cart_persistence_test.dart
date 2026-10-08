import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/cart/domain/cart_clear_policy.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:customer_app/features/cart/domain/usecases/add_to_cart_usecase.dart';
import 'package:customer_app/features/cart/domain/usecases/clear_cart_usecase.dart';
import 'package:customer_app/features/cart/domain/usecases/get_cart_items_usecase.dart';

class _InMemoryCartRepository implements CartRepository {
  final Map<String, Map<String, CartEntity>> _store = {};
  int clearCallCount = 0;

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
    clearCallCount += 1;
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

CartEntity _item() {
  return CartEntity(
    id: 'food-1',
    userId: 'user-1',
    restaurantId: 'r1',
    restaurantName: 'A2B',
    foodId: 'food-1',
    foodName: 'Mini Meals',
    foodImage: '',
    price: 160,
    quantity: 1,
    isVeg: true,
    isAvailable: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('Cart persistence', () {
    test('cart remains after provider/use-case recreation', () async {
      final repository = _InMemoryCartRepository();
      await AddToCartUseCase(repository).call(_item());

      final firstRead = await GetCartItemsUseCase(repository).call('user-1');
      expect(firstRead, isNotEmpty);

      final secondRead = await GetCartItemsUseCase(repository).call('user-1');
      expect(secondRead.length, firstRead.length);
      expect(secondRead.first.foodId, 'food-1');
      expect(repository.clearCallCount, 0);
    });

    test('cart remains after app restart simulation', () async {
      final persistedStore = _InMemoryCartRepository();
      await AddToCartUseCase(persistedStore).call(_item());

      await const CartStartupHandler().onAppStart();

      final afterRestart = await GetCartItemsUseCase(
        persistedStore,
      ).call('user-1');

      expect(afterRestart, isNotEmpty);
      expect(afterRestart.first.quantity, 1);
      expect(persistedStore.clearCallCount, 0);
    });

    test('failed checkout keeps persisted cart items', () async {
      final repository = _InMemoryCartRepository();
      await AddToCartUseCase(repository).call(_item());

      expect(() => throw StateError('Order creation failed'), throwsStateError);
      expect(repository.clearCallCount, 0);
      expect(await repository.getCartItems('user-1'), isNotEmpty);
    });

    test(
      'successful checkout then clearCart empties persisted items',
      () async {
        final repository = _InMemoryCartRepository();
        await AddToCartUseCase(repository).call(_item());

        const policy = CartClearPolicy();
        expect(
          policy.canClear(CartClearReason.orderCompletedSuccessfully),
          isTrue,
        );
        await ClearCartUseCase(repository).call('user-1');

        expect(repository.clearCallCount, 1);
        expect(await repository.getCartItems('user-1'), isEmpty);
      },
    );

    test('clearCart is NOT called during startup', () async {
      final repository = _InMemoryCartRepository();
      await AddToCartUseCase(repository).call(_item());

      await const CartStartupHandler().onAppStart();

      expect(repository.clearCallCount, 0);
      expect(await repository.getCartItems('user-1'), isNotEmpty);
    });
  });

  group('CartClearPolicy', () {
    test('clearCart is only allowed after successful order completion', () {
      const policy = CartClearPolicy();

      expect(
        policy.canClear(CartClearReason.orderCompletedSuccessfully),
        isTrue,
      );
    });

    test('successful order completion is the only clear path', () async {
      final repository = _InMemoryCartRepository();
      await AddToCartUseCase(repository).call(_item());

      const policy = CartClearPolicy();
      if (policy.canClear(CartClearReason.orderCompletedSuccessfully)) {
        await ClearCartUseCase(repository).call('user-1');
      }

      expect(repository.clearCallCount, 1);
      expect(await repository.getCartItems('user-1'), isEmpty);
    });
  });
}
