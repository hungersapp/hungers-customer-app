import '../../../cart/domain/entities/billing_summary.dart';
import '../../../cart/domain/entities/cart_entity.dart';
import '../../../location/domain/entities/user_location.dart';

enum OrderPaymentMethod {
  payOnDelivery,

  /// Cashfree Payment Gateway (prepaid). The order is created
  /// "awaiting_payment" and only becomes "placed" once the BACKEND verifies
  /// the payment with Cashfree — the app never marks it paid.
  upi,
  creditCard,
  debitCard,
}

extension OrderPaymentMethodX on OrderPaymentMethod {
  bool get isOnline => this != OrderPaymentMethod.payOnDelivery;

  /// `placeOrder` callable value (see place_order.ts ALLOWED_PAYMENT_METHODS).
  String get placeOrderValue {
    switch (this) {
      case OrderPaymentMethod.payOnDelivery:
        return 'pay_on_delivery';
      case OrderPaymentMethod.upi:
        return 'upi';
      case OrderPaymentMethod.creditCard:
      case OrderPaymentMethod.debitCard:
        return 'card';
    }
  }

  /// `createCustomerPayment` callable value; null for COD.
  String? get cashfreeMethodValue {
    switch (this) {
      case OrderPaymentMethod.payOnDelivery:
        return null;
      case OrderPaymentMethod.upi:
        return 'UPI';
      case OrderPaymentMethod.creditCard:
        return 'CREDIT_CARD';
      case OrderPaymentMethod.debitCard:
        return 'DEBIT_CARD';
    }
  }

  String get checkoutLabel {
    switch (this) {
      case OrderPaymentMethod.payOnDelivery:
        return 'Cash on Delivery';
      case OrderPaymentMethod.upi:
        return 'UPI';
      case OrderPaymentMethod.creditCard:
        return 'Credit Card';
      case OrderPaymentMethod.debitCard:
        return 'Debit Card';
    }
  }

  String get checkoutSubtitle {
    switch (this) {
      case OrderPaymentMethod.payOnDelivery:
        return 'Pay when your order arrives.';
      case OrderPaymentMethod.upi:
        return 'Pay using any supported UPI option';
      case OrderPaymentMethod.creditCard:
        return 'Visa, Mastercard, RuPay and more';
      case OrderPaymentMethod.debitCard:
        return 'Pay securely with your debit card';
    }
  }
}

enum OrderStatus {
  /// Online (UPI/card) order created but not yet verified as paid. Not
  /// visible to the restaurant; moves to [placed] only after the backend
  /// confirms the Cashfree payment.
  awaitingPayment,
  placed,
  confirmed,
  preparing,
  ready,
  outForDelivery,
  delivered,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.awaitingPayment:
        return 'Payment Pending';
      case OrderStatus.placed:
        return 'Order Placed';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isOngoing {
    switch (this) {
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return false;
      case OrderStatus.awaitingPayment:
      case OrderStatus.placed:
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.ready:
      case OrderStatus.outForDelivery:
        return true;
    }
  }

  bool get isPast => !isOngoing;

  bool get canReorder => isPast;
}

class PlaceOrderRequest {
  const PlaceOrderRequest({
    required this.userId,
    required this.items,
    required this.summary,
    required this.paymentMethod,
    this.deliveryLocation,
    this.orderForOther = false,
    this.recipientName,
    this.recipientPhone,
    this.offerIds = const [],
  });

  final String userId;
  final List<CartEntity> items;
  final BillingSummary summary;
  final OrderPaymentMethod paymentMethod;
  final UserLocation? deliveryLocation;

  /// Offers the customer applied. Ids only — the backend validates each one
  /// again and computes the discount when it creates the order.
  final List<String> offerIds;

  /// When true, [recipientName] and [recipientPhone] are required and
  /// [deliveryLocation] is the recipient drop-off (not the placer's profile).
  final bool orderForOther;
  final String? recipientName;
  final String? recipientPhone;
}

/// Nested `deliveryAddress` on `orders/{orderId}`.
///
/// Older documents may only have city, state, latitude, and longitude.
class OrderDeliveryAddress {
  const OrderDeliveryAddress({
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.latitude,
    this.longitude,
  });

  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final double? latitude;
  final double? longitude;
}

/// Nested `pickupLocation` on `orders/{orderId}` when present.
///
/// The Customer App does not invent restaurant coordinates at checkout.
class OrderPickupLocation {
  const OrderPickupLocation({
    this.latitude,
    this.longitude,
    this.address,
    this.restaurantName,
  });

