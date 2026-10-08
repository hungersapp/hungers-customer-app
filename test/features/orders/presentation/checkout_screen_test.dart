import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:customer_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/domain/entities/food_review_status.dart';
import 'package:customer_app/features/foods/domain/repositories/food_repository.dart';
import 'package:customer_app/features/foods/presentation/providers/food_provider.dart';
import 'package:customer_app/features/location/domain/entities/saved_address_book.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/repositories/location_repository.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/location/presentation/providers/selected_destination_provider.dart';
import 'package:customer_app/features/location/presentation/screens/delivery_address_editor_screen.dart';
import 'package:customer_app/features/offers/domain/offer_failure.dart';
import 'package:customer_app/features/offers/presentation/providers/offer_providers.dart';
import 'package:customer_app/features/orders/data/datasources/checkout_quote_datasource.dart';
import 'package:customer_app/features/orders/data/datasources/online_payment_functions_datasource.dart';
import 'package:customer_app/features/orders/data/datasources/order_functions_datasource.dart';
import 'package:customer_app/features/orders/data/datasources/pending_order_attempt_datasource.dart';
import 'package:customer_app/features/orders/domain/entities/customer_orders_page.dart';
import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/domain/exceptions/place_order_functions_exception.dart';
import 'package:customer_app/features/orders/domain/online_payment_launcher.dart';
import 'package:customer_app/features/orders/domain/repositories/order_repository.dart';
import 'package:customer_app/features/orders/domain/usecases/place_order_usecase.dart'
    show PlaceOrderCreatedButUnreadableException;
import 'package:customer_app/features/orders/presentation/providers/order_provider.dart';
import 'package:customer_app/features/orders/presentation/screens/checkout_screen.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/domain/repositories/restaurant_repository.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';

import '../../../helpers/destination_fakes.dart';

/// Fake for the Phase 2.1 callable bridge, reused here the same way it is
/// in `place_order_usecase_test.dart`: configurable to either return a
/// success result or throw, so `CheckoutScreen`'s real `PlaceOrderUseCase`
/// (only its leaf dependencies are overridden, not the use case itself)
/// exercises the exact production error-handling code path.
class _SuccessfulQuote implements CheckoutQuoteDatasource {
  bool unavailable = false;

  @override
  Future<CheckoutQuote> quoteOrder({
    required String restaurantId,
    required List<PlaceOrderLineRequest> items,
    required PlaceOrderDeliveryAddressRequest deliveryAddress,
    String paymentMethod = 'pay_on_delivery',
    List<String> offerIds = const [],
  }) async {
    if (unavailable) {
      throw const CheckoutQuoteUnavailableException();
    }
    return const CheckoutQuote(
      itemTotal: 320,
      discount: 0,
      deliveryFee: 25,
      platformFee: 0,
      packingCharge: 0,
      gstAmount: 17.25,
      foodGstAmount: 16,
      packingGstAmount: 0,
      deliveryGstAmount: 1.25,
      platformGstAmount: 0,
      grandTotal: 362.25,
    );
  }
}

class _FakeOrderFunctionsDatasource implements OrderFunctionsDatasource {
  _FakeOrderFunctionsDatasource({this.result, this.error});

  PlaceOrderFunctionResult? result;
  Object? error;

  /// The delivery address of the most recent placeOrder call, so a test can
  /// assert exactly which destination checkout sent to the server.
  PlaceOrderDeliveryAddressRequest? lastDeliveryAddress;
  String? lastPaymentMethod;
  int callCount = 0;

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
    lastDeliveryAddress = deliveryAddress;
    lastPaymentMethod = paymentMethod;
    callCount += 1;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return result!;
  }
}

/// Backs the existing Firestore read path (`getOrderById`). Always throws,
/// simulating the follow-up-read failure this test file exists to cover —
/// neither test needs a successful read (that path is already covered by
/// `place_order_usecase_test.dart`).
class _MemoryOrderRepository implements OrderRepository {
  @override
  Future<PlacedOrder> placeOrder(PlaceOrderRequest request) async {
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
    throw StateError('Order not found');
  }
}

class _FakeCartRepository implements CartRepository {
  _FakeCartRepository(this.items);

  final List<CartEntity> items;
  int clearCartCallCount = 0;

  @override
  Future<void> addToCart(CartEntity cart) async {}

