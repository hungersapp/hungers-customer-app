import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/geo/geohash.dart';
import '../models/restaurant_model.dart';
import '../../domain/discovery_debug_log.dart';

class RestaurantFirestoreDatasource {
  RestaurantFirestoreDatasource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collectionName = 'restaurant_public';
  static const String _collection = collectionName;

  /// Bounded geo discovery: one equality query per geohash4 cell.
  ///
  /// Does not download the nationwide catalog. Callers still apply the
  /// 15 km Haversine rule on this candidate set.
  Future<List<RestaurantModel>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  }) async {
    final cells = geohash4Cells
        .map((cell) => cell.trim())
        .where((cell) => cell.isNotEmpty)
        .toSet()
        .take(GeoHash.maxCells)
        .toList();
    if (cells.isEmpty) {
      discoveryDebug('firestore query skipped: no geohash4 cells');
      return const [];
    }

    final snapshots = await Future.wait(
      cells.map((cell) {
        Query<Map<String, dynamic>> query = _firestore
            .collection(_collection)
            .where('isCustomerVisible', isEqualTo: true)
            .where('isOpen', isEqualTo: true)
            .where('geohash4', isEqualTo: cell);
        if (featuredOnly) {
          query = query.where('isFeatured', isEqualTo: true);
        }
        return query.orderBy('name').limit(GeoHash.limitPerCell).get();
      }),
    );

    final byId = <String, RestaurantModel>{};
    for (var i = 0; i < snapshots.length; i++) {
      final snapshot = snapshots[i];
      discoveryDebug('cell=${cells[i]} firestore_docs=${snapshot.docs.length}');
      for (final restaurant in _customerListable(snapshot.docs)) {
        byId[restaurant.id] = restaurant;
      }
    }
    discoveryDebug(
      'geohash_query_total_docs=${snapshots.fold<int>(0, (n, s) => n + s.docs.length)} '
      'listable_deduped=${byId.length}',
    );
    if (kDebugMode && byId.isEmpty) {
      await _debugLogMissingGeohash4(cells);
    }
    return byId.values.toList();
  }

  /// Customer-facing restaurant list.
  ///
  /// Prefer [getDiscoverableRestaurants] for Home/search. This nationwide
  /// query is kept only as a rollback path and is not used by discovery.
  Future<List<RestaurantModel>> getAllRestaurants() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isCustomerVisible', isEqualTo: true)
        .where('isOpen', isEqualTo: true)
        .orderBy('name')
        .limit(GeoHash.limitPerCell)
        .get();

    return _customerListable(snapshot.docs);
  }

  Future<List<RestaurantModel>> getFeaturedRestaurants() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isFeatured', isEqualTo: true)
        .where('isCustomerVisible', isEqualTo: true)
        .where('isOpen', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(GeoHash.limitPerCell)
        .get();

    return _customerListable(snapshot.docs);
  }

  Future<List<RestaurantModel>> getPopularRestaurants() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isCustomerVisible', isEqualTo: true)
        .where('isOpen', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(20)
        .get();

    return _customerListable(snapshot.docs);
  }

  /// Returns null when the restaurant is not customer-listable.
  Future<RestaurantModel?> getRestaurantById(String restaurantId) async {
    final doc = await _firestore
        .collection(_collection)
        .doc(restaurantId)
        .get();

    if (!doc.exists) return null;

    final restaurant = RestaurantModel.fromDocument(doc);
    if (!restaurant.isCustomerListable) {
      return null;
    }
    return restaurant;
  }

  Future<List<RestaurantModel>> searchRestaurants(String keyword) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isCustomerVisible', isEqualTo: true)
        .where('isOpen', isEqualTo: true)
        .orderBy('name')
        .startAt([keyword])
        .endAt(['$keyword\uf8ff'])
        .limit(20)
        .get();

    return _customerListable(snapshot.docs);
  }

  Future<List<RestaurantModel>> getNearbyRestaurants() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isCustomerVisible', isEqualTo: true)
        .where('isOpen', isEqualTo: true)
        .limit(GeoHash.limitPerCell)
        .get();

    return _customerListable(snapshot.docs);
  }

  List<RestaurantModel> _customerListable(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map(RestaurantModel.fromDocument)
        .where((restaurant) => restaurant.isCustomerListable)
        .toList();
  }

  /// Debug-only: when geohash discovery is empty, sample a few listable
  /// restaurants and report whether `geohash4` is missing. Never used as a
  /// listing fallback.
  Future<void> _debugLogMissingGeohash4(List<String> cells) async {
    try {
      final sample = await _firestore
          .collection(_collection)
          .where('isCustomerVisible', isEqualTo: true)
          .where('isOpen', isEqualTo: true)
          .limit(5)
          .get();
      if (sample.docs.isEmpty) {
        discoveryDebug(
          'empty geohash query AND no visible+open restaurant_public sample',
        );
        return;
      }
      for (final doc in sample.docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final stored = data['geohash4']?.toString();
        final computed = (lat != null && lng != null)
            ? GeoHash.cell4(lat, lng)
            : null;
        final missing = stored == null || stored.trim().isEmpty;
        discoveryDebug(
          'sample id=${doc.id} lat=$lat lng=$lng '
          'stored_geohash4=$stored computed_geohash4=$computed '
          'computed_in_customer_cells=${computed != null && cells.contains(computed)} '
          '${missing ? "Restaurant excluded because geohash4 is missing; production backfill required." : ""}',
        );
      }
    } catch (error) {
      discoveryDebug('geohash gap sample failed: $error');
    }
  }
}
