import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/serviceability/data/datasources/serviceability_functions_datasource.dart';

void main() {
  test(
    'customer serviceability uses the callable, not Firestore collections',
    () {
      expect(
        ServiceabilityFunctionsDatasource.callableName,
        'checkPincodeServiceability',
      );

      final source = File(
        'lib/features/serviceability/data/datasources/serviceability_functions_datasource.dart',
      ).readAsStringSync();

      expect(source.contains('serviceability_pincodes'), isFalse);
      expect(source.contains('serviceability_zones'), isFalse);
      expect(source.contains('collection('), isFalse);
      expect(source.contains('httpsCallable'), isTrue);
    },
  );
}
