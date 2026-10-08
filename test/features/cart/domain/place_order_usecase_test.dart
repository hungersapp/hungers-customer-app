import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/cart/domain/entities/billing_summary.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/domain/entities/food_review_status.dart';
import 'package:customer_app/features/foods/domain/repositories/food_repository.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/orders/data/datasources/order_functions_datasource.dart';
import 'package:customer_app/features/orders/data/datasources/pending_order_attempt_datasource.dart';
import 'package:customer_app/features/orders/domain/entities/customer_orders_page.dart';
import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/domain/exceptions/place_order_functions_exception.dart';
import 'package:customer_app/features/orders/domain/repositories/order_repository.dart';
import 'package:customer_app/features/orders/domain/usecases/get_order_by_id_usecase.dart';
import 'package:customer_app/features/orders/domain/usecases/place_order_usecase.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/domain/repositories/restaurant_repository.dart';

/// Backs the existing Firestore read path (`getOrderById`) that the new
/// callable-based flow reuses as-is. Its `placeOrder` must never be called
/// by the new flow — that direct-write method stays in the codebase only
/// as the untouched rollback path, so tests below assert it stays at 0
/// calls rather than removing/mocking it away.
class _MemoryOrderRepository implements OrderRepository {
  _MemoryOrderRepository({this.ordersById = const {}});

  final Map<String, PlacedOrder> ordersById;

  int placeOrderCallCount = 0;
  int getOrderByIdCallCount = 0;
  String? lastGetOrderByIdOrderId;
  String? lastGetOrderByIdUserId;

  @override
  Future<PlacedOrder> placeOrder(PlaceOrderRequest request) async {
    placeOrderCallCount += 1;
    throw UnimplementedError(
      'The direct Firestore create path must not be called by the '
      'callable-based place-order flow.',
    );
  }

  @override
  Future<CustomerOrdersPage> getOrdersPage({
    required String userId,
    int limit = 20,
    Object? startAfter,
  }) async => const CustomerOrdersPage(orders: [], hasMore: false);

  @override
  Future<List<PlacedOrder>> getOrdersByUserId(String userId) async => [];

  @override
  Future<PlacedOrder> getOrderById({
    required String orderId,
    required String userId,
  }) async {
    getOrderByIdCallCount += 1;
    lastGetOrderByIdOrderId = orderId;
    lastGetOrderByIdUserId = userId;
    final order = ordersById[orderId];
    if (order == null) {
      throw StateError('Order not found');
    }
    return order;
  }
}

/// Fake for the Phase 2.1 callable bridge. Records exactly what
/// [PlaceOrderUseCase] sends it, and can be configured to either return a
/// result or throw (mirroring what [FirebaseOrderFunctionsDatasource]
/// would throw for a real callable failure).
///
/// [events], when provided, is a list shared with a
/// [_FakePendingOrderAttemptDatasource] so tests can assert *ordering*
/// between the two (e.g. "the key is persisted before the callable runs").
class _FakeOrderFunctionsDatasource implements OrderFunctionsDatasource {
  _FakeOrderFunctionsDatasource({this.result, this.error, this.events});

  PlaceOrderFunctionResult? result;
  Object? error;
  final List<String>? events;

  int callCount = 0;
  String? lastRestaurantId;
  List<PlaceOrderLineRequest>? lastItems;
  PlaceOrderDeliveryAddressRequest? lastDeliveryAddress;
  bool? lastOrderForOther;
  String? lastRecipientName;
  String? lastRecipientPhone;
  String? lastIdempotencyKey;
  String? lastPaymentMethod;

  @override
  Future<PlaceOrderFunctionResult> placeOrder({
    required String restaurantId,
    required List<PlaceOrderLineRequest> items,
    required PlaceOrderDeliveryAddressRequest deliveryAddress,
    bool orderForOther = false,
    String? recipientName,
    String? recipientPhone,
    String? idempotencyKey,
    String paymentMethod = 'pay_on_delivery',
  }) async {
    events?.add('placeOrder');
    callCount += 1;
    lastRestaurantId = restaurantId;
    lastItems = items;
    lastDeliveryAddress = deliveryAddress;
    lastOrderForOther = orderForOther;
    lastRecipientName = recipientName;
    lastRecipientPhone = recipientPhone;
    lastIdempotencyKey = idempotencyKey;
    lastPaymentMethod = paymentMethod;

    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return result!;
  }
}

/// Fake for the pending-attempt persistence layer (Phase 2.4). Scoped by
/// userId, exactly like the real Firestore implementation is scoped by
/// `users/{uid}` — so it also doubles as the account-isolation fixture.
class _FakePendingOrderAttemptDatasource
    implements PendingOrderAttemptDatasource {
  _FakePendingOrderAttemptDatasource({this.events});

  final List<String>? events;
  final Map<String, PendingOrderAttempt> _byUser = {};

  int saveCallCount = 0;
  int clearCallCount = 0;
  final List<PendingOrderAttempt> savedAttempts = [];

  void seed(String userId, PendingOrderAttempt attempt) {
    _byUser[userId] = attempt;
  }

  /// Test-only hook to simulate a stale attempt without needing to know
  /// [PlaceOrderUseCase]'s private fingerprint algorithm: replace a
  /// previously-saved attempt's timestamp while keeping its key and
  /// fingerprint, exactly as if 30+ minutes had really passed.
  void ageStoredAttempt(String userId, DateTime createdAt) {
    final current = _byUser[userId];
    if (current == null) {
      return;
    }
    _byUser[userId] = PendingOrderAttempt(
      idempotencyKey: current.idempotencyKey,
      fingerprint: current.fingerprint,
      createdAt: createdAt,
    );
  }

  PendingOrderAttempt? storedFor(String userId) => _byUser[userId];

  @override
  Future<PendingOrderAttempt?> getPendingAttempt(String userId) async {
    return _byUser[userId];
  }

  @override
  Future<void> savePendingAttempt({
    required String userId,
    required PendingOrderAttempt attempt,
  }) async {
    events?.add('save');
    saveCallCount += 1;
    savedAttempts.add(attempt);
    _byUser[userId] = attempt;
  }

  @override
  Future<void> clearPendingAttempt(String userId) async {
    events?.add('clear');
    clearCallCount += 1;
    _byUser.remove(userId);
  }
}

