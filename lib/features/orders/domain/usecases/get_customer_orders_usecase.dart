import '../entities/customer_orders_page.dart';
import '../entities/placed_order.dart';
import '../repositories/order_repository.dart';

class GetCustomerOrdersUseCase {
  const GetCustomerOrdersUseCase(this._repository);

  final OrderRepository _repository;

  static const int pageSize = 20;

  Future<List<PlacedOrder>> call(String userId) async {
    return (await page(userId)).orders;
  }

  Future<CustomerOrdersPage> page(
    String userId, {
    Object? startAfter,
    int limit = pageSize,
  }) {
    if (userId.isEmpty) {
      return Future.value(
        const CustomerOrdersPage(orders: [], hasMore: false),
      );
    }
    return _repository.getOrdersPage(
      userId: userId,
      limit: limit,
      startAfter: startAfter,
    );
  }
}
