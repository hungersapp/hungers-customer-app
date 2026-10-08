import '../entities/customer_orders_page.dart';
import '../entities/placed_order.dart';

abstract class OrderRepository {
  Future<PlacedOrder> placeOrder(PlaceOrderRequest request);

  /// Latest [limit] orders for one authenticated customer.
  Future<CustomerOrdersPage> getOrdersPage({
    required String userId,
    int limit = 20,
    Object? startAfter,
  });

  /// Orders for one authenticated customer only.
  ///
  /// First page only (20). Prefer [getOrdersPage] for Load More.
  Future<List<PlacedOrder>> getOrdersByUserId(String userId);

  /// Single order. Must belong to [userId] or the call fails.
  Future<PlacedOrder> getOrderById({
    required String orderId,
    required String userId,
  });
}
