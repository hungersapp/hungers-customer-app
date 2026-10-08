import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/cart/domain/entities/billing_summary.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:customer_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:customer_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:customer_app/features/foods/domain/entities/food_entity.dart';
import 'package:customer_app/features/foods/domain/entities/food_review_status.dart';
import 'package:customer_app/features/foods/domain/repositories/food_repository.dart';
import 'package:customer_app/features/foods/presentation/providers/food_provider.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/offers/data/datasources/offer_datasource.dart';
import 'package:customer_app/features/offers/domain/entities/offer.dart';
import 'package:customer_app/features/offers/domain/offer_failure.dart';
import 'package:customer_app/features/offers/presentation/providers/offer_providers.dart';
import 'package:customer_app/features/orders/data/datasources/checkout_quote_datasource.dart';
import 'package:customer_app/features/orders/data/datasources/order_functions_datasource.dart';
import 'package:customer_app/features/orders/data/datasources/pending_order_attempt_datasource.dart';
import 'package:customer_app/features/orders/domain/entities/customer_orders_page.dart';
import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/domain/exceptions/place_order_functions_exception.dart';
import 'package:customer_app/features/orders/domain/repositories/order_repository.dart';
import 'package:customer_app/features/orders/presentation/providers/order_provider.dart';
import 'package:customer_app/features/orders/presentation/screens/checkout_screen.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/domain/repositories/restaurant_repository.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';

import '../../helpers/destination_fakes.dart';

const _userId = 'user-1';
const _restaurantId = 'a2b';
const _foodId = 'food-a';

// ---------------------------------------------------------------------------
// Offers used across the tests
// ---------------------------------------------------------------------------

const _welcome50 = Offer(
  id: 'welcome50',
  type: OfferType.tukkito,
  discountType: OfferDiscountType.flat,
  discountValue: 50,
  code: 'WELCOME50',
  minimumOrderValue: 299,
);

const _hotel100 = Offer(
  id: 'hotel100',
  type: OfferType.restaurant,
  discountType: OfferDiscountType.flat,
  discountValue: 100,
  code: 'HOTEL100',
  minimumOrderValue: 499,
  restaurantIds: [_restaurantId],
  restaurantName: 'A2B',
);

const _hotel20 = Offer(
  id: 'hotel20',
  type: OfferType.restaurant,
  discountType: OfferDiscountType.flat,
  discountValue: 20,
  code: 'HOTEL20',
  restaurantIds: [_restaurantId],
  restaurantName: 'A2B',
);

const _gpayCashback = Offer(
  id: 'gpay50',
  type: OfferType.paymentPartner,
  discountType: OfferDiscountType.flat,
  discountValue: 50,
  benefitType: OfferBenefitType.cashback,
  partnerName: 'Google Pay',
  description: 'Get ₹50 cashback when you pay using Google Pay.',
  paymentMethods: ['upi'],
);

const _upi25 = Offer(
  id: 'upi25',
  type: OfferType.paymentPartner,
  discountType: OfferDiscountType.flat,
  discountValue: 25,
  partnerName: 'PhonePe',
  paymentMethods: ['upi'],
);

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeOfferDatasource implements OfferDatasource {
  _FakeOfferDatasource(this.offers);

  final List<Offer> offers;

  @override
  Future<List<Offer>> getActiveOffers() async => offers;
}

/// Stands in for `quoteOrder`. Prices the cart the way the backend does
/// (item 320, delivery 25, food GST 5%, delivery GST 18%) and applies or
/// refuses an offer exactly as configured — the app never does either.
class _FakeQuoteBackend implements CheckoutQuoteDatasource {
  _FakeQuoteBackend({
    Map<String, double> discounts = const {},
    Map<String, String> rejections = const {},
    this.grandTotalOverride,
  })  : discounts = Map.of(discounts),
        rejections = Map.of(rejections);

  final Map<String, double> discounts;
  final Map<String, String> rejections;
  bool unavailable = false;

  /// Forces a payable the app could not have computed itself.
  final double? grandTotalOverride;

  final List<({List<String> offerIds, String paymentMethod})> calls = [];