PlaceOrderFunctionResult _functionResult({
  String orderId = 'order-1',
  bool replayed = false,
}) {
  return PlaceOrderFunctionResult(
    orderId: orderId,
    replayed: replayed,
    itemTotal: 320,
    deliveryFee: 30,
    platformFee: 5,
    gstAmount: 17.76,
    grandTotal: 372.76,
    distanceKm: 1.2,
  );
}

PlacedOrder _placedOrder({
  String id = 'order-1',
  String userId = 'user-1',
  String restaurantName = 'A2B',
  double grandTotal = 372.76,
  int itemCount = 2,
}) {
  return PlacedOrder(
    id: id,
    userId: userId,
    restaurantName: restaurantName,
    grandTotal: grandTotal,
    itemCount: itemCount,
    createdAt: DateTime(2026, 8, 16),
  );
}

class _ListableRestaurantRepository implements RestaurantRepository {
  _ListableRestaurantRepository({this.restaurant});

  final RestaurantEntity? restaurant;

  @override
  Future<List<RestaurantEntity>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  }) async => restaurant == null ? [] : [restaurant!];

  @override
  Future<List<RestaurantEntity>> getAllRestaurants() async =>
      restaurant == null ? [] : [restaurant!];

  @override
  Future<List<RestaurantEntity>> getFeaturedRestaurants() async => [];

  @override
  Future<List<RestaurantEntity>> getPopularRestaurants() async => [];

  @override
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async {
    if (restaurant == null || restaurant!.id != restaurantId) {
      return null;
    }
    return restaurant;
  }

  @override
  Future<List<RestaurantEntity>> searchRestaurants(String keyword) async => [];

  @override
  Future<List<RestaurantEntity>> getNearbyRestaurants() async => [];
}

/// Serves multiple restaurants by id — only needed for the fingerprint test
/// that switches restaurants between two calls.
class _MultiRestaurantRepository implements RestaurantRepository {
  _MultiRestaurantRepository(this._byId);

  final Map<String, RestaurantEntity> _byId;

  @override
  Future<List<RestaurantEntity>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  }) async => _byId.values.toList();

  @override
  Future<List<RestaurantEntity>> getAllRestaurants() async =>
      _byId.values.toList();

  @override
  Future<List<RestaurantEntity>> getFeaturedRestaurants() async => [];

  @override
  Future<List<RestaurantEntity>> getPopularRestaurants() async => [];

  @override
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async =>
      _byId[restaurantId];

  @override
  Future<List<RestaurantEntity>> searchRestaurants(String keyword) async => [];

  @override
  Future<List<RestaurantEntity>> getNearbyRestaurants() async => [];
}

class _MemoryFoodRepository implements FoodRepository {
  _MemoryFoodRepository(this.documents);

  final Map<String, FoodEntity?> documents;

  @override
  Future<List<FoodEntity>> getFoodsByRestaurant(String restaurantId) async =>
      [];

  @override
  Future<List<FoodEntity>> getRecommendedFoods(String restaurantId) async => [];

  @override
  Future<List<FoodEntity>> getFoodsByCategory({
    required String restaurantId,
    required String category,
  }) async => [];

  @override
  Future<List<FoodEntity>> getCustomerFoodsByCategoryName(
    String categoryName, {
    List<String> restaurantIds = const [],
    int limit = 30,
    String? startAfterName,
  }) async => [];

  @override
  Future<FoodEntity> getFoodById(String foodId) {
    final food = documents[foodId];
    if (food == null || !food.isCustomerVisibleFood) {
      throw Exception('Food not found');
    }
    return Future.value(food);
  }

  @override
  Future<FoodEntity?> getFoodDocumentById(String foodId) async {
    return documents[foodId];
  }
}

RestaurantEntity _listableRestaurant() {
  final now = DateTime(2026, 1, 1);
  return RestaurantEntity(
    id: 'a2b',
    name: 'A2B',
    description: '',
    logoUrl: '',
    coverImageUrl: '',
    address: '',
    latitude: 0,
    longitude: 0,
    rating: 0,
    totalRatings: 0,
    deliveryTime: 30,
    deliveryFee: 30,
    minimumOrderAmount: 0,
    isPureVeg: false,
    isOpen: true,
    isFeatured: false,
    openingTime: '09:00',
    closingTime: '22:00',
    cuisines: const [],
    isCustomerVisible: true,
    isActive: true,
    approvedFoodCount: 2,
    onboardingStatus: 'approved',
    isVerified: true,
    createdAt: now,
    updatedAt: now,
  );
}

