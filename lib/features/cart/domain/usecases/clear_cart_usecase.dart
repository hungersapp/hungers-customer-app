import '../repositories/cart_repository.dart';

class ClearCartUseCase {
  final CartRepository repository;

  const ClearCartUseCase(this.repository);

  Future<void> call(String userId) async {
    await repository.clearCart(userId);
  }
}