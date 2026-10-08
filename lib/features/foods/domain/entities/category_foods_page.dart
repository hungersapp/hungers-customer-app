import 'category_food_item.dart';

/// One bounded category browse page (default 30).
class CategoryFoodsPage {
  const CategoryFoodsPage({
    required this.items,
    this.cursor,
    required this.hasMore,
  });

  final List<CategoryFoodItem> items;

  /// Last food name on this page; pass as the next startAfterName.
  final String? cursor;
  final bool hasMore;
}