  final double? latitude;
  final double? longitude;
  final String? address;
  final String? restaurantName;
}

class OrderLineItem {
  const OrderLineItem({
    required this.foodId,
    required this.foodName,
    required this.quantity,
    required this.price,
    this.offerPrice,
    this.foodImage = '',
    this.isVeg = true,
  });

  final String foodId;
  final String foodName;
  final int quantity;
  final double price;
  final double? offerPrice;
  final String foodImage;
  final bool isVeg;

  double get unitPrice => offerPrice ?? price;

  double get lineTotal => unitPrice * quantity;
}

class PlacedOrder {
  const PlacedOrder({
    required this.id,
    required this.userId,
    required this.restaurantName,
    required this.grandTotal,
    required this.itemCount,
    required this.createdAt,
    this.updatedAt,
    this.restaurantId = '',
    this.status = OrderStatus.placed,
    this.paymentMethod = OrderPaymentMethod.payOnDelivery,
    this.paymentStatus = 'pending',
    this.itemTotal = 0,
    this.deliveryFee = 0,
    this.platformFee = 0,
    this.gstAmount = 0,
    this.foodGstAmount,
    this.deliveryGstAmount,
    this.platformGstAmount,
    this.packingGstAmount,
    this.discount = 0,
    this.discountLines = const [],
    this.pricingVersion = '',
    this.items = const [],
    this.deliveryAddress,
    this.pickupLocation,
    this.orderForOther = false,
    this.recipientName,
    this.recipientPhone,
    this.reviewId = '',
  });

  final String id;
  final String userId;
  final String restaurantId;
  final String restaurantName;
  final double grandTotal;
  final int itemCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final OrderStatus status;
  final OrderPaymentMethod paymentMethod;
  final String paymentStatus;
  final double itemTotal;
  final double deliveryFee;
  final double platformFee;
  final double gstAmount;
  final double? foodGstAmount;
  final double? deliveryGstAmount;
  final double? platformGstAmount;
  final double? packingGstAmount;
  final double discount;
  final List<BillingDiscountLine> discountLines;
  final String pricingVersion;
  final List<OrderLineItem> items;
  final OrderDeliveryAddress? deliveryAddress;
  final OrderPickupLocation? pickupLocation;

  /// Additive: absent/false on legacy orders = deliver to placer.
  final bool orderForOther;
  final String? recipientName;
  final String? recipientPhone;
  final String reviewId;

  bool get hasReview => reviewId.trim().isNotEmpty;

  bool get canReview => status == OrderStatus.delivered && !hasReview;

  bool get hasRecipient =>
      orderForOther && (recipientName?.trim().isNotEmpty ?? false);

  bool get hasComponentGst =>
      foodGstAmount != null || deliveryGstAmount != null;

  BillingSummary get billingSummary {
    return BillingSummary(
      subtotal: itemTotal,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      discount: discount,
      taxableAmount: 0,
      cgstAmount: 0,
      sgstAmount: 0,
      igstAmount: 0,
      gstAmount: gstAmount,
      gstRate: 0.05,
      isIntraState: true,
      grandTotal: grandTotal,
      itemGstAmount: foodGstAmount ?? 0,
      deliveryGstAmount: deliveryGstAmount ?? 0,
      platformGstAmount: platformGstAmount ?? 0,
      packingGstAmount: packingGstAmount ?? 0,
      itemGstRate: 0.05,
      packingGstRate: 0.05,
      deliveryGstRate: 0.18,
      platformGstRate: 0.18,
      discountLines: discountLines,
    );
  }

  String get shortId {
    if (id.length <= 8) {
      return id.toUpperCase();
    }
    return id.substring(0, 8).toUpperCase();
  }

  String get itemsSummary {
    if (items.isNotEmpty) {
      return items
          .map((item) => '${item.foodName} \u00d7 ${item.quantity}')
          .join(', ');
    }
    return '$itemCount ${itemCount == 1 ? 'item' : 'items'}';
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case OrderPaymentMethod.payOnDelivery:
        return 'Pay on Delivery';
      case OrderPaymentMethod.upi:
      case OrderPaymentMethod.creditCard:
      case OrderPaymentMethod.debitCard:
        return isPaid
            ? '${paymentMethod.checkoutLabel} · Paid'
            : '${paymentMethod.checkoutLabel} · Payment pending';
    }
  }

  /// Server-set only (online_payments.ts after Cashfree verification).
  bool get isPaid => paymentStatus == 'paid';
}
