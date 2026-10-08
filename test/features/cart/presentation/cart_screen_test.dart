import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:customer_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:customer_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:customer_app/features/cart/presentation/widgets/cart_destination_warning.dart';
import 'package:customer_app/features/foods/presentation/providers/food_provider.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/offers/domain/offer_failure.dart';
import 'package:customer_app/features/offers/presentation/providers/offer_providers.dart';
import 'package:customer_app/features/orders/data/datasources/checkout_quote_datasource.dart';
import 'package:customer_app/features/orders/data/datasources/order_functions_datasource.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';

import '../../../helpers/destination_fakes.dart';
import '../../../helpers/discovery_fixtures.dart';

class _FakeCartRepository implements CartRepository {
  _FakeCartRepository(this.items);

  final List<CartEntity> items;

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
  Future<void> clearCart(String userId) async {}

  @override
  Future<int> getCartItemCount(String userId) async => items.length;

  @override
  Future<double> getCartTotal(String userId) async =>
      items.fold<double>(0, (total, item) => total + item.totalPrice);
}

/// The backend's quote: a fixed delivery fee and road distance, or a refusal.
class _FakeQuoteDatasource implements CheckoutQuoteDatasource {
  _FakeQuoteDatasource({this.deliveryFee = 50, this.distanceKm = 7.9, this.failCode});

  final double deliveryFee;
  final double distanceKm;
  final String? failCode;
  int calls = 0;

  @override
  Future<CheckoutQuote> quoteOrder({
    required String restaurantId,
    required List<PlaceOrderLineRequest> items,
    required PlaceOrderDeliveryAddressRequest deliveryAddress,
    String paymentMethod = 'pay_on_delivery',
    List<String> offerIds = const [],
  }) async {
    calls += 1;
    if (failCode != null) {
      throw CheckoutQuoteUnavailableException(failCode);
    }
    return CheckoutQuote(
      itemTotal: 320,
      discount: 0,
      deliveryFee: deliveryFee,
      platformFee: 0,
      packingCharge: 0,
      gstAmount: 25,
      foodGstAmount: 16,
      packingGstAmount: 0,
      deliveryGstAmount: 9,
      platformGstAmount: 0,
      grandTotal: 395,
      distanceKm: distanceKm,
    );
  }
}

