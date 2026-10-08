import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/cart_firestore_datasource.dart';
import '../../data/repositories/cart_repository_impl.dart';
import '../../domain/entities/cart_entity.dart';
import '../../domain/repositories/cart_repository.dart';
import '../../domain/usecases/add_to_cart_usecase.dart';
import '../../domain/usecases/clear_cart_usecase.dart';
import '../../domain/usecases/get_cart_items_usecase.dart';
import '../../domain/usecases/get_cart_total_usecase.dart';
import '../../domain/usecases/remove_cart_item_usecase.dart';
import '../../domain/usecases/update_cart_quantity_usecase.dart';
import '../../domain/usecases/calculate_cart_billing_usecase.dart';
import '../../domain/cart_clear_policy.dart';
import '../../domain/entities/billing_config.dart';

/// Firebase
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Datasource
final cartDatasourceProvider =
    Provider<CartFirestoreDatasource>((ref) {
  return CartFirestoreDatasource(
    ref.watch(firestoreProvider),
  );
});

/// Repository
final cartRepositoryProvider =
    Provider<CartRepository>((ref) {
  return CartRepositoryImpl(
    ref.watch(cartDatasourceProvider),
  );
});

/// UseCases
final addToCartUseCaseProvider =
    Provider<AddToCartUseCase>((ref) {
  return AddToCartUseCase(
    ref.watch(cartRepositoryProvider),
  );
});

final updateCartQuantityUseCaseProvider =
    Provider<UpdateCartQuantityUseCase>((ref) {
  return UpdateCartQuantityUseCase(
    ref.watch(cartRepositoryProvider),
  );
});

final removeCartItemUseCaseProvider =
    Provider<RemoveCartItemUseCase>((ref) {
  return RemoveCartItemUseCase(
    ref.watch(cartRepositoryProvider),
  );
});

final getCartItemsUseCaseProvider =
    Provider<GetCartItemsUseCase>((ref) {
  return GetCartItemsUseCase(
    ref.watch(cartRepositoryProvider),
  );
});

final clearCartUseCaseProvider =
    Provider<ClearCartUseCase>((ref) {
  return ClearCartUseCase(
    ref.watch(cartRepositoryProvider),
  );
});

final getCartTotalUseCaseProvider =
    Provider<GetCartTotalUseCase>((ref) {
  return GetCartTotalUseCase(
    ref.watch(cartRepositoryProvider),
  );
});

final billingConfigProvider = Provider<BillingConfig>((ref) {
  return BillingConfig.mvp();
});

final calculateCartBillingUseCaseProvider =
    Provider<CalculateCartBillingUseCase>((ref) {
  return const CalculateCartBillingUseCase();
});

/// Cart Items
final cartItemsProvider =
    FutureProvider.family<List<CartEntity>, String>(
  (ref, userId) async {
    return ref
        .watch(getCartItemsUseCaseProvider)
        .call(userId);
  },
);

/// Cart Total
final cartTotalProvider =
    FutureProvider.family<double, String>(
  (ref, userId) async {
    final items = await ref.watch(cartItemsProvider(userId).future);
    return items.fold<double>(0, (total, item) => total + item.totalPrice);
  },
);

/// Item Count
final cartItemCountProvider =
    FutureProvider.family<int, String>(
  (ref, userId) async {
    final items = await ref.watch(cartItemsProvider(userId).future);
    return items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
  },
);

/// Quantity changes the customer has made that Firestore has not confirmed
/// yet, keyed by foodId. An entry with quantity 0 means "removed". The menu
/// and the sticky cart bar read [effectiveCartItemsProvider], so ADD and the
/// stepper respond on the same frame instead of after the network write.
final pendingCartItemsProvider =
    StateProvider.family<Map<String, CartEntity>, String>(
  (ref, userId) => const {},
);

/// Saved cart items with [pendingCartItemsProvider] applied on top. Null
/// until the cart has loaded once and nothing is pending.
final effectiveCartItemsProvider =
    Provider.family<List<CartEntity>?, String>((ref, userId) {
  final saved = ref.watch(cartItemsProvider(userId)).valueOrNull;
  final pending = ref.watch(pendingCartItemsProvider(userId));
  if (pending.isEmpty) {
    return saved;
  }
  final merged = <CartEntity>[];
  final seen = <String>{};
  for (final item in saved ?? const <CartEntity>[]) {
    seen.add(item.foodId);
    final override = pending[item.foodId];
    if (override == null) {
      merged.add(item);
    } else if (override.quantity > 0) {
      merged.add(item.copyWith(quantity: override.quantity));
    }
  }
  for (final entry in pending.entries) {
    if (!seen.contains(entry.key) && entry.value.quantity > 0) {
      merged.add(entry.value);
    }
  }
  return merged;
});

