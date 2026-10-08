import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/presentation/providers/order_provider.dart';

class FixedCustomerOrdersNotifier extends CustomerOrdersNotifier {
  FixedCustomerOrdersNotifier(this.orders, {this.error, this.hasMore = false});

  final List<PlacedOrder> orders;
  final Object? error;
  final bool hasMore;

  @override
  Future<CustomerOrdersState> build(String arg) async {
    if (error != null) {
      throw error!;
    }
    return CustomerOrdersState(orders: orders, hasMore: hasMore);
  }
}
