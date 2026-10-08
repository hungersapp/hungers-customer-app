import 'tax_supply_type.dart';

/// Configurable HUNGERS billing rules for the restaurant-service MVP.
///
/// PREVIEW ONLY. The backend (`placeOrder`, place_order_pricing.ts) is the
/// authoritative source of every price, fee and GST amount; this mirrors its
/// current rules so checkout can show a matching estimate. It never carries
/// restaurant commission — that is a settlement-side figure and is not part of
/// what the customer pays.
///
/// GST is charged per bill component at that component's own rate; there is no
/// single blended rate. A component without its own rate uses [gstRate].
class BillingConfig {
  const BillingConfig({
    required this.gstRate,
    required this.supplyType,
    required this.platformFee,
    required this.defaultDeliveryFee,
    required this.itemTotalTaxable,
    required this.deliveryFeeTaxable,
    required this.platformFeeTaxable,
    this.packingChargeTaxable = true,
    this.packingGstRate,
    this.deliveryGstRate,
    this.platformGstRate,
    this.discountReducesTaxableAmount = true,
  });

  /// Current business rules: no platform charge (₹0, mirrors backend
  /// `PLATFORM_FEE`); GST food 5%, packing 5%, delivery 18%, platform fee 18%
  /// (applies only if a platform fee is charged); intra-state CGST + SGST.
  factory BillingConfig.mvp() {
    return const BillingConfig(
      gstRate: 0.05,
      packingGstRate: 0.05,
      deliveryGstRate: 0.18,
      platformGstRate: 0.18,
      supplyType: TaxSupplyType.intraState,
      platformFee: 0,
      defaultDeliveryFee: 0,
      itemTotalTaxable: true,
      deliveryFeeTaxable: true,
      platformFeeTaxable: true,
    );
  }

  /// GST rate on the food value (e.g. 0.05 for 5%). Also the fallback for any
  /// component that has no rate of its own.
  final double gstRate;

  /// Own GST rates for the other components; null falls back to [gstRate].
  final double? packingGstRate;
  final double? deliveryGstRate;
  final double? platformGstRate;

  final TaxSupplyType supplyType;

  /// Customer-facing platform fee.
  final double platformFee;

  /// Delivery fee used when the caller passes none. Always 0 in the app:
  /// the delivery fee comes only from the backend quote (road distance).
  final double defaultDeliveryFee;

  final bool itemTotalTaxable;
  final bool packingChargeTaxable;
  final bool deliveryFeeTaxable;
  final bool platformFeeTaxable;

  /// A discount, when one exists, reduces the food value (and its GST) only.
  final bool discountReducesTaxableAmount;

  double get effectivePackingGstRate => packingGstRate ?? gstRate;

  double get effectiveDeliveryGstRate => deliveryGstRate ?? gstRate;

  double get effectivePlatformGstRate => platformGstRate ?? gstRate;
}
