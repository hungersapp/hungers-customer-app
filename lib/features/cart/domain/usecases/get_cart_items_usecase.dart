import '../entities/cart_entity.dart';
import '../repositories/cart_repository.dart';

class GetCartItemsUseCase {
  final CartRepository repository;

  const GetCartItemsUseCase(this.repository);

  Future<List<CartEntity>> call(
    String userId,
  ) async {
    return await repository.getCartItems(userId);
  }
}