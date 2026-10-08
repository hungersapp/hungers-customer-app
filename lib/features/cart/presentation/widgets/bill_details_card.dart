import 'package:flutter/material.dart';

import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/billing_summary.dart';
import '../../domain/entities/cart_entity.dart';

class BillDetailsCard extends StatefulWidget {
  const BillDetailsCard({
    super.key,
    required this.summary,
  });

  final BillingSummary summary;

  @override
  State<BillDetailsCard> createState() => _BillDetailsCardState();
}

class _BillDetailsCardState extends State<BillDetailsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.summary;

    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bill Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _BillRow(
              label: 'Item Total',
              value: formatInr(summary.itemTotal),
            ),
            if (summary.hasDiscount) ...[
              const SizedBox(height: 10),
              _OffersBlock(summary: summary),
              const SizedBox(height: 10),
              _BillRow(
                label: 'Taxable Food Value',
                value: formatInr(summary.taxableFoodValue),
              ),
            ],
            const SizedBox(height: 10),
            _GstExpandable(
              summary: summary,
              expanded: _expanded,
              onToggle: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
            ),
            const SizedBox(height: 12),
            _BillRow(
              label: 'Delivery Charge',
              value: formatInr(summary.deliveryFee),
            ),
            if (summary.hasPlatformFee) ...[
              const SizedBox(height: 10),
              _BillRow(
                label: 'Platform Fee',
                value: formatInr(summary.platformFee),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            _BillRow(
              label: 'Final Payable',
              value: formatInr(summary.grandTotal),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _OffersBlock extends StatelessWidget {
  const _OffersBlock({required this.summary});

  final BillingSummary summary;

  @override
  Widget build(BuildContext context) {
    final lines = summary.discountLines.isNotEmpty
        ? summary.discountLines
        : [
            BillingDiscountLine(
              offerType: 'tukkito',
              description: 'Discount',
              amount: summary.discount,
            ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offers & Coupons',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        for (final line in lines) ...[
          _BillRow(
            label: line.description,
            value: '-${formatInr(line.amount)}',
            valueColor: AppColors.freshGreen,
          ),
          const SizedBox(height: 6),
        ],
        _BillRow(
          label: 'Total Discount',
          value: '-${formatInr(summary.discount)}',
          valueColor: AppColors.freshGreen,
        ),
      ],
    );
  }
}

class _GstExpandable extends StatelessWidget {
  const _GstExpandable({
    required this.summary,
    required this.expanded,
    required this.onToggle,
  });

  final BillingSummary summary;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _BillRow(
              labelWidget: Row(
                children: [
                  Text(
                    'GST',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.primary.withValues(alpha: 0.85),
                  ),
                ],
              ),
              value: formatInr(summary.gstAmount),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GstComponentBreakdown(summary: summary),
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}

/// Expandable GST ⓘ contents: food vs delivery (and packing/platform when present).
class GstComponentBreakdown extends StatelessWidget {
  const GstComponentBreakdown({super.key, required this.summary});

  final BillingSummary summary;

  @override
  Widget build(BuildContext context) {
    final foodRate = _percentLabel(summary.itemGstRate > 0
        ? summary.itemGstRate * 100
        : summary.gstRate * 100);
    final deliveryRate = _percentLabel(
      (summary.deliveryGstRate > 0 ? summary.deliveryGstRate : 0.18) * 100,
    );
    final packingRate = _percentLabel(
      (summary.packingGstRate > 0 ? summary.packingGstRate : summary.gstRate) *
          100,
    );
    final platformRate = _percentLabel(
      (summary.platformGstRate > 0 ? summary.platformGstRate : 0.18) * 100,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GST Breakdown',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Food / Restaurant',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 6),
        _BillRow(
          label: 'Taxable Value',
          value: formatInr(summary.taxableFoodValue),
        ),
        const SizedBox(height: 4),
        _BillRow(label: 'Applicable GST', value: '$foodRate%'),
        const SizedBox(height: 4),
        _BillRow(
          label: 'Food GST',
          value: formatInr(summary.itemGstAmount),
        ),
        const SizedBox(height: 12),
        Text(
          'Delivery Service',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 6),
        _BillRow(
          label: 'Taxable Value',
          value: formatInr(summary.deliveryFee),
        ),
        const SizedBox(height: 4),
        _BillRow(label: 'Applicable GST', value: '$deliveryRate%'),
        const SizedBox(height: 4),
        _BillRow(
          label: 'Delivery GST',
          value: formatInr(summary.deliveryGstAmount),
        ),
        if (summary.hasPackingCharge) ...[
          const SizedBox(height: 12),
          _BillRow(
            label: 'Packing GST ($packingRate%)',
            value: formatInr(summary.packingGstAmount),
          ),
        ],
        if (summary.hasPlatformFee) ...[
          const SizedBox(height: 12),
          _BillRow(
            label: 'Platform Fee GST ($platformRate%)',
            value: formatInr(summary.platformGstAmount),
          ),
        ],
        const SizedBox(height: 10),
        _BillRow(
          label: 'Total GST',
          value: formatInr(summary.gstAmount),
        ),
      ],
    );
  }

  static String _percentLabel(double percent) {
    if (percent == percent.roundToDouble()) {
      return percent.toStringAsFixed(0);
    }
    return percent.toStringAsFixed(1);
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    this.label,
    this.labelWidget,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  }) : assert(label != null || labelWidget != null);

  final String? label;
  final Widget? labelWidget;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
        );
    final amountStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: valueColor ?? AppColors.textPrimary,
          fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          fontSize: emphasize ? 18 : null,
        );

    return Row(
      children: [
        Expanded(
          child: labelWidget ?? Text(label!, style: labelStyle),
        ),
        Text(value, style: amountStyle),
      ],
    );
  }
}

