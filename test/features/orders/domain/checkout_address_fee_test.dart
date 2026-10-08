import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/location/domain/entities/user_location.dart';

void main() {
  group('UserLocation.isCompleteForCheckout', () {
    test('rejects missing door/street/pincode even with GPS', () {
      final location = UserLocation(
        latitude: 10.4,
        longitude: 79.3,
        city: 'Pattukkottai',
        state: 'TN',
        updatedAt: DateTime(2026, 1, 1),
        pincode: '614601',
      );
      expect(location.isCompleteForCheckout, isFalse);
    });

    test('accepts complete human-readable address with GPS', () {
      final location = UserLocation(
        latitude: 10.4,
        longitude: 79.3,
        city: 'Pattukkottai',
        state: 'TN',
        updatedAt: DateTime(2026, 1, 1),
        pincode: '614601',
        doorNumber: '12A',
        street: 'Main Road',
        area: 'Bazaar',
      );
      expect(location.isCompleteForCheckout, isTrue);
    });

    test('rejects invalid pincode', () {
      final location = UserLocation(
        latitude: 10.4,
        longitude: 79.3,
        city: 'Pattukkottai',
        state: 'TN',
        updatedAt: DateTime(2026, 1, 1),
        pincode: '61',
        doorNumber: '12A',
        street: 'Main Road',
      );
      expect(location.isCompleteForCheckout, isFalse);
    });
  });

}