/// Cart Controller
class CartNotifier extends StateNotifier<AsyncValue<void>> {
  CartNotifier(this.ref)
      : super(const AsyncData(null));

  final Ref ref;

  void _refreshCart(String userId) {
    ref.invalidate(cartItemsProvider(userId));
    ref.invalidate(cartTotalProvider(userId));
    ref.invalidate(cartItemCountProvider(userId));
  }

  Future<void> addToCart(CartEntity item) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref
          .read(addToCartUseCaseProvider)
          .call(item);

      _refreshCart(item.userId);
    });
  }

  Future<void> updateQuantity({
    required String userId,
    required String foodId,
    required int quantity,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref
          .read(updateCartQuantityUseCaseProvider)
          .call(
            userId: userId,
            foodId: foodId,
            quantity: quantity,
          );

      _refreshCart(userId);
    });
  }

  Future<void> removeItem({
    required String userId,
    required String foodId,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref
          .read(removeCartItemUseCaseProvider)
          .call(
            userId: userId,
            foodId: foodId,
          );

      _refreshCart(userId);
    });
  }

  final Set<String> _syncingFoodIds = <String>{};

  void _setPending(String userId, String foodId, CartEntity? item) {
    final notifier = ref.read(pendingCartItemsProvider(userId).notifier);
    final next = Map<String, CartEntity>.of(notifier.state);
    if (item == null) {
      next.remove(foodId);
    } else {
      next[foodId] = item;
    }
    notifier.state = next;
  }

  /// Sets [item]'s cart quantity to exactly [quantity] (0 removes it).
  ///
  /// The new quantity is visible immediately through
  /// [effectiveCartItemsProvider]; Firestore is written in the background.
  /// Rapid taps on the same food collapse into the latest quantity. Returns
  /// false when the write failed, in which case the saved quantity is shown
  /// again.
  Future<bool> setItemQuantity(CartEntity item, int quantity) async {
    final userId = item.userId;
    final foodId = item.foodId;
    final target = quantity < 0 ? 0 : quantity;
    _setPending(userId, foodId, item.copyWith(quantity: target));
    if (!_syncingFoodIds.add(foodId)) {
      // A write for this food is already running; it picks up the new target.
      return true;
    }

    try {
      final repository = ref.read(cartRepositoryProvider);
      while (true) {
        final wanted =
            ref.read(pendingCartItemsProvider(userId))[foodId]?.quantity ??
                target;
        if (wanted <= 0) {
          await repository.removeItem(userId: userId, foodId: foodId);
        } else {
          final existing = await repository.getCartItem(
            userId: userId,
            foodId: foodId,
          );
          if (existing == null) {
            await repository.addToCart(item.copyWith(quantity: wanted));
          } else {
            await repository.updateQuantity(
              userId: userId,
              foodId: foodId,
              quantity: wanted,
            );
          }
        }
        final latest =
            ref.read(pendingCartItemsProvider(userId))[foodId]?.quantity;
        if (latest == null || latest == wanted) {
          break;
        }
      }
      _refreshCart(userId);
      await ref.read(cartItemsProvider(userId).future);
      return true;
    } catch (_) {
      _refreshCart(userId);
      return false;
    } finally {
      _syncingFoodIds.remove(foodId);
      _setPending(userId, foodId, null);
    }
  }

  /// Empties the cart because the customer confirmed switching restaurant,
  /// then adds [item]. Returns false (cart untouched or partly cleared, never
  /// silently replaced) when either step failed.
  Future<bool> replaceCartWith(CartEntity item) async {
    const policy = CartClearPolicy();
    if (!policy.canClear(CartClearReason.customerConfirmedRestaurantSwitch)) {
      return false;
    }
    final userId = item.userId;
    try {
      await ref.read(clearCartUseCaseProvider).call(userId);
      ref.read(pendingCartItemsProvider(userId).notifier).state = const {};
      _refreshCart(userId);
      await ref.read(cartItemsProvider(userId).future);
    } catch (_) {
      _refreshCart(userId);
      return false;
    }
    return setItemQuantity(item, item.quantity);
  }

  /// Deletes persisted cart items only after a successful order.
  ///
  /// Do not call this on navigation, app start, refresh, failed payment,
  /// or failed checkout.
  Future<void> clearCartAfterSuccessfulOrder(String userId) async {
    const policy = CartClearPolicy();
    if (!policy.canClear(CartClearReason.orderCompletedSuccessfully)) {
      return;
    }

    if (userId.isEmpty) {
      return;
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref.read(clearCartUseCaseProvider).call(userId);
      _refreshCart(userId);
    });
  }
}

final cartNotifierProvider =
    StateNotifierProvider<CartNotifier,
        AsyncValue<void>>(
  (ref) => CartNotifier(ref),
);