import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../offers/domain/offer_failure.dart';
import '../../domain/exceptions/place_order_functions_exception.dart';

/// One line item as the `placeOrder` callable expects it: only enough to
/// identify what was added to the cart. Price, name, and image are never
/// sent — the server re-reads them from `foods/{foodId}` and ignores any of
/// those fields if present, so this datasource does not send them either.
class PlaceOrderLineRequest {
  const PlaceOrderLineRequest({
    required this.foodId,
    required this.quantity,
  });

  final String foodId;
  final int quantity;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'foodId': foodId,
        'quantity': quantity,
      };
}

/// Delivery address fields as the `placeOrder` callable expects them.
/// Matches `deliveryAddress` in `super_admin/functions/src/place_order.ts`.
class PlaceOrderDeliveryAddressRequest {
  const PlaceOrderDeliveryAddressRequest({
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    required this.doorNumber,
    required this.street,
    this.area,
  });

  final String address;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;
  final String doorNumber;
  final String street;
  final String? area;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'latitude': latitude,
        'longitude': longitude,
        'doorNumber': doorNumber,
        'street': street,
        if (area != null && area!.trim().isNotEmpty) 'area': area,
      };
}

/// What the `placeOrder` callable actually returns today: `{success,
/// orderId, replayed, summary}`. It does not return restaurant name, items,
/// delivery address, or timestamps, so this result intentionally does not
/// claim to be a full `PlacedOrder` — building one is deferred to whichever
/// phase resolves that response-shape gap.
class PlaceOrderFunctionResult {
  const PlaceOrderFunctionResult({
    required this.orderId,
    required this.replayed,
    required this.itemTotal,
    required this.deliveryFee,
    required this.platformFee,
    required this.gstAmount,
    required this.grandTotal,
    required this.distanceKm,
  });

  final String orderId;
  final bool replayed;
  final double itemTotal;
  final double deliveryFee;
  final double platformFee;
  final double gstAmount;
  final double grandTotal;
  final double distanceKm;
}

/// Callable bridge to the server-authoritative `placeOrder` Cloud Function.
///
/// Live checkout uses this path. `OrderFirestoreDatasource.createOrder` is
/// unused rollback and is denied by Firestore rules.
abstract class OrderFunctionsDatasource {
  Future<PlaceOrderFunctionResult> placeOrder({
    required String restaurantId,
    required List<PlaceOrderLineRequest> items,
    required PlaceOrderDeliveryAddressRequest deliveryAddress,
    bool orderForOther = false,
    String? recipientName,
    String? recipientPhone,
    String? idempotencyKey,
    String paymentMethod = 'pay_on_delivery',
  });
}

/// Placement with offers applied. Separate from [OrderFunctionsDatasource]
/// so `placeOrder`'s signature — and every existing implementation of it —
/// stays as it is; an order without an offer never comes through here.
///
/// Only offer ids are sent. The discount is computed and re-validated by
/// the backend when it creates the order.
abstract class OfferAwareOrderFunctionsDatasource {
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
  });
}

