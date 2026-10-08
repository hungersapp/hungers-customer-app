import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/food_review_status.dart';
import '../models/food_model.dart';

class FoodPage {
  const FoodPage({
    required this.foods,
    this.lastDocument,
    required this.hasMore,
  });

  final List<FoodModel> foods;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class FoodFirestoreDatasource {
  final FirebaseFirestore firestore;

  const FoodFirestoreDatasource(this.firestore);

  static const int menuPageSize = 20;
  static const int categoryPageSize = 30;

  /// Customer menu page: approved + available foods only, ordered by name.
  Future<FoodPage> getFoodsByRestaurantPage(
    String restaurantId, {
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? startAfterName,
    int limit = menuPageSize,
  }) async {
    Query<Map<String, dynamic>> query = firestore
        .collection('foods')
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', isEqualTo: FoodReviewStatus.approved.firestoreValue)
        .where('isAvailable', isEqualTo: true)
        .orderBy('name')
        .limit(limit + 1);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    } else if (startAfterName != null && startAfterName.trim().isNotEmpty) {
      query = query.startAfter([startAfterName]);
    }

    final snapshot = await query.get();
    final hasMore = snapshot.docs.length > limit;
    final pageDocs = hasMore
        ? snapshot.docs.take(limit).toList()
        : snapshot.docs;
    return FoodPage(
      foods: _mapCustomerFoods(pageDocs),
      lastDocument: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: hasMore,
    );
  }

  /// First menu page. Prefer [getFoodsByRestaurantPage] for Load More.
  Future<List<FoodModel>> getFoodsByRestaurant(String restaurantId) async {
    final page = await getFoodsByRestaurantPage(restaurantId);
    return page.foods;
  }

  Future<List<FoodModel>> getRecommendedFoods(String restaurantId) async {
    final snapshot = await firestore
        .collection('foods')
        .where('restaurantId', isEqualTo: restaurantId)
        .where('status', isEqualTo: FoodReviewStatus.approved.firestoreValue)
        .where('isAvailable', isEqualTo: true)
        .where('isRecommended', isEqualTo: true)
        .limit(20)
        .get();

    return _mapCustomerFoods(snapshot.docs);
  }

  Future<List<FoodModel>> getFoodsByCategory({
    required String restaurantId,
    required String category,
  }) async {
    final snapshot = await firestore
        .collection('foods')
        .where('restaurantId', isEqualTo: restaurantId)
        .where('category', isEqualTo: category)
        .where('status', isEqualTo: FoodReviewStatus.approved.firestoreValue)
        .where('isAvailable', isEqualTo: true)
        .limit(20)
        .get();

    return _mapCustomerFoods(snapshot.docs);
  }

  /// Home category browse: foods in [categoryName] sold by [restaurantIds].
  /// Never downloads the nationwide category collection.
  Future<List<FoodModel>> getCustomerFoodsByCategoryName(
    String categoryName, {
    List<String> restaurantIds = const [],
    int limit = categoryPageSize,
    String? startAfterName,
  }) async {
    final name = categoryName.trim();
    final ids = restaurantIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (name.isEmpty || ids.isEmpty || limit <= 0) {
      return const [];
    }

    try {
      final foodsById = <String, FoodModel>{};
      final cursor = startAfterName?.trim();
      for (var i = 0; i < ids.length; i += 10) {
        if (foodsById.length >= limit) {
          break;
        }
        final chunk = ids.sublist(
          i,
          i + 10 > ids.length ? ids.length : i + 10,
        );
        final remaining = limit - foodsById.length;
        Query<Map<String, dynamic>> query = firestore
            .collection('foods')
            .where('restaurantId', whereIn: chunk)
            .where('category', isEqualTo: name)
            .where(
              'status',
              isEqualTo: FoodReviewStatus.approved.firestoreValue,
            )
            .where('isAvailable', isEqualTo: true)
            .orderBy('name');
        if (cursor != null && cursor.isNotEmpty) {
          query = query.startAfter([cursor]);
        }
        final snapshot = await query.limit(remaining).get();
        for (final food in _mapCustomerFoods(snapshot.docs)) {
          foodsById[food.id] = food;
        }
      }
      final foods = foodsById.values.toList()
        ..sort((a, b) {
          final byName = a.name.compareTo(b.name);
          if (byName != 0) {
            return byName;
          }
          return a.id.compareTo(b.id);
        });
      return foods.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to load category foods: $e');
    }
  }

  Future<FoodModel> getFoodById(String foodId) async {
    try {
      final doc = await firestore.collection('foods').doc(foodId).get();

      if (!doc.exists) {
        throw Exception('Food not found');
      }

      final food = FoodModel.fromMap(doc.data()!, doc.id);
      if (!food.isCustomerVisibleFood) {
        throw Exception('Food not found');
      }
      return food;
    } catch (e) {
      throw Exception('Failed to load food: $e');
    }
  }

  /// Raw food document for order-time validation (no availability filter).
  Future<FoodModel?> getFoodDocumentById(String foodId) async {
    final id = foodId.trim();
    if (id.isEmpty) {
      return null;
    }
    final doc = await firestore.collection('foods').doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return FoodModel.fromMap(doc.data()!, doc.id);
  }

  List<FoodModel> _mapCustomerFoods(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final foods = <FoodModel>[];
    for (final doc in docs) {
      final food = FoodModel.fromMap(doc.data(), doc.id);
      if (food.isCustomerVisibleFood) {
        foods.add(food);
      }
    }
    return foods;
  }
}
