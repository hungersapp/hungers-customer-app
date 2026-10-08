import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/serviceability/data/repositories/serviceability_repository_impl.dart';
import 'package:customer_app/features/serviceability/domain/serviceability_read_exception.dart';

void main() {
  test('maps Firestore permission-denied to a serviceability read failure', () {
    final mapped = mapZoneReadFailure(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      ),
    );

    expect(mapped, isA<ServiceabilityReadException>());
    expect(mapped.permissionDenied, isTrue);
  });

  test('maps unexpected zone-read errors as fail-closed', () {
    final mapped = mapZoneReadFailure(StateError('missing datasource'));

    expect(mapped, isA<ServiceabilityReadException>());
    expect(mapped.permissionDenied, isFalse);
  });
}