RestaurantEntity _secondRestaurant() {
  final now = DateTime(2026, 1, 1);
  return RestaurantEntity(
    id: 'b3c',
    name: 'Saravana Bhavan',
    description: '',
    logoUrl: '',
    coverImageUrl: '',
    address: '',
    latitude: 0,
    longitude: 0,
    rating: 0,
    totalRatings: 0,
    deliveryTime: 30,
    deliveryFee: 30,
    minimumOrderAmount: 0,
    isPureVeg: true,
    isOpen: true,
    isFeatured: false,
    openingTime: '09:00',
    closingTime: '22:00',
    cuisines: const [],
    isCustomerVisible: true,
    isActive: true,
    approvedFoodCount: 2,
    onboardingStatus: 'approved',
    isVerified: true,
    createdAt: now,
    updatedAt: now,
  );
}

FoodEntity _foodDoc({
  required String id,
  required bool isAvailable,
  FoodReviewStatus status = FoodReviewStatus.approved,
  String restaurantId = 'a2b',
}) {
  return FoodEntity(
    id: id,
    restaurantId: restaurantId,
    name: 'Mini Meals',
    description: '',
    price: 160,
    imageUrl: '',
    category: 'Meals',
    isVeg: true,
    isAvailable: isAvailable,
    isRecommended: false,
    rating: 0,
    status: status,
  );
}

