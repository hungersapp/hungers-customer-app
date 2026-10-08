import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active zone query filters isActive == true on serviceability_zones', () {
    final source = File(
      'lib/features/serviceability/data/datasources/serviceability_zones_firestore_datasource.dart',
    ).readAsStringSync();

    expect(source.contains("collection('serviceability_zones')"), isTrue);
    expect(source.contains(".where('isActive', isEqualTo: true)"), isTrue);
    expect(
      source.contains("collection('serviceability_zones').get()"),
      isFalse,
    );
  });
}
