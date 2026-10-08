import '../entities/placed_order.dart';
import '../repositories/order_repository.dart';

class GetOrderByIdUseCase {
  const GetOrderByIdUseCase(this._repository);

  final OrderRepository _repository;

  Future<PlacedOrder> call({
    required String orderId,
    required String userId,
  }) {
    if (userId.isEmpty) {
      throw StateError('User must be signed in to view an order.');
    }
    if (orderId.isEmpty) {
      throw StateError('Order id is required.');
    }
    return _repository.getOrderById(
      orderId: orderId,
      userId: userId,
    );
  }
}