  @override
  Future<CheckoutQuote> quoteOrder({
    required String restaurantId,
    required List<PlaceOrderLineRequest> items,
    required PlaceOrderDeliveryAddressRequest deliveryAddress,
    String paymentMethod = 'pay_on_delivery',
    List<String> offerIds = const [],
  }) async {
    calls.add((offerIds: offerIds, paymentMethod: paymentMethod));
    if (unavailable) {
      throw const CheckoutQuoteUnavailableException();
    }
    var discount = 0.0;
    final lines = <BillingDiscountLine>[];
    for (final id in offerIds) {
      final rejection = rejections[id];
      if (rejection != null) {
        throw OfferRejectedException(rejection);
      }
      if (id == _upi25.id && paymentMethod != 'upi') {
        throw const OfferRejectedException('OFFER_PAYMENT_INELIGIBLE');
      }
      final amount = discounts[id] ?? 0;
      discount += amount;
      lines.add(
        BillingDiscountLine(
          offerId: id,
          offerType: 'tukkito',
          description: 'Offer $id',
          amount: amount,
        ),
      );
    }
    const itemTotal = 320.0;
    const deliveryFee = 25.0;
    final foodGst = ((itemTotal - discount) * 5).round() / 100;
    const deliveryGst = 4.5;
    return CheckoutQuote(
      itemTotal: itemTotal,
      discount: discount,
      deliveryFee: deliveryFee,
      platformFee: 0,
      packingCharge: 0,
      gstAmount: foodGst + deliveryGst,
      foodGstAmount: foodGst,
      packingGstAmount: 0,
      deliveryGstAmount: deliveryGst,
      platformGstAmount: 0,
      grandTotal:
          grandTotalOverride ??
          itemTotal - discount + deliveryFee + foodGst + deliveryGst,
      discountLines: lines,
    );
  }
}

class _FakeOrderFunctions
    implements OrderFunctionsDatasource, OfferAwareOrderFunctionsDatasource {
  Object? error;
  int plainCalls = 0;
  final List<({List<String> offerIds, String paymentMethod})> offerCalls = [];

  PlaceOrderFunctionResult get _result => const PlaceOrderFunctionResult(
        orderId: 'order-1',
        replayed: false,
        itemTotal: 320,
        deliveryFee: 25,
        platformFee: 0,
        gstAmount: 18,
        grandTotal: 313,
        distanceKm: 0,
      );

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
    plainCalls += 1;
    return _result;
  }

  @override
  Future<PlaceOrderFunctionResult> placeOrderWithOffers({
    required String restaurantId,
    required List<PlaceOrderLineRequest> items,
    required PlaceOrderDeliveryAddressRequest deliveryAddress,
    required List<String> offerIds,
    bool orderForOther = false,
    String? recipientName,
    String? recipientPhone,
    String? idempotencyKey,
    String paymentMethod = 'pay_on_delivery',
  }) async {
    offerCalls.add((offerIds: offerIds, paymentMethod: paymentMethod));
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return _result;
  }
}

class _CartRepository implements CartRepository {
  final List<CartEntity> items = [_cartItem()];
  int clearCount = 0;

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
    clearCount += 1;
  }

  @override
  Future<int> getCartItemCount(String userId) async => items.length;

  @override
  Future<double> getCartTotal(String userId) async => 320;
}

class _RestaurantRepository implements RestaurantRepository {
  @override
  Future<List<RestaurantEntity>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  }) async => [_restaurant()];

  @override
  Future<List<RestaurantEntity>> getAllRestaurants() async => [_restaurant()];

  @override
  Future<List<RestaurantEntity>> getFeaturedRestaurants() async => [];

  @override
  Future<List<RestaurantEntity>> getPopularRestaurants() async => [];

  @override
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async =>
      restaurantId == _restaurantId ? _restaurant() : null;

  @override
  Future<List<RestaurantEntity>> searchRestaurants(String keyword) async => [];

  @override
  Future<List<RestaurantEntity>> getNearbyRestaurants() async => [];
}

class _FoodRepository implements FoodRepository {
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
  Future<FoodEntity> getFoodById(String foodId) async => _food();

