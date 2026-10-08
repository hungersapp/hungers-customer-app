import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/offer.dart';
import '../providers/offer_providers.dart';

/// "Offers & Savings": the offers available for a restaurant's cart, grouped
/// by who provides them. Shared by the cart and checkout.
///
/// This widget only lists offers and reports taps. Applying one means asking
/// the backend (`quoteOrder`); the saving shown in [savedAmount] is whatever
/// the backend returned, never a figure computed here.
class OffersSavingsSection extends ConsumerWidget {
  const OffersSavingsSection({
    super.key,
    required this.restaurantId,
    required this.itemTotal,
    required this.onApply,
    required this.onRemove,
    this.appliedOffer,
    this.savedAmount,
    this.busyOfferId,
    this.message,
    this.paymentMethod,
  });

  final String restaurantId;
  final double itemTotal;
  final ValueChanged<Offer> onApply;
  final VoidCallback onRemove;
  final Offer? appliedOffer;

  /// Backend-confirmed saving for [appliedOffer]; null while unconfirmed.
  final double? savedAmount;
  final String? busyOfferId;

  /// Validation feedback for the last attempt (customer wording).
  final String? message;

  /// The `placeOrder` payment value selected at checkout. Null in the cart,
  /// where no method is chosen yet and payment offers are view-only.
  final String? paymentMethod;

  static const String heading = 'Offers & Savings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(restaurantOffersProvider(restaurantId));

