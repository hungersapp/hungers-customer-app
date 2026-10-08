import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/orders/domain/entities/customer_orders_page.dart';
import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/domain/repositories/order_repository.dart';
import 'package:customer_app/features/orders/domain/usecases/get_customer_orders_usecase.dart';
import 'package:customer_app/features/orders/domain/usecases/get_order_by_id_usecase.dart';

class _MemoryOrderRepository implements OrderRepository {
  _MemoryOrderRepository(this.orders);

  final List<PlacedOrder> orders;

  @override
  Future<PlacedOrder> placeOrder(PlaceOrderRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<CustomerOrdersPage> getOrdersPage({
    required String userId,
    int limit = 20,
    Object? startAfter,
  }) async {
    final mine = orders.where((order) => order.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final start = startAfter is int ? startAfter : 0;
    final slice = mine.skip(start).take(limit).toList();
    return CustomerOrdersPage(
      orders: slice,
      cursor: start + slice.length,
      hasMore: start + slice.length < mine.length,
    );
  }

  @override
  Future<List<PlacedOrder>> getOrdersByUserId(String userId) async {
    return (await getOrdersPage(userId: userId)).orders;
  }

  @override
  Future<PlacedOrder> getOrderById({
    required String orderId,
    required String userId,
  }) async {
    final match = orders.where((order) => order.id == orderId);
    if (match.isEmpty || match.first.userId != userId) {
      throw StateError('Order not found');
    }
    return match.first;
  }
}

PlacedOrder _order({
  required String id,
  required String userId,
  OrderStatus status = OrderStatus.placed,
  DateTime? createdAt,
}) {
  return PlacedOrder(
    id: id,
    userId: userId,
    restaurantName: 'A2B Restaurant',
    grandTotal: 372.76,
    itemCount: 2,
    createdAt: createdAt ?? DateTime(2026, 8, 16),
    status: status,
    items: const [
      OrderLineItem(
        foodId: 'food-a',
        foodName: 'Mini Meals',
        quantity: 2,
        price: 160,
      ),
    ],
  );
}

void main() {
  test('customer orders include only the authenticated user', () async {
    final repository = _MemoryOrderRepository([
      _order(id: 'mine', userId: 'user-1'),
      _order(id: 'theirs', userId: 'user-2'),
    ]);

    final orders = await GetCustomerOrdersUseCase(repository).call('user-1');

    expect(orders.length, 1);
    expect(orders.first.id, 'mine');
    expect(orders.first.userId, 'user-1');
  });

  test('empty user id returns no orders', () async {
    final repository = _MemoryOrderRepository([
      _order(id: 'mine', userId: 'user-1'),
    ]);

    final orders = await GetCustomerOrdersUseCase(repository).call('');
    expect(orders, isEmpty);
  });

  test('first page is bounded at 20 and reports hasMore', () async {
    final repository = _MemoryOrderRepository([
      for (var i = 0; i < 21; i++)
        _order(
          id: 'o-$i',
          userId: 'user-1',
          createdAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        ),
    ]);

    final page = await GetCustomerOrdersUseCase(repository).page('user-1');
    expect(page.orders, hasLength(20));
    expect(page.hasMore, isTrue);
    expect(page.orders.first.id, 'o-20');
  });

  test('second page has no duplicates and can be the last page', () async {
    final repository = _MemoryOrderRepository([
      for (var i = 0; i < 21; i++)
        _order(
          id: 'o-$i',
          userId: 'user-1',
          createdAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        ),
    ]);
    final useCase = GetCustomerOrdersUseCase(repository);
    final first = await useCase.page('user-1');
    final second = await useCase.page('user-1', startAfter: first.cursor);

    expect(second.orders, hasLength(1));
    expect(second.hasMore, isFalse);
    expect(
      {...first.orders, ...second.orders}.map((o) => o.id).toSet(),
      hasLength(21),
    );
  });

  test('0 orders is an empty last page', () async {
    final page = await GetCustomerOrdersUseCase(
      _MemoryOrderRepository([]),
    ).page('user-1');
    expect(page.orders, isEmpty);
    expect(page.hasMore, isFalse);
  });

  test('1 order is a last page of one', () async {
    final page = await GetCustomerOrdersUseCase(
      _MemoryOrderRepository([_order(id: 'only', userId: 'user-1')]),
    ).page('user-1');
    expect(page.orders, hasLength(1));
    expect(page.hasMore, isFalse);
  });

  test('40+ orders paginate without duplicates', () async {
    final repository = _MemoryOrderRepository([
      for (var i = 0; i < 41; i++)
        _order(
          id: 'o-$i',
          userId: 'user-1',
          createdAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        ),
    ]);
    final useCase = GetCustomerOrdersUseCase(repository);
    final first = await useCase.page('user-1');
    final second = await useCase.page('user-1', startAfter: first.cursor);
    final third = await useCase.page('user-1', startAfter: second.cursor);

    expect(first.orders, hasLength(20));
    expect(first.hasMore, isTrue);
    expect(second.orders, hasLength(20));
    expect(second.hasMore, isTrue);
    expect(third.orders, hasLength(1));
    expect(third.hasMore, isFalse);
    final ids = [
      ...first.orders,
      ...second.orders,
      ...third.orders,
    ].map((order) => order.id).toSet();
    expect(ids, hasLength(41));
  });

  test('get order by id rejects another customer order', () async {
    final repository = _MemoryOrderRepository([
      _order(id: 'theirs', userId: 'user-2'),
    ]);

    expect(
      () => GetOrderByIdUseCase(
        repository,
      ).call(orderId: 'theirs', userId: 'user-1'),
      throwsStateError,
    );
  });

  test('get order by id returns the matching customer order', () async {
    final repository = _MemoryOrderRepository([
      _order(id: 'mine', userId: 'user-1'),
    ]);

    final order = await GetOrderByIdUseCase(
      repository,
    ).call(orderId: 'mine', userId: 'user-1');

    expect(order.id, 'mine');
    expect(order.restaurantName, 'A2B Restaurant');
  });
}
