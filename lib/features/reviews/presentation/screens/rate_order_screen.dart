import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../orders/domain/entities/placed_order.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../domain/review_tags.dart';
import '../../domain/submit_order_review_request.dart';
import '../providers/review_provider.dart';

/// Rates a delivered order: an overall star rating up front, then optional
/// sections — a thumbs up / down per dish, a detailed review, and the delivery
/// partner — and a single Submit. A successful submit swaps the form for a
/// full-screen thank-you that closes itself.
class RateOrderScreen extends ConsumerStatefulWidget {
  const RateOrderScreen({
    super.key,
    required this.order,
    this.initialRating,
    this.initialDeliveryRating,
  });

  final PlacedOrder order;

  /// The star the customer tapped on the order card (1–5), pre-selected here.
  final int? initialRating;

  /// The delivery star tapped on the order card (1–5): pre-selected, with the
  /// delivery section opened.
  final int? initialDeliveryRating;

  /// How long the thank-you stays up before the screen closes itself.
  static const Duration thankYouDuration = Duration(seconds: 2);

  @override
  ConsumerState<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends ConsumerState<RateOrderScreen> {
  /// What a thumbs up / down on a dish is submitted as on the 1–5 food scale.
  static const int _thumbsUpRating = 5;
  static const int _thumbsDownRating = 1;

  int _restaurantRating = 0;
  int? _deliveryRating;
  final Map<String, int> _foodRatings = {};
  final Set<String> _restaurantTags = {};
  final Set<String> _deliveryTags = {};
  final _restaurantComment = TextEditingController();
  final _deliveryComment = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  bool _dishesExpanded = true;
  bool _detailsExpanded = false;
  bool _deliveryExpanded = false;

  Timer? _closeTimer;

  PlacedOrder get order => widget.order;

  @override
  void initState() {
    super.initState();
    final rating = widget.initialRating;
    if (rating != null && rating >= 1 && rating <= 5) {
      _restaurantRating = rating;
    }
    final delivery = widget.initialDeliveryRating;
    if (delivery != null && delivery >= 1 && delivery <= 5) {
      _deliveryRating = delivery;
      _deliveryExpanded = true;
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _restaurantComment.dispose();
    _deliveryComment.dispose();
    super.dispose();
  }

  void _close() {
    _closeTimer?.cancel();
    Navigator.of(context).pop(_submitted ? true : null);
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (_restaurantRating < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(submitOrderReviewUseCaseProvider)(
        SubmitOrderReviewRequest(
          orderId: order.id,
          restaurantRating: _restaurantRating,
          restaurantComment: _restaurantComment.text.trim(),
          restaurantTags: _restaurantTags.toList(),
          deliveryRating: _deliveryRating,
          deliveryComment: _deliveryComment.text.trim(),
          deliveryTags: _deliveryTags.toList(),
          foodRatings: [
            for (final foodId in {
              for (final item in order.items)
                if (item.foodId.trim().isNotEmpty) item.foodId,
            })
              if ((_foodRatings[foodId] ?? 0) >= 1)
                FoodRatingInput(foodId: foodId, rating: _foodRatings[foodId]!),
          ],
        ),
      );
      if (!mounted) {
        return;
      }
      ref.invalidate(customerOrdersProvider(order.userId));
      ref.invalidate(
        orderDetailsProvider(
          OrderLookup(userId: order.userId, orderId: order.id),
        ),
      );
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      _closeTimer = Timer(RateOrderScreen.thankYouDuration, () {
        if (mounted) {
          _close();
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _toggleFoodRating(String foodId, int rating) {
    setState(() {
      if (_foodRatings[foodId] == rating) {
        _foodRatings.remove(foodId);
      } else {
        _foodRatings[foodId] = rating;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Once submitted, leaving by any route reports the review as done.
      canPop: !_submitted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close();
        }
      },
      child: Scaffold(
        backgroundColor: _submitted ? AppColors.surface : AppColors.background,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            child: _submitted
                ? _ThankYouView(key: const ValueKey('thanks'), onClose: _close)
                : _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final ratedItems = [
      for (final item in order.items)
        if (item.foodId.trim().isNotEmpty) item,
    ];

    return Column(
      key: const ValueKey('form'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: _submitting ? null : _close,
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textPrimary,
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        order.restaurantName.trim().isEmpty
                            ? 'Rate your order'
                            : 'Meal from ${order.restaurantName.trim()}',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  // Balances the close button so the title stays centred.
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _StarRow(
                value: _restaurantRating,
                size: 34,
                alignment: MainAxisAlignment.center,
                showFace: true,
                onChanged: _submitting
                    ? null
                    : (value) {
                        // The "select a star rating" notice sits over Submit:
                        // clear it as soon as a star is chosen.
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        setState(() => _restaurantRating = value);
                      },
              ),
              const SizedBox(height: AppSpacing.xl),
              if (ratedItems.isNotEmpty) ...[
                _SectionCard(
                  title: 'Rate your ordered dishes',
                  expanded: _dishesExpanded,
                  onToggle: () =>
                      setState(() => _dishesExpanded = !_dishesExpanded),
                  child: Column(
                    children: [
                      for (final item in ratedItems)
                        _DishRow(
                          name: item.foodName,
                          rating: _foodRatings[item.foodId],
                          upRating: _thumbsUpRating,
                          downRating: _thumbsDownRating,
                          onRate: _submitting
                              ? null
                              : (rating) =>
                                    _toggleFoodRating(item.foodId, rating),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              _SectionCard(
                title: 'Add a detailed review',
                expanded: _detailsExpanded,
                onToggle: () =>
                    setState(() => _detailsExpanded = !_detailsExpanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TagWrap(
                      tags: ReviewTags.restaurant,
                      selected: _restaurantTags,
                      enabled: !_submitting,
                      onToggle: (tag) {
                        setState(() {
                          if (!_restaurantTags.add(tag)) {
                            _restaurantTags.remove(tag);
                          }
                        });
                      },
                    ),
                    _CommentField(
                      controller: _restaurantComment,
                      enabled: !_submitting,
                      hintText: 'Tell us more about your order (optional)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionCard(
                title: 'Rate your delivery partner',
                expanded: _deliveryExpanded,
                onToggle: () =>
                    setState(() => _deliveryExpanded = !_deliveryExpanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StarRow(
                      value: _deliveryRating ?? 0,
                      size: 28,
                      alignment: MainAxisAlignment.start,
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _deliveryRating = value),
                    ),
                    _TagWrap(
                      tags: ReviewTags.delivery,
                      selected: _deliveryTags,
                      enabled: !_submitting,
                      onToggle: (tag) {
                        setState(() {
                          if (!_deliveryTags.add(tag)) {
                            _deliveryTags.remove(tag);
                          }
                        });
                      },
                    ),
                    _CommentField(
                      controller: _deliveryComment,
                      enabled: !_submitting,
                      hintText: 'Tell us about the delivery (optional)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.textLight,
                    ),
                  )
                : const Text(
                    'Submit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen confirmation shown after a review is submitted.
class _ThankYouView extends StatelessWidget {
  const _ThankYouView({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: const Text('🥰', style: TextStyle(fontSize: 72)),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                Text(
                  'Thank you for your valuable\nfeedback!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: AppSpacing.md,
          left: AppSpacing.page,
          child: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textPrimary,
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          ),
        ),
      ],
    );
  }
}

/// A white rounded card with a title row that expands / collapses its body.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(
                        height: 1,
                        indent: AppSpacing.lg,
                        endIndent: AppSpacing.lg,
                        color: AppColors.divider,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: child,
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.name,
    required this.rating,
    required this.upRating,
    required this.downRating,
    required this.onRate,
  });

  final String name;
  final int? rating;
  final int upRating;
  final int downRating;
  final ValueChanged<int>? onRate;

  @override
  Widget build(BuildContext context) {
    final liked = rating == upRating;
    final disliked = rating == downRating;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        IconButton(
          onPressed: onRate == null ? null : () => onRate!(upRating),
          tooltip: 'Liked it',
          icon: Icon(
            liked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
            color: liked ? AppColors.freshGreen : AppColors.textSecondary,
          ),
        ),
        IconButton(
          onPressed: onRate == null ? null : () => onRate!(downRating),
          tooltip: 'Did not like it',
          icon: Icon(
            disliked
                ? Icons.thumb_down_alt_rounded
                : Icons.thumb_down_alt_outlined,
            color: disliked ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CommentField extends StatelessWidget {
  const _CommentField({
    required this.controller,
    required this.enabled,
    required this.hintText,
  });

  final TextEditingController controller;
  final bool enabled;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.value,
    required this.onChanged,
    required this.size,
    required this.alignment,
    this.showFace = false,
  });

  static const Color _filled = Color(0xFFF5A623);

  final int value;
  final ValueChanged<int>? onChanged;
  final double size;
  final MainAxisAlignment alignment;

  /// The chosen star grows a little face whose mood follows the rating, and
  /// wobbles as it lands — the reference's animated star.
  final bool showFace;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: onChanged == null ? null : () => onChanged!(i),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: BoxConstraints.tightFor(
              width: size + 12,
              height: size + 12,
            ),
            icon: i == value
                ? _ChosenStar(
                    // A new key restarts the landing animation for each pick.
                    key: ValueKey<int>(value),
                    rating: value,
                    size: size,
                    color: _filled,
                    showFace: showFace,
                  )
                : Icon(
                    i <= value ? Icons.star_rounded : Icons.star_border_rounded,
                    size: size,
                    color: i <= value ? _filled : AppColors.textSecondary,
                  ),
          ),
      ],
    );
  }
}

/// The star the customer just picked: it pops, wobbles and settles slightly
/// larger than its neighbours, optionally with a face for the rating.
class _ChosenStar extends StatelessWidget {
  const _ChosenStar({
    super.key,
    required this.rating,
    required this.size,
    required this.color,
    required this.showFace,
  });

  final int rating;
  final double size;
  final Color color;
  final bool showFace;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      builder: (context, t, child) {
        final settle = 1 - t;
        return Transform.rotate(
          angle: math.sin(t * math.pi * 4) * 0.22 * settle,
          child: Transform.scale(
            scale: 1.25 + math.sin(t * math.pi) * 0.25 * settle,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.star_rounded, size: size, color: color),
            if (showFace)
              CustomPaint(
                size: Size.square(size),
                painter: _StarFacePainter(rating),
              ),
          ],
        ),
      ),
    );
  }
}

/// Two eyes and a mouth on the star: a frown at 1, flat at 3, a wide smile
/// at 5.
class _StarFacePainter extends CustomPainter {
  const _StarFacePainter(this.rating);

  final int rating;

  static const Color _ink = Color(0xFF7A4A00);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // The star's body sits a little below the icon's geometric centre.
    final centre = Offset(w / 2, size.height * 0.56);
    final eye = Paint()..color = _ink;
    final eyeRadius = w * 0.04;
    canvas.drawCircle(centre + Offset(-w * 0.11, -w * 0.05), eyeRadius, eye);
    canvas.drawCircle(centre + Offset(w * 0.11, -w * 0.05), eyeRadius, eye);

    // -1 (frown) … 0 (flat) … +1 (smile).
    final mood = ((rating.clamp(1, 5) - 3) / 2).toDouble();
    final mouthY = centre.dy + w * 0.09 - mood * w * 0.02;
    final mouth = Path()
      ..moveTo(centre.dx - w * 0.1, mouthY)
      ..quadraticBezierTo(
        centre.dx,
        mouthY + mood * w * 0.11,
        centre.dx + w * 0.1,
        mouthY,
      );
    canvas.drawPath(
      mouth,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.045,
    );
  }

  @override
  bool shouldRepaint(_StarFacePainter oldDelegate) =>
      oldDelegate.rating != rating;
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({
    required this.tags,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final List<String> tags;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in tags)
            FilterChip(
              label: Text(tag),
              selected: selected.contains(tag),
              onSelected: enabled ? (_) => onToggle(tag) : null,
            ),
        ],
      ),
    );
  }
}
