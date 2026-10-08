import '../../../../core/format/inr_format.dart';

/// Who provides (and funds) an offer. Mirrors `offerType` on
/// `offers/{offerId}` (functions/src/order_offers.ts).
enum OfferType {
  tukkito('tukkito'),
  restaurant('restaurant'),
  paymentPartner('payment');

  const OfferType(this.wireValue);

  final String wireValue;

  static OfferType? tryParse(Object? raw) {
    for (final type in OfferType.values) {
      if (type.wireValue == raw) {
        return type;
      }
    }
    return null;
  }
}

/// An instant discount lowers the amount payable now. Cashback does not: the
/// customer pays the full bill and the provider credits them afterwards.
enum OfferBenefitType {
  instantDiscount('instant_discount'),
  cashback('cashback');

  const OfferBenefitType(this.wireValue);

  final String wireValue;
}

enum OfferDiscountType { flat, percent }

/// A commercial offer as shown to the customer. Display only: whether it
/// applies, and for how much, is always decided by the backend.
class Offer {
  const Offer({
    required this.id,
    required this.type,
    required this.discountType,
    required this.discountValue,
    this.name = '',
    this.code,
    this.description = '',
    this.benefitType = OfferBenefitType.instantDiscount,
    this.maximumDiscount,
    this.minimumOrderValue = 0,
    this.restaurantIds = const [],
    this.paymentMethods = const [],
    this.partnerName,
    this.restaurantName,
    this.validFrom,
    this.validUntil,
    this.usageLimit,
    this.usageCount = 0,
    this.newCustomerOnly = false,
    this.terms,
    this.isActive = true,
    this.isArchived = false,
    this.isApproved = true,
  });

  final String id;
  final OfferType type;
  final OfferDiscountType discountType;
  final double discountValue;
  final String name;
  final String? code;
  final String description;
  final OfferBenefitType benefitType;
  final double? maximumDiscount;
  final double minimumOrderValue;

  /// Empty = every restaurant.
  final List<String> restaurantIds;

  /// `placeOrder` payment values (`upi`, `card`). Empty = any method.
  final List<String> paymentMethods;
  final String? partnerName;
  final String? restaurantName;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final int? usageLimit;
  final int usageCount;
  final bool newCustomerOnly;
  final String? terms;
  final bool isActive;
  final bool isArchived;
  final bool isApproved;

  bool get isCashback => benefitType == OfferBenefitType.cashback;

  /// What the customer reads first: the code, else the partner or offer name.
  String get title {
    final value = code?.trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
    final partner = partnerName?.trim() ?? '';
    if (partner.isNotEmpty) {
      return partner;
    }
    return name.trim().isEmpty ? 'Offer' : name.trim();
  }

  /// e.g. `₹50 OFF`, `10% OFF up to ₹100`, `₹50 cashback`.
  String get benefitLabel {
    final amount = discountType == OfferDiscountType.flat
        ? formatInrWhole(discountValue)
        : '${_trim(discountValue)}%';
    final cap = discountType == OfferDiscountType.percent &&
            maximumDiscount != null
        ? ' up to ${formatInrWhole(maximumDiscount!)}'
        : '';
    return isCashback ? '$amount cashback$cap' : '$amount OFF$cap';
  }

  /// e.g. `on orders above ₹299`. Empty when there is no minimum.
  String get conditionLabel => minimumOrderValue > 0
      ? 'on orders above ${formatInrWhole(minimumOrderValue)}'
      : '';

  /// How much more the cart needs before this offer can apply; 0 when met.
  double shortfallFor(double itemTotal) {
    final missing = minimumOrderValue - itemTotal;
    return missing > 0 ? missing : 0;
  }

  /// Whether to list this offer for [restaurantId] at [now]. A convenience
  /// filter only — an offer shown here can still be refused by the backend.
  bool isListedFor(String restaurantId, DateTime now) {
    if (!isActive || isArchived || !isApproved) {
      return false;
    }
    if (validFrom != null && now.isBefore(validFrom!)) {
      return false;
    }
    if (validUntil != null && now.isAfter(validUntil!)) {
      return false;
    }
    if (usageLimit != null && usageCount >= usageLimit!) {
      return false;
    }
    return restaurantIds.isEmpty || restaurantIds.contains(restaurantId);
  }

  static String _trim(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
