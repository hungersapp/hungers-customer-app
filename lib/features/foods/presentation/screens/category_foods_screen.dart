import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../cart/domain/cart_quantity.dart';
import '../../../cart/domain/entities/cart_entity.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../dashboard/domain/entities/category.dart';
import '../../../location/domain/entities/user_location.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../serviceability/domain/geo_distance.dart';
import '../../../serviceability/presentation/providers/serviceable_destination_provider.dart';
import '../../domain/entities/category_food_item.dart';
import '../../domain/entities/food_entity.dart';
import '../../domain/usecases/get_customer_foods_by_category_usecase.dart';
import '../providers/food_provider.dart';
import '../widgets/category_food_discovery_card.dart';
import 'food_details_screen.dart';

/// Lists customer-eligible foods for a Home category (by category name).
class CategoryFoodsScreen extends ConsumerStatefulWidget {
  const CategoryFoodsScreen({super.key, required this.category});

  final Category category;

  @override
  ConsumerState<CategoryFoodsScreen> createState() =>
      _CategoryFoodsScreenState();
}

class _CategoryFoodsScreenState extends ConsumerState<CategoryFoodsScreen> {
  final Set<String> _updatingFoodIds = <String>{};
  final List<CategoryFoodItem> _extraItems = [];
  bool _loadingMore = false;
  bool _endReached = false;

  String get _categoryName => widget.category.name.trim();

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(customerCategoryFoodsProvider(_categoryName));
    final userId = ref.watch(currentUserIdProvider);

    final cartQuantities = <String, int>{};
    if (userId != null) {
      final cartItems = ref.watch(cartItemsProvider(userId)).valueOrNull;
      if (cartItems != null) {
        cartQuantities.addAll(CartQuantity.indexByFoodId(cartItems));
      }
    }

