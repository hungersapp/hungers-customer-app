import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_model.dart';

class DashboardDatasource {
  DashboardDatasource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<CategoryModel>> getCategories() async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .orderBy('displayOrder')
          .get();

      return snapshot.docs
          .map(
            (doc) => CategoryModel.fromFirestore(doc),
          )
          .toList();
    } on FirebaseException catch (e) {
      throw Exception(
        e.message ?? 'Failed to load categories',
      );
    } catch (e) {
      throw Exception(
        'Failed to load categories',
      );
    }
  }
}