CartEntity _item() {
  return CartEntity(
    id: 'food-a',
    userId: 'user-1',
    restaurantId: 'a2b',
    restaurantName: 'A2B',
    foodId: 'food-a',
    foodName: 'Mini Meals',
    foodImage: '',
    price: 160,
    quantity: 2,
    isVeg: true,
    isAvailable: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpCart(
  WidgetTester tester, {
  required UserLocation destination,
  required List<Override> extraRestaurantAndLocation,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        cartRepositoryProvider.overrideWithValue(
          _FakeCartRepository([_item()]),
        ),
        restaurantFoodsProvider.overrideWith((ref, id) async => []),
        locationRepositoryProvider.overrideWithValue(
          FakeLocationRepository(destination),
        ),
        ...extraRestaurantAndLocation,
      ],
      child: const MaterialApp(home: CartScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final nearbyRestaurant = restaurantIn(chennai, 'a2b');

  testWidgets('cart shows the backend delivery fee for the saved address', (
    tester,
  ) async {
    final quotes = _FakeQuoteDatasource(deliveryFee: 50, distanceKm: 7.9);
    await _pumpCart(
      tester,
      destination: destinationIn(chennai),
      extraRestaurantAndLocation: [
        restaurantRepositoryProvider.overrideWithValue(
          NationwideRestaurantRepository([nearbyRestaurant]),
        ),
        serviceabilityRepositoryProvider.overrideWithValue(
          FakeServiceabilityRepository(),
        ),
        checkoutQuoteDatasourceProvider.overrideWithValue(quotes),
      ],
    );

    expect(find.text('Delivery Fee'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('cart-delivery-fee-value')))
          .data,
      '\u20B950.00',
    );
    expect(find.text('7.9 km from the restaurant'), findsOneWidget);
    expect(quotes.calls, 1);
    // No rider payout or incentive wording reaches the customer.
    expect(find.textContaining('Rider'), findsNothing);
    expect(find.textContaining('Incentive'), findsNothing);
    expect(find.textContaining('payout'), findsNothing);
  });

  testWidgets('cart explains an address beyond the delivery distance', (
    tester,
  ) async {
    await _pumpCart(
      tester,
      destination: destinationIn(chennai),
      extraRestaurantAndLocation: [
        restaurantRepositoryProvider.overrideWithValue(
          NationwideRestaurantRepository([nearbyRestaurant]),
        ),
        serviceabilityRepositoryProvider.overrideWithValue(
          FakeServiceabilityRepository(),
        ),
        checkoutQuoteDatasourceProvider.overrideWithValue(
          _FakeQuoteDatasource(failCode: 'NOT_SERVICEABLE'),
        ),
      ],
    );

    expect(
      find.text(OfferFailureMessages.beyondDeliveryDistance),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('cart-delivery-fee-value')))
          .data,
      '—',
    );
  });

  testWidgets('cart does not show the final payable bill before checkout', (
    tester,
  ) async {
    await _pumpCart(
      tester,
      destination: destinationIn(chennai),
      extraRestaurantAndLocation: [
        restaurantRepositoryProvider.overrideWithValue(
          NationwideRestaurantRepository([nearbyRestaurant]),
        ),
        serviceabilityRepositoryProvider.overrideWithValue(
          FakeServiceabilityRepository(),
        ),
      ],
    );

    expect(find.text('Mini Meals'), findsOneWidget);
    expect(find.text('Item total'), findsOneWidget);
    expect(find.text('\u20B9320.00'), findsWidgets);
    expect(find.text('Proceed to Checkout'), findsOneWidget);
    expect(find.text('Bill Details'), findsNothing);
    // The delivery fee row is shown; without a backend price it has no amount.
    expect(find.text('Delivery Fee'), findsOneWidget);
    expect(find.text('\u20B925.00'), findsNothing);
    expect(find.text('\u20B930.00'), findsNothing);
    expect(find.text('Platform Fee'), findsNothing);
    expect(find.text('GST (5%)'), findsNothing);
    expect(find.text('Grand Total'), findsNothing);
    expect(find.text('Total Payable'), findsNothing);
    expect(find.text('Packing Charges'), findsNothing);
    expect(find.text(CartDestinationWarning.outOfRangeMessage), findsNothing);
  });

  testWidgets(
    'changing destination out of restaurant range warns and keeps the cart',
    (tester) async {
      await _pumpCart(
        tester,
        destination: destinationIn(chennai),
        extraRestaurantAndLocation: [
          restaurantRepositoryProvider.overrideWithValue(
            NationwideRestaurantRepository([restaurantIn(madurai, 'a2b')]),
          ),
          serviceabilityRepositoryProvider.overrideWithValue(
            FakeServiceabilityRepository(),
          ),
        ],
      );

      expect(
        find.text(CartDestinationWarning.outOfRangeMessage),
        findsOneWidget,
      );
      expect(find.text('Mini Meals'), findsOneWidget);
      expect(find.text('Proceed to Checkout'), findsOneWidget);
    },
  );

  testWidgets('an unserved destination warns without clearing cart items', (
    tester,
  ) async {
    await _pumpCart(
      tester,
      destination: destinationIn(chennai),
      extraRestaurantAndLocation: [
        restaurantRepositoryProvider.overrideWithValue(
          NationwideRestaurantRepository([nearbyRestaurant]),
        ),
        serviceabilityRepositoryProvider.overrideWithValue(
          FakeServiceabilityRepository(zones: const []),
        ),
      ],
    );

    expect(find.text(CartDestinationWarning.notServedMessage), findsOneWidget);
    expect(find.text('Mini Meals'), findsOneWidget);
  });
}
