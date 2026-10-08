import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/cart/domain/entities/billing_summary.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/orders/data/models/order_model.dart';

/// Order-for-others must never write `users/{uid}.location`.
/// Profile persistence is gated only by DeliveryAddressEditorScreen.saveToProfile.
void main() {
  test('order create payload never includes user profile location fields', () {
    final payload = OrderModel.toCreateDocument(
      userId: 'user-1',
      restaurantId: 'a2b',
      restaurantName: 'A2B',
      summary: const BillingSummary(
        subtotal: 100,
        deliveryFee: 25,
        platformFee: 5,
        discount: 0,
        taxableAmount: 130,
        cgstAmount: 3.25,
        sgstAmount: 3.25,
        igstAmount: 0,
        gstAmount: 6.5,
        gstRate: 0.05,
        isIntraState: true,
        grandTotal: 136.5,
      ),
      items: [
        CartEntity(
          id: 'food-a',
          userId: 'user-1',
          restaurantId: 'a2b',
          restaurantName: 'A2B',
          foodId: 'food-a',
          foodName: 'Idli',
          foodImage: '',
          price: 50,
          quantity: 2,
          isVeg: true,
          isAvailable: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      deliveryLocation: UserLocation(
        latitude: 10.45,
        longitude: 79.35,
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
    );

    expect(payload.keys, isNot(contains('location')));
    expect(payload.containsKey('userLocation'), isFalse);
    expect(payload['userId'], 'user-1');
    expect(payload['deliveryAddress'], isA<Map>());
    expect(payload['recipientName'], 'Priya');
  });
}
