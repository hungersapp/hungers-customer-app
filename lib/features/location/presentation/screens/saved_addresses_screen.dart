import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../domain/entities/saved_address_book.dart';
import '../../domain/entities/user_location.dart';
import '../providers/location_provider.dart';
import 'delivery_address_editor_screen.dart';

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Saved Addresses'), centerTitle: true),
      body: userId == null
          ? const Center(child: Text('Please login to manage addresses.'))
          : _SavedAddressList(userId: userId),
    );
  }
}

class _SavedAddressList extends ConsumerWidget {
  const _SavedAddressList({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(savedAddressBookProvider(userId));
    final selected = ref.watch(userLocationProvider(userId)).valueOrNull;

    return bookAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            'Unable to load saved addresses.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (book) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.lg,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            for (final slot in SavedAddressSlot.values)
              _SlotCard(
                userId: userId,
                slot: slot,
                address: book[slot],
                selected: selected,
              ),
          ],
        );
      },
    );
  }
}

class _SlotCard extends ConsumerWidget {
  const _SlotCard({
    required this.userId,
    required this.slot,
    required this.address,
    required this.selected,
  });

  final String userId;
  final SavedAddressSlot slot;
  final UserLocation? address;
  final UserLocation? selected;

  bool get _isSelected {
    final current = address;
    final dest = selected;
    if (current == null || dest == null) {
      return false;
    }
    return current.latitude == dest.latitude &&
        current.longitude == dest.longitude;
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DeliveryAddressEditorScreen(
          initial: address ?? selected,
          requireAddressDetails: true,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    final latest = ref.read(userLocationProvider(userId)).valueOrNull;
    if (latest == null || !latest.isCompleteForDiscovery) {
      return;
    }
    await ref
        .read(savedAddressRepositoryProvider)
        .saveAddress(userId: userId, slot: slot, location: latest);
    ref.invalidate(savedAddressBookProvider(userId));
  }

  Future<void> _select(WidgetRef ref) async {
    final current = address;
    if (current == null) {
      return;
    }
    await ref
        .read(locationSetupProvider.notifier)
        .selectLocation(
          userId: userId,
          location: current,
          source: LocationSource.forSavedSlot(slot),
        );
    ref.invalidate(savedAddressBookProvider(userId));
  }

  Future<void> _delete(WidgetRef ref) async {
    await ref
        .read(savedAddressRepositoryProvider)
        .deleteAddress(userId: userId, slot: slot);
    ref.invalidate(savedAddressBookProvider(userId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = address;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surface,
        elevation: 1,
        shadowColor: AppColors.shadow,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    slot.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (_isSelected) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Text(
                      'Selected',
                      style: TextStyle(
                        color: AppColors.freshGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                current?.checkoutDisplayBlock.isNotEmpty == true
                    ? current!.checkoutDisplayBlock
                    : current?.displayAddress ?? 'Not saved yet',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => _edit(context, ref),
                    child: Text(current == null ? 'Add' : 'Edit'),
                  ),
                  if (current != null)
                    TextButton(
                      onPressed: () => _select(ref),
                      child: const Text('Deliver here'),
                    ),
                  if (current != null)
                    TextButton(
                      onPressed: () => _delete(ref),
                      child: const Text('Delete'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
