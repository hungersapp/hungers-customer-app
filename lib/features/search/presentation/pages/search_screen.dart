import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../dashboard/domain/entities/category.dart';
import '../../../foods/presentation/providers/food_provider.dart';
import '../../../foods/presentation/screens/category_foods_screen.dart';
import '../../../foods/presentation/screens/food_details_screen.dart';
import '../../../restaurants/presentation/providers/restaurant_details_provider.dart';
import '../../../restaurants/presentation/providers/restaurant_provider.dart';
import '../../../restaurants/presentation/screens/restaurant_details_screen.dart';
import '../../domain/entities/search_result_entity.dart';
import '../../../serviceability/presentation/providers/serviceable_destination_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/no_result_widget.dart';
import '../widgets/recent_search_widget.dart';
import '../widgets/search_loading.dart';
import '../widgets/search_result_tile.dart';

/// Combined restaurant + food + category search.
///
/// Results are a bounded first page (20 per Firestore source). Load More is
/// not shown: those sources cannot share one cursor without skipping or
/// duplicating hits. Debounce is 400 ms; overlapping in-flight searches are
/// dropped via a generation counter.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _focusNode;
  final List<String> _recentSearches = [
    'Pizza',
    'Burger',
    'Chicken Biryani',
    'A2B',
  ];

  /// Prevents duplicate taps while a result is opening.
  String? _openingResultId;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});

    final query = value.trim();

    if (query.isEmpty) {
      ref.read(searchProvider.notifier).clearSearch();
      return;
    }

    ref.read(searchProvider.notifier).search(query);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onResultTap(SearchResultEntity result) async {
    final id = result.id.trim();
    if (id.isEmpty || _openingResultId != null) {
      return;
    }

    setState(() => _openingResultId = id);

    try {
      switch (result.type) {
        case SearchResultType.restaurant:
          await _openRestaurant(id);
        case SearchResultType.food:
          await _openFood(result);
        case SearchResultType.category:
          await _openCategory(result);
      }
    } finally {
      if (mounted) {
        setState(() => _openingResultId = null);
      }
    }
  }

  Future<void> _openRestaurant(String restaurantId) async {
    final restaurant = await ref
        .read(getRestaurantByIdProvider)
        .call(restaurantId);

    if (!mounted) {
      return;
    }

    if (restaurant == null) {
      _showMessage('This restaurant is not available.');
      return;
    }

    ref.read(lastViewedRestaurantProvider.notifier).state = restaurant;
    await Navigator.push(
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

  Future<void> _openFood(SearchResultEntity result) async {
    try {
      final food = await ref
          .read(getFoodByIdUseCaseProvider)
          .call(result.id.trim());

      if (!mounted) {
        return;
      }

      final restaurantName = result.subtitle.trim().isNotEmpty
          ? result.subtitle.trim()
          : food.restaurantId;

      openFoodDetails(context, food: food, restaurantName: restaurantName);
    } catch (_) {
      _showMessage('Unable to open this item.');
    }
  }

  Future<void> _openCategory(SearchResultEntity result) async {
    final id = result.id.trim();
    final name = result.title.trim();
    if (id.isEmpty || name.isEmpty) {
      _showMessage('This category is not available.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
          name: AppRoutes.categoryFoods,
          arguments: Category(
            id: id,
            name: name,
            imageUrl: result.imageUrl,
            isActive: true,
            displayOrder: 0,
          ),
        ),
        builder: (_) => CategoryFoodsScreen(
          category: Category(
            id: id,
            name: name,
            imageUrl: result.imageUrl,
            isActive: true,
            displayOrder: 0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search restaurants & foods',
              prefixIcon: const Icon(Icons.search),
              border: InputBorder.none,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchProvider.notifier).clearSearch();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
        ),
      ),
      body: searchState.when(
        data: (results) {
          final query = _searchController.text.trim();

          // Empty Search
          if (query.isEmpty) {
            return RecentSearchWidget(
              recentSearches: _recentSearches,
              onSearchTap: (value) {
                _searchController.text = value;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: value.length),
                );

                ref.read(searchProvider.notifier).search(value);
                setState(() {});
              },
              onClearAll: () {
                setState(_recentSearches.clear);
              },
            );
          }

          // No Results
          if (results.isEmpty) {
            // Nothing can be delivered to the selected location (none chosen,
            // or not served): say that, rather than blaming the search words.
            final destination = ref.watch(
              serviceableDeliveryDestinationProvider,
            );
            final locationIsTheReason =
                destination.hasValue && destination.value == null;
            return NoResultWidget(
              query: query,
              title: locationIsTheReason
                  ? 'Sorry, no restaurants available in this location.'
                  : null,
              message: locationIsTheReason
                  ? 'Try choosing a different delivery location.'
                  : null,
              onClear: () {
                _searchController.clear();
                ref.read(searchProvider.notifier).clearSearch();
                setState(() {});
              },
            );
          }

          // Results
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return SearchResultTile(
                result: results[index],
                onTap: () => _onResultTap(results[index]),
              );
            },
          );
        },

        loading: () => const SearchLoading(),

        error: (error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.read(searchProvider.notifier).retry(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