    return _Panel(
      child: offers.when(
        loading: () => const _OffersSkeleton(),
        error: (_, _) => _Notice(
          text: "Offers couldn't be loaded.",
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(activeOffersProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const _Notice(text: 'No offers available for this order.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (appliedOffer != null) ...[
                _AppliedBanner(
                  offer: appliedOffer!,
                  savedAmount: savedAmount,
                  onRemove: onRemove,
                ),
                const SizedBox(height: 12),
              ],
              if (message != null) ...[
                Text(
                  message!,
                  key: const ValueKey<String>('offer-message'),
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final type in OfferType.values)
                if (list.any((offer) => offer.type == type))
                  _OfferGroup(
                    type: type,
                    offers: [
                      for (final offer in list)
                        if (offer.type == type) offer,
                    ],
                    itemTotal: itemTotal,
                    appliedOfferId: appliedOffer?.id,
                    busyOfferId: busyOfferId,
                    paymentMethod: paymentMethod,
                    onApply: onApply,
                    onRemove: onRemove,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              OffersSavingsSection.heading.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.35),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _OffersSkeleton extends StatelessWidget {
  const _OffersSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width) => Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bar(120),
        const SizedBox(height: 10),
        bar(220),
        const SizedBox(height: 16),
        bar(100),
        const SizedBox(height: 10),
        bar(200),
      ],
    );
  }
}

class _AppliedBanner extends StatelessWidget {
  const _AppliedBanner({
    required this.offer,
    required this.savedAmount,
    required this.onRemove,
  });

  final Offer offer;
  final double? savedAmount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final saved = savedAmount;
    return DecoratedBox(
      key: const ValueKey<String>('offer-applied-banner'),
      decoration: BoxDecoration(
        color: AppColors.freshGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.freshGreen.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.freshGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${offer.title} applied',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (saved != null && saved > 0)
                    Text(
                      'You saved ${formatInr(saved)}',
                      style: const TextStyle(
                        color: AppColors.freshGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              key: const ValueKey<String>('offer-remove'),
              onPressed: onRemove,
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Presentation of one provider. Each has its own icon and accent so the
/// three kinds of offer never read as the same thing.
class _GroupStyle {
  const _GroupStyle(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static _GroupStyle of(OfferType type) {
    switch (type) {
      case OfferType.tukkito:
        return const _GroupStyle(
          'Tukkito Offers',
          Icons.local_offer_rounded,
          AppColors.primary,
        );
      case OfferType.restaurant:
        return const _GroupStyle(
          'Restaurant Offers',
          Icons.storefront_rounded,
          AppColors.charcoal,
        );
      case OfferType.paymentPartner:
        return const _GroupStyle(
          'Payment Offers',
          Icons.account_balance_wallet_rounded,
          AppColors.info,
        );
    }
  }
}

class _OfferGroup extends StatelessWidget {
  const _OfferGroup({
    required this.type,
    required this.offers,
    required this.itemTotal,
    required this.appliedOfferId,
    required this.busyOfferId,
    required this.paymentMethod,
    required this.onApply,
    required this.onRemove,
  });

  final OfferType type;
  final List<Offer> offers;
  final double itemTotal;
  final String? appliedOfferId;
  final String? busyOfferId;
  final String? paymentMethod;
  final ValueChanged<Offer> onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final style = _GroupStyle.of(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(style.icon, size: 18, color: style.color),
              const SizedBox(width: 8),
              Text(
                style.label,
                style: TextStyle(
                  color: style.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          for (final offer in offers)
            _OfferRow(
              offer: offer,
              accent: style.color,
              itemTotal: itemTotal,
              isApplied: offer.id == appliedOfferId,
              isBusy: offer.id == busyOfferId,
              canInteract: busyOfferId == null,
              paymentMethod: paymentMethod,
              onApply: () => onApply(offer),
              onRemove: onRemove,
            ),
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.offer,
    required this.accent,
    required this.itemTotal,
    required this.isApplied,
    required this.isBusy,
    required this.canInteract,
    required this.paymentMethod,
    required this.onApply,
    required this.onRemove,
  });

  final Offer offer;
  final Color accent;
  final double itemTotal;
  final bool isApplied;
  final bool isBusy;
  final bool canInteract;
  final String? paymentMethod;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  /// Cashback is informational, and a payment discount needs a payment
  /// method, which the cart does not have yet.
  bool get _viewOnly =>
      offer.isCashback ||
      (offer.type == OfferType.paymentPartner && paymentMethod == null);

  String get _provider {
    switch (offer.type) {
      case OfferType.tukkito:
        return 'Tukkito';
      case OfferType.restaurant:
        return offer.restaurantName ?? 'the restaurant';
      case OfferType.paymentPartner:
        return offer.partnerName ?? 'the payment partner';
    }
  }

  String get _hint {
    if (offer.isCashback) {
      return 'Cashback from $_provider after payment. '
          'It does not reduce the amount you pay now.';
    }
    final shortfall = offer.shortfallFor(itemTotal);
    if (shortfall > 0) {
      return 'Add ${formatInrWhole(shortfall.ceilToDouble())} more to use '
          'this offer.';
    }
    if (offer.type == OfferType.paymentPartner && paymentMethod == null) {
      return 'Choose the eligible payment method at checkout.';
    }
    return 'Instant discount from $_provider.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = [
      offer.benefitLabel,
      if (offer.conditionLabel.isNotEmpty) offer.conditionLabel,
    ].join(' ');

    return InkWell(
      onTap: () => _showDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          offer.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _BenefitTag(isCashback: offer.isCashback),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _action(context),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    if (isBusy) {
      return const SizedBox(
        width: 72,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (isApplied) {
      return OutlinedButton(
        onPressed: canInteract ? onRemove : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.freshGreen,
          side: const BorderSide(color: AppColors.freshGreen),
          minimumSize: const Size(72, 36),
          shape: shape,
        ),
        child: const Text('Applied'),
      );
    }
    if (_viewOnly) {
      return OutlinedButton(
        key: ValueKey<String>('offer-view-${offer.id}'),
        onPressed: () => _showDetails(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.5)),
          minimumSize: const Size(72, 36),
          shape: shape,
        ),
        child: const Text('View Offer'),
      );
    }
    return OutlinedButton(
      key: ValueKey<String>('offer-apply-${offer.id}'),
      onPressed: canInteract ? onApply : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        minimumSize: const Size(72, 36),
        shape: shape,
      ),
      child: const Text(
        'Apply',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                offer.title,
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Offered by $_provider',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                [
                  offer.benefitLabel,
                  if (offer.conditionLabel.isNotEmpty) offer.conditionLabel,
                ].join(' '),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (offer.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(offer.description, style: const TextStyle(height: 1.4)),
              ],
              const SizedBox(height: 8),
              Text(
                offer.isCashback
                    ? 'This is cashback, not a discount: you pay the full '
                          'bill and $_provider credits the cashback afterwards.'
                    : 'This is an instant discount: it reduces the amount you '
                          'pay for this order.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (offer.newCustomerOnly) ...[
                const SizedBox(height: 8),
                const Text(
                  'Valid on your first order only.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
              if ((offer.terms ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Terms',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offer.terms!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitTag extends StatelessWidget {
  const _BenefitTag({required this.isCashback});

  final bool isCashback;

  @override
  Widget build(BuildContext context) {
    final color = isCashback ? AppColors.info : AppColors.freshGreen;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          isCashback ? 'Cashback' : 'Instant discount',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