class FirebaseOrderFunctionsDatasource
    implements OrderFunctionsDatasource, OfferAwareOrderFunctionsDatasource {
  FirebaseOrderFunctionsDatasource({
    FirebaseFunctions? functions,
  }) : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  static const String callableName = 'placeOrder';

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
  }) {
    return placeOrderWithOffers(
      restaurantId: restaurantId,
      items: items,
      deliveryAddress: deliveryAddress,
      offerIds: const [],
      orderForOther: orderForOther,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      idempotencyKey: idempotencyKey,
      paymentMethod: paymentMethod,
    );
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
    try {
      final callable = _functions.httpsCallable(callableName);
      final payload = <String, dynamic>{
        // Only online methods are sent; the server defaults to
        // pay_on_delivery, so the COD payload is unchanged.
        if (paymentMethod != 'pay_on_delivery') 'paymentMethod': paymentMethod,
        if (offerIds.isNotEmpty) 'offerIds': offerIds,
        'restaurantId': restaurantId,
        'items': items.map((item) => item.toJson()).toList(),
        'deliveryAddress': deliveryAddress.toJson(),
        'orderForOther': orderForOther,
        if (orderForOther) 'recipientName': recipientName,
        if (orderForOther) 'recipientPhone': recipientPhone,
        if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
          'idempotencyKey': idempotencyKey.trim(),
      };

      final result = await callable.call<dynamic>(payload);
      return _readResult(result.data);
    } on FirebaseFunctionsException catch (error) {
      final mapped = _mapFunctionsError(error);
      // TEMPORARY DIAGNOSTIC LOGGING — real-device order-failure
      // investigation only. Logs only the final mapped exception's type
      // name (never its message text, which can carry server-provided
      // free text) — no order/user/address data. Remove once the runtime
      // shape is confirmed.
      debugPrint('[placeOrder diagnostic] mappedException=${mapped.runtimeType}');
      throw mapped;
    }
  }

  PlaceOrderFunctionResult _readResult(dynamic data) {
    if (data is! Map) {
      throw const PlaceOrderServerException();
    }
    final map = Map<String, dynamic>.from(data);
    final rawOrderId = map['orderId'];
    final orderId = (rawOrderId is String ? rawOrderId : '').trim();
    final summaryRaw = map['summary'];
    if (orderId.isEmpty || summaryRaw is! Map) {
      throw const PlaceOrderServerException();
    }
    final summary = Map<String, dynamic>.from(summaryRaw);
    return PlaceOrderFunctionResult(
      orderId: orderId,
      replayed: map['replayed'] == true,
      itemTotal: _readDouble(summary['itemTotal']),
      deliveryFee: _readDouble(summary['deliveryFee']),
      platformFee: _readDouble(summary['platformFee']),
      gstAmount: _readDouble(summary['gstAmount']),
      grandTotal: _readDouble(summary['grandTotal']),
      distanceKm: _readDouble(summary['distanceKm']),
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  /// Maps the callable's failure surface (`error.code` plus the
  /// `{code: <DETAIL>}` payload the server attaches via `HttpsError`'s third
  /// argument, exposed here as `error.details`) to a typed
  /// [PlaceOrderFunctionsException]. `error.code` is checked first: for
  /// `permission-denied` the server currently reuses the generic
  /// `INVALID_ARGUMENT` detail label for an unrelated condition (idempotency
  /// key reuse), so the detail is only consulted for the codes where it
  /// actually distinguishes multiple business meanings.
  PlaceOrderFunctionsException _mapFunctionsError(
    FirebaseFunctionsException error,
  ) {
    // TEMPORARY DIAGNOSTIC LOGGING — V1-C runtime investigation only.
    // Logs only error.code, error.message, the runtime type of
    // error.details, and (if details is a Map) its extracted 'code'
    // field — never the raw details map, never any order/user/address
    // data. Remove once the runtime shape is confirmed.
    debugPrint(
      '[placeOrder diagnostic] code=${error.code} '
      'message=${error.message} '
      'detailsType=${error.details.runtimeType} '
      'detailsCode=${_readDetailCode(error.details)}',
    );
    switch (error.code) {
      case 'unauthenticated':
        return const PlaceOrderUnauthenticatedException();
      case 'permission-denied':
        return const PlaceOrderPermissionDeniedException();
      case 'not-found':
        return _mapNotFound(_readDetailCode(error.details));
      case 'failed-precondition':
        return _mapFailedPrecondition(_readDetailCode(error.details));
      case 'invalid-argument':
        return _mapInvalidArgument(_readDetailCode(error.details), error.message);
      default:
        return const PlaceOrderServerException();
    }
  }

  PlaceOrderFunctionsException _mapNotFound(String? detail) {
    switch (detail) {
      case 'FOOD_NOT_FOUND':
        return const PlaceOrderItemsUnavailableException();
      case 'RESTAURANT_NOT_FOUND':
      default:
        return const PlaceOrderRestaurantNotFoundException();
    }
  }

  PlaceOrderFunctionsException _mapFailedPrecondition(String? detail) {
    if (detail != null && OfferFailureMessages.rejectionCodes.contains(detail)) {
      return PlaceOrderOfferRejectedException(
        detail,
        OfferFailureMessages.forCode(detail),
      );
    }
    switch (detail) {
      case 'RESTAURANT_NOT_ACCEPTING':
        return const PlaceOrderRestaurantNotAcceptingException();
      case 'NOT_SERVICEABLE':
        return const PlaceOrderNotServiceableException();
      case 'PINCODE_NOT_SERVICEABLE':
        return const PlaceOrderPincodeNotServiceableException();
      case 'INVALID_ADDRESS':
        return const PlaceOrderInvalidAddressException();
      case 'ONLINE_PAYMENTS_UNAVAILABLE':
        return const PlaceOrderOnlinePaymentUnavailableException();
      case 'FOOD_RESTAURANT_MISMATCH':
      case 'FOOD_NOT_APPROVED':
      case 'FOOD_UNAVAILABLE':
      case 'INVALID_PRICING_DATA':
      default:
        return const PlaceOrderItemsUnavailableException();
    }
  }

  PlaceOrderFunctionsException _mapInvalidArgument(
    String? detail,
    String? message,
  ) {
    if (detail != null && OfferFailureMessages.rejectionCodes.contains(detail)) {
      return PlaceOrderOfferRejectedException(
        detail,
        OfferFailureMessages.forCode(detail),
      );
    }
    switch (detail) {
      case 'INVALID_ADDRESS':
        return const PlaceOrderInvalidAddressException();
      case 'INVALID_RECIPIENT':
        return PlaceOrderInvalidRecipientException(_cleanMessage(
          message,
          'Please check the recipient details and try again.',
        ));
      case 'INVALID_ARGUMENT':
      default:
        return PlaceOrderInvalidArgumentException(_cleanMessage(
          message,
          'This order could not be placed. Please check your details and try again.',
        ));
    }
  }

  static String _cleanMessage(String? message, String fallback) {
    final trimmed = message?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static String? _readDetailCode(dynamic details) {
    if (details is Map) {
      final code = details['code'];
      if (code is String && code.trim().isNotEmpty) {
        return code.trim();
      }
    }
    return null;
  }
}
