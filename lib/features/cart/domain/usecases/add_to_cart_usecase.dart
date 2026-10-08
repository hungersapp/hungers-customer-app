import '../entities/cart_entity.dart';
import '../repositories/cart_repository.dart';

class AddToCartUseCase {
  final CartRepository repository;

  const AddToCartUseCase(this.repository);

  Future<void> call(CartEntity cart) async {
    // Check whether this food already exists in cart
    final existingItem = await repository.getCartItem(
      userId: cart.userId,
      foodId: cart.foodId,
    );

    if (existingItem != null) {
      // Increase quantity if item already exists
      await repository.updateQuantity(
        userId: cart.userId,
        foodId: cart.foodId,
        quantity: existingItem.quantity + 1,
      );
    } else {
      // Add new item
      await repository.addToCart(cart);
    }
  }
}