import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../cart/domain/entities/billing_summary.dart';
import '../../../cart/domain/entities/cart_entity.dart';
import '../../../location/domain/entities/user_location.dart';
import '../../domain/entities/placed_order.dart';

class OrderModel {
  const OrderModel._();

  static Map<String, dynamic> toCreateDocument({
    required String userId,
    required String restaurantId,
    required String restaurantName,
    required BillingSummary summary,
    required List<CartEntity> items,
    UserLocation? deliveryLocation,
    bool orderForOther = false,
    String? recipientName,
    String? recipientPhone,
  }) {
    final lineItems = items.map(_itemMap).toList();
    final itemCount = items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );

    return <String, dynamic>{
      'userId': userId,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'status': 'placed',
      'paymentMethod': 'pay_on_delivery',
      'paymentStatus': 'pending',
      'itemCount': itemCount,
      'itemTotal': summary.itemTotal,
      'deliveryFee': summary.deliveryFee,
      'platformFee': summary.platformFee,
      'gstAmount': summary.gstAmount,
      'grandTotal': summary.grandTotal,
      'items': lineItems,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'orderForOther': orderForOther,
      if (orderForOther) ...{
        'recipientName': recipientName?.trim() ?? '',
        'recipientPhone': recipientPhone?.trim() ?? '',
      },
      if (deliveryLocation != null)
        'deliveryAddress': deliveryAddressFromLocation(deliveryLocation),
    };
  }

  static Map<String, dynamic> deliveryAddressFromLocation(
    UserLocation location,
  ) {
    final detail = location.detailedAddressLine.trim();
    return <String, dynamic>{
      'address': detail.isNotEmpty ? detail : location.displayAddress,
      'city': location.city,
      'state': location.state,
      'pincode': location.pincode ?? '',
      'latitude': location.latitude,
      'longitude': location.longitude,
      if (location.doorNumber.trim().isNotEmpty)
        'doorNumber': location.doorNumber.trim(),
      if (location.street.trim().isNotEmpty) 'street': location.street.trim(),
      if (location.area.trim().isNotEmpty) 'area': location.area.trim(),
    };
  }

  static Map<String, dynamic> _itemMap(CartEntity item) {
    return {
      'foodId': item.foodId,
      'foodName': item.foodName,
      'quantity': item.quantity,
      'price': item.price,
      'offerPrice': item.offerPrice,
      'foodImage': item.foodImage,
      'isVeg': item.isVeg,
    };
  }

  static PlacedOrder fromMap(Map<String, dynamic> map, String documentId) {
    final items = _readItems(map['items']);
    final storedCount = _readInt(
      _valueForKeys(map, const ['itemCount', 'item_count']),
    );
    final itemCount = items.isEmpty
        ? storedCount
        : items.fold<int>(0, (total, item) => total + item.quantity);

    return PlacedOrder(
      id: documentId,
      userId: _readString(_valueForKeys(map, const ['userId', 'user_id'])),
      restaurantId: _readString(
        _valueForKeys(map, const ['restaurantId', 'restaurant_id']),
      ),
      restaurantName: _readString(
        _valueForKeys(map, const [
          'restaurantName',
          'restaurant_name',
        ]),
      ),
      grandTotal: _readDouble(
        _valueForKeys(map, const ['grandTotal', 'grand_total', 'total']),
      ),
      itemCount: itemCount,
      createdAt: _readDate(_valueForKeys(map, const ['createdAt', 'created_at'])),
      updatedAt: _readNullableDate(
        _valueForKeys(map, const ['updatedAt', 'updated_at']),
      ),
      status: _readStatus(_valueForKeys(map, const ['status'])),
      paymentMethod: _readPaymentMethod(
        _valueForKeys(map, const ['paymentMethod', 'payment_method']),
        paidMethod: _valueForKeys(map, const ['paidMethod']),
      ),
      paymentStatus: _readString(
        _valueForKeys(map, const ['paymentStatus', 'payment_status']),
      ),
      itemTotal: _readDouble(
        _valueForKeys(map, const ['itemTotal', 'item_total', 'subtotal']),
      ),
      deliveryFee: _readDouble(
        _valueForKeys(map, const ['deliveryFee', 'delivery_fee']),
      ),
      platformFee: _readDouble(
        _valueForKeys(map, const ['platformFee', 'platform_fee']),
      ),
      gstAmount: _readDouble(
        _valueForKeys(map, const ['gstAmount', 'gst_amount', 'gst']),
      ),
      foodGstAmount: _readNullableDouble(
        _valueForKeys(map, const ['foodGstAmount', 'food_gst_amount']),
      ),
      deliveryGstAmount: _readNullableDouble(
        _valueForKeys(map, const ['deliveryGstAmount', 'delivery_gst_amount']),
      ),
      platformGstAmount: _readNullableDouble(
        _valueForKeys(map, const ['platformGstAmount', 'platform_gst_amount']),
      ),
      packingGstAmount: _readNullableDouble(
        _valueForKeys(map, const ['packingGstAmount', 'packing_gst_amount']),
      ),
      discount: _readDouble(_valueForKeys(map, const ['discount'])),
      discountLines: _readDiscountLines(map),
      pricingVersion: _readString(
        _valueForKeys(map, const ['pricingVersion', 'pricing_version']),
      ),
      items: items,
      deliveryAddress: _readDeliveryAddress(
        _valueForKeys(map, const ['deliveryAddress', 'delivery_address']),
      ),
      pickupLocation: _readPickupLocation(
        _valueForKeys(map, const ['pickupLocation', 'pickup_location']),
      ),
      orderForOther: _readBool(
        _valueForKeys(map, const ['orderForOther', 'order_for_other']),
        false,
      ),
      recipientName: _readNullableString(
        _valueForKeys(map, const ['recipientName', 'recipient_name']),
      ),
      recipientPhone: _readNullableString(
        _valueForKeys(map, const ['recipientPhone', 'recipient_phone']),
      ),
      reviewId: _readString(
        _valueForKeys(map, const ['reviewId', 'review_id']),
      ),
    );
  }

  static List<OrderLineItem> _readItems(dynamic raw) {
    if (raw is! List) {
      return const [];
    }

    final items = <OrderLineItem>[];
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(entry);
      final name = _readString(
        _valueForKeys(map, const ['foodName', 'food_name', 'name']),
      );
      final quantity = _readInt(_valueForKeys(map, const ['quantity', 'qty']));
      if (name.isEmpty && quantity <= 0) {
        continue;
      }
      items.add(
        OrderLineItem(
          foodId: _readString(_valueForKeys(map, const ['foodId', 'food_id'])),
          foodName: name,
          quantity: quantity <= 0 ? 1 : quantity,
          price: _readDouble(_valueForKeys(map, const ['price'])),
          offerPrice: _readNullableDouble(
            _valueForKeys(map, const ['offerPrice', 'offer_price']),
          ),
          foodImage: _readString(
            _valueForKeys(map, const ['foodImage', 'food_image', 'imageUrl']),
          ),
          isVeg: _readBool(_valueForKeys(map, const ['isVeg', 'is_veg']), true),
        ),
      );
    }
    return items;
  }

  static List<BillingDiscountLine> _readDiscountLines(Map<String, dynamic> map) {
    dynamic raw = map['discounts'];
    final billing = map['billing'];
    if (billing is Map && billing['discounts'] is List) {
      raw = billing['discounts'];
    }
    if (raw is! List) {
      return const [];
    }
    final lines = <BillingDiscountLine>[];
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final line = Map<String, dynamic>.from(entry);
      final amount = _readDouble(line['amount']);
      if (amount <= 0) {
        continue;
      }
      final offerType = _readString(line['offerType']);
      lines.add(
        BillingDiscountLine(
          offerId: _readString(line['offerId']),
          offerType: offerType,
          description: _readString(line['description']).isEmpty
              ? offerType
              : _readString(line['description']),
          fundedBy: _readString(line['fundedBy']),
          amount: amount,
        ),
      );
    }
    return lines;
  }

  static OrderDeliveryAddress? _readDeliveryAddress(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    return OrderDeliveryAddress(
      address: _readNullableString(
        _valueForKeys(map, const ['address']),
      ),
      city: _readNullableString(_valueForKeys(map, const ['city'])),
      state: _readNullableString(_valueForKeys(map, const ['state'])),
      pincode: _readNullableString(
        _valueForKeys(map, const ['pincode', 'pinCode', 'pin_code']),
      ),
      latitude: _readNullableDouble(
        _valueForKeys(map, const ['latitude', 'lat']),
      ),
      longitude: _readNullableDouble(
        _valueForKeys(map, const ['longitude', 'lng', 'long']),
      ),
    );
  }

  static OrderPickupLocation? _readPickupLocation(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    return OrderPickupLocation(
      latitude: _readNullableDouble(
        _valueForKeys(map, const ['latitude', 'lat']),
      ),
      longitude: _readNullableDouble(
        _valueForKeys(map, const ['longitude', 'lng', 'long']),
      ),
      address: _readNullableString(_valueForKeys(map, const ['address'])),
      restaurantName: _readNullableString(
        _valueForKeys(map, const ['restaurantName', 'restaurant_name']),
      ),
    );
  }

  static OrderStatus _readStatus(dynamic value) {
    final raw = _readString(value).toLowerCase().replaceAll(' ', '_');
    switch (raw) {
      case 'awaiting_payment':
        return OrderStatus.awaitingPayment;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'out_for_delivery':
      case 'outfordelivery':
      case 'dispatched':
        return OrderStatus.outForDelivery;
      case 'delivered':
      case 'completed':
        return OrderStatus.delivered;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      case 'placed':
      case 'order_placed':
      default:
        return OrderStatus.placed;
    }
  }

  /// `paymentMethod` is what placeOrder stored ("upi" / "card" /
  /// "pay_on_delivery"); `paidMethod` is what Cashfree actually charged
  /// (UPI / CREDIT_CARD / DEBIT_CARD), written only by the backend.
  static OrderPaymentMethod _readPaymentMethod(dynamic value, {dynamic paidMethod}) {
    final paid = _readString(paidMethod).toUpperCase();
    switch (_readString(value).toLowerCase()) {
      case 'upi':
        return OrderPaymentMethod.upi;
      case 'card':
        return paid == 'DEBIT_CARD'
            ? OrderPaymentMethod.debitCard
            : OrderPaymentMethod.creditCard;
      default:
        return OrderPaymentMethod.payOnDelivery;
    }
  }

  static dynamic _valueForKeys(Map<String, dynamic> map, List<String> keys) {
    final lower = <String, dynamic>{
      for (final entry in map.entries) entry.key.toLowerCase(): entry.value,
    };
    for (final key in keys) {
      if (map[key] != null) {
        return map[key];
      }
      final match = lower[key.toLowerCase()];
      if (match != null) {
        return match;
      }
    }
    return null;
  }

  static String _readString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static double? _readNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    return _readDouble(value);
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static bool _readBool(dynamic value, bool fallback) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return fallback;
  }

  static DateTime _readDate(dynamic value) {
    return _readNullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _readNullableDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
