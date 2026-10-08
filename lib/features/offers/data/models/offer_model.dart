import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../domain/entities/offer.dart';

/// Maps `offers/{offerId}`. Returns null for a document the app cannot show
/// safely (unknown type, no usable value). Every other missing field takes a
/// default, so offers created before a field existed still load.
class OfferModel {
  const OfferModel._();

  static Offer? fromMap(String id, Map<String, dynamic> map) {
    final type = OfferType.tryParse(map['offerType']);
    final discountType = switch (map['discountType']) {
      'flat' => OfferDiscountType.flat,
      'percent' => OfferDiscountType.percent,
      _ => null,
    };
    final value = _double(map['discountValue']);
    if (id.trim().isEmpty ||
        type == null ||
        discountType == null ||
        value == null ||
        value <= 0) {
      return null;
    }
    final approval = map['approvalStatus'];
    return Offer(
      id: id,
      type: type,
      discountType: discountType,
      discountValue: value,
      name: _string(map['name']),
      code: _nullableString(map['couponCode']),
      description: _string(map['description']),
      benefitType: map['benefitType'] == OfferBenefitType.cashback.wireValue
          ? OfferBenefitType.cashback
          : OfferBenefitType.instantDiscount,
      maximumDiscount: _double(map['maximumDiscount']),
      minimumOrderValue: _double(map['minimumOrderValue']) ?? 0,
      restaurantIds: _strings(map['eligibleRestaurantIds']),
      paymentMethods: _strings(
        map['eligiblePaymentMethods'],
      ).map((method) => method.toLowerCase()).toList(),
      partnerName: _nullableString(map['partnerName']),
      restaurantName: _nullableString(map['restaurantName']),
      validFrom: _date(map['validFrom']),
      validUntil: _date(map['validUntil']),
      usageLimit: _int(map['usageLimit']),
      usageCount: _int(map['usageCount']) ?? 0,
      newCustomerOnly: map['newCustomerOnly'] == true,
      terms: _nullableString(map['terms']),
      isActive: map['isActive'] == true,
      isArchived: map['isArchived'] == true,
      isApproved: approval == null || approval == 'approved',
    );
  }

  static String _string(Object? raw) => raw is String ? raw.trim() : '';

  static String? _nullableString(Object? raw) {
    final value = _string(raw);
    return value.isEmpty ? null : value;
  }

  static double? _double(Object? raw) =>
      raw is num && raw.isFinite ? raw.toDouble() : null;

  static int? _int(Object? raw) => raw is num && raw.isFinite ? raw.toInt() : null;

  static List<String> _strings(Object? raw) => raw is Iterable
      ? [
          for (final entry in raw)
            if (entry is String && entry.trim().isNotEmpty) entry.trim(),
        ]
      : const [];

  static DateTime? _date(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }
}