  @override
  Future<FoodEntity?> getFoodDocumentById(String foodId) async =>
      foodId == _foodId ? _food() : null;
}

class _OrderRepository implements OrderRepository {
  @override
  Future<PlacedOrder> placeOrder(PlaceOrderRequest request) async =>
      throw UnimplementedError();

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
  }) async => throw StateError('Order not found');
}

class _PendingAttempts implements PendingOrderAttemptDatasource {
  PendingOrderAttempt? _attempt;

  @override
  Future<PendingOrderAttempt?> getPendingAttempt(String userId) async =>
      _attempt;

  @override
  Future<void> savePendingAttempt({
    required String userId,
    required PendingOrderAttempt attempt,
  }) async {
    _attempt = attempt;
  }

  @override
  Future<void> clearPendingAttempt(String userId) async {
    _attempt = null;
  }
}

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

UserLocation _location({bool complete = true}) {
  return UserLocation(
    latitude: 13.08,
    longitude: 80.27,
    city: 'Chennai',
    state: 'Tamil Nadu',
    updatedAt: DateTime(2026, 9, 1),
    pincode: complete ? '600001' : null,
    doorNumber: complete ? '12' : '',
    street: complete ? 'Main Road' : '',
    area: 'Anna Nagar',
  );
}

class _Harness {
  _Harness({
    required this.offers,
    _FakeQuoteBackend? quotes,
  }) : quotes = quotes ?? _FakeQuoteBackend();

  final List<Offer> offers;
  final _FakeQuoteBackend quotes;
  final _FakeOrderFunctions orders = _FakeOrderFunctions();
  final _CartRepository cart = _CartRepository();

  List<Override> overrides({bool completeAddress = true}) => [
        currentUserIdProvider.overrideWithValue(_userId),
        cartRepositoryProvider.overrideWithValue(cart),
        locationRepositoryProvider.overrideWithValue(
          FakeLocationRepository(_location(complete: completeAddress)),
        ),
        savedAddressRepositoryProvider.overrideWithValue(
          FakeSavedAddressRepository(),
        ),
        restaurantRepositoryProvider.overrideWithValue(_RestaurantRepository()),
        foodRepositoryProvider.overrideWithValue(_FoodRepository()),
        serviceabilityRepositoryProvider.overrideWithValue(
          FakeServiceabilityRepository(),
        ),
        restaurantFoodsProvider.overrideWith((ref, id) async => []),
        orderFunctionsDatasourceProvider.overrideWithValue(orders),
        orderRepositoryProvider.overrideWithValue(_OrderRepository()),
        pendingOrderAttemptDatasourceProvider.overrideWithValue(
          _PendingAttempts(),
        ),
        offerDatasourceProvider.overrideWithValue(_FakeOfferDatasource(offers)),
        checkoutQuoteDatasourceProvider.overrideWithValue(quotes),
      ];

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    bool completeAddress = true,
  }) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(completeAddress: completeAddress),
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String _toPay(WidgetTester tester) {
  final label = tester.getTopLeft(find.text('To Pay'));
  // The amount sits directly under the "To Pay" label.
  final amounts = find.textContaining('₹').evaluate().where((element) {
    final box = tester.getTopLeft(find.byWidget(element.widget));
    return (box.dx - label.dx).abs() < 1 && box.dy > label.dy;
  });
  return (amounts.first.widget as Text).data!;
}

