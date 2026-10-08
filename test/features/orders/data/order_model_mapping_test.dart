import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/cart/domain/entities/billing_summary.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/orders/data/models/order_model.dart';
import 'package:customer_app/features/orders/domain/entities/placed_order.dart';

BillingSummary _summary() {
  return const BillingSummary(
    subtotal: 419,
    deliveryFee: 30,
    platformFee: 5,
    discount: 0,
    taxableAmount: 454,
    cgstAmount: 11.35,
    sgstAmount: 11.35,
    igstAmount: 0,
    gstAmount: 22.70,
    gstRate: 0.05,
    isIntraState: true,
    grandTotal: 476.70,
  );
}

CartEntity _item() {
  return CartEntity(
    id: 'food-a',
    userId: 'user-1',
    restaurantId: 'a2b',
    restaurantName: 'A2B Restaurant',
    foodId: 'food-a',
    foodName: 'Mini Meals',
    foodImage: 'https://example.com/mini.jpg',
    price: 160,
    offerPrice: 150,
    quantity: 2,
    isVeg: true,
    isAvailable: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

UserLocation _location() {
  return UserLocation(
    latitude: 10.423,
    longitude: 79.319,
    city: 'Pattukkottai',
    state: 'Tamil Nadu',
    updatedAt: DateTime(2026, 9, 1),
    pincode: '614601',
  );
}

void main() {
  group('OrderModel.toCreateDocument', () {
    test('writes createdAt and updatedAt as server timestamps', () {
      final payload = OrderModel.toCreateDocument(
        userId: 'user-1',
        restaurantId: 'a2b',
        restaurantName: 'A2B Restaurant',
        summary: _summary(),
        items: [_item()],
        deliveryLocation: _location(),
      );

      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['updatedAt'], isA<FieldValue>());
      expect(payload['createdAt'], isNot(isA<DateTime>()));
      expect(payload['updatedAt'], isNot(isA<Timestamp>()));
      expect(payload.containsKey('pickupLocation'), isFalse);
      expect(payload.containsKey('deliveryPartnerId'), isFalse);
      expect(payload.containsKey('dispatch'), isFalse);
      expect(payload['status'], 'placed');
      expect(payload['userId'], 'user-1');
      expect(payload['restaurantId'], 'a2b');
      expect(payload['restaurantName'], 'A2B Restaurant');
      expect(payload['paymentMethod'], 'pay_on_delivery');
      expect(payload['paymentStatus'], 'pending');
      expect(payload['itemCount'], 2);
      expect(payload['itemTotal'], 419);
      expect(payload['deliveryFee'], 30);
      expect(payload['platformFee'], 5);
      expect(payload['gstAmount'], 22.70);
      expect(payload['grandTotal'], 476.70);
    });

    test('writes the full delivery address without fabricating pickup', () {
      final payload = OrderModel.toCreateDocument(
        userId: 'user-1',
        restaurantId: 'a2b',
        restaurantName: 'A2B Restaurant',
        summary: _summary(),
        items: [_item()],
        deliveryLocation: _location(),
      );

      expect(payload['deliveryAddress'], {
        'address': 'Pattukkottai, Tamil Nadu · 614601',
        'city': 'Pattukkottai',
        'state': 'Tamil Nadu',
        'pincode': '614601',
        'latitude': 10.423,
        'longitude': 79.319,
      });
    });

    test('omits deliveryAddress when location is missing and still places', () {
      final payload = OrderModel.toCreateDocument(
        userId: 'user-1',
        restaurantId: 'a2b',
        restaurantName: 'A2B Restaurant',
        summary: _summary(),
        items: [_item()],
      );

      expect(payload.containsKey('deliveryAddress'), isFalse);
      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['updatedAt'], isA<FieldValue>());
    });

    test(
      'writes order-for-others recipient fields into the order document',
      () {
        final payload = OrderModel.toCreateDocument(
          userId: 'user-1',
          restaurantId: 'a2b',
          restaurantName: 'A2B Restaurant',
          summary: _summary(),
          items: [_item()],
          deliveryLocation: UserLocation(
            latitude: 10.45,
            longitude: 79.35,
            city: 'Chennai',
            state: 'TN',
            updatedAt: DateTime(2026, 9, 1),
            pincode: '600001',
            doorNumber: '9',
            street: 'Beach Road',
            area: 'Besant Nagar',
          ),
          orderForOther: true,
          recipientName: 'Priya',
          recipientPhone: '9876543210',
        );

        expect(payload['orderForOther'], isTrue);
        expect(payload['recipientName'], 'Priya');
        expect(payload['recipientPhone'], '9876543210');
        expect(payload['userId'], 'user-1');
        expect(payload['deliveryAddress']['latitude'], 10.45);
        expect(payload['deliveryAddress']['longitude'], 79.35);
        expect(payload.containsKey('users'), isFalse);
      },
    );

    test('deliver-to-me omits recipient name and phone keys', () {
      final payload = OrderModel.toCreateDocument(
        userId: 'user-1',
        restaurantId: 'a2b',
        restaurantName: 'A2B Restaurant',
        summary: _summary(),
        items: [_item()],
        deliveryLocation: _location(),
        orderForOther: false,
      );

      expect(payload['orderForOther'], isFalse);
      expect(payload.containsKey('recipientName'), isFalse);
      expect(payload.containsKey('recipientPhone'), isFalse);
    });

    test('preserves existing item field names', () {
      final payload = OrderModel.toCreateDocument(
        userId: 'user-1',
        restaurantId: 'a2b',
        restaurantName: 'A2B Restaurant',
        summary: _summary(),
        items: [_item()],
      );

      expect(payload['items'], [
        {
          'foodId': 'food-a',
          'foodName': 'Mini Meals',
          'quantity': 2,
          'price': 160,
          'offerPrice': 150,
          'foodImage': 'https://example.com/mini.jpg',
          'isVeg': true,
        },
      ]);
    });
  });

  group('OrderModel.fromMap', () {
    test('maps a Firestore order document for the customer', () {
      final order = OrderModel.fromMap({
        'userId': 'user-1',
        'restaurantId': 'a2b',
        'restaurantName': 'A2B Restaurant',
        'status': 'placed',
        'paymentMethod': 'pay_on_delivery',
        'itemCount': 3,
        'itemTotal': 419,
        'gstAmount': 22.70,
        'deliveryFee': 30,
        'platformFee': 5,
        'grandTotal': 476.70,
        'createdAt': DateTime(2026, 8, 16, 13, 5),
        'items': [
          {
            'foodId': 'food-a',
            'foodName': 'Mini Meals',
            'quantity': 2,
            'price': 160,
            'isVeg': true,
          },
          {
            'foodId': 'food-b',
            'foodName': 'Food B',
            'quantity': 1,
            'price': 99,
            'isVeg': true,
          },
        ],
      }, 'order-abc12345');

      expect(order.userId, 'user-1');
      expect(order.restaurantName, 'A2B Restaurant');
      expect(order.items.length, 2);
      expect(order.items.first.foodName, 'Mini Meals');
      expect(order.items.last.foodName, 'Food B');
      expect(order.itemCount, 3);
      expect(order.grandTotal, 476.70);
      expect(order.status, OrderStatus.placed);
      expect(order.itemsSummary, 'Mini Meals \u00d7 2, Food B \u00d7 1');
    });

    test('maps a full delivery address', () {
      final order = OrderModel.fromMap({
        'userId': 'user-1',
        'createdAt': DateTime(2026, 8, 16),
        'updatedAt': DateTime(2026, 8, 16, 14),
        'deliveryAddress': {
          'address': '12 Market Street, Pattukkottai, Tamil Nadu · 614601',
          'city': 'Pattukkottai',
          'state': 'Tamil Nadu',
          'pincode': '614601',
          'latitude': 10.423,
          'longitude': 79.319,
        },
      }, 'order-1');

      expect(order.deliveryAddress?.address, contains('12 Market Street'));
      expect(order.deliveryAddress?.city, 'Pattukkottai');
      expect(order.deliveryAddress?.state, 'Tamil Nadu');
      expect(order.deliveryAddress?.pincode, '614601');
      expect(order.deliveryAddress?.latitude, 10.423);
      expect(order.deliveryAddress?.longitude, 79.319);
      expect(order.updatedAt, DateTime(2026, 8, 16, 14));
    });

    test(
      'maps an old deliveryAddress with only city state and coordinates',
      () {
        final order = OrderModel.fromMap({
          'userId': 'user-1',
          'createdAt': DateTime(2026, 8, 16),
          'deliveryAddress': {
            'city': 'Pattukkottai',
            'state': 'Tamil Nadu',
            'latitude': 10.4,
            'longitude': 79.3,
          },
        }, 'legacy-1');

        expect(order.deliveryAddress?.city, 'Pattukkottai');
        expect(order.deliveryAddress?.state, 'Tamil Nadu');
        expect(order.deliveryAddress?.latitude, 10.4);
        expect(order.deliveryAddress?.longitude, 79.3);
        expect(order.deliveryAddress?.address, isNull);
        expect(order.deliveryAddress?.pincode, isNull);
        expect(order.updatedAt, isNull);
        expect(order.pickupLocation, isNull);
      },
    );

    test('missing updatedAt and pickupLocation do not crash', () {
      final order = OrderModel.fromMap({
        'userId': 'user-1',
        'restaurantName': 'A2B Restaurant',
        'status': 'placed',
      }, 'sparse-1');

      expect(order.updatedAt, isNull);
      expect(order.pickupLocation, isNull);
      expect(order.deliveryAddress, isNull);
      expect(order.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('legacy orders without recipient fields remain readable', () {
      final order = OrderModel.fromMap({
        'userId': 'user-1',
        'restaurantName': 'A2B Restaurant',
        'status': 'delivered',
        'grandTotal': 100,
      }, 'legacy-1');

      expect(order.orderForOther, isFalse);
      expect(order.recipientName, isNull);
      expect(order.recipientPhone, isNull);
      expect(order.hasRecipient, isFalse);
    });

    test('maps order-for-others recipient fields', () {
      final order = OrderModel.fromMap({
        'userId': 'user-1',
        'orderForOther': true,
        'recipientName': 'Priya',
        'recipientPhone': '9876543210',
        'deliveryAddress': {
          'address': '9 Beach Road',
          'city': 'Chennai',
          'latitude': 10.45,
          'longitude': 79.35,
        },
      }, 'other-1');

      expect(order.orderForOther, isTrue);
      expect(order.recipientName, 'Priya');
      expect(order.recipientPhone, '9876543210');
      expect(order.hasRecipient, isTrue);
      expect(order.deliveryAddress?.latitude, 10.45);
    });

    test('maps pickupLocation when present without requiring it on create', () {
      final order = OrderModel.fromMap({
        'userId': 'user-1',
        'pickupLocation': {
          'latitude': 10.79,
          'longitude': 79.14,
          'address': 'Restaurant Street',
          'restaurantName': 'A2B Restaurant',
        },
      }, 'with-pickup');

      expect(order.pickupLocation?.latitude, 10.79);
      expect(order.pickupLocation?.longitude, 79.14);
      expect(order.pickupLocation?.address, 'Restaurant Street');
      expect(order.pickupLocation?.restaurantName, 'A2B Restaurant');
    });

    test('maps delivered and cancelled statuses as past orders', () {
      expect(
        OrderModel.fromMap({
          'status': 'delivered',
          'userId': 'u',
        }, '1').status.isPast,
        isTrue,
      );
      expect(
        OrderModel.fromMap({
          'status': 'cancelled',
          'userId': 'u',
        }, '2').status.isPast,
        isTrue,
      );
      expect(
        OrderModel.fromMap({
          'status': 'preparing',
          'userId': 'u',
        }, '3').status.isOngoing,
        isTrue,
      );
    });

    test('keeps existing status aliases unchanged', () {
      expect(
        OrderModel.fromMap({'status': 'out_for_delivery'}, 'a').status,
        OrderStatus.outForDelivery,
      );
      expect(
        OrderModel.fromMap({'status': 'dispatched'}, 'b').status,
        OrderStatus.outForDelivery,
      );
      expect(
        OrderModel.fromMap({'status': 'completed'}, 'c').status,
        OrderStatus.delivered,
      );
      expect(
        OrderModel.fromMap({'status': 'canceled'}, 'd').status,
        OrderStatus.cancelled,
      );
      expect(
        OrderModel.fromMap({'status': 'order_placed'}, 'e').status,
        OrderStatus.placed,
      );
    });

    test('keeps existing item mapping unchanged', () {
      final order = OrderModel.fromMap({
        'items': [
          {
            'food_id': 'food-a',
            'food_name': 'Mini Meals',
            'qty': 2,
            'price': 160,
            'offer_price': 140,
            'food_image': 'img.png',
            'is_veg': false,
          },
        ],
      }, 'alias-items');

      expect(order.items.single.foodId, 'food-a');
      expect(order.items.single.foodName, 'Mini Meals');
      expect(order.items.single.quantity, 2);
      expect(order.items.single.price, 160);
      expect(order.items.single.offerPrice, 140);
      expect(order.items.single.foodImage, 'img.png');
      expect(order.items.single.isVeg, isFalse);
    });
  });

  group('Cashfree online payment mapping', () {
    Map<String, dynamic> base(Map<String, dynamic> overrides) => {
      'userId': 'user-1',
      'restaurantId': 'a2b',
      'restaurantName': 'A2B Restaurant',
      'itemCount': 1,
      'grandTotal': 487,
      'createdAt': DateTime(2026, 9, 27, 10),
      ...overrides,
    };

    test('awaiting_payment is its own status, never shown as Order Placed', () {
      final order = OrderModel.fromMap(
        base({
          'status': 'awaiting_payment',
          'paymentMethod': 'upi',
          'paymentStatus': 'pending',
        }),
        'order-online-1',
      );
      expect(order.status, OrderStatus.awaitingPayment);
      expect(order.status.label, 'Payment Pending');
      expect(order.paymentMethod, OrderPaymentMethod.upi);
      expect(order.isPaid, isFalse);
      expect(order.paymentMethodLabel, 'UPI · Payment pending');
    });

    test(
      'a server-verified card payment reads as paid with the charged card type',
      () {
        final order = OrderModel.fromMap(
          base({
            'status': 'placed',
            'paymentMethod': 'card',
            'paymentStatus': 'paid',
            'paidMethod': 'DEBIT_CARD',
          }),
          'order-online-1',
        );
        expect(order.status, OrderStatus.placed);
        expect(order.paymentMethod, OrderPaymentMethod.debitCard);
        expect(order.isPaid, isTrue);
        expect(order.paymentMethodLabel, 'Debit Card · Paid');
      },
    );

    test('COD orders keep mapping to Pay on Delivery', () {
      final order = OrderModel.fromMap(
        base({'status': 'placed', 'paymentMethod': 'pay_on_delivery'}),
        'order-online-1',
      );
      expect(order.paymentMethod, OrderPaymentMethod.payOnDelivery);
      expect(order.paymentMethodLabel, 'Pay on Delivery');
    });

    test('placeOrder / Cashfree wire values', () {
      expect(OrderPaymentMethod.upi.placeOrderValue, 'upi');
      expect(OrderPaymentMethod.creditCard.placeOrderValue, 'card');
      expect(OrderPaymentMethod.debitCard.placeOrderValue, 'card');
      expect(
        OrderPaymentMethod.payOnDelivery.placeOrderValue,
        'pay_on_delivery',
      );
      expect(OrderPaymentMethod.creditCard.cashfreeMethodValue, 'CREDIT_CARD');
      expect(OrderPaymentMethod.debitCard.cashfreeMethodValue, 'DEBIT_CARD');
      expect(OrderPaymentMethod.upi.cashfreeMethodValue, 'UPI');
      expect(OrderPaymentMethod.payOnDelivery.cashfreeMethodValue, isNull);
    });
  });
}
