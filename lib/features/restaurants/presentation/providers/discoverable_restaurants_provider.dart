import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../serviceability/presentation/providers/serviceable_destination_provider.dart';
import '../../domain/discovery_debug_log.dart';
import '../../domain/entities/restaurant_entity.dart';
import 'restaurant_provider.dart';

/// Single destination-scoped restaurant catalog for Home, Search, and
/// Category. One geohash read per destination change — not per section.
final discoverableRestaurantsProvider =
    FutureProvider<List<RestaurantEntity>>((ref) async {
      final destination = await ref.watch(
        serviceableDeliveryDestinationProvider.future,
      );
      if (destination == null) {
        discoveryDebug(
          'discoverableRestaurants=0 first_empty_stage='
          'serviceability or no destination '
          '(serviceableDeliveryDestinationProvider is null)',
        );
        return const [];
      }
      discoveryDebug(
        'serviceable destination lat=${destination.latitude} '
        'lng=${destination.longitude} city=${destination.city} '
        'selectedByCustomer=${destination.selectedByCustomer} '
        'isLiveGpsDefault=${destination.isLiveGpsDefault}',
      );
      return ref.read(getAllRestaurantsProvider)(destination: destination);
    });
