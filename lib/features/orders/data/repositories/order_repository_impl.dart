import '../../domain/entities/customer_orders_page.dart';
import '../../domain/entities/placed_order.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_firestore_datasource.dart';

class OrderRepositoryImpl implements OrderRepository {
  const OrderRepositoryImpl(this._datasource);

  final OrderFirestoreDatasource _datasource;

  @override
  Future<PlacedOrder> placeOrder(PlaceOrderRequest request) {
    return _datasource.createOrder(request);
  }

  @override
  Future<CustomerOrdersPage> getOrdersPage({
    required String userId,
    int limit = 20,
    Object? startAfter,
  }) {
    return _datasource.getOrdersPage(
      userId: userId,
      limit: limit,
      startAfter: startAfter,
    );
  }

  @override
  Future<List<PlacedOrder>> getOrdersByUserId(String userId) {
    return _datasource.getOrdersByUserId(userId);
  }

  @override
  Future<PlacedOrder> getOrderById({
    required String orderId,
    required String userId,
  }) {
    return _datasource.getOrderById(
      orderId: orderId,
      userId: userId,
    );
  }
}
