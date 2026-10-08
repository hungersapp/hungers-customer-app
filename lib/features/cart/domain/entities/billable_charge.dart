/// A single bill line that can be taxed independently later.
class BillableCharge {
  const BillableCharge({
    required this.id,
    required this.label,
    required this.amount,
    required this.taxable,
    required this.taxCategory,
    this.taxRate,
  });

  final String id;
  final String label;
  final double amount;
  final bool taxable;
  final String taxCategory;

  /// When null, the calculator uses [BillingConfig.gstRate].
  final double? taxRate;
}
