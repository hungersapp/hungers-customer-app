import '../../domain/entities/cart_entity.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_firestore_datasource.dart';
import '../models/cart_model.dart';

class CartRepositoryImpl implements CartRepository {
  final CartFirestoreDatasource datasource;

  const CartRepositoryImpl(this.datasource);

  @override
  Future<void> addToCart(CartEntity cart) async {
    final model = CartModel.fromEntity(cart);
    await datasource.addToCart(model);
  }

  @override
  Future<List<CartEntity>> getCartItems(
    String userId,
  ) async {
    final items = await datasource.getCartItems(userId);

    return items
        .map((item) => item.toEntity())
        .toList();
  }

  @override
  Future<CartEntity?> getCartItem({
    required String userId,
    required String foodId,
  }) async {
    final item = await datasource.getCartItem(
      userId,
      foodId,
    );

    return item?.toEntity();
  }

  @override
  Future<void> updateQuantity({
    required String userId,
    required String foodId,
    required int quantity,
  }) async {
    await datasource.updateQuantity(
      userId: userId,
      foodId: foodId,
      quantity: quantity,
    );
  }

  @override
  Future<void> removeItem({
    required String userId,
    required String foodId,
  }) async {
    await datasource.removeItem(
      userId: userId,
      foodId: foodId,
    );
  }

  @override
  Future<void> clearCart(
    String userId,
  ) async {
    await datasource.clearCart(userId);
  }

  @override
  Future<int> getCartItemCount(
    String userId,
  ) async {
    return await datasource.getCartItemCount(userId);
  }

  @override
  Future<double> getCartTotal(
    String userId,
  ) async {
    return await datasource.getCartTotal(userId);
  }
}