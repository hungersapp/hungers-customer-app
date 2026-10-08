import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/domain/order_contact_visibility.dart';

void main() {
  group('Call Rider visibility (the only customer call action)', () {
    test('shown for an ongoing order with an active rider assignment', () {
      for (final status in [OrderStatus.ready, OrderStatus.outForDelivery]) {
        expect(
          OrderContactVisibility.showRiderCall(
            status: status,
            hasActiveRiderAssignment: true,
          ),
          isTrue,
          reason: '$status',
        );
      }
    });

    test('hidden without an active rider assignment, in every state', () {
      for (final status in OrderStatus.values) {
        expect(
          OrderContactVisibility.showRiderCall(
            status: status,
            hasActiveRiderAssignment: false,
          ),
          isFalse,
          reason: '$status',
        );
      }
    });

    test('hidden for delivered and cancelled orders even if a job lingers', () {
      for (final status in [OrderStatus.delivered, OrderStatus.cancelled]) {
        expect(
          OrderContactVisibility.showRiderCall(
            status: status,
            hasActiveRiderAssignment: true,
          ),
          isFalse,
          reason: '$status',
        );
      }
    });
  });
}
