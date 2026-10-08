import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../cart/domain/cart_quantity.dart';
import '../../../cart/domain/entities/cart_entity.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../domain/entities/food_entity.dart';
import '../providers/food_provider.dart';
import '../screens/food_details_screen.dart';
import 'menu_item_row.dart';

/// Restaurant menu: search, category tabs and a list of [MenuItemRow]s.
///
/// ADD and the quantity stepper update the cart in place — the customer
/// stays on this page and the list is never reloaded or re-scrolled.
class FoodSection extends ConsumerStatefulWidget {
  final String title;
  final String restaurantId;
  final String restaurantName;

  const FoodSection({
    super.key,
    this.title = 'Popular Foods',
    required this.restaurantId,
    required this.restaurantName,
  });

  /// Shown before the cart is replaced with an item from another restaurant.
  static const String replaceCartMessage =
      'Your cart contains items from another restaurant. '
      'Clear the existing cart and add this item?';

  @override
  ConsumerState<FoodSection> createState() => _FoodSectionState();
}

class _FoodSectionState extends ConsumerState<FoodSection> {
  static const String _popularTab = '\u0000popular';

  final List<FoodEntity> _extraFoods = [];
  final TextEditingController _searchController = TextEditingController();
  bool _loadingMore = false;
  bool _endReached = false;

  /// Null shows every item.
  String? _selectedTab;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(restaurantFoodsProvider(widget.restaurantId));
    final userId = ref.watch(currentUserIdProvider);

    final cartQuantities = <String, int>{};
    if (userId != null) {
      final cartItems = ref.watch(effectiveCartItemsProvider(userId));
      if (cartItems != null) {
        cartQuantities.addAll(CartQuantity.indexByFoodId(cartItems));
      }
    }

