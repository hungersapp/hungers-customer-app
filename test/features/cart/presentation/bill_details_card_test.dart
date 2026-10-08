import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/cart/domain/entities/billing_config.dart';
import 'package:customer_app/features/cart/domain/entities/billing_summary.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/cart/domain/services/billing_calculator.dart';
import 'package:customer_app/features/cart/presentation/widgets/bill_details_card.dart';

BillingSummary _summary() {
  return const BillingSummary(
    subtotal: 320,
    deliveryFee: 30,
    platformFee: 5,
    discount: 0,
    taxableAmount: 355,
    cgstAmount: 8.88,
    sgstAmount: 8.88,
    igstAmount: 0,
    gstAmount: 17.76,
    gstRate: 0.05,
    isIntraState: true,
    grandTotal: 372.76,
  );
}

/// Component-wise summary for the spec examples: food 150, delivery 25,
/// platform fee 12, GST food 5% / packing 5% / delivery 18% / platform 18%.
BillingSummary _componentSummary({double packing = 0}) {
  final hasPacking = packing > 0;
  return BillingSummary(
    subtotal: 150,
    packingCharge: packing,
    deliveryFee: 25,
    platformFee: 12,
    discount: 0,
    taxableAmount: hasPacking ? 199 : 187,
    cgstAmount: hasPacking ? 7.38 : 7.08,
    sgstAmount: hasPacking ? 7.38 : 7.08,
    igstAmount: 0,
    gstAmount: hasPacking ? 14.76 : 14.16,
    gstRate: 0.05,
    isIntraState: true,
    grandTotal: hasPacking ? 213.76 : 201.16,
    itemGstAmount: 7.5,
    packingGstAmount: hasPacking ? 0.6 : 0,
    deliveryGstAmount: 4.5,
    platformGstAmount: 2.16,
    itemGstRate: 0.05,
    packingGstRate: 0.05,
    deliveryGstRate: 0.18,
    platformGstRate: 0.18,
  );
}

