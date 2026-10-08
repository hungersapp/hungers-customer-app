import 'package:customer_app/features/restaurants/data/datasource/restaurant_firestore_datasource.dart';
import 'package:customer_app/features/search/data/datasources/search_firestore_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer restaurant discovery reads restaurant_public only', () {
    expect(RestaurantFirestoreDatasource.collectionName, 'restaurant_public');
  });

  test('search datasource is wired to restaurant_public', () {
    expect(SearchFirestoreDatasource.collectionName, 'restaurant_public');
  });
}