class CheckoutBillSummary extends StatefulWidget {
  const CheckoutBillSummary({
    super.key,
    required this.summary,
    this.items = const [],
    this.deliveryDistanceLabel,
  });

  final BillingSummary summary;
  final List<CartEntity> items;

  /// Optional distance text, e.g. `4.2 km`, shown with the delivery fee row.
  final String? deliveryDistanceLabel;

  @override
  State<CheckoutBillSummary> createState() => _CheckoutBillSummaryState();
}

class _CheckoutBillSummaryState extends State<CheckoutBillSummary> {
  bool _gstExpanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final distance = widget.deliveryDistanceLabel?.trim();
    final deliveryLabel = (distance != null && distance.isNotEmpty)
        ? 'Delivery Charge ($distance)'
        : 'Delivery Charge';

    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bill Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 12),
            if (widget.items.isNotEmpty) ...[
              Text(
                'Items',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              for (final item in widget.items) ...[
                _ItemBillRow(item: item),
                const SizedBox(height: 8),
              ],
            ],
            _BillRow(
              label: 'Item Total',
              value: formatInr(summary.itemTotal),
            ),
            if (summary.hasDiscount) ...[
              const SizedBox(height: 10),
              _OffersBlock(summary: summary),
              const SizedBox(height: 10),
              _BillRow(
                label: 'Taxable Food Value',
                value: formatInr(summary.taxableFoodValue),
              ),
            ],
            const SizedBox(height: 8),
            _BillRow(
              label: deliveryLabel,
              value: formatInr(summary.deliveryFee),
            ),
            if (summary.hasPackingCharge) ...[
              const SizedBox(height: 8),
              _BillRow(
                label: 'Packing Charges',
                value: formatInr(summary.packingCharge),
              ),
            ],
            if (summary.hasPlatformFee) ...[
              const SizedBox(height: 8),
              _BillRow(
                label: 'Platform Fee',
                value: formatInr(summary.platformFee),
              ),
            ],
            const SizedBox(height: 10),
            _GstExpandable(
              summary: summary,
              expanded: _gstExpanded,
              onToggle: () {
                setState(() {
                  _gstExpanded = !_gstExpanded;
                });
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            _BillRow(
              label: 'Final Payable',
              value: formatInr(summary.grandTotal),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemBillRow extends StatelessWidget {
  const _ItemBillRow({required this.item});

  final CartEntity item;

  @override
  Widget build(BuildContext context) {
    final name = item.foodName.trim().isEmpty ? 'Item' : item.foodName.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                '${formatInr(item.finalPrice)} \u00d7 ${item.quantity}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              formatInr(item.totalPrice),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
