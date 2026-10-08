import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../location/domain/entities/user_location.dart';
import '../../../location/presentation/helpers/open_delivery_location_chooser.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../serviceability/domain/geo_distance.dart';
import '../../../serviceability/presentation/providers/destination_serviceability_provider.dart';
import '../../../serviceability/presentation/widgets/serviceability_status_view.dart';
import '../../domain/entities/restaurant_entity.dart';
import '../providers/popular_restaurant_provider.dart';
import '../providers/restaurant_details_provider.dart';
import '../providers/restaurant_list_provider.dart';
import '../screens/restaurant_details_screen.dart';
import 'restaurant_card.dart';
import 'restaurant_empty_view.dart';
import 'restaurant_error_view.dart';
import 'restaurant_shimmer.dart';

class RestaurantSection extends ConsumerWidget {
  const RestaurantSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Serviceability of the SELECTED LOCATION, decided from its coordinates.
    final serviceability = ref.watch(deliveryServiceabilityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ServiceabilityStatusView(
          state: serviceability,
          onRetry: () {
            ref.invalidate(destinationServiceabilityProvider);
          },
          onChangeLocation: () => openDeliveryLocationChooser(context, ref),
        ),
        if (serviceability.allowsRestaurantQuery)
          const _PopularNearYouSection(),
      ],
    );
  }
}

class _PopularNearYouSection extends ConsumerStatefulWidget {
  const _PopularNearYouSection();

  @override
  ConsumerState<_PopularNearYouSection> createState() =>
      _PopularNearYouSectionState();
}

class _PopularNearYouSectionState
    extends ConsumerState<_PopularNearYouSection> {
  bool _showAll = false;

  void _openDetails(RestaurantEntity restaurant) {
    ref.read(lastViewedRestaurantProvider.notifier).state = restaurant;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
          name: AppRoutes.restaurantDetails,
          arguments: restaurant,
        ),
        builder: (_) => RestaurantDetailsScreen(restaurant: restaurant),
      ),
    );
  }

  String? _distanceLabel({
    required RestaurantEntity restaurant,
    required UserLocation? location,
  }) {
    if (location == null) {
      return null;
    }

    final km = GeoDistance.calculateDistanceKm(
      latitude1: location.latitude,
      longitude1: location.longitude,
      latitude2: restaurant.latitude,
      longitude2: restaurant.longitude,
    );
    if (km == null) {
      return null;
    }
    if (km < 0.1) {
      return '< 0.1 km';
    }
    if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    }
    return '${km.round()} km';
  }

  @override
  Widget build(BuildContext context) {
    final restaurantsAsync = _showAll
        ? ref.watch(restaurantListProvider)
        : ref.watch(popularRestaurantProvider);
    final userId = ref.watch(authProvider).valueOrNull?.uid;
    final location = userId == null
        ? null
        : ref.watch(userLocationProvider(userId)).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.lg,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Popular Near You',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAll = true;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        restaurantsAsync.when(
          loading: () => const RestaurantShimmer(),
          error: (error, _) {
            return RestaurantErrorView(
              message: error.toString(),
              onRetry: () {
                if (_showAll) {
                  ref.read(restaurantListProvider.notifier).refresh();
                } else {
                  ref.read(popularRestaurantProvider.notifier).refresh();
                }
              },
            );
          },
          data: (restaurants) {
            if (restaurants.isEmpty) {
              // Nothing delivers to the selected location: say so, and let the
              // customer choose another one.
              return RestaurantEmptyView(
                onPressed: () => openDeliveryLocationChooser(context, ref),
                buttonText: 'Change location',
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < restaurants.length; i++) ...[
                    RestaurantCard(
                      restaurant: restaurants[i],
                      distanceLabel: _distanceLabel(
                        restaurant: restaurants[i],
                        location: location,
                      ),
                      onTap: () => _openDetails(restaurants[i]),
                    ),
                    if (i < restaurants.length - 1)
                      const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