void main() {
  testWidgets('bill details are collapsed by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BillDetailsCard(
            summary: BillingSummary(
              subtotal: 320,
              deliveryFee: 30,
              platformFee: 5,
              discount: 0,
              taxableAmount: 355,
              cgstAmount: 8.88,
              sgstAmount: 8.88,
              igstAmount: 0,
              gstAmount: 17.76,
              gstRate: 0.05,
              isIntraState: true,
              grandTotal: 372.76,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bill Details'), findsOneWidget);
    expect(find.text('Item Total'), findsOneWidget);
    expect(find.text('GST'), findsOneWidget);
    expect(find.text('GST (5%)'), findsNothing);
    expect(find.text('Delivery Charge'), findsOneWidget);
    expect(find.text('Platform Fee'), findsOneWidget);
    expect(find.text('\u20B930.00'), findsOneWidget);
    expect(find.text('\u20B95.00'), findsOneWidget);
    expect(find.text('Final Payable'), findsOneWidget);
    expect(find.text('\u20B9372.76'), findsOneWidget);
    expect(find.text('GST Breakdown'), findsNothing);
  });

  testWidgets('expanding GST shows food vs delivery components', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BillDetailsCard(summary: _componentSummary())),
      ),
    );

    await tester.tap(find.text('GST'));
    await tester.pumpAndSettle();

    expect(find.text('GST Breakdown'), findsOneWidget);
    expect(find.text('Food / Restaurant'), findsOneWidget);
    expect(find.text('Delivery Service'), findsOneWidget);
    expect(find.text('Food GST'), findsOneWidget);
    expect(find.text('Delivery GST'), findsOneWidget);
    expect(find.text('Total GST'), findsOneWidget);
    expect(find.text('GST (5%)'), findsNothing);
  });

  testWidgets('checkout bill summary stays compact', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CheckoutBillSummary(summary: _componentSummary())),
      ),
    );

    expect(find.text('Bill Details'), findsOneWidget);
    expect(find.text('Item Total'), findsOneWidget);
    expect(find.text('GST'), findsWidgets);
    expect(find.text('Grand Total'), findsNothing);
    expect(find.text('View full bill details'), findsNothing);
    expect(find.text('Final Payable'), findsOneWidget);
    expect(find.text('GST Breakdown'), findsNothing);
    expect(find.textContaining('ommission'), findsNothing);

    await tester.tap(find.text('GST').first);
    await tester.pumpAndSettle();

    expect(find.text('Food GST'), findsOneWidget);
    expect(find.text('Delivery GST'), findsOneWidget);
    expect(find.text('Platform Fee GST (18%)'), findsOneWidget);
    expect(find.text('Total GST'), findsOneWidget);
    expect(find.text('₹7.50'), findsOneWidget);
    expect(find.text('₹4.50'), findsOneWidget);
    expect(find.text('₹2.16'), findsOneWidget);
    expect(find.text('₹14.16'), findsWidgets);
    expect(find.text('₹201.16'), findsOneWidget);
    expect(find.text('Packing Charges'), findsNothing);
    expect(find.textContaining('Packing GST'), findsNothing);
  });

  testWidgets(
    'packing charges and packing GST render only when packing exists',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CheckoutBillSummary(
                summary: _componentSummary(packing: 12),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Packing Charges'), findsOneWidget);
      expect(find.text('₹12.00'), findsWidgets);
      await tester.tap(find.text('GST').first);
      await tester.pumpAndSettle();
      expect(find.text('Packing GST (5%)'), findsOneWidget);
      expect(find.text('₹0.60'), findsOneWidget);
      expect(find.text('Food GST'), findsOneWidget);
      expect(find.text('Delivery GST'), findsOneWidget);
      expect(find.text('Platform Fee GST (18%)'), findsOneWidget);
      expect(find.text('₹14.76'), findsWidgets);
      expect(find.text('₹213.76'), findsOneWidget);
    },
  );

  testWidgets('checkout bill lists item rate, quantity, and subtotal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckoutBillSummary(
            summary: _summary(),
            items: [
              CartEntity(
                id: '1',
                userId: 'u',
                restaurantId: 'r',
                restaurantName: 'A2B',
                foodId: 'f1',
                foodName: 'Mini Meals',
                foodImage: '',
                price: 160,
                quantity: 2,
                isVeg: true,
                isAvailable: true,
                createdAt: DateTime(2026, 1, 1),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Mini Meals'), findsOneWidget);
    expect(find.text('\u20B9160.00 \u00d7 2'), findsOneWidget);
    expect(find.text('\u20B9320.00'), findsWidgets);
  });

  group('no platform charge (BillingConfig.mvp)', () {
    BillingSummary currentRulesSummary() {
      final config = BillingConfig.mvp();
      return BillingCalculator(config).calculate(
        itemTotal: 150,
        deliveryFee: 25,
        platformFee: config.platformFee,
      );
    }

    test('customer payable is food + delivery + their GST only', () {
      final summary = currentRulesSummary();
      expect(summary.platformFee, 0);
      expect(summary.platformGstAmount, 0);
      expect(summary.hasPlatformFee, isFalse);
      // Delivery fee unchanged by this rule: 25 in, 25 out.
      expect(summary.deliveryFee, 25);
      // 7.50 food GST + 4.50 delivery GST.
      expect(summary.gstAmount, 12);
      expect(summary.grandTotal, 150 + 25 + 12);
    });

    for (final compact in [false, true]) {
      testWidgets(
        '${compact ? 'checkout' : 'cart'} bill omits the Platform Fee rows',
        (tester) async {
          final summary = currentRulesSummary();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: compact
                      ? CheckoutBillSummary(summary: summary)
                      : BillDetailsCard(summary: summary),
                ),
              ),
            ),
          );

          expect(find.text('Platform Fee'), findsNothing);
          expect(find.textContaining('Platform Fee GST'), findsNothing);
          expect(find.text('₹187.00'), findsWidgets);
        },
      );
    }
  });
}
