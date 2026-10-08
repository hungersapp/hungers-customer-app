import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/search_result_model.dart';
import '../../domain/entities/search_result_entity.dart';

class SearchFirestoreDatasource {
  static const String collectionName = 'restaurant_public';
  static const int defaultLimit = 20;

  final FirebaseFirestore firestore;

  SearchFirestoreDatasource(this.firestore);

  /// Search restaurants in nearby [geohash4Cells] only. Bounded per cell.
  Future<List<SearchResultModel>> searchRestaurants(
    String query, {
    List<String> geohash4Cells = const [],
    int limit = defaultLimit,
  }) async {
    final searchText = query.trim().toLowerCase();
    if (searchText.isEmpty || geohash4Cells.isEmpty || limit <= 0) {
      return [];
    }

    final cells = geohash4Cells
        .map((cell) => cell.trim())
        .where((cell) => cell.isNotEmpty)
        .toSet()
        .take(9)
        .toList();
    if (cells.isEmpty) {
      return [];
    }

    final perCell = (limit / cells.length).ceil().clamp(1, limit);
    final snapshots = await Future.wait(
      cells.map(
        (cell) => firestore
            .collection(collectionName)
            .where('searchKeywords', arrayContains: searchText)
            .where('geohash4', isEqualTo: cell)
            .where('isCustomerVisible', isEqualTo: true)
            .where('isOpen', isEqualTo: true)
            .limit(perCell)
            .get(),
      ),
    );

    final byId = <String, SearchResultModel>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        if (!_isCustomerListableRestaurant(doc.data())) {
          continue;
        }
        final data = doc.data();
        final id = (data['id'] as String?)?.trim().isNotEmpty == true
            ? data['id'] as String
            : doc.id;
        byId[id] = SearchResultModel(
          id: id,
          title: data['name'] ?? '',
          subtitle: (data['cuisines'] as List<dynamic>?)?.join(' • ') ?? '',
          imageUrl: data['logoUrl'] ?? '',
          type: SearchResultType.restaurant,
        );
        if (byId.length >= limit) {
          return byId.values.take(limit).toList();
        }
      }
    }
    return byId.values.take(limit).toList();
  }

  /// Search foods sold by [restaurantIds] only. Bounded.
  Future<List<SearchResultModel>> searchFoods(
    String query, {
    List<String> restaurantIds = const [],
    int limit = defaultLimit,
  }) async {
    final searchText = query.trim().toLowerCase();
    final ids = restaurantIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (searchText.isEmpty || ids.isEmpty || limit <= 0) {
      return [];
    }

    final byId = <String, SearchResultModel>{};
    for (var i = 0; i < ids.length; i += 10) {
      if (byId.length >= limit) {
        break;
      }
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final remaining = limit - byId.length;
      final snapshot = await firestore
          .collection('foods')
          .where('restaurantId', whereIn: chunk)
          .where('searchKeywords', arrayContains: searchText)
          .where('status', isEqualTo: 'approved')
          .where('isAvailable', isEqualTo: true)
          .limit(remaining)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = (data['id'] as String?)?.trim().isNotEmpty == true
            ? data['id'] as String
            : doc.id;
        byId[id] = SearchResultModel(
          id: id,
          title: data['name'] ?? '',
          subtitle: data['restaurantName'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          type: SearchResultType.food,
          restaurantId: _restaurantIdOf(data),
        );
      }
    }
    return byId.values.take(limit).toList();
  }

  static String _restaurantIdOf(Map<String, dynamic> data) {
    for (final key in const ['restaurantId', 'restaurant_id']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  bool _isCustomerListableRestaurant(Map<String, dynamic> data) {
    final count = data['approvedFoodCount'];
    final approvedCount = count is num ? count.toInt() : 0;
    if (approvedCount <= 0) {
      return false;
    }
    final verified = data['isVerified'] == true;
    final status =
        (data['onboardingStatus'] as String?)?.trim().toLowerCase() ?? '';
    final isActive = data['isActive'] == true;
    return isActive && (verified || status == 'approved');
  }

  Future<List<SearchResultModel>> searchAll(
    String query, {
    List<String> geohash4Cells = const [],
    List<String> restaurantIds = const [],
    int limit = defaultLimit,
  }) async {
    final restaurants = await searchRestaurants(
      query,
      geohash4Cells: geohash4Cells,
      limit: limit,
    );
    final foods = await searchFoods(
      query,
      restaurantIds: restaurantIds,
      limit: limit,
    );
    return [...restaurants, ...foods];
  }
}
