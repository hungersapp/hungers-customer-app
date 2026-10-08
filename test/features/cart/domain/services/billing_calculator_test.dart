import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/cart/domain/entities/billable_charge.dart';
import 'package:customer_app/features/cart/domain/entities/billing_config.dart';
import 'package:customer_app/features/cart/domain/entities/cart_entity.dart';
import 'package:customer_app/features/cart/domain/entities/tax_supply_type.dart';
import 'package:customer_app/features/cart/domain/services/billing_calculator.dart';
import 'package:customer_app/features/cart/domain/usecases/calculate_cart_billing_usecase.dart';

/// Customer billing PREVIEW, component by component. The backend
/// (`placeOrder`) is authoritative; these cases mirror the shared fixtures in
/// super_admin/functions/test/fixtures/cross_runtime_parity.fixtures.json.
///
/// Business rules: platform fee ₹12; GST food 5%, packing 5%, delivery 18%,
/// platform fee 18%. Restaurant commission is not a customer charge and is
/// not an input anywhere in billing.
void main() {
  const intraConfig = BillingConfig(
    gstRate: 0.05,
    packingGstRate: 0.05,
    deliveryGstRate: 0.18,
    platformGstRate: 0.18,
    supplyType: TaxSupplyType.intraState,
    platformFee: 12,
    defaultDeliveryFee: 30,
    itemTotalTaxable: true,
    deliveryFeeTaxable: true,
    platformFeeTaxable: true,
  );

  const interConfig = BillingConfig(
    gstRate: 0.05,
    packingGstRate: 0.05,
    deliveryGstRate: 0.18,
    platformGstRate: 0.18,
    supplyType: TaxSupplyType.interState,
    platformFee: 12,
    defaultDeliveryFee: 30,
    itemTotalTaxable: true,
    deliveryFeeTaxable: true,
    platformFeeTaxable: true,
  );

  CartEntity cartItem({required double price, int quantity = 1}) {
    return CartEntity(
      id: '1',
      userId: 'user',
      restaurantId: 'r1',
      restaurantName: 'A2B',
      foodId: 'f1',
      foodName: 'Mini Meals',
      foodImage: '',
      price: price,
      quantity: quantity,
      isVeg: true,
      isAvailable: true,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  group('BillingConfig.mvp', () {
    test('carries the current business rules', () {
      final config = BillingConfig.mvp();

      // No platform charge is active (mirrors backend PLATFORM_FEE = 0).
      expect(config.platformFee, 0);
      expect(config.gstRate, 0.05);
      expect(config.effectivePackingGstRate, 0.05);
      expect(config.effectiveDeliveryGstRate, 0.18);
      expect(config.effectivePlatformGstRate, 0.18);
      expect(config.supplyType, TaxSupplyType.intraState);
    });

    test('a component without its own rate falls back to the food rate', () {
      const config = BillingConfig(
        gstRate: 0.05,
        supplyType: TaxSupplyType.intraState,
        platformFee: 12,
        defaultDeliveryFee: 30,
        itemTotalTaxable: true,
        deliveryFeeTaxable: true,
        platformFeeTaxable: true,
      );

      expect(config.effectiveDeliveryGstRate, 0.05);
      expect(config.effectivePlatformGstRate, 0.05);
      expect(config.effectivePackingGstRate, 0.05);
    });
  });

  group('BillingCalculator', () {
    test(
      'A. with packing: food 5%, packing 5%, delivery 18%, platform 18%',
      () {
        final summary = const BillingCalculator(intraConfig).calculate(
          itemTotal: 150,
          packingCharge: 12,
          deliveryFee: 25,
          platformFee: 12,
        );

        expect(summary.subtotal, 150);
        expect(summary.packingCharge, 12);
        expect(summary.deliveryFee, 25);
        expect(summary.platformFee, 12);
        expect(summary.taxableAmount, 199);
        expect(summary.itemGstAmount, 7.5);
        expect(summary.packingGstAmount, 0.6);
        expect(summary.deliveryGstAmount, 4.5);
        expect(summary.platformGstAmount, 2.16);
        expect(summary.cgstAmount, 7.38);
        expect(summary.sgstAmount, 7.38);
        expect(summary.igstAmount, 0);
        expect(summary.gstAmount, 14.76);
        // 150 + 12 + 25 + 12 = 199; 199 + 14.76 = 213.76.
        expect(summary.grandTotal, 213.76);
      },
    );

    test(
      'A2. without packing: no packing GST, total GST 14.16, total 201.16',
      () {
        final summary = const BillingCalculator(
          intraConfig,
        ).calculate(itemTotal: 150, deliveryFee: 25, platformFee: 12);

        expect(summary.packingCharge, 0);
        expect(summary.hasPackingCharge, isFalse);
        expect(summary.packingGstAmount, 0);
        expect(summary.taxableAmount, 187);
        expect(summary.itemGstAmount, 7.5);
        expect(summary.deliveryGstAmount, 4.5);
        expect(summary.platformGstAmount, 2.16);
        expect(summary.cgstAmount, 7.08);
        expect(summary.sgstAmount, 7.08);
        expect(summary.gstAmount, 14.16);
        expect(summary.grandTotal, 201.16);
      },
    );

    test('B. interstate GST charges each component fully as IGST', () {
      final summary = const BillingCalculator(interConfig).calculate(
        itemTotal: 150,
        packingCharge: 12,
        deliveryFee: 25,
        platformFee: 12,
      );

      expect(summary.igstAmount, 14.76);
      expect(summary.cgstAmount, 0);
      expect(summary.sgstAmount, 0);
      expect(summary.gstAmount, 14.76);
      expect(summary.isIntraState, isFalse);
      expect(summary.grandTotal, 213.76);
    });

    test('C. zero delivery fee contributes no delivery GST', () {
      final summary = const BillingCalculator(
        intraConfig,
      ).calculate(itemTotal: 198, deliveryFee: 0, platformFee: 12);

      expect(summary.deliveryFee, 0);
      expect(summary.deliveryGstAmount, 0);
      expect(summary.taxableAmount, 210);
      expect(summary.itemGstAmount, 9.9);
      expect(summary.cgstAmount, 6.03);
      expect(summary.sgstAmount, 6.03);
      expect(summary.gstAmount, 12.06);
      expect(summary.grandTotal, 222.06);
    });

    test('D. a discount reduces the food value and its GST only', () {
      final summary = const BillingCalculator(intraConfig).calculate(
        itemTotal: 150,
        deliveryFee: 25,
        platformFee: 12,
        discount: 20,
      );

      expect(summary.discount, 20);
      expect(summary.taxableAmount, 167);
      expect(summary.itemGstAmount, 6.5);
      expect(summary.deliveryGstAmount, 4.5);
      expect(summary.platformGstAmount, 2.16);
      expect(summary.cgstAmount, 6.58);
      expect(summary.sgstAmount, 6.58);
      expect(summary.gstAmount, 13.16);
      expect(summary.grandTotal, 180.16);
    });

    test('E. empty cart returns zeroed summary', () {
      final summary = const BillingCalculator(
        intraConfig,
      ).calculate(itemTotal: 0, deliveryFee: 0, platformFee: 0);

      expect(summary.subtotal, 0);
      expect(summary.deliveryFee, 0);
      expect(summary.platformFee, 0);
      expect(summary.taxableAmount, 0);
      expect(summary.gstAmount, 0);
      expect(summary.grandTotal, 0);
    });

    test('F. rounds GST components to 2 decimal places', () {
      expect(BillingCalculator.roundToPaise(5.825), 5.83);
      expect(BillingCalculator.roundToPaise(11.65), 11.65);
      expect(BillingCalculator.roundToPaise(11.666), 11.67);
    });

    test('non-taxable delivery fee is excluded from GST', () {
      const config = BillingConfig(
        gstRate: 0.05,
        packingGstRate: 0.05,
        deliveryGstRate: 0.18,
        platformGstRate: 0.18,
        supplyType: TaxSupplyType.intraState,
        platformFee: 12,
        defaultDeliveryFee: 30,
        itemTotalTaxable: true,
        deliveryFeeTaxable: false,
        platformFeeTaxable: true,
      );

      final summary = const BillingCalculator(
        config,
      ).calculate(itemTotal: 150, deliveryFee: 25, platformFee: 12);

      expect(summary.taxableAmount, 162);
      expect(summary.deliveryGstAmount, 0);
      expect(summary.gstAmount, 9.66);
      expect(summary.grandTotal, 196.66);
    });

    test(
      'the four component GSTs sum exactly to the authoritative gstAmount',
      () {
        final summary = const BillingCalculator(intraConfig).calculate(
          itemTotal: 149.5,
          packingCharge: 7.5,
          deliveryFee: 35,
          platformFee: 12,
        );

        expect(
          BillingCalculator.roundToPaise(
            summary.itemGstAmount +
                summary.packingGstAmount +
                summary.deliveryGstAmount +
                summary.platformGstAmount,
          ),
          summary.gstAmount,
        );
        expect(
          BillingCalculator.roundToPaise(
            summary.cgstAmount + summary.sgstAmount,
          ),
          summary.gstAmount,
        );
      },
    );

    test('each component is charged at its own rate, not one blended rate', () {
      final summary = const BillingCalculator(intraConfig).calculate(
        itemTotal: 150,
        packingCharge: 12,
        deliveryFee: 25,
        platformFee: 12,
      );

      expect(summary.itemGstRate, 0.05);
      expect(summary.packingGstRate, 0.05);
      expect(summary.deliveryGstRate, 0.18);
      expect(summary.platformGstRate, 0.18);
      // Delivery is 18% (4.50), not the food rate's 5% (1.25); packing is 5%
      // (0.60), not 18% (2.16).
      expect(summary.deliveryGstAmount, isNot(1.25));
      expect(summary.packingGstAmount, isNot(2.16));
    });

    test(
      'odd-paisa rounding: each component rounded once, odd paisa to CGST',
      () {
        final summary = const BillingCalculator(intraConfig).calculate(
          itemTotal: 12.35,
          packingCharge: 3.33,
          deliveryFee: 25,
          platformFee: 12,
        );

        expect(summary.itemGstAmount, 0.62);
        expect(summary.packingGstAmount, 0.17);
        expect(summary.gstAmount, 7.45);
        expect(summary.cgstAmount, 3.73);
        expect(summary.sgstAmount, 3.72);
        expect(summary.grandTotal, 60.13);
      },
    );

    test(
      'a charge with an unknown id has no bill line and changes nothing',
      () {
        final summary = const BillingCalculator(intraConfig)
            .calculateFromCharges(
              charges: const [
                BillableCharge(
                  id: 'itemTotal',
                  label: 'Item Total',
                  amount: 100,
                  taxable: true,
                  taxCategory: 'food',
                  taxRate: 0.05,
                ),
                BillableCharge(
                  id: 'restaurantCommission',
                  label: 'Commission',
                  amount: 15,
                  taxable: true,
                  taxCategory: 'commission',
                  taxRate: 0.05,
                ),
              ],
            );

        expect(summary.subtotal, 100);
        expect(summary.taxableAmount, 100);
        expect(summary.gstAmount, 5);
        expect(summary.grandTotal, 105);
      },
    );

    test('restaurant commission is not an input: a 100 price bills as 100', () {
      final summary = const BillingCalculator(
        intraConfig,
      ).calculate(itemTotal: 100, deliveryFee: 25, platformFee: 12);

      expect(summary.subtotal, 100);
      expect(summary.subtotal, isNot(115));
      expect(summary.itemGstAmount, 5);
    });
  });

  group('CalculateCartBillingUseCase', () {
    test('empty items do not apply default fees', () {
      const useCase = CalculateCartBillingUseCase();

      final summary = useCase(items: const [], config: intraConfig);

      expect(summary.grandTotal, 0);
      expect(summary.deliveryFee, 0);
      expect(summary.platformFee, 0);
    });

    test('the app carries no delivery fee of its own', () {
      const useCase = CalculateCartBillingUseCase();
      final items = [cartItem(price: 160, quantity: 2)];

      // The delivery fee comes only from the backend quote (road distance).
      final summary = useCase(items: items, config: BillingConfig.mvp());

      expect(BillingConfig.mvp().defaultDeliveryFee, 0);
      expect(summary.deliveryFee, 0);
      expect(summary.deliveryGstAmount, 0);
    });

    test(
      'uses MVP GST and the given delivery fee, and no platform fee, for a 320 item total',
      () {
        const useCase = CalculateCartBillingUseCase();
        final items = [cartItem(price: 160, quantity: 2)];

        final summary = useCase(
          items: items,
          config: BillingConfig.mvp(),
          deliveryFee: 30,
        );

        expect(summary.subtotal, 320);
        expect(summary.deliveryFee, 30);
        expect(summary.platformFee, 0);
        expect(summary.hasPlatformFee, isFalse);
        expect(summary.itemGstAmount, 16);
        expect(summary.deliveryGstAmount, 5.4);
        expect(summary.platformGstAmount, 0);
        // 16.00 + 5.40 = 21.40; 320 + 30 + 21.40 = 371.40.
        expect(summary.gstAmount, 21.4);
        expect(summary.cgstAmount, 10.7);
        expect(summary.sgstAmount, 10.7);
        expect(summary.grandTotal, 371.4);
      },
    );

    test('uses cart line totals without extra data sources', () {
      const useCase = CalculateCartBillingUseCase();
      final items = [cartItem(price: 198)];

      final summary = useCase(items: items, config: intraConfig);

      expect(summary.subtotal, 198);
      expect(summary.deliveryFee, 30);
      expect(summary.platformFee, 12);
      // 9.90 + 5.40 + 2.16 = 17.46; 198 + 30 + 12 + 17.46 = 257.46.
      expect(summary.gstAmount, 17.46);
      expect(summary.grandTotal, 257.46);
    });

    test('the restaurant\'s price is the customer\'s price: 100 stays 100', () {
      const useCase = CalculateCartBillingUseCase();

      final summary = useCase(
        items: [cartItem(price: 100)],
        config: BillingConfig.mvp(),
        deliveryFee: 25,
      );

      expect(summary.subtotal, 100);
      expect(summary.subtotal, isNot(115));
      expect(summary.itemGstAmount, 5);
      // 100 + 25 + (5.00 + 4.50) GST; no platform fee.
      expect(summary.grandTotal, 134.5);
    });

    test('an optional packing charge is billed with its own 5% GST', () {
      const useCase = CalculateCartBillingUseCase();

      final summary = useCase(
        items: [cartItem(price: 150)],
        config: BillingConfig.mvp(),
        deliveryFee: 25,
        packingCharge: 12,
      );

      expect(summary.packingCharge, 12);
      expect(summary.packingGstAmount, 0.6);
      // 7.50 + 0.60 + 4.50 = 12.60; 150 + 12 + 25 + 12.60 = 199.60.
      expect(summary.gstAmount, 12.6);
      expect(summary.grandTotal, 199.6);
    });

    test('no packing charge is added unless one is supplied', () {
      const useCase = CalculateCartBillingUseCase();

      final summary = useCase(
        items: [cartItem(price: 150)],
        config: BillingConfig.mvp(),
        deliveryFee: 25,
      );

      expect(summary.packingCharge, 0);
      expect(summary.packingGstAmount, 0);
      expect(summary.gstAmount, 12);
      expect(summary.grandTotal, 187);
    });
  });
}
