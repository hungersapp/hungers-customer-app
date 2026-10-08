import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/domain/entities/rider_location.dart';
import 'package:customer_app/features/orders/presentation/providers/order_provider.dart';
import 'package:customer_app/features/orders/presentation/widgets/delivery_partner_card.dart';

import '../../../helpers/fake_phone_dialer_service.dart';

void main() {
  PlacedOrder order({OrderStatus status = OrderStatus.outForDelivery}) {
    return PlacedOrder(
      id: 'order-1',
      userId: 'user-1',
      restaurantName: 'Kitchen',
      grandTotal: 200,
      itemCount: 1,
      createdAt: DateTime(2026, 9, 24),
      status: status,
    );
  }

  testWidgets('hides the rider card call icon before a rider is allowed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneDialerServiceProvider.overrideWithValue(
            FakePhoneDialerService(),
          ),
        ],
        child: MaterialApp(
          home: DeliveryPartnerCard(
            order: order(status: OrderStatus.delivered),
            tracking: const DeliveryJobRiderTracking(
              orderId: 'order-1',
              status: 'out_for_delivery',
              riderDisplayName: 'Arun',
              riderPhone: '+919111111111',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Arun'), findsOneWidget);
    expect(find.byTooltip('Call Rider'), findsNothing);
    expect(find.textContaining('9111111111'), findsNothing);
  });

  testWidgets('shows name, rating, and call after pickup', (tester) async {
    final dialer = FakePhoneDialerService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [phoneDialerServiceProvider.overrideWithValue(dialer)],
        child: MaterialApp(
          home: DeliveryPartnerCard(
            order: order(),
            tracking: const DeliveryJobRiderTracking(
              orderId: 'order-1',
              status: 'picked_up',
              riderDisplayName: 'Kavitha',
              riderRating: 4.8,
              riderPhone: '+919222222222',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Delivery Partner'), findsOneWidget);
    expect(find.text('Kavitha'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Order picked up'), findsOneWidget);
    expect(find.textContaining('9222222222'), findsNothing);

    await tester.tap(find.byTooltip('Call Rider'));
    await tester.pumpAndSettle();
    expect(dialer.calledNumbers, ['+919222222222']);
    expect(find.textContaining('9222222222'), findsNothing);
  });
}
