import '../repositories/cart_repository.dart';

class UpdateCartQuantityUseCase {
  final CartRepository repository;

  const UpdateCartQuantityUseCase(this.repository);

  Future<void> call({
    required String userId,
    required String foodId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      await repository.removeItem(
        userId: userId,
        foodId: foodId,
      );
      return;
    }

    await repository.updateQuantity(
      userId: userId,
      foodId: foodId,
      quantity: quantity,
    );
  }
}