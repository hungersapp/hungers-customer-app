import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart_model.dart';

class CartFirestoreDatasource {
  final FirebaseFirestore firestore;

  const CartFirestoreDatasource(this.firestore);

  CollectionReference<Map<String, dynamic>> _cartCollection(
    String userId,
  ) {
    return firestore
        .collection('carts')
        .doc(userId)
        .collection('items');
  }

  /// Add Item to Cart
  Future<void> addToCart(CartModel cart) async {
    await _cartCollection(cart.userId)
        .doc(cart.foodId)
        .set(cart.toMap());
  }

  /// Get Cart Items
  Future<List<CartModel>> getCartItems(
    String userId,
  ) async {
    final snapshot = await _cartCollection(userId)
        .orderBy(
          'createdAt',
          descending: true,
        )
        .get();

    return snapshot.docs
        .map(
          (doc) => CartModel.fromMap(
            doc.data(),
            doc.id,
          ),
        )
        .toList();
  }

  /// Get Single Cart Item
  Future<CartModel?> getCartItem(
    String userId,
    String foodId,
  ) async {
    final doc = await _cartCollection(userId)
        .doc(foodId)
        .get();

    if (!doc.exists) return null;

    return CartModel.fromMap(
      doc.data()!,
      doc.id,
    );
  }

  /// Update Quantity
  Future<void> updateQuantity({
    required String userId,
    required String foodId,
    required int quantity,
  }) async {
    await _cartCollection(userId)
        .doc(foodId)
        .update({
      'quantity': quantity,
    });
  }

  /// Remove Item
  Future<void> removeItem({
    required String userId,
    required String foodId,
  }) async {
    await _cartCollection(userId)
        .doc(foodId)
        .delete();
  }

  /// Clear Entire Cart
  Future<void> clearCart(
    String userId,
  ) async {
    final snapshot =
        await _cartCollection(userId).get();

    final batch = firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Returns the number of distinct cart line items.
  ///
  /// Not used by the current presentation layer; [cartItemCountProvider]
  /// derives the total quantity from cart items instead.
  Future<int> getCartItemCount(
    String userId,
  ) async {
    final items = await getCartItems(userId);
    return items.length;
  }

  /// Cart Total
  ///
  /// Calculated from [getCartItems] to avoid duplicating Firestore query logic.
  Future<double> getCartTotal(
    String userId,
  ) async {
    final items = await getCartItems(userId);

    return items.fold<double>(
      0,
      (total, item) => total + item.totalPrice,
    );
  }
}