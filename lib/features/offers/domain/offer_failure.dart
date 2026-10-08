import '../../../core/format/inr_format.dart';
import 'entities/offer.dart';

/// Why the backend refused an offer, as the `code` it returns in the
/// callable error details (see OfferRejectionCode in order_offers.ts).
class OfferRejectedException implements Exception {
  const OfferRejectedException(this.code);

  final String code;

  @override
  String toString() => 'OfferRejectedException($code)';
}

/// The backend did not price the order: it could not be reached, or it
/// refused the order for a reason other than an offer. [code] is the backend
/// detail code when it gave one (e.g. `NOT_SERVICEABLE`).
class CheckoutQuoteUnavailableException implements Exception {
  const CheckoutQuoteUnavailableException([this.code]);

  final String? code;
}

/// Customer wording for offer failures. Raw backend text is never shown.
class OfferFailureMessages {
  const OfferFailureMessages._();

  static const String unavailable =
      "We couldn't apply the offer right now. Please try again.";
  static const String quoteUnavailable =
      'Unable to calculate your latest order total. Please try again.';
  static const String beyondDeliveryDistance =
      'This address is too far from the restaurant to deliver to. '
      'Please choose a closer address.';
  static const String locationNotServiceable =
      'Delivery is not available at this location.';

  /// Wording for a quote the backend refused; [code] is its detail code.
  static String forQuoteFailure(String? code) {
    switch (code) {
      case 'NOT_SERVICEABLE':
        return beyondDeliveryDistance;
      case 'PINCODE_NOT_SERVICEABLE':
        return locationNotServiceable;
      default:
        return quoteUnavailable;
    }
  }
  static const String invalid = 'That offer is not valid for this order.';
  static const String needsAddress =
      'Add your delivery address at checkout to apply offers.';

  static const Set<String> rejectionCodes = {
    'INVALID_COUPON',
    'OFFER_NOT_FOUND',
    'OFFER_INACTIVE',
    'OFFER_EXPIRED',
    'OFFER_NOT_STARTED',
    'OFFER_MIN_ORDER',
    'OFFER_RESTAURANT_INELIGIBLE',
    'OFFER_FOOD_INELIGIBLE',
    'OFFER_PAYMENT_INELIGIBLE',
    'OFFER_USAGE_LIMIT',
    'OFFER_CUSTOMER_LIMIT',
    'OFFER_NEW_CUSTOMER_ONLY',
    'OFFER_CUSTOMER_INELIGIBLE',
    'OFFER_DUPLICATE',
  };

  /// [offer] and [itemTotal] let a minimum-order refusal say how much is
  /// missing.
  static String forCode(String code, {Offer? offer, double? itemTotal}) {
    switch (code) {
      case 'OFFER_MIN_ORDER':
        if (offer != null && itemTotal != null) {
          final shortfall = offer.shortfallFor(itemTotal);
          if (shortfall > 0) {
            return 'Add ${formatInrWhole(shortfall.ceilToDouble())} more to '
                'use this offer.';
          }
        }
        return 'This order does not meet the minimum for this offer.';
      case 'OFFER_EXPIRED':
        return 'This offer has expired.';
      case 'OFFER_NOT_STARTED':
        return 'This offer has not started yet.';
      case 'OFFER_USAGE_LIMIT':
      case 'OFFER_INACTIVE':
        return 'This offer is no longer available.';
      case 'OFFER_CUSTOMER_LIMIT':
        return 'You have already used this offer.';
      case 'OFFER_NEW_CUSTOMER_ONLY':
        return 'This offer is only for your first order.';
      case 'OFFER_RESTAURANT_INELIGIBLE':
        return 'This offer is not available at this restaurant.';
      case 'OFFER_PAYMENT_INELIGIBLE':
        return 'Use the eligible payment method to receive this offer.';
      default:
        return invalid;
    }
  }
}
