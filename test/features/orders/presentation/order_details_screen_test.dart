import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/domain/entities/rider_location.dart';
import 'package:customer_app/features/orders/domain/order_masked_call_service.dart';
import 'package:customer_app/features/orders/presentation/providers/order_provider.dart';
import 'package:customer_app/features/orders/presentation/providers/rider_location_provider.dart';
import 'package:customer_app/features/orders/presentation/screens/order_details_screen.dart';
import 'package:customer_app/features/orders/presentation/widgets/order_status_chip.dart';
import 'package:customer_app/features/orders/presentation/widgets/order_tracking_map.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_details_provider.dart';

import '../../../helpers/fake_google_maps_flutter_platform.dart';
import '../../../helpers/fake_phone_dialer_service.dart';
import '../../../helpers/fake_wakelock_plus_platform.dart';

PlacedOrder _order({
  OrderStatus status = OrderStatus.preparing,
  OrderDeliveryAddress? deliveryAddress,
  OrderPickupLocation? pickupLocation,
  List<OrderLineItem> items = const [],
  String restaurantName = 'Ammaiappar Hotel',
  String id = 'abcdef12xyz',
  String paymentStatus = 'pending',
  String reviewId = '',
}) {
  return PlacedOrder(
    id: id,
    userId: 'user-1',
    restaurantId: 'r1',
    restaurantName: restaurantName,
    grandTotal: 245,
    itemCount: items.isEmpty
        ? 1
        : items.fold<int>(0, (sum, item) => sum + item.quantity),
    createdAt: DateTime(2026, 9, 12, 19, 45),
    status: status,
    paymentStatus: paymentStatus,
    itemTotal: 200,
    gstAmount: 20,
    deliveryFee: 15,
    platformFee: 10,
    items: items,
    deliveryAddress: deliveryAddress,
    pickupLocation: pickupLocation,
    reviewId: reviewId,
  );
}

RestaurantEntity _restaurant({String phone = ''}) {
  return RestaurantEntity(
    id: 'r1',
    name: 'Ammaiappar Hotel',
    description: '',
    logoUrl: '',
    coverImageUrl: '',
    address: '1 Main Road',
    latitude: 10.79,
    longitude: 79.14,
    phone: phone,
    rating: 4,
    totalRatings: 10,
    deliveryTime: 30,
    deliveryFee: 0,
    minimumOrderAmount: 0,
    isPureVeg: false,
    isOpen: true,
    isFeatured: false,
    openingTime: '',
    closingTime: '',
    cuisines: const [],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

/// Spy for the retired masked-call path. Any call is a test failure.
class _MaskedCallSpy implements OrderMaskedCallService {
  int calls = 0;

  @override
  Future<OrderMaskedCallOutcome> callRider({required String orderId}) async {
    calls += 1;
    return const OrderMaskedCallOutcome(OrderMaskedCallResult.failed);
  }

  @override
  Future<OrderMaskedCallOutcome> callRestaurant({
    required String orderId,
  }) async {
    calls += 1;
    return const OrderMaskedCallOutcome(OrderMaskedCallResult.failed);
  }
}

DeliveryJobRiderTracking _assignedRider({
  String status = 'out_for_delivery',
  String? riderPhone = '+919222222222',
}) {
  return DeliveryJobRiderTracking(
    orderId: 'abcdef12xyz',
    status: status,
    riderPhone: riderPhone,
  );
}

Widget _wrap(
  PlacedOrder order, {
  DeliveryJobRiderTracking? tracking,
  RestaurantEntity? restaurant,
  FakePhoneDialerService? dialer,
  _MaskedCallSpy? maskedCall,
}) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('user-1'),
      restaurantDetailsProvider.overrideWith((ref, id) async => restaurant),
      if (dialer != null) phoneDialerServiceProvider.overrideWithValue(dialer),
      if (maskedCall != null)
        orderMaskedCallServiceProvider.overrideWithValue(maskedCall),
      riderTrackingProvider.overrideWith((ref, orderId) {
        return Stream<DeliveryJobRiderTracking?>.value(tracking);
      }),
    ],
    child: MaterialApp(
      home: OrderDetailsScreen(orderId: order.id, initialOrder: order),
    ),
  );
}

