import '../repositories/cart_repository.dart';

class RemoveCartItemUseCase {
  final CartRepository repository;

  const RemoveCartItemUseCase(this.repository);

  Future<void> call({
    required String userId,
    required String foodId,
  }) async {
    await repository.removeItem(
      userId: userId,
      foodId: foodId,
    );
  }
}