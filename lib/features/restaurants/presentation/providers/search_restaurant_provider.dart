import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../serviceability/presentation/providers/serviceable_destination_provider.dart';
import '../../domain/entities/restaurant_entity.dart';
import 'restaurant_provider.dart';

/// Search Restaurant Provider
///
/// Scoped to the selected delivery destination; re-runs when it changes.
final searchRestaurantProvider =
    FutureProvider.family<List<RestaurantEntity>, String>((ref, keyword) async {
      // Empty search என்றால் Firestore call செய்ய வேண்டாம்.
      if (keyword.trim().isEmpty) {
        return [];
      }

      final destination = await ref.watch(
        serviceableDeliveryDestinationProvider.future,
      );
      final useCase = ref.read(searchRestaurantsProvider);

      return await useCase(keyword.trim(), destination: destination);
    });