    final location = userId == null
        ? null
        : ref.watch(userLocationProvider(userId)).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_categoryName.isEmpty ? 'Category' : _categoryName),
      ),
      body: foodsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => _CategoryFoodsError(
          message: error.toString(),
          onRetry: () {
            setState(() {
              _extraItems.clear();
              _endReached = false;
            });
            ref.invalidate(customerCategoryFoodsProvider(_categoryName));
          },
        ),
        data: (items) {
          final allItems = [...items, ..._extraItems];
          if (allItems.isEmpty) {
            return const _CategoryFoodsEmpty();
          }
          return _CategoryFoodsList(
            items: allItems,
            location: location,
            cartQuantities: cartQuantities,
            updatingFoodIds: _updatingFoodIds,
            isLoadingMore: _loadingMore,
            showLoadMore: !_endReached && items.length >= GetCustomerFoodsByCategoryUseCase.pageSize,
            onLoadMore: () => _loadMore(items),
            onFoodTap: (item) => openFoodDetails(
              context,
              food: item.food,
              restaurantName: item.restaurantName,
            ),
            onAddTap: _addFood,
            onIncreaseTap: (item, next) =>
                _changeQuantity(item: item, nextQuantity: next),
            onDecreaseTap: (item, next) =>
                _changeQuantity(item: item, nextQuantity: next),
          );
        },
      ),
    );
  }

  Future<void> _loadMore(List<CategoryFoodItem> firstPage) async {
    if (_loadingMore || _endReached) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final lastName = [...firstPage, ..._extraItems].isEmpty
          ? null
          : [...firstPage, ..._extraItems].last.food.name;
      final destination = await ref.read(
        serviceableDeliveryDestinationProvider.future,
      );
      final page = await ref.read(getCustomerFoodsByCategoryUseCaseProvider).page(
            _categoryName,
            destination: destination,
            startAfterName: lastName,
          );
      final seen = {
        for (final item in firstPage) item.food.id,
        for (final item in _extraItems) item.food.id,
      };
      final extra = [
        for (final item in page.items)
          if (seen.add(item.food.id)) item,
      ];
      if (!mounted) {
        return;
      }
      setState(() {
        _extraItems.addAll(extra);
        _endReached = !page.hasMore || extra.isEmpty;
        _loadingMore = false;
      });
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  String _foodDisplayName(FoodEntity food) {
    if (food.name.trim().isNotEmpty) {
      return food.name.trim();
    }
    return food.description.trim();
  }

  Future<void> _addFood(CategoryFoodItem item) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      _showMessage('Please login to add items.');
      return;
    }

    final food = item.food;
    if (_updatingFoodIds.contains(food.id)) {
      return;
    }

    setState(() {
      _updatingFoodIds.add(food.id);
    });

    try {
      await ref
          .read(cartNotifierProvider.notifier)
          .addToCart(
            CartEntity(
              id: food.id,
              userId: userId,
              restaurantId: food.restaurantId,
              restaurantName: item.restaurantName,
              foodId: food.id,
              foodName: _foodDisplayName(food),
              foodImage: food.imageUrl,
              price: food.price,
              offerPrice: food.offerPrice,
              quantity: 1,
              isVeg: food.isVeg,
              isAvailable: food.isAvailable,
              createdAt: DateTime.now(),
            ),
          );

      if (ref.read(cartNotifierProvider).hasError) {
        _showMessage('Unable to add item. Please try again.');
        return;
      }

      await ref.read(cartItemsProvider(userId).future);
    } catch (_) {
      _showMessage('Unable to add item. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _updatingFoodIds.remove(food.id);
        });
      }
    }
  }

  Future<void> _changeQuantity({
    required CategoryFoodItem item,
    required int nextQuantity,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      _showMessage('Please login to update your cart.');
      return;
    }

    final food = item.food;
    if (_updatingFoodIds.contains(food.id)) {
      return;
    }

    setState(() {
      _updatingFoodIds.add(food.id);
    });

    try {
      await ref
          .read(cartNotifierProvider.notifier)
          .updateQuantity(
            userId: userId,
            foodId: food.id,
            quantity: nextQuantity,
          );

      if (ref.read(cartNotifierProvider).hasError) {
        _showMessage('Unable to update quantity. Please try again.');
        return;
      }

      await ref.read(cartItemsProvider(userId).future);
    } catch (_) {
      _showMessage('Unable to update quantity. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _updatingFoodIds.remove(food.id);
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CategoryFoodsList extends StatelessWidget {
  const _CategoryFoodsList({
    required this.items,
    required this.location,
    required this.cartQuantities,
    required this.updatingFoodIds,
    required this.isLoadingMore,
    required this.showLoadMore,
    required this.onLoadMore,
    required this.onFoodTap,
    required this.onAddTap,
    required this.onIncreaseTap,
    required this.onDecreaseTap,
  });

  final List<CategoryFoodItem> items;
  final UserLocation? location;
  final Map<String, int> cartQuantities;
  final Set<String> updatingFoodIds;
  final bool isLoadingMore;
  final bool showLoadMore;
  final VoidCallback onLoadMore;
  final ValueChanged<CategoryFoodItem> onFoodTap;
  final ValueChanged<CategoryFoodItem> onAddTap;
  final void Function(CategoryFoodItem item, int nextQuantity) onIncreaseTap;
  final void Function(CategoryFoodItem item, int nextQuantity) onDecreaseTap;

  String? _distanceLabel(CategoryFoodItem item) {
    final userLocation = location;
    if (userLocation == null) {
      return null;
    }
    final km = GeoDistance.calculateDistanceKm(
      latitude1: userLocation.latitude,
      longitude1: userLocation.longitude,
      latitude2: item.restaurant.latitude,
      longitude2: item.restaurant.longitude,
    );
    return GeoDistance.formatKmLabel(km);
  }

  String? _cuisineLabel(CategoryFoodItem item) {
    final label = item.restaurant.cuisines
        .where((c) => c.trim().isNotEmpty)
        .join(' • ');
    return label.isEmpty ? null : label;
  }

  String _foodDisplayName(FoodEntity food) {
    if (food.name.trim().isNotEmpty) {
      return food.name.trim();
    }
    return food.description.trim();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      itemCount: items.length + (showLoadMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          if (isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          return Center(
            child: TextButton(
              onPressed: onLoadMore,
              child: const Text('Load More'),
            ),
          );
        }
        final item = items[index];
        final description = item.food.description.trim();
        return CategoryFoodDiscoveryCard(
          key: ValueKey('category-food-card-${item.food.id}'),
          foodName: _foodDisplayName(item.food),
          restaurantName: item.restaurantName,
          price: item.food.finalPrice,
          description: description.isEmpty ? null : description,
          imageUrl: item.food.imageUrl.isEmpty ? null : item.food.imageUrl,
          distanceLabel: _distanceLabel(item),
          cuisineLabel: _cuisineLabel(item),
          isVeg: item.food.isVeg,
          quantity: cartQuantities[item.food.id] ?? 0,
          isUpdating: updatingFoodIds.contains(item.food.id),
          onTap: () => onFoodTap(item),
          onAddTap: () => onAddTap(item),
          onIncreaseTap: () =>
              onIncreaseTap(item, (cartQuantities[item.food.id] ?? 0) + 1),
          onDecreaseTap: () =>
              onDecreaseTap(item, (cartQuantities[item.food.id] ?? 0) - 1),
        );
      },
    );
  }
}

class _CategoryFoodsEmpty extends StatelessWidget {
  const _CategoryFoodsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No foods available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'There are no approved dishes in this category right now.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFoodsError extends StatelessWidget {
  const _CategoryFoodsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unable to load foods',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
