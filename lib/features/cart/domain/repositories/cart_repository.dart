import '../entities/cart_entity.dart';

abstract class CartRepository {
  /// Add a food item to cart
  Future<void> addToCart(CartEntity cart);

  /// Get all cart items of a user
  Future<List<CartEntity>> getCartItems(
    String userId,
  );

  /// Get a single cart item
  Future<CartEntity?> getCartItem({
    required String userId,
    required String foodId,
  });

  /// Update quantity of an item
  Future<void> updateQuantity({
    required String userId,
    required String foodId,
    required int quantity,
  });

  /// Remove one item from cart
  Future<void> removeItem({
    required String userId,
    required String foodId,
  });

  /// Clear complete cart
  Future<void> clearCart(
    String userId,
  );

  /// Number of items in cart
  Future<int> getCartItemCount(
    String userId,
  );

  /// Total payable amount
  Future<double> getCartTotal(
    String userId,
  );
}