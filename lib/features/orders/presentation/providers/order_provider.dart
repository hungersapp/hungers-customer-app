import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/phone_dialer_service.dart';
import '../../data/cashfree_payment_launcher.dart';
import '../../data/datasources/masked_call_functions_datasource.dart';
import '../../data/datasources/online_payment_functions_datasource.dart';
import '../../data/datasources/order_firestore_datasource.dart';
import '../../data/datasources/order_functions_datasource.dart';
import '../../data/datasources/pending_order_attempt_datasource.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/entities/placed_order.dart';
import '../../domain/online_payment_launcher.dart';
import '../../domain/order_masked_call_service.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/usecases/get_customer_orders_usecase.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/place_order_usecase.dart';
import '../../../foods/presentation/providers/food_provider.dart';
import '../../../restaurants/presentation/providers/restaurant_provider.dart';

final orderFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final orderDatasourceProvider = Provider<OrderFirestoreDatasource>(
  (ref) => OrderFirestoreDatasource(ref.watch(orderFirestoreProvider)),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepositoryImpl(ref.watch(orderDatasourceProvider)),
);

/// Callable bridge to the server-authoritative `placeOrder` Cloud Function.
/// Order creation now goes through this datasource (see
/// [placeOrderUseCaseProvider]); [orderRepositoryProvider]'s direct
/// Firestore `placeOrder` write stays in place, unused, as the rollback
/// path — it is still what backs order reads via [getOrderByIdUseCaseProvider]
/// and [getCustomerOrdersUseCaseProvider] below.
final orderFunctionsDatasourceProvider = Provider<OrderFunctionsDatasource>(
  (ref) => FirebaseOrderFunctionsDatasource(),
);

/// Cashfree online payment (UPI / credit card / debit card): the backend
/// creates the session for the server-computed amount and is the only
/// place a payment can be verified.
final onlinePaymentFunctionsDatasourceProvider =
    Provider<OnlinePaymentFunctionsDatasource>(
  (ref) => FirebaseOnlinePaymentFunctionsDatasource(),
);

/// Opens Cashfree's checkout. Overridden with a fake in tests.
final onlinePaymentLauncherProvider = Provider<OnlinePaymentLauncher>(
  (ref) => CashfreePaymentLauncher(),
);

final maskedCallFunctionsDatasourceProvider =
    Provider<MaskedCallFunctionsDatasource>(
  (ref) => FirebaseMaskedCallFunctionsDatasource(),
);

/// RETIRED for the current phase: masked calling (createMaskedCallSession) is
/// not used by any call button. Kept, unused, for a later phase.
final orderMaskedCallServiceProvider = Provider<OrderMaskedCallService>(
  (ref) => CloudOrderMaskedCallService(
    ref.watch(maskedCallFunctionsDatasourceProvider),
  ),
);

/// Call Rider: direct dial (tel:) of the assigned rider's number. No
/// masking, no relay, no telephony provider. The only call action here.
final phoneDialerServiceProvider = Provider<PhoneDialerService>(
  (ref) => const UrlLauncherPhoneDialerService(),
);

/// Backs the client-side idempotency key for order placement: reads/writes
/// only the `pendingOrderAttempt` field on the current user's own
/// `users/{uid}` document (see `PlaceOrderUseCase`).
final pendingOrderAttemptDatasourceProvider =
    Provider<PendingOrderAttemptDatasource>(
      (ref) => FirestorePendingOrderAttemptDatasource(),
    );

final placeOrderUseCaseProvider = Provider<PlaceOrderUseCase>(
  (ref) => PlaceOrderUseCase(
    ref.watch(orderFunctionsDatasourceProvider),
    restaurantRepository: ref.watch(restaurantRepositoryProvider),
    foodRepository: ref.watch(foodRepositoryProvider),
    getOrderByIdUseCase: ref.watch(getOrderByIdUseCaseProvider),
    pendingAttemptDatasource: ref.watch(pendingOrderAttemptDatasourceProvider),
  ),
);

final getCustomerOrdersUseCaseProvider = Provider<GetCustomerOrdersUseCase>(
  (ref) => GetCustomerOrdersUseCase(ref.watch(orderRepositoryProvider)),
);

final getOrderByIdUseCaseProvider = Provider<GetOrderByIdUseCase>(
  (ref) => GetOrderByIdUseCase(ref.watch(orderRepositoryProvider)),
);

class CustomerOrdersState {
  const CustomerOrdersState({
    required this.orders,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<PlacedOrder> orders;
  final bool hasMore;
  final bool isLoadingMore;

  CustomerOrdersState copyWith({
    List<PlacedOrder>? orders,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return CustomerOrdersState(
      orders: orders ?? this.orders,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class CustomerOrdersNotifier
    extends AutoDisposeFamilyAsyncNotifier<CustomerOrdersState, String> {
  Object? _cursor;

  @override
  Future<CustomerOrdersState> build(String userId) async {
    _cursor = null;
    final page = await ref.watch(getCustomerOrdersUseCaseProvider).page(userId);
    _cursor = page.cursor;
    return CustomerOrdersState(orders: page.orders, hasMore: page.hasMore);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(getCustomerOrdersUseCaseProvider).page(
            arg,
            startAfter: _cursor,
          );
      final seen = {for (final order in current.orders) order.id};
      final appended = [
        ...current.orders,
        for (final order in page.orders)
          if (seen.add(order.id)) order,
      ];
      _cursor = page.cursor;
      state = AsyncData(
        CustomerOrdersState(orders: appended, hasMore: page.hasMore),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

final customerOrdersProvider = AsyncNotifierProvider.autoDispose
    .family<CustomerOrdersNotifier, CustomerOrdersState, String>(
      CustomerOrdersNotifier.new,
    );

class OrderLookup {
  const OrderLookup({required this.userId, required this.orderId});

  final String userId;
  final String orderId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderLookup &&
          userId == other.userId &&
          orderId == other.orderId;

  @override
  int get hashCode => Object.hash(userId, orderId);
}

final orderDetailsProvider =
    FutureProvider.autoDispose.family<PlacedOrder, OrderLookup>((
  ref,
  lookup,
) {
  return ref
      .watch(getOrderByIdUseCaseProvider)
      .call(orderId: lookup.orderId, userId: lookup.userId);
});
