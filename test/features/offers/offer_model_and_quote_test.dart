import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/cart/domain/entities/billing_config.dart';
import 'package:customer_app/features/cart/domain/services/billing_calculator.dart';
import 'package:customer_app/features/offers/data/models/offer_model.dart';
import 'package:customer_app/features/offers/domain/entities/offer.dart';
import 'package:customer_app/features/offers/domain/offer_failure.dart';
import 'package:customer_app/features/orders/data/datasources/checkout_quote_datasource.dart';

void main() {
  group('OfferModel', () {
    test('maps a Tukkito percentage offer with a cap', () {
      final offer = OfferModel.fromMap('tuk10', {
        'offerType': 'tukkito',
        'discountType': 'percent',
        'discountValue': 10,
        'maximumDiscount': 100,
        'couponCode': 'TUK10',
        'isActive': true,
      })!;
      expect(offer.type, OfferType.tukkito);
      expect(offer.title, 'TUK10');
      expect(offer.benefitLabel, '10% OFF up to ₹100');
      expect(offer.isCashback, isFalse);
    });

    test('maps a payment-partner cashback offer', () {
      final offer = OfferModel.fromMap('gpay', {
        'offerType': 'payment',
        'discountType': 'flat',
        'discountValue': 50,
        'benefitType': 'cashback',
        'partnerName': 'Google Pay',
        'eligiblePaymentMethods': ['UPI'],
        'isActive': true,
      })!;
      expect(offer.type, OfferType.paymentPartner);
      expect(offer.isCashback, isTrue);
      expect(offer.title, 'Google Pay');
      expect(offer.benefitLabel, '₹50 cashback');
      expect(offer.paymentMethods, ['upi']);
    });

    test('an offer stored before the new fields existed still loads', () {
      final offer = OfferModel.fromMap('legacy', {
        'offerType': 'restaurant',
        'discountType': 'flat',
        'discountValue': 20,
        'isActive': true,
      })!;
      expect(offer.benefitType, OfferBenefitType.instantDiscount);
      expect(offer.isApproved, isTrue);
      expect(offer.isArchived, isFalse);
      expect(offer.restaurantIds, isEmpty);
      expect(offer.minimumOrderValue, 0);
      expect(offer.title, 'Offer');
    });

    test('rejects documents it cannot show safely', () {
      expect(OfferModel.fromMap('x', {'offerType': 'mystery'}), isNull);
      expect(
        OfferModel.fromMap('x', {
          'offerType': 'tukkito',
          'discountType': 'flat',
          'discountValue': 0,
        }),
        isNull,
      );
      expect(
        OfferModel.fromMap('x', {
          'offerType': 'tukkito',
          'discountType': 'flat',
          'discountValue': 'fifty',
        }),
        isNull,
      );
    });
  });

  group('Offer listing filter', () {
    final now = DateTime(2026, 10, 4);
    const base = Offer(
      id: 'o',
      type: OfferType.tukkito,
      discountType: OfferDiscountType.flat,
      discountValue: 50,
    );

    Offer offer({
      bool isActive = true,
      bool isArchived = false,
      bool isApproved = true,
      DateTime? validFrom,
      DateTime? validUntil,
      int? usageLimit,
      int usageCount = 0,
      List<String> restaurantIds = const [],
    }) => Offer(
      id: base.id,
      type: base.type,
      discountType: base.discountType,
      discountValue: base.discountValue,
      isActive: isActive,
      isArchived: isArchived,
      isApproved: isApproved,
      validFrom: validFrom,
      validUntil: validUntil,
      usageLimit: usageLimit,
      usageCount: usageCount,
      restaurantIds: restaurantIds,
    );

    test('hides inactive, archived, unapproved, expired and exhausted offers', () {
      expect(offer().isListedFor('r1', now), isTrue);
      expect(offer(isActive: false).isListedFor('r1', now), isFalse);
      expect(offer(isArchived: true).isListedFor('r1', now), isFalse);
      expect(offer(isApproved: false).isListedFor('r1', now), isFalse);
      expect(
        offer(validUntil: DateTime(2026, 10, 1)).isListedFor('r1', now),
        isFalse,
      );
      expect(
        offer(validFrom: DateTime(2026, 11, 1)).isListedFor('r1', now),
        isFalse,
      );
      expect(
        offer(usageLimit: 10, usageCount: 10).isListedFor('r1', now),
        isFalse,
      );
    });

    test('a restaurant offer is listed only at its restaurant', () {
      expect(offer(restaurantIds: ['r1']).isListedFor('r1', now), isTrue);
      expect(offer(restaurantIds: ['r1']).isListedFor('r2', now), isFalse);
    });
  });

  group('OfferFailureMessages', () {
    const offer = Offer(
      id: 'welcome50',
      type: OfferType.tukkito,
      discountType: OfferDiscountType.flat,
      discountValue: 50,
      minimumOrderValue: 299,
    );

    test('says how much more is needed for the minimum order', () {
      expect(
        OfferFailureMessages.forCode(
          'OFFER_MIN_ORDER',
          offer: offer,
          itemTotal: 250,
        ),
        'Add ₹49 more to use this offer.',
      );
    });

    test('every rejection code has customer wording, never a raw code', () {
      for (final code in OfferFailureMessages.rejectionCodes) {
        final message = OfferFailureMessages.forCode(code);
        expect(message, isNotEmpty);
        expect(message.contains('OFFER_'), isFalse, reason: code);
        expect(message.endsWith('.'), isTrue, reason: code);
      }
      expect(
        OfferFailureMessages.forCode('SOMETHING_NEW'),
        OfferFailureMessages.invalid,
      );
    });
  });

  group('CheckoutQuote', () {
    final payload = {
      'success': true,
      'summary': {
        'itemTotal': 499,
        'deliveryFee': 25,
        'platformFee': 0,
        'gstAmount': 26.95,
        'grandTotal': 500.95,
        'distanceKm': 1.2,
        'discount': 50,
        'foodGstAmount': 22.45,
        'deliveryGstAmount': 4.5,
        'platformGstAmount': 0,
      },
      'billing': {
        'packingCharge': 0,
        'totalDiscount': 50,
        'discounts': [
          {
            'offerId': 'welcome50',
            'offerType': 'tukkito',
            'description': '₹50 OFF above ₹299',
            'amount': 50,
            'fundedBy': 'tukkito',
          },
        ],
        'cashbacks': [
          {
            'offerId': 'gpay50',
            'offerType': 'payment',
            'description': 'GPay cashback',
            'amount': 50,
            'fundedBy': 'payment_partner',
          },
        ],
        'taxes': {
          'food': {'taxableValue': 449, 'rateBp': 500, 'amount': 22.45},
          'packing': {'taxableValue': 0, 'rateBp': 500, 'amount': 0},
          'delivery': {'taxableValue': 25, 'rateBp': 1800, 'amount': 4.5},
          'platform': {'taxableValue': 0, 'rateBp': 1800, 'amount': 0},
          'totalTax': 26.95,
        },
      },
    };

    test('reads the backend quote, keeping cashback out of the discount', () {
      final quote = FirebaseCheckoutQuoteDatasource.parseQuote(payload)!;
      expect(quote.itemTotal, 499);
      expect(quote.discount, 50);
      expect(quote.platformFee, 0);
      expect(quote.grandTotal, 500.95);
      expect(quote.discountLines.single.offerId, 'welcome50');
      expect(quote.cashbackLines.single.amount, 50);
      // 499 - 50 + 25 + 26.95: the cashback is not deducted.
      expect(
        quote.itemTotal - quote.discount + quote.deliveryFee + quote.gstAmount,
        closeTo(quote.grandTotal, 0.001),
      );
    });

    test('the displayed bill carries the backend amounts, not the preview', () {
      final preview = BillingCalculator(BillingConfig.mvp()).calculate(
        itemTotal: 499,
        deliveryFee: 25,
        platformFee: 0,
      );
      expect(preview.discount, 0);

      final bill = FirebaseCheckoutQuoteDatasource.parseQuote(payload)!
          .toBillingSummary(preview);
      expect(bill.grandTotal, 500.95);
      expect(bill.discount, 50);
      expect(bill.platformFee, 0);
      expect(bill.hasPlatformFee, isFalse);
      expect(bill.gstAmount, 26.95);
      expect(bill.itemGstAmount, 22.45);
      expect(bill.tukkitoDiscount, 50);
      expect(bill.restaurantDiscount, 0);
      expect(bill.cgstAmount + bill.sgstAmount + bill.igstAmount,
          closeTo(26.95, 0.001));
    });

    test('an unusable payload is refused rather than shown', () {
      expect(FirebaseCheckoutQuoteDatasource.parseQuote(null), isNull);
      expect(FirebaseCheckoutQuoteDatasource.parseQuote({'summary': 3}), isNull);
      expect(
        FirebaseCheckoutQuoteDatasource.parseQuote({
          'summary': {'grandTotal': 'free'},
        }),
        isNull,
      );
    });
  });
}