  @override
  Future<List<CartEntity>> getCartItems(String userId) async => items;

  @override
  Future<CartEntity?> getCartItem({
    required String userId,
    required String foodId,
  }) async => null;

  @override
  Future<void> updateQuantity({
    required String userId,
    required String foodId,
    required int quantity,
  }) async {}

  @override
  Future<void> removeItem({
    required String userId,
    required String foodId,
  }) async {}

  @override
  Future<void> clearCart(String userId) async {
    clearCartCallCount += 1;
  }

  @override
  Future<int> getCartItemCount(String userId) async => items.length;

  @override
  Future<double> getCartTotal(String userId) async => 0;
}

class _FakeLocationRepository implements LocationRepository {
  _FakeLocationRepository(this.location);

  final UserLocation? location;

  @override
  Future<UserLocation?> getUserLocation(String userId) async => location;

  @override
  Future<void> saveUserLocation({
    required String userId,
    required UserLocation location,
    bool clearStaleAddressDetails = false,
  }) async {}

  @override
  Future<void> saveDeliveryPincode({
    required String userId,
    required String pincode,
  }) async {}

  @override
  Future<String?> getDeliveryPincode(String userId) async => location?.pincode;
}

class _ListableRestaurantRepository implements RestaurantRepository {
  _ListableRestaurantRepository(this.restaurant);

  final RestaurantEntity restaurant;

  @override
  Future<List<RestaurantEntity>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  }) async => [restaurant];

  @override
  Future<List<RestaurantEntity>> getAllRestaurants() async => [restaurant];

  @override
  Future<List<RestaurantEntity>> getFeaturedRestaurants() async => [];

  @override
  Future<List<RestaurantEntity>> getPopularRestaurants() async => [];

  @override
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async {
    return restaurant.id == restaurantId ? restaurant : null;
  }

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
  Future<FoodEntity> getFoodById(String foodId) async {
    final food = documents[foodId];
    if (food == null) {
      throw Exception('Food not found');
    }
    return food;
  }

  @override
  Future<FoodEntity?> getFoodDocumentById(String foodId) async {
    return documents[foodId];
  }
}

/// Minimal in-memory stand-in for the Phase 2.4 pending-attempt
/// persistence layer, so this widget test never touches real Firestore.
/// Its own behavior isn't under test here (that's
/// `place_order_usecase_test.dart`'s job) — it only needs to not blow up.
class _FakePendingOrderAttemptDatasource
    implements PendingOrderAttemptDatasource {
  final Map<String, PendingOrderAttempt> _byUser = {};

  @override
  Future<PendingOrderAttempt?> getPendingAttempt(String userId) async =>
      _byUser[userId];

  @override
  Future<void> savePendingAttempt({
    required String userId,
    required PendingOrderAttempt attempt,
  }) async {
    _byUser[userId] = attempt;
  }

  @override
  Future<void> clearPendingAttempt(String userId) async {
    _byUser.remove(userId);
  }
}

const _restaurantId = 'a2b';
const _foodId = 'food-a';
const _userId = 'user-1';

