import '../../dashboard/domain/entities/category.dart';
import 'entities/search_result_entity.dart';

/// Matches active dashboard categories by name against the search query.
/// Uses the real Firestore category document [Category.id].
List<SearchResultEntity> categorySearchHits({
  required List<Category> categories,
  required String query,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return const [];
  }
  return categories
      .where((category) {
        if (!category.isActive) {
          return false;
        }
        final name = category.name.trim();
        final id = category.id.trim();
        if (name.isEmpty || id.isEmpty) {
          return false;
        }
        return name.toLowerCase().contains(needle);
      })
      .map(
        (category) => SearchResultEntity(
          id: category.id.trim(),
          title: category.name.trim(),
          subtitle: 'Category',
          imageUrl: category.imageUrl,
          type: SearchResultType.category,
        ),
      )
      .toList();
}
