import 'entities/cart_entity.dart';

/// Per-food cart quantities. Each [foodId] is independent.
class CartQuantity {
  const CartQuantity._();

  static String _idOf(CartEntity item) {
    if (item.foodId.isNotEmpty) {
      return item.foodId;
    }
    return item.id;
  }

  /// Quantity for a single food. `0` means the item is not in the cart.
  static int forFood(List<CartEntity> items, String foodId) {
    if (foodId.isEmpty) {
      return 0;
    }

    for (final item in items) {
      if (_idOf(item) == foodId) {
        return item.quantity;
      }
    }
    return 0;
  }

  /// Index of cart quantity by foodId. One entry per food line.
  static Map<String, int> indexByFoodId(List<CartEntity> items) {
    final quantities = <String, int>{};
    for (final item in items) {
      final id = _idOf(item);
      if (id.isEmpty) {
        continue;
      }
      quantities[id] = item.quantity;
    }
    return quantities;
  }
}