void main() {
  group('checkout — offers and savings', () {
    testWidgets('lists the three kinds of offer as distinct groups', (
      tester,
    ) async {
      final harness = _Harness(
        offers: const [_welcome50, _hotel20, _gpayCashback],
      );
      await harness.pump(tester, const CheckoutScreen());

      expect(find.text('OFFERS & SAVINGS'), findsOneWidget);
      expect(find.text('Tukkito Offers'), findsOneWidget);
      expect(find.text('Restaurant Offers'), findsOneWidget);
      expect(find.text('Payment Offers'), findsOneWidget);

      expect(find.text('WELCOME50'), findsOneWidget);
      expect(
        find.text('₹50 OFF on orders above ₹299'),
        findsOneWidget,
      );
      expect(find.text('Instant discount from Tukkito.'), findsOneWidget);
      expect(find.text('Instant discount from A2B.'), findsOneWidget);

      // The payment offer is cashback: labelled as such, and view-only.
      expect(find.text('Google Pay'), findsOneWidget);
      expect(find.text('₹50 cashback'), findsOneWidget);
      expect(find.text('Cashback'), findsOneWidget);
      expect(find.text('Instant discount'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('offer-view-gpay50')), findsOneWidget);
      expect(find.byKey(const ValueKey('offer-apply-gpay50')), findsNothing);
    });

    testWidgets('the bill and pay button show the backend price, no fee row', (
      tester,
    ) async {
      // 987.65 is not something the app could compute from this cart.
      final harness = _Harness(
        offers: const [],
        quotes: _FakeQuoteBackend(grandTotalOverride: 987.65),
      );
      await harness.pump(tester, const CheckoutScreen());

      expect(_toPay(tester), '₹987.65');
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('checkout-primary-amount')),
            )
            .data,
        ' • ₹987.65',
      );
      expect(find.text('Final Payable'), findsOneWidget);
      // Platform fee is ₹0: it is not charged and not listed.
      expect(find.text('Platform Fee'), findsNothing);
      expect(find.text('No offers available for this order.'), findsOneWidget);
    });

    testWidgets('applying a Tukkito offer shows the backend discount', (
      tester,
    ) async {
      final harness = _Harness(
        offers: const [_welcome50],
        quotes: _FakeQuoteBackend(discounts: {'welcome50': 50}),
      );
      await harness.pump(tester, const CheckoutScreen());
      expect(_toPay(tester), '₹365.50');

      await _tapKey(tester, 'offer-apply-welcome50');

      expect(harness.quotes.calls.last.offerIds, ['welcome50']);
      expect(find.text('WELCOME50 applied'), findsOneWidget);
      expect(find.text('You saved ₹50.00'), findsOneWidget);
      expect(find.text('Total Discount'), findsOneWidget);
      expect(find.text('-₹50.00'), findsWidgets);
      expect(_toPay(tester), '₹313.00');

      await _tapKey(tester, 'offer-remove');
      expect(find.text('WELCOME50 applied'), findsNothing);
      expect(_toPay(tester), '₹365.50');
    });

    testWidgets('applying a restaurant offer shows the backend discount', (
      tester,
    ) async {
      final harness = _Harness(
        offers: const [_hotel20],
        quotes: _FakeQuoteBackend(discounts: {'hotel20': 20}),
      );
      await harness.pump(tester, const CheckoutScreen());

      await _tapKey(tester, 'offer-apply-hotel20');

      expect(find.text('HOTEL20 applied'), findsOneWidget);
      expect(find.text('You saved ₹20.00'), findsOneWidget);
      expect(_toPay(tester), '₹344.50');
    });

    Future<void> expectRejected(
      WidgetTester tester, {
      required Offer offer,
      required String code,
      required String message,
    }) async {
      final harness = _Harness(
        offers: [offer],
        quotes: _FakeQuoteBackend(rejections: {offer.id: code}),
      );
      await harness.pump(tester, const CheckoutScreen());

      await _tapKey(tester, 'offer-apply-${offer.id}');

      expect(find.text(message), findsWidgets);
      expect(find.byKey(const ValueKey('offer-applied-banner')), findsNothing);
      // Back to the price without the offer, and the order can still go ahead.
      expect(_toPay(tester), '₹365.50');
      expect(harness.quotes.calls.last.offerIds, isEmpty);
    }

    testWidgets('minimum order not met', (tester) async {
      await expectRejected(
        tester,
        offer: _hotel100,
        code: 'OFFER_MIN_ORDER',
        message: 'Add ₹179 more to use this offer.',
      );
    });

    testWidgets('expired offer', (tester) async {
      await expectRejected(
        tester,
        offer: _welcome50,
        code: 'OFFER_EXPIRED',
        message: 'This offer has expired.',
      );
    });

    testWidgets('usage limit reached', (tester) async {
      await expectRejected(
        tester,
        offer: _welcome50,
        code: 'OFFER_USAGE_LIMIT',
        message: 'This offer is no longer available.',
      );
    });

    testWidgets('per-customer limit reached', (tester) async {
      await expectRejected(
        tester,
        offer: _welcome50,
        code: 'OFFER_CUSTOMER_LIMIT',
        message: 'You have already used this offer.',
      );
    });

    testWidgets('invalid offer', (tester) async {
      await expectRejected(
        tester,
        offer: _welcome50,
        code: 'OFFER_NOT_FOUND',
        message: 'That offer is not valid for this order.',
      );
    });

    testWidgets('offer not available at this restaurant', (tester) async {
      await expectRejected(
        tester,
        offer: _welcome50,
        code: 'OFFER_RESTAURANT_INELIGIBLE',
        message: 'This offer is not available at this restaurant.',
      );
    });

    testWidgets('customer not eligible (first order only)', (tester) async {
      await expectRejected(
        tester,
        offer: _welcome50,
        code: 'OFFER_NEW_CUSTOMER_ONLY',
        message: 'This offer is only for your first order.',
      );
    });

    testWidgets('a backend failure never leaves an offer looking applied', (
      tester,
    ) async {
      final harness = _Harness(offers: const [_welcome50]);
      await harness.pump(tester, const CheckoutScreen());
      harness.quotes.unavailable = true;

      await _tapKey(tester, 'offer-apply-welcome50');

      expect(find.text(OfferFailureMessages.unavailable), findsOneWidget);
      expect(find.byKey(const ValueKey('offer-applied-banner')), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('firebase'), findsNothing);
    });

    testWidgets('cashback is explained and never reduces the payable', (
      tester,
    ) async {
      final harness = _Harness(offers: const [_gpayCashback]);
      await harness.pump(tester, const CheckoutScreen());
      final before = _toPay(tester);

      await _tapKey(tester, 'offer-view-gpay50');

      expect(find.text('Offered by Google Pay'), findsOneWidget);
      expect(find.textContaining('This is cashback, not a discount'), findsOneWidget);
      // Viewing it priced nothing and changed nothing.
      expect(harness.quotes.calls.every((call) => call.offerIds.isEmpty), isTrue);
      Navigator.of(tester.element(find.text('Offered by Google Pay'))).pop();
      await tester.pumpAndSettle();
      expect(_toPay(tester), before);
      expect(find.byKey(const ValueKey('offer-applied-banner')), findsNothing);
    });

    testWidgets('a payment offer follows the selected payment method', (
      tester,
    ) async {
      final harness = _Harness(
        offers: const [_upi25],
        quotes: _FakeQuoteBackend(discounts: {'upi25': 25}),
      );
      await harness.pump(tester, const CheckoutScreen());

      await _tapKey(tester, 'payment-method-upi');
      await _tapKey(tester, 'offer-apply-upi25');
      expect(harness.quotes.calls.last.paymentMethod, 'upi');
      expect(find.text('PhonePe applied'), findsOneWidget);
      expect(find.text('Proceed to Pay'), findsOneWidget);

      // Back to cash: the backend refuses the offer and it is dropped.
      await _tapKey(tester, 'payment-method-payOnDelivery');
      expect(
        find.text('Use the eligible payment method to receive this offer.'),
        findsOneWidget,
      );
      expect(find.text('PhonePe applied'), findsNothing);
      expect(_toPay(tester), '₹365.50');
    });

    testWidgets('the order is created with the offer id, not an amount', (
      tester,
    ) async {
      final harness = _Harness(
        offers: const [_welcome50],
        quotes: _FakeQuoteBackend(discounts: {'welcome50': 50}),
      );
      await harness.pump(tester, const CheckoutScreen());
      await _tapKey(tester, 'offer-apply-welcome50');

      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(harness.orders.plainCalls, 0);
      expect(harness.orders.offerCalls.single.offerIds, ['welcome50']);
      expect(harness.orders.offerCalls.single.paymentMethod, 'pay_on_delivery');
      expect(harness.cart.clearCount, greaterThan(0));
    });

    testWidgets('an order without an offer uses the unchanged place path', (
      tester,
    ) async {
      final harness = _Harness(offers: const [_welcome50]);
      await harness.pump(tester, const CheckoutScreen());

      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(harness.orders.plainCalls, 1);
      expect(harness.orders.offerCalls, isEmpty);
    });

    testWidgets('an offer refused at order creation creates no order', (
      tester,
    ) async {
      final harness = _Harness(
        offers: const [_welcome50],
        quotes: _FakeQuoteBackend(discounts: {'welcome50': 50}),
      );
      harness.orders.error = const PlaceOrderOfferRejectedException(
        'OFFER_USAGE_LIMIT',
        'This offer is no longer available.',
      );
      await harness.pump(tester, const CheckoutScreen());
      await _tapKey(tester, 'offer-apply-welcome50');
      expect(_toPay(tester), '₹313.00');

      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(find.text('This offer is no longer available.'), findsWidgets);
      expect(find.byKey(const ValueKey('offer-applied-banner')), findsNothing);
      expect(harness.cart.clearCount, 0);
      // Re-priced without the discount before the customer can try again.
      expect(_toPay(tester), '₹365.50');
      expect(find.byType(CheckoutScreen), findsOneWidget);
    });
  });

  group('cart — offers and savings', () {
    testWidgets('shows offers; payment offers are view-only before checkout', (
      tester,
    ) async {
      final harness = _Harness(offers: const [_welcome50, _upi25]);
      await harness.pump(tester, const CartScreen());

      expect(find.text('OFFERS & SAVINGS'), findsOneWidget);
      expect(find.byKey(const ValueKey('offer-apply-welcome50')), findsOneWidget);
      expect(find.byKey(const ValueKey('offer-view-upi25')), findsOneWidget);
      expect(
        find.text('Choose the eligible payment method at checkout.'),
        findsOneWidget,
      );
      // The cart still does not present a final bill.
      expect(find.text('Bill Details'), findsNothing);
      expect(find.text('Platform Fee'), findsNothing);
      expect(find.text('Proceed to Checkout'), findsOneWidget);
    });

    testWidgets('Apply asks the backend and carries the offer to checkout', (
      tester,
    ) async {
      final harness = _Harness(
        offers: const [_welcome50],
        quotes: _FakeQuoteBackend(discounts: {'welcome50': 50}),
      );
      await harness.pump(tester, const CartScreen());

      await _tapKey(tester, 'offer-apply-welcome50');

      // The cart also asks the backend for the delivery fee (no offer);
      // exactly one request carries the offer being applied.
      expect(
        harness.quotes.calls
            .where((call) => call.offerIds.isNotEmpty)
            .single
            .offerIds,
        ['welcome50'],
      );
      expect(find.text('WELCOME50 applied'), findsOneWidget);
      expect(find.text('You saved ₹50.00'), findsOneWidget);

      await tester.tap(find.text('Proceed to Checkout'));
      await tester.pumpAndSettle();

      expect(find.byType(CheckoutScreen), findsOneWidget);
      expect(find.text('WELCOME50 applied'), findsOneWidget);
      expect(_toPay(tester), '₹313.00');
    });

    testWidgets('a refused offer is not applied in the cart', (tester) async {
      final harness = _Harness(
        offers: const [_hotel100],
        quotes: _FakeQuoteBackend(rejections: {'hotel100': 'OFFER_MIN_ORDER'}),
      );
      await harness.pump(tester, const CartScreen());

      await _tapKey(tester, 'offer-apply-hotel100');

      expect(find.text('Add ₹179 more to use this offer.'), findsWidgets);
      expect(find.byKey(const ValueKey('offer-applied-banner')), findsNothing);
    });

    testWidgets('without a delivery address the offer waits for checkout', (
      tester,
    ) async {
      final harness = _Harness(offers: const [_welcome50]);
      await harness.pump(tester, const CartScreen(), completeAddress: false);

      await _tapKey(tester, 'offer-apply-welcome50');

      expect(find.text(OfferFailureMessages.needsAddress), findsOneWidget);
      expect(harness.quotes.calls, isEmpty);
      expect(find.byKey(const ValueKey('offer-applied-banner')), findsNothing);
    });
  });
}
