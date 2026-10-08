import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/restaurant_entity.dart';
import 'restaurant_provider.dart';

/// Keeps the last opened restaurant so Chrome can rebuild
/// `/restaurant-details` without dropping the page to blank.
final lastViewedRestaurantProvider = StateProvider<RestaurantEntity?>(
  (ref) => null,
);

/// Restaurant Details Provider
final restaurantDetailsProvider =
    FutureProvider.family<RestaurantEntity?, String>((ref, restaurantId) async {
      final useCase = ref.read(getRestaurantByIdProvider);

      return await useCase(restaurantId);
    });