CartEntity _item({String foodId = 'food-a'}) {
  return CartEntity(
    id: foodId,
    userId: 'user-1',
    restaurantId: 'a2b',
    restaurantName: 'A2B',
    foodId: foodId,
    foodName: 'Mini Meals',
    foodImage: '',
    price: 160,
    quantity: 2,
    isVeg: true,
    isAvailable: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

BillingSummary _summary() {
  return const BillingSummary(
    subtotal: 320,
    deliveryFee: 30,
    platformFee: 5,
    discount: 0,
    taxableAmount: 355,
    cgstAmount: 8.88,
    sgstAmount: 8.88,
    igstAmount: 0,
    gstAmount: 17.76,
    gstRate: 0.05,
    isIntraState: true,
    grandTotal: 372.76,
  );
}

PlaceOrderUseCase _useCase(
  _FakeOrderFunctionsDatasource functionsDatasource,
  _MemoryOrderRepository orderRepository, {
  RestaurantEntity? restaurant,
  FoodRepository? foods,
  RestaurantRepository? restaurantRepository,
  PendingOrderAttemptDatasource? pendingAttemptDatasource,
}) {
  return PlaceOrderUseCase(
    functionsDatasource,
    restaurantRepository:
        restaurantRepository ??
        _ListableRestaurantRepository(
          restaurant: restaurant ?? _listableRestaurant(),
        ),
    foodRepository:
        foods ??
        _MemoryFoodRepository({
          'food-a': _foodDoc(id: 'food-a', isAvailable: true),
        }),
    getOrderByIdUseCase: GetOrderByIdUseCase(orderRepository),
    pendingAttemptDatasource:
        pendingAttemptDatasource ?? _FakePendingOrderAttemptDatasource(),
  );
}

UserLocation _completeLocation() {
  return UserLocation(
    latitude: 10.423,
    longitude: 79.319,
    city: 'Pattukkottai',
    state: 'Tamil Nadu',
    updatedAt: DateTime(2026, 9, 1),
    pincode: '614601',
    doorNumber: '12',
    street: 'Main Road',
    area: 'Anna Nagar',
  );
}

PlaceOrderRequest _request({
  List<CartEntity>? items,
  BillingSummary? summary,
  UserLocation? location,
}) {
  return PlaceOrderRequest(
    userId: 'user-1',
    items: items ?? [_item()],
    summary: summary ?? _summary(),
    paymentMethod: OrderPaymentMethod.payOnDelivery,
    deliveryLocation: location ?? _completeLocation(),
  );
}

void main() {
  test(
    'place order calls the callable then reads back the complete order',
    () async {
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      final useCase = _useCase(functionsDatasource, orderRepository);

      final order = await useCase.call(_request());

      expect(order.id, 'order-1');
      expect(functionsDatasource.callCount, 1);
      expect(
        orderRepository.placeOrderCallCount,
        0,
        reason: 'the direct Firestore create path must not be used',
      );
      expect(orderRepository.getOrderByIdCallCount, 1);
      expect(orderRepository.lastGetOrderByIdOrderId, 'order-1');
      expect(orderRepository.lastGetOrderByIdUserId, 'user-1');
      expect(functionsDatasource.lastRestaurantId, 'a2b');
      expect(functionsDatasource.lastItems, hasLength(1));
      expect(functionsDatasource.lastItems!.single.foodId, 'food-a');
      expect(functionsDatasource.lastItems!.single.quantity, 2);
    },
  );

  test(
    'place order sends only foodId and quantity per line, never price',
    () async {
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      final useCase = _useCase(functionsDatasource, orderRepository);

      await useCase.call(_request());

      final line = functionsDatasource.lastItems!.single;
      expect(line, isA<PlaceOrderLineRequest>());
      expect(line.toJson().keys, containsAll(['foodId', 'quantity']));
      expect(line.toJson().keys, hasLength(2));
    },
  );

  test('replayed placement still reads back the order the same way, with no '
      'special branch', () async {
    final functionsDatasource = _FakeOrderFunctionsDatasource(
      result: _functionResult(replayed: true),
    );
    final orderRepository = _MemoryOrderRepository(
      ordersById: {'order-1': _placedOrder()},
    );
    final useCase = _useCase(functionsDatasource, orderRepository);

    final order = await useCase.call(_request());

    expect(order.id, 'order-1');
    expect(orderRepository.getOrderByIdCallCount, 1);
    expect(orderRepository.lastGetOrderByIdOrderId, 'order-1');
    expect(orderRepository.lastGetOrderByIdUserId, 'user-1');
  });

  test(
    'callable failure propagates the existing typed exception unchanged',
    () async {
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        error: const PlaceOrderRestaurantNotAcceptingException(),
      );
      final orderRepository = _MemoryOrderRepository();
      final useCase = _useCase(functionsDatasource, orderRepository);

      await expectLater(
        () => useCase.call(_request()),
        throwsA(isA<PlaceOrderRestaurantNotAcceptingException>()),
      );
      expect(
        orderRepository.getOrderByIdCallCount,
        0,
        reason: 'a failed placement must never attempt a follow-up read',
      );
    },
  );

  test('2.6-I: a malformed-callable-response exception from the datasource '
      'propagates without ever attempting a follow-up read', () async {
    // PlaceOrderServerException is exactly what
    // FirebaseOrderFunctionsDatasource._readResult throws for every
    // malformed-but-successful raw response case (null result, non-map
    // result, missing orderId, empty/invalid orderId) — see
    // order_functions_datasource_test.dart for those cases directly. At
    // this layer, only the propagation contract matters: no false
    // success, no getOrderById call with whatever orderId might
    // otherwise have been guessed at.
    final functionsDatasource = _FakeOrderFunctionsDatasource(
      error: const PlaceOrderServerException(),
    );
    final orderRepository = _MemoryOrderRepository();
    final useCase = _useCase(functionsDatasource, orderRepository);

    await expectLater(
      () => useCase.call(_request()),
      throwsA(isA<PlaceOrderServerException>()),
    );
    expect(
      orderRepository.getOrderByIdCallCount,
      0,
      reason:
          'a malformed/unrecognized response must never be treated as '
          'success, so no follow-up read may happen',
    );
  });

  test('a successful placement whose follow-up read fails surfaces a clear '
      'error without losing the order id', () async {
    final functionsDatasource = _FakeOrderFunctionsDatasource(
      result: _functionResult(),
    );
    // No 'order-1' entry: getOrderById will throw, simulating a follow-up
    // read failure after the order was already created server-side.
    final orderRepository = _MemoryOrderRepository();
    final useCase = _useCase(functionsDatasource, orderRepository);

    await expectLater(
      () => useCase.call(_request()),
      throwsA(
        isA<PlaceOrderCreatedButUnreadableException>().having(
          (e) => e.orderId,
          'orderId',
          'order-1',
        ),
      ),
    );
    expect(
      functionsDatasource.callCount,
      1,
      reason: 'the order really was created before the read failed',
    );
  });

  test('place order fails when the cart is empty', () async {
    final functionsDatasource = _FakeOrderFunctionsDatasource();
    final orderRepository = _MemoryOrderRepository();
    final useCase = _useCase(functionsDatasource, orderRepository);

    expect(
      () => useCase.call(
        _request(items: const [], summary: BillingSummary.empty()),
      ),
      throwsStateError,
    );
    expect(functionsDatasource.callCount, 0);
  });

  test('place order fails without a complete delivery address', () async {
    final functionsDatasource = _FakeOrderFunctionsDatasource();
    final orderRepository = _MemoryOrderRepository();
    final useCase = _useCase(functionsDatasource, orderRepository);

    expect(
      () => useCase.call(
        PlaceOrderRequest(
          userId: 'user-1',
          items: [_item()],
          summary: _summary(),
          paymentMethod: OrderPaymentMethod.payOnDelivery,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('complete delivery address'),
        ),
      ),
    );
    expect(functionsDatasource.callCount, 0);
  });

  test('inactive restaurant blocks NEW orders', () async {
    final functionsDatasource = _FakeOrderFunctionsDatasource();
    final orderRepository = _MemoryOrderRepository();
    final useCase = PlaceOrderUseCase(
      functionsDatasource,
      restaurantRepository: _ListableRestaurantRepository(restaurant: null),
      foodRepository: _MemoryFoodRepository({
        'food-a': _foodDoc(id: 'food-a', isAvailable: true),
      }),
      getOrderByIdUseCase: GetOrderByIdUseCase(orderRepository),
      pendingAttemptDatasource: _FakePendingOrderAttemptDatasource(),
    );

    expect(() => useCase.call(_request()), throwsStateError);
    expect(functionsDatasource.callCount, 0);
  });

  test('stale cart with unavailable food cannot place order', () async {
    final functionsDatasource = _FakeOrderFunctionsDatasource();
    final orderRepository = _MemoryOrderRepository();
    final useCase = _useCase(
      functionsDatasource,
      orderRepository,
      foods: _MemoryFoodRepository({
        'food-a': _foodDoc(id: 'food-a', isAvailable: false),
      }),
    );

    expect(
      () => useCase.call(_request()),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('no longer available'),
        ),
      ),
    );
    expect(functionsDatasource.callCount, 0);
  });

  test('missing isAvailable defaults remain orderable when approved', () async {
    final functionsDatasource = _FakeOrderFunctionsDatasource(
      result: _functionResult(),
    );
    final orderRepository = _MemoryOrderRepository(
      ordersById: {'order-1': _placedOrder()},
    );
    final useCase = _useCase(
      functionsDatasource,
      orderRepository,
      foods: _MemoryFoodRepository({
        'food-a': _foodDoc(id: 'food-a', isAvailable: true),
      }),
    );

    final order = await useCase.call(_request());
    expect(order.id, 'order-1');
    expect(functionsDatasource.callCount, 1);
  });

  test(
    'deliver to me strips recipient fields before calling the callable',
    () async {
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      final useCase = _useCase(functionsDatasource, orderRepository);

      await useCase.call(
        PlaceOrderRequest(
          userId: 'user-1',
          items: [_item()],
          summary: _summary(),
          paymentMethod: OrderPaymentMethod.payOnDelivery,
          deliveryLocation: _completeLocation(),
          orderForOther: false,
          recipientName: 'Should Be Ignored',
          recipientPhone: '9876543210',
        ),
      );

      expect(functionsDatasource.lastOrderForOther, isFalse);
      expect(functionsDatasource.lastRecipientName, isNull);
      expect(functionsDatasource.lastRecipientPhone, isNull);
      expect(functionsDatasource.lastDeliveryAddress?.latitude, 10.423);
    },
  );

  test('order for others sends normalized recipient and the recipient '
      'address to the callable', () async {
    final functionsDatasource = _FakeOrderFunctionsDatasource(
      result: _functionResult(),
    );
    final orderRepository = _MemoryOrderRepository(
      ordersById: {'order-1': _placedOrder()},
    );
    final useCase = _useCase(functionsDatasource, orderRepository);
    final recipientPin = UserLocation(
      latitude: 10.45,
      longitude: 79.35,
      city: 'Chennai',
      state: 'TN',
      updatedAt: DateTime(2026, 9, 1),
      pincode: '600001',
      doorNumber: '9',
      street: 'Beach Road',
      area: 'Besant Nagar',
    );

    await useCase.call(
      PlaceOrderRequest(
        userId: 'user-1',
        items: [_item()],
        summary: _summary(),
        paymentMethod: OrderPaymentMethod.payOnDelivery,
        deliveryLocation: recipientPin,
        orderForOther: true,
        recipientName: ' Priya ',
        recipientPhone: '9876543210',
      ),
    );

    expect(functionsDatasource.lastOrderForOther, isTrue);
    expect(functionsDatasource.lastRecipientName, 'Priya');
    expect(functionsDatasource.lastRecipientPhone, '9876543210');
    expect(functionsDatasource.lastDeliveryAddress?.latitude, 10.45);
    expect(functionsDatasource.lastDeliveryAddress?.longitude, 79.35);
    // The customer's own identity still flows only through the follow-up
    // read, not through the callable payload (the server derives userId
    // from the auth token, never from client input).
    expect(orderRepository.lastGetOrderByIdUserId, 'user-1');
  });

  test('order for others requires recipient name', () async {
    final functionsDatasource = _FakeOrderFunctionsDatasource();
    final orderRepository = _MemoryOrderRepository();
    final useCase = _useCase(functionsDatasource, orderRepository);

    expect(
      () => useCase.call(
        PlaceOrderRequest(
          userId: 'user-1',
          items: [_item()],
          summary: _summary(),
          paymentMethod: OrderPaymentMethod.payOnDelivery,
          deliveryLocation: _completeLocation(),
          orderForOther: true,
          recipientName: '  ',
          recipientPhone: '9876543210',
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Recipient name'),
        ),
      ),
    );
    expect(functionsDatasource.callCount, 0);
  });

  test('order for others requires valid Indian recipient phone', () async {
    final functionsDatasource = _FakeOrderFunctionsDatasource();
    final orderRepository = _MemoryOrderRepository();
    final useCase = _useCase(functionsDatasource, orderRepository);

    expect(
      () => useCase.call(
        PlaceOrderRequest(
          userId: 'user-1',
          items: [_item()],
          summary: _summary(),
          paymentMethod: OrderPaymentMethod.payOnDelivery,
          deliveryLocation: _completeLocation(),
          orderForOther: true,
          recipientName: 'Priya',
          recipientPhone: '12345',
        ),
      ),
      throwsStateError,
    );
    expect(functionsDatasource.callCount, 0);
  });

  test(
    'order for others requires complete recipient address with GPS',
    () async {
      final functionsDatasource = _FakeOrderFunctionsDatasource();
      final orderRepository = _MemoryOrderRepository();
      final useCase = _useCase(functionsDatasource, orderRepository);

      expect(
        () => useCase.call(
          PlaceOrderRequest(
            userId: 'user-1',
            items: [_item()],
            summary: _summary(),
            paymentMethod: OrderPaymentMethod.payOnDelivery,
            deliveryLocation: UserLocation(
              latitude: 10.4,
              longitude: 79.3,
              city: 'Chennai',
              state: 'TN',
              updatedAt: DateTime(2026, 9, 1),
            ),
            orderForOther: true,
            recipientName: 'Priya',
            recipientPhone: '9876543210',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('complete delivery address'),
          ),
        ),
      );
      expect(functionsDatasource.callCount, 0);
    },
  );

  test('order for others rejects missing confirmed GPS coordinates', () async {
    final functionsDatasource = _FakeOrderFunctionsDatasource();
    final orderRepository = _MemoryOrderRepository();
    final useCase = _useCase(functionsDatasource, orderRepository);

    expect(
      () => useCase.call(
        PlaceOrderRequest(
          userId: 'user-1',
          items: [_item()],
          summary: _summary(),
          paymentMethod: OrderPaymentMethod.payOnDelivery,
          deliveryLocation: UserLocation(
            latitude: 999,
            longitude: 999,
            city: 'Chennai',
            state: 'TN',
            updatedAt: DateTime(2026, 9, 1),
            pincode: '600001',
            doorNumber: '9',
            street: 'Beach Road',
          ),
          orderForOther: true,
          recipientName: 'Priya',
          recipientPhone: '9876543210',
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('complete delivery address'),
        ),
      ),
    );
    expect(functionsDatasource.callCount, 0);
  });

  group('idempotency (Phase 2.4)', () {
    test('a fresh checkout attempt generates a non-empty key within the '
        "server's 128-character limit", () async {
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      final useCase = _useCase(functionsDatasource, orderRepository);

      await useCase.call(_request());

      final key = functionsDatasource.lastIdempotencyKey;
      expect(key, isNotNull);
      expect(key!.isNotEmpty, isTrue);
      expect(key.length, lessThanOrEqualTo(128));
    });

    test('the key is persisted before the callable is invoked', () async {
      final events = <String>[];
      final pending = _FakePendingOrderAttemptDatasource(events: events);
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
        events: events,
      );
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      final useCase = _useCase(
        functionsDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );

      await useCase.call(_request());

      expect(
        events.indexOf('save'),
        lessThan(events.indexOf('placeOrder')),
        reason: 'the key must be saved before the callable is invoked',
      );
    });

    test('the callable receives exactly the key that was persisted', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      final useCase = _useCase(
        functionsDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );

      await useCase.call(_request());

      expect(pending.saveCallCount, 1);
      expect(
        functionsDatasource.lastIdempotencyKey,
        pending.savedAttempts.single.idempotencyKey,
      );
    });

    test('an ambiguous (non-business) callable failure preserves the '
        'pending key', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        error: Exception('simulated network timeout'),
      );
      final orderRepository = _MemoryOrderRepository();
      final useCase = _useCase(
        functionsDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );

      await expectLater(() => useCase.call(_request()), throwsException);

      expect(pending.clearCallCount, 0);
      expect(pending.storedFor('user-1'), isNotNull);
    });

    test('retrying the same order context after an ambiguous failure '
        'reuses the identical key', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );

      final failingDatasource = _FakeOrderFunctionsDatasource(
        error: Exception('simulated network timeout'),
      );
      final failingUseCase = _useCase(
        failingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await expectLater(() => failingUseCase.call(_request()), throwsException);
      final firstKey = failingDatasource.lastIdempotencyKey;

      final succeedingDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final retryUseCase = _useCase(
        succeedingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await retryUseCase.call(_request());

      expect(succeedingDatasource.lastIdempotencyKey, firstKey);
      expect(
        pending.saveCallCount,
        1,
        reason: 'the retry must reuse the persisted key, not save a new one',
      );
    });

    test('a successful fresh placement clears the pending key', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(replayed: false),
      );
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      final useCase = _useCase(
        functionsDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );

      await useCase.call(_request());

      expect(pending.clearCallCount, 1);
      expect(pending.storedFor('user-1'), isNull);
    });

    test('a successful replay also clears the pending key, with no special '
        'branch', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(replayed: true),
      );
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      final useCase = _useCase(
        functionsDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );

      await useCase.call(_request());

      expect(pending.clearCallCount, 1);
      expect(pending.storedFor('user-1'), isNull);
    });

    test('a definitive business failure clears the key so the next attempt '
        'gets a fresh one', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final failingDatasource = _FakeOrderFunctionsDatasource(
        error: const PlaceOrderRestaurantNotAcceptingException(),
      );
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      final failingUseCase = _useCase(
        failingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );

      await expectLater(
        () => failingUseCase.call(_request()),
        throwsA(isA<PlaceOrderRestaurantNotAcceptingException>()),
      );
      expect(pending.clearCallCount, 1);
      expect(pending.storedFor('user-1'), isNull);
      final firstKey = failingDatasource.lastIdempotencyKey;

      final succeedingDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final retryUseCase = _useCase(
        succeedingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await retryUseCase.call(_request());

      expect(
        succeedingDatasource.lastIdempotencyKey,
        isNot(firstKey),
        reason: 'a clean failure must not be followed by key reuse',
      );
    });

    test(
      'changing the cart after an ambiguous failure generates a new key',
      () async {
        final pending = _FakePendingOrderAttemptDatasource();
        final foods = _MemoryFoodRepository({
          'food-a': _foodDoc(id: 'food-a', isAvailable: true),
          'food-b': _foodDoc(id: 'food-b', isAvailable: true),
        });
        final orderRepository = _MemoryOrderRepository(
          ordersById: {'order-1': _placedOrder()},
        );

        final failingDatasource = _FakeOrderFunctionsDatasource(
          error: Exception('simulated network timeout'),
        );
        final failingUseCase = _useCase(
          failingDatasource,
          orderRepository,
          pendingAttemptDatasource: pending,
          foods: foods,
        );
        await expectLater(
          () => failingUseCase.call(_request(items: [_item(foodId: 'food-a')])),
          throwsException,
        );
        final firstKey = failingDatasource.lastIdempotencyKey;

        final succeedingDatasource = _FakeOrderFunctionsDatasource(
          result: _functionResult(),
        );
        final retryUseCase = _useCase(
          succeedingDatasource,
          orderRepository,
          pendingAttemptDatasource: pending,
          foods: foods,
        );
        // A genuinely different cart (different food entirely).
        await retryUseCase.call(_request(items: [_item(foodId: 'food-b')]));

        expect(succeedingDatasource.lastIdempotencyKey, isNot(firstKey));
        expect(
          pending.saveCallCount,
          2,
          reason: 'the mismatched cart must save a fresh attempt, not reuse',
        );
      },
    );

    test('changing the restaurant after an ambiguous failure generates a '
        'new key', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final restaurants = _MultiRestaurantRepository({
        'a2b': _listableRestaurant(),
        'b3c': _secondRestaurant(),
      });
      final foods = _MemoryFoodRepository({
        'food-a': _foodDoc(
          id: 'food-a',
          isAvailable: true,
          restaurantId: 'a2b',
        ),
        'food-c': _foodDoc(
          id: 'food-c',
          isAvailable: true,
          restaurantId: 'b3c',
        ),
      });
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );

      CartEntity cartFor(String restaurantId, String foodId) => CartEntity(
        id: foodId,
        userId: 'user-1',
        restaurantId: restaurantId,
        restaurantName: restaurantId,
        foodId: foodId,
        foodName: 'Meal',
        foodImage: '',
        price: 160,
        quantity: 2,
        isVeg: true,
        isAvailable: true,
        createdAt: DateTime(2026, 1, 1),
      );

      final failingDatasource = _FakeOrderFunctionsDatasource(
        error: Exception('simulated network timeout'),
      );
      final failingUseCase = _useCase(
        failingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
        restaurantRepository: restaurants,
        foods: foods,
      );
      await expectLater(
        () => failingUseCase.call(_request(items: [cartFor('a2b', 'food-a')])),
        throwsException,
      );
      final firstKey = failingDatasource.lastIdempotencyKey;

      final succeedingDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final retryUseCase = _useCase(
        succeedingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
        restaurantRepository: restaurants,
        foods: foods,
      );
      await retryUseCase.call(_request(items: [cartFor('b3c', 'food-c')]));

      expect(succeedingDatasource.lastIdempotencyKey, isNot(firstKey));
    });

    test('a changed order-for-other recipient after an ambiguous failure '
        'generates a new key', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );

      PlaceOrderRequest requestFor(String phone) => PlaceOrderRequest(
        userId: 'user-1',
        items: [_item()],
        summary: _summary(),
        paymentMethod: OrderPaymentMethod.payOnDelivery,
        deliveryLocation: _completeLocation(),
        orderForOther: true,
        recipientName: 'Priya',
        recipientPhone: phone,
      );

      final failingDatasource = _FakeOrderFunctionsDatasource(
        error: Exception('simulated network timeout'),
      );
      final failingUseCase = _useCase(
        failingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await expectLater(
        () => failingUseCase.call(requestFor('9876543210')),
        throwsException,
      );
      final firstKey = failingDatasource.lastIdempotencyKey;

      final succeedingDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final retryUseCase = _useCase(
        succeedingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      // A different recipient phone entirely.
      await retryUseCase.call(requestFor('9123456780'));

      expect(succeedingDatasource.lastIdempotencyKey, isNot(firstKey));
    });

    test('a changed delivery address after an ambiguous failure generates '
        'a new key', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      final otherLocation = UserLocation(
        latitude: 11.0,
        longitude: 78.0,
        city: 'Trichy',
        state: 'Tamil Nadu',
        updatedAt: DateTime(2026, 9, 1),
        pincode: '620001',
        doorNumber: '5',
        street: 'Cauvery Street',
      );

      final failingDatasource = _FakeOrderFunctionsDatasource(
        error: Exception('simulated network timeout'),
      );
      final failingUseCase = _useCase(
        failingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await expectLater(
        () => failingUseCase.call(_request(location: _completeLocation())),
        throwsException,
      );
      final firstKey = failingDatasource.lastIdempotencyKey;

      final succeedingDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final retryUseCase = _useCase(
        succeedingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await retryUseCase.call(_request(location: otherLocation));

      expect(succeedingDatasource.lastIdempotencyKey, isNot(firstKey));
    });

    test('changing only the address area after an ambiguous failure '
        'generates a new key', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      // Identical to _completeLocation() in every field except `area` -
      // door number, street, pincode, and coordinates are unchanged.
      final sameAddressDifferentArea = UserLocation(
        latitude: 10.423,
        longitude: 79.319,
        city: 'Pattukkottai',
        state: 'Tamil Nadu',
        updatedAt: DateTime(2026, 9, 1),
        pincode: '614601',
        doorNumber: '12',
        street: 'Main Road',
        area: 'Bazaar',
      );

      final failingDatasource = _FakeOrderFunctionsDatasource(
        error: Exception('simulated network timeout'),
      );
      final failingUseCase = _useCase(
        failingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await expectLater(
        () => failingUseCase.call(_request(location: _completeLocation())),
        throwsException,
      );
      final firstKey = failingDatasource.lastIdempotencyKey;

      final succeedingDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final retryUseCase = _useCase(
        succeedingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await retryUseCase.call(_request(location: sameAddressDifferentArea));

      expect(succeedingDatasource.lastIdempotencyKey, isNot(firstKey));
      expect(
        pending.saveCallCount,
        2,
        reason:
            'an area-only change must save a fresh attempt, not reuse '
            'the one from a different area',
      );
    });

    test('identical order context, including the same area, reuses the '
        'same key across an ambiguous failure and its retry', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );

      final failingDatasource = _FakeOrderFunctionsDatasource(
        error: Exception('simulated network timeout'),
      );
      final failingUseCase = _useCase(
        failingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await expectLater(
        () => failingUseCase.call(_request(location: _completeLocation())),
        throwsException,
      );
      final firstKey = failingDatasource.lastIdempotencyKey;

      final succeedingDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final retryUseCase = _useCase(
        succeedingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      // Same location value, including the same area ('Anna Nagar').
      await retryUseCase.call(_request(location: _completeLocation()));

      expect(succeedingDatasource.lastIdempotencyKey, firstKey);
      expect(
        pending.saveCallCount,
        1,
        reason:
            'an unchanged order context, area included, must reuse '
            'the persisted key rather than saving a new one',
      );
    });

    test('a pending attempt older than 30 minutes is treated as stale and '
        'not reused', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );

      final failingDatasource = _FakeOrderFunctionsDatasource(
        error: Exception('simulated network timeout'),
      );
      final failingUseCase = _useCase(
        failingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await expectLater(() => failingUseCase.call(_request()), throwsException);
      final firstKey = failingDatasource.lastIdempotencyKey;

      // Age the stored attempt past the locked 30-minute expiry without
      // changing its key or fingerprint.
      pending.ageStoredAttempt(
        'user-1',
        DateTime.now().subtract(const Duration(minutes: 31)),
      );

      final succeedingDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final retryUseCase = _useCase(
        succeedingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await retryUseCase.call(_request());

      expect(succeedingDatasource.lastIdempotencyKey, isNot(firstKey));
    });

    test('a fresh PlaceOrderUseCase instance reading the same persisted '
        'attempt reuses it (simulates surviving an app restart)', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );

      final failingDatasource = _FakeOrderFunctionsDatasource(
        error: Exception('simulated network timeout'),
      );
      // First "process": fails ambiguously, leaves a pending attempt in
      // the shared persistence fake.
      final firstProcessUseCase = _useCase(
        failingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await expectLater(
        () => firstProcessUseCase.call(_request()),
        throwsException,
      );
      final firstKey = failingDatasource.lastIdempotencyKey;

      // A brand new PlaceOrderUseCase instance - standing in for a fresh
      // app process - backed by the SAME persistence fake, exactly as
      // Firestore would be in production.
      final succeedingDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final secondProcessUseCase = _useCase(
        succeedingDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );
      await secondProcessUseCase.call(_request());

      expect(succeedingDatasource.lastIdempotencyKey, firstKey);
    });

    test("a different authenticated user can never reuse another user's "
        'pending attempt', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      pending.seed(
        'user-1',
        PendingOrderAttempt(
          idempotencyKey: 'user-1-key',
          fingerprint: 'whatever-user-1-was-checking-out',
          createdAt: DateTime.now(),
        ),
      );

      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder(userId: 'user-2')},
      );
      final useCase = _useCase(
        functionsDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );

      await useCase.call(
        PlaceOrderRequest(
          userId: 'user-2',
          items: [_item()],
          summary: _summary(),
          paymentMethod: OrderPaymentMethod.payOnDelivery,
          deliveryLocation: _completeLocation(),
        ),
      );

      expect(functionsDatasource.lastIdempotencyKey, isNot('user-1-key'));
      expect(
        pending.storedFor('user-1')?.idempotencyKey,
        'user-1-key',
        reason:
            "user 1's pending attempt must be untouched by user 2's "
            'checkout',
      );
    });

    test('PlaceOrderCreatedButUnreadableException still clears the pending '
        'key', () async {
      final pending = _FakePendingOrderAttemptDatasource();
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      // No 'order-1' entry: getOrderById throws, matching the existing
      // "created but unreadable" test above.
      final orderRepository = _MemoryOrderRepository();
      final useCase = _useCase(
        functionsDatasource,
        orderRepository,
        pendingAttemptDatasource: pending,
      );

      await expectLater(
        () => useCase.call(_request()),
        throwsA(isA<PlaceOrderCreatedButUnreadableException>()),
      );

      expect(pending.clearCallCount, 1);
      expect(pending.storedFor('user-1'), isNull);
    });

    test('a normal successful placement with no pre-existing pending '
        'attempt behaves exactly as before idempotency was added', () async {
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: _functionResult(),
      );
      final orderRepository = _MemoryOrderRepository(
        ordersById: {'order-1': _placedOrder()},
      );
      final useCase = _useCase(functionsDatasource, orderRepository);

      final order = await useCase.call(_request());

      expect(order.id, 'order-1');
      expect(functionsDatasource.callCount, 1);
      expect(orderRepository.getOrderByIdCallCount, 1);
      expect(functionsDatasource.lastIdempotencyKey, isNotNull);
    });
  });
}