Future<void> _pumpDetails(
  WidgetTester tester,
  PlacedOrder order, {
  DeliveryJobRiderTracking? tracking,
  RestaurantEntity? restaurant,
  FakePhoneDialerService? dialer,
  _MaskedCallSpy? maskedCall,
}) async {
  final view = tester.view;
  view.physicalSize = const Size(800, 1600);
  view.devicePixelRatio = 1.0;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _wrap(
      order,
      tracking: tracking,
      restaurant: restaurant,
      dialer: dialer,
      maskedCall: maskedCall,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('status hero renders real status, short id, and date once', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      _order(
        items: const [
          OrderLineItem(
            foodId: 'f1',
            foodName: 'Veg Meals',
            quantity: 1,
            price: 120,
          ),
        ],
      ),
    );

    expect(find.text('TRACK YOUR ORDER'), findsOneWidget);
    expect(find.byType(OrderStatusChip), findsOneWidget);
    expect(find.text('Preparing'), findsOneWidget);
    expect(find.text('Your food is being prepared.'), findsOneWidget);
    expect(find.text('Order #ABCDEF12'), findsOneWidget);
    expect(find.text('12 Sep 2026, 7:45 PM'), findsOneWidget);
    expect(find.text('Order Status'), findsNothing);
    expect(find.text('Order Date'), findsNothing);
  });

  testWidgets('restaurant, items, bill, and payment render', (tester) async {
    await _pumpDetails(
      tester,
      _order(
        items: const [
          OrderLineItem(
            foodId: 'f1',
            foodName: 'Veg Meals',
            quantity: 2,
            price: 100,
          ),
          OrderLineItem(
            foodId: 'f2',
            foodName: 'Filter Coffee',
            quantity: 1,
            price: 40,
          ),
        ],
      ),
    );

    expect(find.text('Ammaiappar Hotel'), findsOneWidget);
    expect(find.text('Your Items'), findsOneWidget);
    expect(find.text('Bill Details'), findsOneWidget);
    expect(find.text('Final Payable'), findsOneWidget);
    expect(find.text('₹245.00'), findsWidgets);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Pay on Delivery'), findsOneWidget);
    expect(find.text('Status: pending'), findsOneWidget);
    expect(find.text('Veg Meals  \u00d7 2'), findsOneWidget);
    expect(find.text('Filter Coffee  \u00d7 1'), findsOneWidget);
  });

  testWidgets('delivery address renders when available and omitted when null', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      _order(
        deliveryAddress: const OrderDeliveryAddress(
          address: '12 Market Street',
          city: 'Pattukkottai',
          state: 'Tamil Nadu',
          pincode: '614601',
        ),
        items: const [
          OrderLineItem(foodId: 'f1', foodName: 'Idli', quantity: 1, price: 40),
        ],
      ),
    );

    expect(find.text('Delivery Address'), findsOneWidget);
    expect(find.text('Delivering to you'), findsOneWidget);
    expect(find.textContaining('12 Market Street'), findsOneWidget);
    expect(find.textContaining('Pattukkottai, Tamil Nadu'), findsOneWidget);
    expect(find.textContaining('614601'), findsOneWidget);

    await _pumpDetails(
      tester,
      _order(
        items: const [
          OrderLineItem(foodId: 'f1', foodName: 'Idli', quantity: 1, price: 40),
        ],
      ),
    );

    expect(find.text('Delivery Address'), findsNothing);
  });

  testWidgets('recipient delivery details render for order-for-others', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      PlacedOrder(
        id: 'rec1',
        userId: 'user-1',
        restaurantId: 'r1',
        restaurantName: 'Ammaiappar Hotel',
        grandTotal: 245,
        itemCount: 1,
        createdAt: DateTime(2026, 9, 12, 19, 45),
        status: OrderStatus.preparing,
        paymentStatus: 'pending',
        itemTotal: 200,
        gstAmount: 20,
        deliveryFee: 15,
        platformFee: 10,
        items: const [
          OrderLineItem(foodId: 'f1', foodName: 'Idli', quantity: 1, price: 40),
        ],
        orderForOther: true,
        recipientName: 'Priya',
        recipientPhone: '9876543210',
        deliveryAddress: const OrderDeliveryAddress(
          address: '44 Beach Road',
          city: 'Chennai',
          state: 'TN',
          pincode: '600001',
        ),
      ),
    );

    expect(find.text('Delivering to recipient'), findsOneWidget);
    expect(find.text('Priya'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.textContaining('44 Beach Road'), findsOneWidget);
  });

  testWidgets('reorder appears only for past orders', (tester) async {
    await _pumpDetails(
      tester,
      _order(
        status: OrderStatus.preparing,
        items: const [
          OrderLineItem(foodId: 'f1', foodName: 'Dosa', quantity: 1, price: 60),
        ],
      ),
    );
    expect(find.text('Reorder'), findsNothing);

    await _pumpDetails(
      tester,
      _order(
        status: OrderStatus.delivered,
        items: const [
          OrderLineItem(foodId: 'f1', foodName: 'Dosa', quantity: 1, price: 60),
        ],
      ),
    );
    expect(find.text('Reorder'), findsOneWidget);
    expect(find.text('Your order has been delivered.'), findsOneWidget);
    expect(find.text('Rate Your Order'), findsOneWidget);
  });

  testWidgets('cancelled status message renders', (tester) async {
    await _pumpDetails(
      tester,
      _order(
        status: OrderStatus.cancelled,
        items: const [
          OrderLineItem(
            foodId: 'f1',
            foodName: 'Pizza',
            quantity: 1,
            price: 180,
          ),
        ],
      ),
    );

    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('This order was cancelled.'), findsOneWidget);
    expect(find.text('Reorder'), findsOneWidget);
  });

  testWidgets('long food names do not overflow layout', (tester) async {
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        fail(details.toString());
      }
      FlutterError.presentError(details);
    };

    await _pumpDetails(
      tester,
      _order(
        items: const [
          OrderLineItem(
            foodId: 'f1',
            foodName:
                'Extra Long Special Festival Combo Meal With Many Words And More',
            quantity: 3,
            price: 199,
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Extra Long Special'), findsOneWidget);
  });

  group('screen-awake wakelock', () {
    late FakeWakelockPlusPlatform fake;

    setUp(() {
      fake = FakeWakelockPlusPlatform();
      wakelockPlusPlatformInstance = fake;
    });

    testWidgets(
      'an ongoing (out for delivery) order keeps the screen awake while tracking',
      (tester) async {
        await _pumpDetails(tester, _order(status: OrderStatus.outForDelivery));

        expect(fake.isEnabledNow, isTrue);
      },
    );

    testWidgets(
      'a terminal (delivered) order never enables the screen-awake wakelock',
      (tester) async {
        await _pumpDetails(tester, _order(status: OrderStatus.delivered));

        expect(fake.isEnabledNow, isFalse);
      },
    );

    testWidgets(
      'leaving the order-tracking screen disables the wakelock (no leaks)',
      (tester) async {
        await _pumpDetails(tester, _order(status: OrderStatus.outForDelivery));
        expect(fake.isEnabledNow, isTrue);

        // Navigate away entirely — the tracking screen is disposed.
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('elsewhere'))),
        );
        await tester.pumpAndSettle();

        expect(
          fake.isEnabledNow,
          isFalse,
          reason:
              'no wakelock may remain enabled after leaving the tracking screen',
        );
      },
    );
  });

  group('call actions (Call Rider is the only call)', () {
    List<OrderLineItem> idli() => const [
      OrderLineItem(foodId: 'f1', foodName: 'Idli', quantity: 1, price: 40),
    ];

    Future<void> tapCallRider(
      WidgetTester tester, {
      String? riderPhone = '+919222222222',
      bool dialerSucceeds = true,
      OrderStatus status = OrderStatus.outForDelivery,
      _MaskedCallSpy? spy,
      FakePhoneDialerService? dialer,
    }) async {
      await _pumpDetails(
        tester,
        _order(status: status, items: idli()),
        tracking: _assignedRider(riderPhone: riderPhone),
        dialer: dialer ?? FakePhoneDialerService(succeeds: dialerSucceeds),
        maskedCall: spy,
      );
      await tester.tap(find.byTooltip('Call Rider'));
      await tester.pumpAndSettle();
    }

    testWidgets('Call Rider is visible with an active rider assignment', (
      tester,
    ) async {
      await _pumpDetails(
        tester,
        _order(status: OrderStatus.outForDelivery, items: idli()),
        tracking: _assignedRider(),
      );

      expect(find.byTooltip('Call Rider'), findsOneWidget);
    });

    testWidgets('tapping Call Rider dials the rider number via tel:', (
      tester,
    ) async {
      final dialer = FakePhoneDialerService();
      await tapCallRider(tester, riderPhone: '+919222222222', dialer: dialer);

      expect(dialer.calledNumbers, ['+919222222222']);
      expect(find.text('Rider phone number unavailable.'), findsNothing);
      expect(
        find.text('Unable to open the phone dialer. Please try again.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an already-formatted number is passed through unchanged', (
      tester,
    ) async {
      final dialer = FakePhoneDialerService();
      await tapCallRider(tester, riderPhone: '09222222222', dialer: dialer);

      expect(dialer.calledNumbers, ['09222222222']);
    });

    testWidgets('the rider phone number is never rendered as text', (
      tester,
    ) async {
      final dialer = FakePhoneDialerService();
      await _pumpDetails(
        tester,
        _order(status: OrderStatus.outForDelivery, items: idli()),
        tracking: _assignedRider(riderPhone: '+919222222222'),
        dialer: dialer,
      );
      expect(find.textContaining('9222222222'), findsNothing);

      await tester.tap(find.byTooltip('Call Rider'));
      await tester.pumpAndSettle();

      expect(find.textContaining('9222222222'), findsNothing);
      expect(find.textContaining(RegExp(r'\+?\d{10}')), findsNothing);
    });

    testWidgets('Call Rider is shown for an assigned rider before pickup', (
      tester,
    ) async {
      await _pumpDetails(
        tester,
        _order(status: OrderStatus.ready, items: idli()),
        tracking: _assignedRider(status: 'assigned'),
      );

      expect(find.byTooltip('Call Rider'), findsOneWidget);
    });

    testWidgets('Call Rider is hidden when no rider is assigned', (
      tester,
    ) async {
      // No readable delivery job at all.
      await _pumpDetails(
        tester,
        _order(status: OrderStatus.outForDelivery, items: idli()),
      );
      expect(find.byTooltip('Call Rider'), findsNothing);

      // Order still waiting for a rider.
      await _pumpDetails(
        tester,
        _order(status: OrderStatus.preparing, items: idli()),
      );
      expect(find.byTooltip('Call Rider'), findsNothing);

      // A delivery job that is no longer active.
      await _pumpDetails(
        tester,
        _order(status: OrderStatus.outForDelivery, items: idli()),
        tracking: _assignedRider(status: 'delivered'),
      );
      expect(find.byTooltip('Call Rider'), findsNothing);
    });

    testWidgets('Call Rider is hidden for delivered and cancelled orders', (
      tester,
    ) async {
      for (final status in [OrderStatus.delivered, OrderStatus.cancelled]) {
        await _pumpDetails(
          tester,
          _order(status: status, items: idli()),
          tracking: _assignedRider(),
        );
        expect(find.byTooltip('Call Rider'), findsNothing, reason: '$status');
      }
    });

    testWidgets('missing rider phone shows a safe message and never dials', (
      tester,
    ) async {
      for (final phone in [null, '', '   ']) {
        final dialer = FakePhoneDialerService();
        await tapCallRider(tester, riderPhone: phone, dialer: dialer);

        expect(dialer.calledNumbers, isEmpty);
        expect(find.text('Rider phone number unavailable.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('dialer failure shows a safe message and does not crash', (
      tester,
    ) async {
      await tapCallRider(tester, dialerSucceeds: false);

      expect(
        find.text('Unable to open the phone dialer. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the retired masked-call service is never invoked', (
      tester,
    ) async {
      final spy = _MaskedCallSpy();
      await tapCallRider(tester, spy: spy);
      await tapCallRider(tester, riderPhone: null, spy: spy);

      expect(spy.calls, 0);
    });

    testWidgets('there is no Call Restaurant action in any order state', (
      tester,
    ) async {
      for (final status in OrderStatus.values) {
        await _pumpDetails(
          tester,
          _order(status: status, items: idli()),
          tracking: status == OrderStatus.outForDelivery
              ? _assignedRider()
              : null,
          restaurant: _restaurant(phone: '+914312345678'),
        );
        expect(find.text('Call Restaurant'), findsNothing, reason: '$status');
        expect(find.textContaining('Call Customer'), findsNothing);
        expect(find.textContaining('Call Support'), findsNothing);
      }
    });
  });

  testWidgets(
    'tracking map uses order pickup and snapshotted delivery coords',
    (tester) async {
      final original = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = original);

      await _pumpDetails(
        tester,
        _order(
          status: OrderStatus.outForDelivery,
          pickupLocation: const OrderPickupLocation(
            latitude: 10.79,
            longitude: 79.14,
            restaurantName: 'Ammaiappar Hotel',
          ),
          deliveryAddress: const OrderDeliveryAddress(
            address: '12 Market Street',
            city: 'Pattukkottai',
            state: 'Tamil Nadu',
            pincode: '614601',
            latitude: 10.80,
            longitude: 79.15,
          ),
          items: const [
            OrderLineItem(
              foodId: 'f1',
              foodName: 'Idli',
              quantity: 1,
              price: 40,
            ),
          ],
        ),
      );

      expect(find.byType(OrderTrackingMap), findsOneWidget);
      // No delivery job readable => no assigned rider => no Call Rider.
      expect(find.byTooltip('Call Rider'), findsNothing);
    },
  );

  testWidgets('delivered orders keep the existing status-only tracking UI', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      _order(
        status: OrderStatus.delivered,
        pickupLocation: const OrderPickupLocation(
          latitude: 10.79,
          longitude: 79.14,
        ),
        deliveryAddress: const OrderDeliveryAddress(
          latitude: 10.80,
          longitude: 79.15,
        ),
        items: const [
          OrderLineItem(foodId: 'f1', foodName: 'Idli', quantity: 1, price: 40),
        ],
      ),
    );

    expect(find.byType(OrderTrackingMap), findsNothing);
    expect(find.text('Your order has been delivered.'), findsOneWidget);
    expect(find.text('Rate Your Order'), findsOneWidget);
  });

  testWidgets('a reviewed delivered order shows Reviewed instead of Rate', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      _order(
        status: OrderStatus.delivered,
        reviewId: 'abcdef12xyz_user-1',
        items: const [
          OrderLineItem(foodId: 'f1', foodName: 'Idli', quantity: 1, price: 40),
        ],
      ),
    );

    expect(find.text('✓ Reviewed'), findsOneWidget);
    expect(find.text('Rate Your Order'), findsNothing);
  });

  testWidgets('Stage A shows the map when a rider is assigned with GPS', (
    tester,
  ) async {
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);

    await _pumpDetails(
      tester,
      _order(
        status: OrderStatus.ready,
        pickupLocation: const OrderPickupLocation(
          latitude: 10.79,
          longitude: 79.14,
          restaurantName: 'Ammaiappar Hotel',
        ),
      ),
      tracking: DeliveryJobRiderTracking(
        orderId: 'abcdef12xyz',
        status: 'assigned',
        riderLocation: RiderLocation(
          latitude: 10.78,
          longitude: 79.13,
          updatedAt: DateTime.now(),
        ),
      ),
    );

    expect(find.byType(OrderTrackingMap), findsOneWidget);
  });

  testWidgets(
    'no assigned rider keeps the restaurant map without a rider pin',
    (tester) async {
      final original = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = original);

      await _pumpDetails(
        tester,
        _order(
          status: OrderStatus.ready,
          pickupLocation: const OrderPickupLocation(
            latitude: 10.79,
            longitude: 79.14,
          ),
        ),
      );

      expect(find.byType(OrderTrackingMap), findsOneWidget);
    },
  );

  testWidgets('Stage B keeps the map after out_for_delivery with live GPS', (
    tester,
  ) async {
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);

    await _pumpDetails(
      tester,
      _order(
        status: OrderStatus.outForDelivery,
        pickupLocation: const OrderPickupLocation(
          latitude: 10.79,
          longitude: 79.14,
        ),
        deliveryAddress: const OrderDeliveryAddress(
          latitude: 10.80,
          longitude: 79.15,
        ),
      ),
      tracking: DeliveryJobRiderTracking(
        orderId: 'abcdef12xyz',
        status: 'out_for_delivery',
        riderLocation: RiderLocation(
          latitude: 10.795,
          longitude: 79.145,
          updatedAt: DateTime.now(),
        ),
      ),
    );

    expect(find.byType(OrderTrackingMap), findsOneWidget);
  });

  testWidgets('delivered tracking status hides the live map', (tester) async {
    await _pumpDetails(
      tester,
      _order(
        status: OrderStatus.outForDelivery,
        pickupLocation: const OrderPickupLocation(
          latitude: 10.79,
          longitude: 79.14,
        ),
        deliveryAddress: const OrderDeliveryAddress(
          latitude: 10.80,
          longitude: 79.15,
        ),
      ),
      tracking: const DeliveryJobRiderTracking(
        orderId: 'abcdef12xyz',
        status: 'delivered',
      ),
    );

    expect(find.byType(OrderTrackingMap), findsNothing);
  });
}