RestaurantEntity _restaurant() {
  final now = DateTime(2026, 1, 1);
  return RestaurantEntity(
    id: _restaurantId,
    name: 'A2B',
    description: '',
    logoUrl: '',
    coverImageUrl: '',
    address: '',
    latitude: 13.08,
    longitude: 80.27,
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

FoodEntity _food() {
  return const FoodEntity(
    id: _foodId,
    restaurantId: _restaurantId,
    name: 'Mini Meals',
    description: '',
    price: 160,
    imageUrl: '',
    category: 'Meals',
    isVeg: true,
    isAvailable: true,
    isRecommended: false,
    rating: 0,
    status: FoodReviewStatus.approved,
  );
}

CartEntity _cartItem() {
  return CartEntity(
    id: _foodId,
    userId: _userId,
    restaurantId: _restaurantId,
    restaurantName: 'A2B',
    foodId: _foodId,
    foodName: 'Mini Meals',
    foodImage: '',
    price: 160,
    quantity: 2,
    isVeg: true,
    isAvailable: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

UserLocation _completeLocation() {
  // Same coordinates as the restaurant: distance 0km, delivery fee slab
  // resolves to a priced ₹25, and no >15km serviceability check is
  // triggered — keeping this test focused on the place-order error
  // handling, not the fee/serviceability logic (already covered
  // elsewhere).
  return UserLocation(
    latitude: 13.08,
    longitude: 80.27,
    city: 'Chennai',
    state: 'Tamil Nadu',
    updatedAt: DateTime(2026, 9, 1),
    pincode: '600001',
    doorNumber: '12',
    street: 'Main Road',
    area: 'Anna Nagar',
  );
}

Widget _wrap({
  required _FakeOrderFunctionsDatasource functionsDatasource,
  required _MemoryOrderRepository orderRepository,
  required _FakeCartRepository cartRepository,
  UserLocation? location,
  SavedAddressBook savedAddresses = const SavedAddressBook(),
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue(_userId),
      cartRepositoryProvider.overrideWithValue(cartRepository),
      locationRepositoryProvider.overrideWithValue(
        _FakeLocationRepository(location ?? _completeLocation()),
      ),
      savedAddressRepositoryProvider.overrideWithValue(
        FakeSavedAddressRepository(savedAddresses),
      ),
      restaurantRepositoryProvider.overrideWithValue(
        _ListableRestaurantRepository(_restaurant()),
      ),
      foodRepositoryProvider.overrideWithValue(
        _MemoryFoodRepository({_foodId: _food()}),
      ),
      orderFunctionsDatasourceProvider.overrideWithValue(functionsDatasource),
      checkoutQuoteDatasourceProvider.overrideWithValue(_SuccessfulQuote()),
      orderRepositoryProvider.overrideWithValue(orderRepository),
      pendingOrderAttemptDatasourceProvider.overrideWithValue(
        _FakePendingOrderAttemptDatasource(),
      ),
      ...extraOverrides,
    ],
    child: const MaterialApp(home: CheckoutScreen()),
  );
}

Future<void> _pumpCheckoutAndPlaceOrder(
  WidgetTester tester, {
  required _FakeOrderFunctionsDatasource functionsDatasource,
  required _MemoryOrderRepository orderRepository,
  required _FakeCartRepository cartRepository,
  List<Override> extraOverrides = const [],
}) async {
  final view = tester.view;
  view.physicalSize = const Size(900, 1800);
  view.devicePixelRatio = 1.0;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _wrap(
      functionsDatasource: functionsDatasource,
      orderRepository: orderRepository,
      cartRepository: cartRepository,
      extraOverrides: extraOverrides,
    ),
  );
  await tester.pumpAndSettle();

  expect(
    find.text('Place Order'),
    findsOneWidget,
    reason: 'checkout did not reach a placeable state before the tap',
  );
  await tester.tap(find.text('Place Order'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a created-but-unreadable order shows a success message directing to '
    'My Orders, not the generic failure message',
    (tester) async {
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: const PlaceOrderFunctionResult(
          orderId: 'order-1',
          replayed: false,
          itemTotal: 320,
          deliveryFee: 25,
          platformFee: 5,
          gstAmount: 17.5,
          grandTotal: 367.5,
          distanceKm: 0,
        ),
      );
      // No 'order-1' entry: getOrderById throws, simulating the follow-up
      // read failing after the order was already created server-side.
      final orderRepository = _MemoryOrderRepository();
      final cartRepository = _FakeCartRepository([_cartItem()]);

      await _pumpCheckoutAndPlaceOrder(
        tester,
        functionsDatasource: functionsDatasource,
        orderRepository: orderRepository,
        cartRepository: cartRepository,
      );

      expect(
        find.text(
          const PlaceOrderCreatedButUnreadableException('order-1').message,
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Unable to place order'), findsNothing);
      expect(
        cartRepository.clearCartCallCount,
        1,
        reason:
            'the order was really created, so the cart must still be '
            'cleared for this case',
      );
    },
  );

  testWidgets(
    'a pincode-not-serviceable rejection shows its own specific message, '
    'not the generic failure message or an items-unavailable message',
    (tester) async {
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        error: const PlaceOrderPincodeNotServiceableException(),
      );
      final orderRepository = _MemoryOrderRepository();
      final cartRepository = _FakeCartRepository([_cartItem()]);

      await _pumpCheckoutAndPlaceOrder(
        tester,
        functionsDatasource: functionsDatasource,
        orderRepository: orderRepository,
        cartRepository: cartRepository,
      );

      expect(
        find.text(const PlaceOrderPincodeNotServiceableException().message),
        findsOneWidget,
      );
      expect(
        find.text('Unable to place order. Your cart was not cleared.'),
        findsNothing,
      );
      expect(find.textContaining('no longer available'), findsNothing);
      expect(
        cartRepository.clearCartCallCount,
        0,
        reason: 'a genuine rejection must not clear the cart',
      );
    },
  );

  testWidgets('an ordinary callable failure still shows the existing generic '
      'message, unchanged', (tester) async {
    final functionsDatasource = _FakeOrderFunctionsDatasource(
      error: const PlaceOrderRestaurantNotAcceptingException(),
    );
    final orderRepository = _MemoryOrderRepository();
    final cartRepository = _FakeCartRepository([_cartItem()]);

    await _pumpCheckoutAndPlaceOrder(
      tester,
      functionsDatasource: functionsDatasource,
      orderRepository: orderRepository,
      cartRepository: cartRepository,
    );

    expect(
      find.text('Unable to place order. Your cart was not cleared.'),
      findsOneWidget,
    );
    expect(find.textContaining('order was placed successfully'), findsNothing);
    expect(
      cartRepository.clearCartCallCount,
      0,
      reason:
          'a genuine failure must not clear the cart, same as before '
          'this change',
    );
  });

  testWidgets('incomplete address hides the final payable bill amount', (
    tester,
  ) async {
    final view = tester.view;
    view.physicalSize = const Size(900, 1800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    final incomplete = UserLocation(
      latitude: 13.08,
      longitude: 80.27,
      city: 'Chennai',
      state: 'Tamil Nadu',
      updatedAt: DateTime(2026, 9, 1),
      // missing door/street/pincode → not complete for checkout
    );

    await tester.pumpWidget(
      _wrap(
        functionsDatasource: _FakeOrderFunctionsDatasource(
          result: const PlaceOrderFunctionResult(
            orderId: 'order-1',
            replayed: false,
            itemTotal: 320,
            deliveryFee: 25,
            platformFee: 5,
            gstAmount: 17.5,
            grandTotal: 367.5,
            distanceKm: 0,
          ),
        ),
        orderRepository: _MemoryOrderRepository(),
        cartRepository: _FakeCartRepository([_cartItem()]),
        location: incomplete,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Finalize your delivery address to see the final amount to pay.',
      ),
      findsOneWidget,
    );
    expect(find.text('To Pay'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Item Total'), findsNothing);
    expect(find.text('Platform Fee'), findsNothing);
  });

  testWidgets(
    'finalized complete address shows the payable bill with delivery fee',
    (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1800);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          functionsDatasource: _FakeOrderFunctionsDatasource(
            result: const PlaceOrderFunctionResult(
              orderId: 'order-1',
              replayed: false,
              itemTotal: 320,
              deliveryFee: 25,
              platformFee: 5,
              gstAmount: 17.5,
              grandTotal: 367.5,
              distanceKm: 0,
            ),
          ),
          orderRepository: _MemoryOrderRepository(),
          cartRepository: _FakeCartRepository([_cartItem()]),
          location: _completeLocation(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Item Total'), findsOneWidget);
      // No platform charge: the row is omitted, not shown as ₹0.
      expect(find.text('Platform Fee'), findsNothing);
      expect(find.text('To Pay'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(find.text('Place Order'), findsOneWidget);
      expect(find.text('Final Payable'), findsOneWidget);
      expect(find.text('GST Breakdown'), findsNothing);
      await tester.tap(find.text('GST').first);
      await tester.pumpAndSettle();
      expect(find.text('Food GST'), findsOneWidget);
      expect(find.text('Delivery GST'), findsOneWidget);
      expect(find.text('Platform Fee GST (18%)'), findsNothing);
      // No packing configured: no packing line and no packing GST.
      expect(find.text('Packing Charges'), findsNothing);
      expect(find.textContaining('Packing GST'), findsNothing);
      // The customer never sees restaurant commission.
      expect(find.textContaining('ommission'), findsNothing);
      expect(find.text('Mini Meals'), findsWidgets);
      expect(find.text('\u20B9160.00 \u00d7 2'), findsOneWidget);
    },
  );

  testWidgets(
    'an unavailable quote blocks checkout instead of using a local total',
    (tester) async {
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: const PlaceOrderFunctionResult(
          orderId: 'order-1',
          replayed: false,
          itemTotal: 320,
          deliveryFee: 25,
          platformFee: 0,
          gstAmount: 17.25,
          grandTotal: 362.25,
          distanceKm: 0,
        ),
      );
      final view = tester.view;
      view.physicalSize = const Size(900, 1800);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      final quote = _SuccessfulQuote()..unavailable = true;
      await tester.pumpWidget(
        _wrap(
          functionsDatasource: functionsDatasource,
          orderRepository: _MemoryOrderRepository(),
          cartRepository: _FakeCartRepository([_cartItem()]),
          extraOverrides: [
            checkoutQuoteDatasourceProvider.overrideWithValue(quote),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(OfferFailureMessages.quoteUnavailable),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Place Order'),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();
      expect(functionsDatasource.callCount, 0);
    },
  );

  testWidgets('opening Change address invalidates the prior final bill', (
    tester,
  ) async {
    final view = tester.view;
    view.physicalSize = const Size(900, 1800);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        functionsDatasource: _FakeOrderFunctionsDatasource(
          result: const PlaceOrderFunctionResult(
            orderId: 'order-1',
            replayed: false,
            itemTotal: 320,
            deliveryFee: 25,
            platformFee: 5,
            gstAmount: 17.5,
            grandTotal: 367.5,
            distanceKm: 0,
          ),
        ),
        orderRepository: _MemoryOrderRepository(),
        cartRepository: _FakeCartRepository([_cartItem()]),
        location: _completeLocation(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Item Total'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pump();

    expect(
      find.text('Confirm the delivery address to refresh the final bill.'),
      findsOneWidget,
    );
    expect(find.text('Item Total'), findsNothing);
    expect(find.text('—'), findsOneWidget);
  });

  const successResult = PlaceOrderFunctionResult(
    orderId: 'order-1',
    replayed: false,
    itemTotal: 320,
    deliveryFee: 25,
    platformFee: 5,
    gstAmount: 17.5,
    grandTotal: 367.5,
    distanceKm: 0,
  );

  // The customer's selected destination (Chennai, from _completeLocation) vs a
  // phone that is physically in Bengaluru.
  final bengaluruGps = UserLocation(
    latitude: 12.9716,
    longitude: 77.5946,
    city: 'Bengaluru',
    state: 'Karnataka',
    updatedAt: DateTime(2026, 9, 2),
    pincode: '560001',
  );

  testWidgets(
    'checkout sends the SELECTED destination, not the phone\'s current GPS',
    (tester) async {
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: successResult,
      );

      await _pumpCheckoutAndPlaceOrder(
        tester,
        functionsDatasource: functionsDatasource,
        orderRepository: _MemoryOrderRepository(),
        cartRepository: _FakeCartRepository([_cartItem()]),
        extraOverrides: [
          // Current-location data is available and DIFFERENT — it must have
          // no influence on what gets ordered.
          currentGpsLocationProvider.overrideWith((ref) => bengaluruGps),
        ],
      );

      final sent = functionsDatasource.lastDeliveryAddress;
      expect(sent, isNotNull);
      expect(sent!.latitude, 13.08);
      expect(sent.longitude, 80.27);
      expect(sent.city, 'Chennai');
      expect(sent.state, 'Tamil Nadu');
      expect(sent.pincode, '600001');
      expect(sent.doorNumber, '12');
      expect(sent.street, 'Main Road');
    },
  );

  testWidgets(
    'checkout orders to the very location that discovery is based on',
    (tester) async {
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: successResult,
      );
      final view = tester.view;
      view.physicalSize = const Size(900, 1800);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          functionsDatasource: functionsDatasource,
          orderRepository: _MemoryOrderRepository(),
          cartRepository: _FakeCartRepository([_cartItem()]),
          extraOverrides: [
            // The phone is elsewhere; it must not matter.
            currentGpsLocationProvider.overrideWith((ref) => bengaluruGps),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The destination every discovery surface is based on.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CheckoutScreen)),
      );
      final discovery = await container.read(
        selectedDeliveryDestinationProvider.future,
      );
      expect(discovery, isNotNull);

      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      final sent = functionsDatasource.lastDeliveryAddress;
      expect(sent, isNotNull);
      expect(sent!.latitude, discovery!.latitude);
      expect(sent.longitude, discovery.longitude);
      expect(sent.city, discovery.city);
      expect(sent.state, discovery.state);
      expect(sent.pincode, discovery.pincode);
    },
  );

  testWidgets(
    'a place chosen only for browsing (no door / street) is completed at '
    'checkout before an order can be placed',
    (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1800);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          functionsDatasource: _FakeOrderFunctionsDatasource(
            result: successResult,
          ),
          orderRepository: _MemoryOrderRepository(),
          cartRepository: _FakeCartRepository([_cartItem()]),
          location: UserLocation(
            latitude: 13.08,
            longitude: 80.27,
            city: 'Chennai',
            state: 'Tamil Nadu',
            pincode: '600001',
            selectedByCustomer: true,
            updatedAt: DateTime(2026, 9, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The chosen place is offered for completion, and no payable amount is
      // shown until door and street are added.
      expect(find.text('Complete address'), findsOneWidget);
      expect(
        find.text(
          'Finalize your delivery address to see the final amount to pay.',
        ),
        findsOneWidget,
      );
      expect(find.text('Item Total'), findsNothing);
    },
  );

  testWidgets(
    'an order for someone else keeps the recipient address, independent of '
    'both the saved destination and the phone\'s GPS',
    (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 2400);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: successResult,
      );
      await tester.pumpWidget(
        _wrap(
          functionsDatasource: functionsDatasource,
          orderRepository: _MemoryOrderRepository(),
          cartRepository: _FakeCartRepository([_cartItem()]),
          extraOverrides: [
            currentGpsLocationProvider.overrideWith((ref) => bengaluruGps),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Switch to "Order for someone else": no recipient address yet, so the
      // saved destination (and GPS) must NOT be sent on their behalf.
      await tester.tap(find.text('Order for someone else'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Add the recipient delivery address'),
        findsOneWidget,
      );
      expect(functionsDatasource.lastDeliveryAddress, isNull);
    },
  );

  testWidgets(
    'missing delivery address cannot call placeOrder — Place Order opens '
    'the address editor instead',
    (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1800);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: successResult,
      );
      await tester.pumpWidget(
        _wrap(
          functionsDatasource: functionsDatasource,
          orderRepository: _MemoryOrderRepository(),
          cartRepository: _FakeCartRepository([_cartItem()]),
          location: UserLocation(
            latitude: 10.07,
            longitude: 78.78,
            city: 'Karaikudi',
            state: 'Tamil Nadu',
            selectedByCustomer: true,
            updatedAt: DateTime(2026, 9, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete address'), findsOneWidget);
      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryAddressEditorScreen), findsOneWidget);
      expect(functionsDatasource.lastDeliveryAddress, isNull);
    },
  );

  testWidgets(
    'a complete saved HOME address can proceed without entering address again',
    (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1800);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      final home = _completeLocation();
      final functionsDatasource = _FakeOrderFunctionsDatasource(
        result: successResult,
      );
      await tester.pumpWidget(
        _wrap(
          functionsDatasource: functionsDatasource,
          orderRepository: _MemoryOrderRepository(),
          cartRepository: _FakeCartRepository([_cartItem()]),
          location: home,
          savedAddresses: SavedAddressBook(home: home),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Complete address'), findsNothing);
      expect(find.text('Add address'), findsNothing);

      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(functionsDatasource.lastDeliveryAddress, isNotNull);
      expect(functionsDatasource.lastDeliveryAddress!.city, 'Chennai');
      expect(functionsDatasource.lastDeliveryAddress!.doorNumber, '12');
    },
  );

  group('Cashfree online payment at checkout', () {
    PlaceOrderFunctionResult created() => const PlaceOrderFunctionResult(
      orderId: 'order-online-1',
      replayed: false,
      itemTotal: 320,
      deliveryFee: 25,
      platformFee: 0,
      gstAmount: 17.5,
      grandTotal: 362.5,
      distanceKm: 0,
    );

    Future<void> pumpAndChoose(
      WidgetTester tester, {
      required _FakeOrderFunctionsDatasource functionsDatasource,
      required _FakeCartRepository cartRepository,
      required _FakeOnlinePayments payments,
      required _FakePaymentLauncher launcher,
      OrderPaymentMethod? method,
    }) async {
      final view = tester.view;
      view.physicalSize = const Size(900, 1800);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _wrap(
          functionsDatasource: functionsDatasource,
          orderRepository: _MemoryOrderRepository(),
          cartRepository: cartRepository,
          extraOverrides: [
            onlinePaymentFunctionsDatasourceProvider.overrideWithValue(
              payments,
            ),
            onlinePaymentLauncherProvider.overrideWithValue(launcher),
          ],
        ),
      );
      await tester.pumpAndSettle();
      if (method != null) {
        final tile = find.byKey(
          ValueKey<String>('payment-method-${method.name}'),
        );
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
    }

    Future<void> tapPrimary(WidgetTester tester) async {
      final button = find.byKey(
        const ValueKey<String>('checkout-primary-action'),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets(
      '1-3: shows Cash on Delivery, UPI, Credit Card and Debit Card',
      (tester) async {
        await pumpAndChoose(
          tester,
          functionsDatasource: _FakeOrderFunctionsDatasource(result: created()),
          cartRepository: _FakeCartRepository([_cartItem()]),
          payments: _FakeOnlinePayments(),
          launcher: _FakePaymentLauncher(),
        );
        expect(find.text('Cash on Delivery'), findsOneWidget);
        expect(find.text('UPI'), findsOneWidget);
        expect(find.text('Pay using any supported UPI option'), findsOneWidget);
        expect(find.text('Credit Card'), findsOneWidget);
        expect(find.text('Debit Card'), findsOneWidget);
        expect(find.text('Place Order'), findsOneWidget);
      },
    );

    testWidgets(
      'UPI: order is placed as upi, the backend creates the session, and only a verified payment completes checkout',
      (tester) async {
        final functions = _FakeOrderFunctionsDatasource(result: created());
        final cart = _FakeCartRepository([_cartItem()]);
        final payments = _FakeOnlinePayments()..verifications = ['paid'];
        final launcher = _FakePaymentLauncher();
        await pumpAndChoose(
          tester,
          functionsDatasource: functions,
          cartRepository: cart,
          payments: payments,
          launcher: launcher,
          method: OrderPaymentMethod.upi,
        );
        expect(find.text('Proceed to Pay'), findsOneWidget);

        await tapPrimary(tester);

        expect(functions.lastPaymentMethod, 'upi');
        expect(payments.createCalls, [('order-online-1', 'UPI')]);
        expect(launcher.launchCount, 1);
        expect(payments.verifyCalls, 1);
        expect(cart.clearCartCallCount, 1);
        expect(
          find.text('Payment received. Your order has been placed.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a checkout the SDK reports as finished is not success until the backend says paid; retry reuses the same order',
      (tester) async {
        final functions = _FakeOrderFunctionsDatasource(result: created());
        final cart = _FakeCartRepository([_cartItem()]);
        final payments = _FakeOnlinePayments()
          ..verifications = ['pending', 'paid'];
        await pumpAndChoose(
          tester,
          functionsDatasource: functions,
          cartRepository: cart,
          payments: payments,
          launcher: _FakePaymentLauncher(),
          method: OrderPaymentMethod.creditCard,
        );

        await tapPrimary(tester);

        expect(functions.lastPaymentMethod, 'card');
        expect(payments.createCalls.single.$2, 'CREDIT_CARD');
        expect(cart.clearCartCallCount, 0);
        expect(
          find.textContaining('Payment not completed yet'),
          findsOneWidget,
        );
        expect(find.text('Retry Payment'), findsOneWidget);

        await tapPrimary(tester);

        expect(
          functions.callCount,
          1,
          reason: 'retry must not create a second order',
        );
        expect(payments.createCalls.length, 2);
        expect(payments.createCalls.last.$1, 'order-online-1');
        expect(cart.clearCartCallCount, 1);
      },
    );

    testWidgets(
      'a failed payment keeps the cart and says the customer was not charged',
      (tester) async {
        final cart = _FakeCartRepository([_cartItem()]);
        final payments = _FakeOnlinePayments()..verifications = ['failed'];
        await pumpAndChoose(
          tester,
          functionsDatasource: _FakeOrderFunctionsDatasource(result: created()),
          cartRepository: cart,
          payments: payments,
          launcher: _FakePaymentLauncher(
            outcome: OnlinePaymentLaunchOutcome.errored,
          ),
          method: OrderPaymentMethod.debitCard,
        );

        await tapPrimary(tester);

        expect(payments.createCalls.single.$2, 'DEBIT_CARD');
        expect(find.textContaining('Payment failed'), findsOneWidget);
        expect(cart.clearCartCallCount, 0);
      },
    );

    testWidgets('an already-paid order skips the checkout UI and completes', (
      tester,
    ) async {
      final cart = _FakeCartRepository([_cartItem()]);
      final payments = _FakeOnlinePayments(alreadyPaid: true)
        ..verifications = ['paid'];
      final launcher = _FakePaymentLauncher();
      await pumpAndChoose(
        tester,
        functionsDatasource: _FakeOrderFunctionsDatasource(result: created()),
        cartRepository: cart,
        payments: payments,
        launcher: launcher,
        method: OrderPaymentMethod.upi,
      );

      await tapPrimary(tester);

      expect(launcher.launchCount, 0);
      expect(cart.clearCartCallCount, 1);
    });

    testWidgets(
      'online payment unavailable on the backend shows a clear message and keeps the cart',
      (tester) async {
        final cart = _FakeCartRepository([_cartItem()]);
        await pumpAndChoose(
          tester,
          functionsDatasource: _FakeOrderFunctionsDatasource(
            error: const PlaceOrderOnlinePaymentUnavailableException(),
          ),
          cartRepository: cart,
          payments: _FakeOnlinePayments(),
          launcher: _FakePaymentLauncher(),
          method: OrderPaymentMethod.upi,
        );

        await tapPrimary(tester);

        expect(
          find.textContaining('Online payment is not available'),
          findsOneWidget,
        );
        expect(cart.clearCartCallCount, 0);
      },
    );

    testWidgets(
      'Cash on Delivery is unchanged: no online payment call is made',
      (tester) async {
        final functions = _FakeOrderFunctionsDatasource(result: created());
        final payments = _FakeOnlinePayments();
        await pumpAndChoose(
          tester,
          functionsDatasource: functions,
          cartRepository: _FakeCartRepository([_cartItem()]),
          payments: payments,
          launcher: _FakePaymentLauncher(),
        );

        await tapPrimary(tester);

        expect(functions.lastPaymentMethod, 'pay_on_delivery');
        expect(payments.createCalls, isEmpty);
        expect(payments.verifyCalls, 0);
      },
    );
  });
}

class _FakeOnlinePayments implements OnlinePaymentFunctionsDatasource {
  _FakeOnlinePayments({this.alreadyPaid = false});

  final bool alreadyPaid;
  final List<(String, String)> createCalls = [];
  int verifyCalls = 0;

  /// Successive backend verification answers: 'paid', 'pending', 'failed'.
  List<String> verifications = ['pending'];

  @override
  Future<OnlinePaymentSession> createPayment({
    required String orderId,
    required String paymentMethod,
  }) async {
    createCalls.add((orderId, paymentMethod));
    return OnlinePaymentSession(
      orderId: orderId,
      amount: 362.5,
      environment: 'SANDBOX',
      alreadyPaid: alreadyPaid,
      paymentId: 'cp_${orderId}_${createCalls.length}',
      providerOrderId: 'cp_${orderId}_${createCalls.length}',
      paymentSessionId: 'session_test',
    );
  }

  @override
  Future<OnlinePaymentVerification> verifyPayment({
    required String orderId,
  }) async {
    final answer =
        verifications[verifyCalls.clamp(0, verifications.length - 1)];
    verifyCalls += 1;
    return OnlinePaymentVerification(
      orderId: orderId,
      paymentStatus: answer == 'paid' ? 'paid' : 'pending',
      orderStatus: answer == 'paid' ? 'placed' : 'awaiting_payment',
      latestAttemptStatus: answer == 'failed'
          ? 'FAILED'
          : (answer == 'paid' ? 'SUCCESS' : 'PENDING'),
    );
  }
}

class _FakePaymentLauncher implements OnlinePaymentLauncher {
  _FakePaymentLauncher({this.outcome = OnlinePaymentLaunchOutcome.returned});

  final OnlinePaymentLaunchOutcome outcome;
  int launchCount = 0;

  @override
  Future<OnlinePaymentLaunchResult> launch(OnlinePaymentSession session) async {
    launchCount += 1;
    return OnlinePaymentLaunchResult(outcome);
  }
}
