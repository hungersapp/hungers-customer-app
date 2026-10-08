import 'placed_order.dart';

class CustomerOrdersPage {
  const CustomerOrdersPage({
    required this.orders,
    this.cursor,
    required this.hasMore,
  });

  final List<PlacedOrder> orders;

  /// Opaque Firestore cursor for the next page. Null on the last page.
  final Object? cursor;
  final bool hasMore;
}
