import 'package:cloud_functions/cloud_functions.dart';

import '../../../cart/domain/entities/billing_summary.dart';
import '../../../offers/domain/offer_failure.dart';
import 'order_functions_datasource.dart';

/// The backend's price for a cart, from the `quoteOrder` callable. It runs
/// the same code as `placeOrder` (live item prices, offer validation,
/// delivery fee, GST) without creating an order, so the amount shown at
/// checkout is the amount the order will be created with.
///
/// The delivery fee is the backend's alone: it is looked up from the road
/// distance between the restaurant and the address. The app has no delivery
/// rate of its own and never estimates one.
class CheckoutQuote {
  const CheckoutQuote({
    required this.itemTotal,
    required this.discount,
    required this.deliveryFee,
    required this.platformFee,
    required this.packingCharge,
    required this.gstAmount,
    required this.foodGstAmount,
    required this.packingGstAmount,
    required this.deliveryGstAmount,
    required this.platformGstAmount,
    required this.grandTotal,
    this.distanceKm,
    this.discountLines = const [],
    this.cashbackLines = const [],
  });

  /// Road distance restaurant → address the delivery fee was priced on.
  final double? distanceKm;

  final double itemTotal;
  final double discount;
  final double deliveryFee;
  final double platformFee;
  final double packingCharge;
  final double gstAmount;
  final double foodGstAmount;
  final double packingGstAmount;
  final double deliveryGstAmount;
  final double platformGstAmount;
  final double grandTotal;
  final List<BillingDiscountLine> discountLines;

  /// Earned after payment; never part of [discount] or [grandTotal].
  final List<BillingDiscountLine> cashbackLines;

  /// The bill to display. Amounts are the server's; [preview] only supplies
  /// the display rates and tax-split flags the quote does not carry.
  BillingSummary toBillingSummary(BillingSummary preview) {
    final half = (gstAmount * 100 / 2).ceil() / 100;
    return BillingSummary(
      subtotal: itemTotal,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      discount: discount,
      taxableAmount:
          (itemTotal - discount) + packingCharge + deliveryFee + platformFee,
      cgstAmount: preview.isIntraState ? half : 0,
      sgstAmount: preview.isIntraState ? gstAmount - half : 0,
      igstAmount: preview.isIntraState ? 0 : gstAmount,
      gstAmount: gstAmount,
      gstRate: preview.gstRate,
      isIntraState: preview.isIntraState,
      grandTotal: grandTotal,
      itemGstAmount: foodGstAmount,
      deliveryGstAmount: deliveryGstAmount,
      platformGstAmount: platformGstAmount,
      packingCharge: packingCharge,
      packingGstAmount: packingGstAmount,
      itemGstRate: preview.itemGstRate,
      packingGstRate: preview.packingGstRate,
      deliveryGstRate: preview.deliveryGstRate,
      platformGstRate: preview.platformGstRate,
      discountLines: discountLines,
    );
  }
}

abstract class CheckoutQuoteDatasource {
  /// Throws [OfferRejectedException] when an offer in [offerIds] does not
  /// apply, and [CheckoutQuoteUnavailableException] for anything else.
  Future<CheckoutQuote> quoteOrder({
    required String restaurantId,
    required List<PlaceOrderLineRequest> items,
    required PlaceOrderDeliveryAddressRequest deliveryAddress,
    String paymentMethod = 'pay_on_delivery',
    List<String> offerIds = const [],
  });
}

class FirebaseCheckoutQuoteDatasource implements CheckoutQuoteDatasource {
  FirebaseCheckoutQuoteDatasource({this._functions});

  final FirebaseFunctions? _functions;

  static const String callableName = 'quoteOrder';

  @override
  Future<CheckoutQuote> quoteOrder({
    required String restaurantId,
    required List<PlaceOrderLineRequest> items,
    required PlaceOrderDeliveryAddressRequest deliveryAddress,
    String paymentMethod = 'pay_on_delivery',
    List<String> offerIds = const [],
  }) async {
    try {
      final functions =
          _functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');
      final result = await functions.httpsCallable(callableName).call<dynamic>(
        <String, dynamic>{
          'restaurantId': restaurantId,
          'items': items.map((item) => item.toJson()).toList(),
          'deliveryAddress': deliveryAddress.toJson(),
          'orderForOther': false,
          'paymentMethod': paymentMethod,
          if (offerIds.isNotEmpty) 'offerIds': offerIds,
        },
      );
      final quote = parseQuote(result.data);
      if (quote == null) {
        throw const CheckoutQuoteUnavailableException();
      }
      return quote;
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final code = details is Map ? details['code'] : null;
      if (code is String && OfferFailureMessages.rejectionCodes.contains(code)) {
        throw OfferRejectedException(code);
      }
      throw CheckoutQuoteUnavailableException(code is String ? code : null);
    } on OfferRejectedException {
      rethrow;
    } on CheckoutQuoteUnavailableException {
      rethrow;
    } catch (_) {
      throw const CheckoutQuoteUnavailableException();
    }
  }

  /// Reads the `{summary, billing}` payload. Null when it is not usable.
  static CheckoutQuote? parseQuote(dynamic data) {
    if (data is! Map || data['summary'] is! Map) {
      return null;
    }
    final summary = Map<String, dynamic>.from(data['summary'] as Map);
    final billing = data['billing'] is Map
        ? Map<String, dynamic>.from(data['billing'] as Map)
        : const <String, dynamic>{};
    final taxes = billing['taxes'] is Map
        ? Map<String, dynamic>.from(billing['taxes'] as Map)
        : const <String, dynamic>{};
    final grandTotal = summary['grandTotal'];
    if (grandTotal is! num || grandTotal < 0) {
      return null;
    }

    double tax(String component, String fallbackKey) {
      final entry = taxes[component];
      if (entry is Map && entry['amount'] is num) {
        return (entry['amount'] as num).toDouble();
      }
      return _double(summary[fallbackKey]);
    }

    return CheckoutQuote(
      itemTotal: _double(summary['itemTotal']),
      discount: _double(summary['discount']),
      deliveryFee: _double(summary['deliveryFee']),
      platformFee: _double(summary['platformFee']),
      packingCharge: _double(billing['packingCharge']),
      gstAmount: _double(summary['gstAmount']),
      foodGstAmount: tax('food', 'foodGstAmount'),
      packingGstAmount: tax('packing', 'packingGstAmount'),
      deliveryGstAmount: tax('delivery', 'deliveryGstAmount'),
      platformGstAmount: tax('platform', 'platformGstAmount'),
      grandTotal: grandTotal.toDouble(),
      distanceKm: summary['distanceKm'] is num
          ? (summary['distanceKm'] as num).toDouble()
          : null,
      discountLines: _lines(billing['discounts']),
      cashbackLines: _lines(billing['cashbacks']),
    );
  }

  static double _double(Object? raw) => raw is num ? raw.toDouble() : 0;

  static List<BillingDiscountLine> _lines(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final entry in raw)
        if (entry is Map && entry['amount'] is num)
          BillingDiscountLine(
            offerId: entry['offerId'] is String ? entry['offerId'] as String : '',
            offerType:
                entry['offerType'] is String ? entry['offerType'] as String : '',
            description: entry['description'] is String
                ? entry['description'] as String
                : 'Offer',
            fundedBy:
                entry['fundedBy'] is String ? entry['fundedBy'] as String : '',
            amount: (entry['amount'] as num).toDouble(),
          ),
    ];
  }
}
