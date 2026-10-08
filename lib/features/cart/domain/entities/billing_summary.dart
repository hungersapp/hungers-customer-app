class BillingSummary {
  const BillingSummary({
    required this.subtotal,
    required this.deliveryFee,
    required this.platformFee,
    required this.discount,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.gstAmount,
    required this.gstRate,
    required this.isIntraState,
    required this.grandTotal,
    this.itemGstAmount = 0,
    this.deliveryGstAmount = 0,
    this.platformGstAmount = 0,
    this.packingCharge = 0,
    this.packingGstAmount = 0,
    this.itemGstRate = 0,
    this.packingGstRate = 0,
    this.deliveryGstRate = 0,
    this.platformGstRate = 0,
    this.discountLines = const [],
  });

  factory BillingSummary.empty() {
    return const BillingSummary(
      subtotal: 0,
      deliveryFee: 0,
      platformFee: 0,
      discount: 0,
      taxableAmount: 0,
      cgstAmount: 0,
      sgstAmount: 0,
      igstAmount: 0,
      gstAmount: 0,
      gstRate: 0,
      isIntraState: true,
      grandTotal: 0,
    );
  }

  /// Food item total before fees and tax.
  final double subtotal;

  final double deliveryFee;
  final double platformFee;
  final double discount;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double gstAmount;
  final double gstRate;
  final bool isIntraState;
  final double grandTotal;

  /// Share of [gstAmount] attributed to the item total. Sums with the other
  /// GST shares to [gstAmount] (authoritative total is never recomputed).
  final double itemGstAmount;
  final double deliveryGstAmount;
  final double platformGstAmount;

  /// GST on the packing charge. Zero when there is no packing charge.
  final double packingGstAmount;

  /// The GST rate each component was charged at (e.g. 0.05, 0.18), for display.
  final double itemGstRate;
  final double packingGstRate;
  final double deliveryGstRate;
  final double platformGstRate;

  /// Optional packing charge. Shown only when it is above zero; no restaurant
  /// packing configuration exists yet, so today it is always 0.
  final double packingCharge;

  /// Server-authored discount lines (restaurant / Tukkito / payment). Empty
  /// when no offer was applied. [discount] remains the authoritative total.
  final List<BillingDiscountLine> discountLines;

  bool get hasPackingCharge => packingCharge > 0;

  /// No platform charge is active today (₹0), so the bill omits the row;
  /// orders placed while one was charged still show it.
  bool get hasPlatformFee => platformFee > 0;

  bool get hasDiscount => discount > 0 || discountLines.isNotEmpty;

  double get itemTotal => subtotal;

  double get taxableFoodValue =>
      BillingSummary._round(subtotal > discount ? subtotal - discount : 0);

  double get restaurantDiscount => _discountFor('restaurant');

  double get tukkitoDiscount => _discountFor('tukkito');

  double get paymentDiscount => _discountFor('payment');

  double _discountFor(String offerType) {
    return discountLines
        .where((line) => line.offerType == offerType)
        .fold<double>(0, (sum, line) => sum + line.amount);
  }

  double get subtotalBeforeTax =>
      BillingSummary._round(
        subtotal + packingCharge + deliveryFee + platformFee - discount,
      );

  static double _round(double value) => (value * 100).round() / 100;
}

class BillingDiscountLine {
  const BillingDiscountLine({
    required this.offerType,
    required this.description,
    required this.amount,
    this.offerId = '',
    this.fundedBy = '',
  });

  final String offerId;
  final String offerType;
  final String description;
  final String fundedBy;
  final double amount;
}
