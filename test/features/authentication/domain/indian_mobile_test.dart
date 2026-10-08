import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/core/validators/indian_mobile.dart';

void main() {
  group('IndianMobile', () {
    test('accepts a valid 10-digit mobile number', () {
      expect(IndianMobile.isValid('9876543210'), isTrue);
      expect(IndianMobile.toE164('9876543210'), '+919876543210');
      expect(IndianMobile.validate('9876543210'), isNull);
    });

    test('accepts +91 and leading zero prefixes', () {
      expect(IndianMobile.normalize('+919876543210'), '9876543210');
      expect(IndianMobile.normalize('09876543210'), '9876543210');
    });

    test('rejects invalid mobiles', () {
      for (final value in ['', '12345', '5876543210', 'abcdefghij']) {
        expect(IndianMobile.isValid(value), isFalse);
        expect(IndianMobile.validate(value), IndianMobile.invalidMessage);
      }
    });
  });
}
