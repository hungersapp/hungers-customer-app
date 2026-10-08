import '../repositories/cart_repository.dart';

class GetCartTotalUseCase {
  final CartRepository repository;

  const GetCartTotalUseCase(this.repository);

  Future<double> call(String userId) async {
    return await repository.getCartTotal(userId);
  }
}