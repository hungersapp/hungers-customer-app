import 'package:flutter/material.dart';

import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';

/// Persistent cart summary shown on the restaurant menu while items exist.
class BottomCartBar extends StatelessWidget {
  const BottomCartBar({
    super.key,
    required this.itemCount,
    required this.total,
    required this.onViewCart,
    this.maxWidth = 960,
  });

  final int itemCount;
  final double? total;
  final VoidCallback onViewCart;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final itemLabel = itemCount == 1 ? '1 item' : '$itemCount items';

    return SafeArea(
      top: false,
      // heightFactor keeps the bar at its own height. Without it, Align
      // fills the whole Scaffold bottomNavigationBar slot and the menu body
      // above collapses to an empty page as soon as the bar appears.
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Material(
              color: AppColors.primary,
              elevation: 4,
              shadowColor: AppColors.shadow,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: const ValueKey<String>('bottom-cart-bar'),
                onTap: onViewCart,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              itemLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              total == null
                                  ? '\u20B9\u2014'
                                  : formatInrWhole(total!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'View Cart',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.textLight,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
