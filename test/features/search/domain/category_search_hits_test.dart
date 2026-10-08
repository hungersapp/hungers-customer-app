import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/dashboard/domain/entities/category.dart';
import 'package:customer_app/features/search/domain/category_search_hits.dart';
import 'package:customer_app/features/search/domain/entities/search_result_entity.dart';

void main() {
  const pizza = Category(
    id: 'cat-pizza',
    name: 'Pizza',
    imageUrl: '',
    isActive: true,
    displayOrder: 1,
  );

  test('matches active categories by name using the Firestore id', () {
    final hits = categorySearchHits(categories: const [pizza], query: 'piz');
    expect(hits, hasLength(1));
    expect(hits.first.id, 'cat-pizza');
    expect(hits.first.type, SearchResultType.category);
  });

  test('ignores inactive categories', () {
    const inactive = Category(
      id: 'cat-old',
      name: 'Pizza',
      imageUrl: '',
      isActive: false,
      displayOrder: 1,
    );
    expect(
      categorySearchHits(categories: const [inactive], query: 'pizza'),
      isEmpty,
    );
  });
}
