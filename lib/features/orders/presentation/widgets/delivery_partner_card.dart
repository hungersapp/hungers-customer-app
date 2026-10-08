import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/placed_order.dart';
import '../../domain/entities/rider_location.dart';
import '../../domain/order_contact_visibility.dart';
import '../providers/order_provider.dart';

class DeliveryPartnerCard extends ConsumerStatefulWidget {
  const DeliveryPartnerCard({
    super.key,
    required this.order,
    required this.tracking,
  });

  final PlacedOrder order;
  final DeliveryJobRiderTracking tracking;

  @override
  ConsumerState<DeliveryPartnerCard> createState() =>
      _DeliveryPartnerCardState();
}

class _DeliveryPartnerCardState extends ConsumerState<DeliveryPartnerCard> {
  bool _busy = false;
  String? _error;

  bool get _showCall => OrderContactVisibility.showRiderCall(
        status: widget.order.status,
        hasActiveRiderAssignment: widget.tracking.isAssigned,
      );

  String get _statusLine {
    switch (widget.tracking.status) {
      case 'picked_up':
      case 'out_for_delivery':
        return 'Order picked up';
      case 'assigned':
        return 'Rider assigned';
      default:
        return 'Delivery partner';
    }
  }

  String get _subtitle {
    switch (widget.tracking.status) {
      case 'picked_up':
      case 'out_for_delivery':
        return 'Arriving with your order';
      case 'assigned':
        return 'Heading to the restaurant';
      default:
        return 'On the way';
    }
  }

  Future<void> _callRider() async {
    if (_busy || !_showCall) {
      return;
    }
    final phone = widget.tracking.riderPhone?.trim() ?? '';
    if (phone.isEmpty) {
      setState(() => _error = 'Rider phone number unavailable.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final launched = await ref.read(phoneDialerServiceProvider).call(phone);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = launched
          ? null
          : 'Unable to open the phone dialer. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.tracking.riderDisplayName?.trim().isNotEmpty == true
        ? widget.tracking.riderDisplayName!.trim()
        : 'Delivery Partner';
    final rating = widget.tracking.riderRating;
    final photoUrl = widget.tracking.riderPhotoUrl;

    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Partner',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _RiderAvatar(name: name, photoUrl: photoUrl),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      if (rating != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (_showCall)
                  Material(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: _busy ? null : _callRider,
                      icon: const Icon(Icons.phone_rounded),
                      color: AppColors.primary,
                      tooltip: 'Call Rider',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _statusLine,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RiderAvatar extends StatelessWidget {
  const _RiderAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: photoUrl == null || photoUrl!.isEmpty
          ? null
          : ResizeImage(NetworkImage(photoUrl!), width: 112, height: 112),
      child: photoUrl == null || photoUrl!.isEmpty
          ? Text(
              initial,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                fontSize: 20,
              ),
            )
          : null,
    );
  }
}