    return foodsAsync.when(
      loading: () => _MenuFrame(
        title: widget.title,
        child: const _MenuSkeleton(),
      ),
      error: (_, _) => _MenuFrame(
        title: widget.title,
        child: _FoodSectionError(
          onRetry: () {
            setState(() {
              _extraFoods.clear();
              _endReached = false;
            });
            ref.invalidate(restaurantFoodsProvider(widget.restaurantId));
          },
        ),
      ),
      data: (foods) {
        if (foods.isEmpty && _extraFoods.isEmpty) {
          return _MenuFrame(
            title: widget.title,
            child: const _FoodSectionEmpty(),
          );
        }
        final allFoods = [...foods, ..._extraFoods];
        final tabs = _tabsFor(allFoods);
        final selected = tabs.any((tab) => tab.id == _selectedTab)
            ? _selectedTab
            : null;
        final visible = _filter(allFoods, selected);
        final heading = selected == null
            ? widget.title
            : tabs.firstWhere((tab) => tab.id == selected).label;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuSearchField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              hasQuery: _query.isNotEmpty,
            ),
            if (tabs.length > 1) ...[
              const SizedBox(height: 12),
              _CategoryTabs(
                tabs: tabs,
                selectedId: selected,
                onSelected: (id) => setState(() => _selectedTab = id),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    heading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  // "dishes", not "items": the cart bar below counts items.
                  visible.length == 1 ? '1 dish' : '${visible.length} dishes',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (visible.isEmpty)
              _NoMatches(query: _query)
            else
              _MenuList(
                foods: visible,
                cartQuantities: cartQuantities,
                displayName: _foodDisplayName,
                onOpen: (food) => openFoodDetails(
                  context,
                  food: food,
                  restaurantName: widget.restaurantName,
                ),
                onSetQuantity: _setQuantity,
              ),
            if (!_endReached && allFoods.length >= 20) ...[
              const SizedBox(height: 12),
              if (_loadingMore)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                Center(
                  child: TextButton(
                    onPressed: () => _loadMoreMenu(foods),
                    child: const Text('Load More'),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  /// "Popular" when any item is recommended, then every category the
  /// restaurant actually has, in menu order.
  List<_MenuTab> _tabsFor(List<FoodEntity> foods) {
    final tabs = <_MenuTab>[const _MenuTab(id: null, label: 'All')];
    if (foods.any((food) => food.isRecommended)) {
      tabs.add(const _MenuTab(id: _popularTab, label: 'Popular'));
    }
    final seen = <String>{};
    for (final food in foods) {
      final key = food.category.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) {
        continue;
      }
      tabs.add(_MenuTab(id: key, label: _categoryLabel(food.category)));
    }
    // "All" alone (or with a single category) adds nothing to choose from.
    return tabs.length <= 2 ? const [_MenuTab(id: null, label: 'All')] : tabs;
  }

  List<FoodEntity> _filter(List<FoodEntity> foods, String? tab) {
    final query = _query.toLowerCase();
    return [
      for (final food in foods)
        if ((tab == null ||
                (tab == _popularTab
                    ? food.isRecommended
                    : food.category.trim().toLowerCase() == tab)) &&
            (query.isEmpty ||
                food.name.toLowerCase().contains(query) ||
                food.description.toLowerCase().contains(query) ||
                food.category.toLowerCase().contains(query)))
          food,
    ];
  }

  static String _categoryLabel(String raw) {
    final words = raw
        .trim()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    return words
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _loadMoreMenu(List<FoodEntity> firstPage) async {
    if (_loadingMore || _endReached) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final lastName = [...firstPage, ..._extraFoods].isEmpty
          ? null
          : [...firstPage, ..._extraFoods].last.name;
      final page = await ref.read(foodDatasourceProvider).getFoodsByRestaurantPage(
            widget.restaurantId,
            startAfterName: lastName,
          );
      final seen = {
        for (final food in firstPage) food.id,
        for (final food in _extraFoods) food.id,
      };
      final extra = [
        for (final food in page.foods)
          if (seen.add(food.id)) food,
      ];
      setState(() {
        _extraFoods.addAll(extra);
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

  CartEntity _cartLine(FoodEntity food, String userId, int quantity) {
    return CartEntity(
      id: food.id,
      userId: userId,
      restaurantId: widget.restaurantId,
      restaurantName: widget.restaurantName,
      foodId: food.id,
      foodName: _foodDisplayName(food),
      foodImage: food.imageUrl,
      price: food.price,
      offerPrice: food.offerPrice,
      quantity: quantity,
      isVeg: food.isVeg,
      isAvailable: food.isAvailable,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _setQuantity(FoodEntity food, int quantity) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      _showMessage(
        quantity > 0
            ? 'Please login to add items.'
            : 'Please login to update your cart.',
      );
      return;
    }

    final notifier = ref.read(cartNotifierProvider.notifier);
    final line = _cartLine(food, userId, quantity);

    if (quantity > 0) {
      final current = ref.read(effectiveCartItemsProvider(userId)) ?? const [];
      final hasOtherRestaurant = current.any((item) {
        final id = item.restaurantId.trim();
        return id.isNotEmpty && id != widget.restaurantId;
      });
      if (hasOtherRestaurant) {
        final confirmed = await _confirmReplaceCart();
        if (!confirmed || !mounted) {
          return;
        }
        final replaced = await notifier.replaceCartWith(line);
        if (!replaced) {
          _showMessage('Unable to update your cart. Please try again.');
        }
        return;
      }
    }

    final saved = await notifier.setItemQuantity(line, quantity);
    if (!saved) {
      _showMessage(
        quantity > 0
            ? 'Unable to add item. Please try again.'
            : 'Unable to update quantity. Please try again.',
      );
    }
  }

  Future<bool> _confirmReplaceCart() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace cart?'),
        content: const Text(FoodSection.replaceCartMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
            ),
            child: const Text('Clear Cart & Add'),
          ),
        ],
      ),
    );
    return result ?? false;
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

class _MenuTab {
  const _MenuTab({required this.id, required this.label});

  final String? id;
  final String label;
}

/// Heading + body used for the loading, error and empty states.
class _MenuFrame extends StatelessWidget {
  const _MenuFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _MenuSearchField extends StatelessWidget {
  const _MenuSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasQuery,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );

    return TextField(
      key: const ValueKey<String>('menu-search'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search in menu',
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: hasQuery
            ? IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClear,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.primary),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.tabs,
    required this.selectedId,
    required this.onSelected,
  });

  final List<_MenuTab> tabs;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      // A restaurant has a handful of categories, so every tab is built up
      // front: nothing to gain from a lazy list, and all tabs stay reachable
      // by assistive tech.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _tab(tabs[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tab(_MenuTab tab) {
    final selected = tab.id == selectedId;
    return SizedBox(
      height: 40,
      child: Material(
        color: selected ? AppColors.secondary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? AppColors.secondary : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('menu-tab-${tab.label}'),
          onTap: () => onSelected(tab.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                tab.label,
                style: TextStyle(
                  color: selected ? AppColors.textLight : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One column of rows on phones, two on tablet/desktop widths. Rows keep
/// their horizontal shape at every width.
class _MenuList extends StatelessWidget {
  const _MenuList({
    required this.foods,
    required this.cartQuantities,
    required this.displayName,
    required this.onOpen,
    required this.onSetQuantity,
  });

  final List<FoodEntity> foods;
  final Map<String, int> cartQuantities;
  final String Function(FoodEntity food) displayName;
  final ValueChanged<FoodEntity> onOpen;
  final void Function(FoodEntity food, int quantity) onSetQuantity;

  static const double _twoColumnWidth = 720;
  static const double _columnGap = 32;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) {
          width = MediaQuery.sizeOf(context).width;
        }
        final columns = width >= _twoColumnWidth ? 2 : 1;
        final itemWidth = columns == 1
            ? width
            : (width - _columnGap) / columns;

        return Wrap(
          spacing: _columnGap,
          children: [
            for (final food in foods)
              SizedBox(
                width: itemWidth,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: MenuItemRow(
                    key: ValueKey<String>(food.id),
                    foodId: food.id,
                    name: displayName(food),
                    price: food.finalPrice,
                    originalPrice: food.offerPrice == null ? null : food.price,
                    description: food.name.trim().isEmpty
                        ? ''
                        : food.description.trim(),
                    rating: food.rating,
                    ratingCount: food.ratingCount,
                    imageUrl: food.imageUrl.isEmpty ? null : food.imageUrl,
                    isVeg: food.isVeg,
                    isRecommended: food.isRecommended,
                    offerText: food.offerLabel,
                    quantity: cartQuantities[food.id] ?? 0,
                    onTap: () => onOpen(food),
                    onAdd: () => onSetQuantity(food, 1),
                    onIncrease: () => onSetQuantity(
                      food,
                      (cartQuantities[food.id] ?? 0) + 1,
                    ),
                    onDecrease: () => onSetQuantity(
                      food,
                      (cartQuantities[food.id] ?? 0) - 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          query.isEmpty
              ? 'No items in this category yet.'
              : 'No items match "$query".',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _FoodSectionEmpty extends StatelessWidget {
  const _FoodSectionEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          const Icon(Icons.restaurant_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            'No foods available',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FoodSectionError extends StatelessWidget {
  const _FoodSectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load menu',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please try again.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _MenuSkeleton extends StatelessWidget {
  const _MenuSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
    );

    return Column(
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(16, 16),
                      const SizedBox(height: 10),
                      bar(160, 16),
                      const SizedBox(height: 10),
                      bar(64, 14),
                      const SizedBox(height: 12),
                      bar(200, 12),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: MenuItemRow.imageSize,
                  height: MenuItemRow.imageSize,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
