import '../entities/billable_charge.dart';
import '../entities/billing_config.dart';
import '../entities/billing_summary.dart';
import '../entities/tax_supply_type.dart';

/// Customer billing preview, component by component (mirrors the backend's
/// calculateMvpBilling; the backend value is authoritative):
///
///   food     GST = (itemTotal - discount) x food rate
///   packing  GST = packingCharge          x packing rate
///   delivery GST = deliveryFee            x delivery rate
///   platform GST = platformFee            x platform rate
///   total GST    = the four component GSTs added together
///   grand total  = item + packing + delivery + platform - discount + GST
///
/// Each component's GST is rounded once, half-up, to the paisa, so the total is
/// exactly the sum of its parts. Restaurant commission is not an input.
class BillingCalculator {
  const BillingCalculator(this._config);

  final BillingConfig _config;

  BillingSummary calculate({
    required double itemTotal,
    double deliveryFee = 0,
    double platformFee = 0,
    double packingCharge = 0,
    double discount = 0,
  }) {
    final safeItemTotal = _nonNegative(itemTotal);
    final safeDeliveryFee = _nonNegative(deliveryFee);
    final safePlatformFee = _nonNegative(platformFee);
    final safePackingCharge = _nonNegative(packingCharge);
    final safeDiscount = _nonNegative(discount);

    if (safeItemTotal == 0 &&
        safeDeliveryFee == 0 &&
        safePlatformFee == 0 &&
        safePackingCharge == 0 &&
        safeDiscount == 0) {
      return BillingSummary.empty();
    }

    final charges = [
      BillableCharge(
        id: 'itemTotal',
        label: 'Item Total',
        amount: safeItemTotal,
        taxable: _config.itemTotalTaxable,
        taxCategory: 'food',
        taxRate: _config.gstRate,
      ),
      BillableCharge(
        id: 'packingCharge',
        label: 'Packing Charge',
        amount: safePackingCharge,
        taxable: _config.packingChargeTaxable,
        taxCategory: 'packing',
        taxRate: _config.effectivePackingGstRate,
      ),
      BillableCharge(
        id: 'deliveryFee',
        label: 'Delivery Fee',
        amount: safeDeliveryFee,
        taxable: _config.deliveryFeeTaxable,
        taxCategory: 'delivery',
        taxRate: _config.effectiveDeliveryGstRate,
      ),
      BillableCharge(
        id: 'platformFee',
        label: 'Platform Fee',
        amount: safePlatformFee,
        taxable: _config.platformFeeTaxable,
        taxCategory: 'platform',
        taxRate: _config.effectivePlatformGstRate,
      ),
    ];

    return calculateFromCharges(
      charges: charges,
      discount: safeDiscount,
    );
  }

  /// Charges with an id other than itemTotal / packingCharge / deliveryFee /
  /// platformFee are ignored: they have no bill line, so they must not change
  /// the taxable base, the GST or the total.
  BillingSummary calculateFromCharges({
    required List<BillableCharge> charges,
    double discount = 0,
  }) {
    final discountPaise = _toPaise(_nonNegative(discount));

    final item = _Component();
    final packing = _Component();
    final delivery = _Component();
    final platform = _Component();

    for (final charge in charges) {
      final _Component component;
      switch (charge.id) {
        case 'itemTotal':
          component = item;
        case 'packingCharge':
          component = packing;
        case 'deliveryFee':
          component = delivery;
        case 'platformFee':
          component = platform;
        default:
          continue;
      }

      final amountPaise = _toPaise(_nonNegative(charge.amount));
      final rate = charge.taxRate ?? _config.gstRate;
      var basePaise = charge.taxable ? amountPaise : 0;
      if (charge.id == 'itemTotal' && _config.discountReducesTaxableAmount) {
        basePaise = basePaise > discountPaise ? basePaise - discountPaise : 0;
      }
      component.add(amountPaise, basePaise, _gstPaise(basePaise, rate), rate);
    }

    final components = [item, packing, delivery, platform];
    final intra = _config.supplyType == TaxSupplyType.intraState;
    var cgstPaise = 0;
    var sgstPaise = 0;
    var igstPaise = 0;
    var gstTotalPaise = 0;
    var taxablePaise = 0;
    for (final component in components) {
      gstTotalPaise += component.gstPaise;
      taxablePaise += component.basePaise;
      if (intra) {
        // An odd paisa goes to the CGST half; the halves sum exactly.
        final cgst = (component.gstPaise + 1) ~/ 2;
        cgstPaise += cgst;
        sgstPaise += component.gstPaise - cgst;
      } else {
        igstPaise += component.gstPaise;
      }
    }

    final netBeforeTaxPaise = item.amountPaise +
        packing.amountPaise +
        delivery.amountPaise +
        platform.amountPaise -
        discountPaise;

    return BillingSummary(
      subtotal: _fromPaise(item.amountPaise),
      packingCharge: _fromPaise(packing.amountPaise),
      deliveryFee: _fromPaise(delivery.amountPaise),
      platformFee: _fromPaise(platform.amountPaise),
      discount: _fromPaise(discountPaise),
      taxableAmount: _fromPaise(taxablePaise),
      cgstAmount: _fromPaise(cgstPaise),
      sgstAmount: _fromPaise(sgstPaise),
      igstAmount: _fromPaise(igstPaise),
      gstAmount: _fromPaise(gstTotalPaise),
      gstRate: _config.gstRate,
      isIntraState: intra,
      grandTotal: _fromPaise(netBeforeTaxPaise + gstTotalPaise),
      itemGstAmount: _fromPaise(item.gstPaise),
      packingGstAmount: _fromPaise(packing.gstPaise),
      deliveryGstAmount: _fromPaise(delivery.gstPaise),
      platformGstAmount: _fromPaise(platform.gstPaise),
      itemGstRate: item.rate,
      packingGstRate: packing.rate,
      deliveryGstRate: delivery.rate,
      platformGstRate: platform.rate,
    );
  }

  static double roundToPaise(double value) {
    return (value * 100).round() / 100;
  }

  static int _toPaise(double value) => (value * 100).round();

  static double _fromPaise(int paise) => paise / 100;

  /// Half-up GST in paise on an integer paise base, using integer basis
  /// points so the arithmetic is exact.
  static int _gstPaise(int basePaise, double rate) {
    final rateBasisPoints = (rate * 10000).round();
    return (basePaise * rateBasisPoints + 5000) ~/ 10000;
  }

  static double _nonNegative(double value) {
    if (value.isNaN || value.isNegative) {
      return 0;
    }
    return value;
  }
}

class _Component {
  int amountPaise = 0;
  int basePaise = 0;
  int gstPaise = 0;
  double rate = 0;

  void add(int amount, int base, int gst, double chargeRate) {
    amountPaise += amount;
    basePaise += base;
    gstPaise += gst;
    rate = chargeRate;
  }
}
