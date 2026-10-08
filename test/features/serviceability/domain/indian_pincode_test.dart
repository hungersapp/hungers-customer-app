import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/serviceability/domain/indian_pincode.dart';

void main() {
  group('IndianPincode validation', () {
    test('accepts a valid 6-digit pincode', () {
      expect(IndianPincode.isValid('613403'), isTrue);
      expect(IndianPincode.normalize('613403'), '613403');
      expect(IndianPincode.validate('613403'), isNull);
    });

    test('trims surrounding whitespace', () {
      expect(IndianPincode.normalize('  625001  '), '625001');
    });

    test('rejects empty, short, long, and non-numeric values', () {
      const invalid = ['', '61340', '6134031', '61340a', '61340 ', 'abcdef'];
      for (final value in invalid) {
        expect(IndianPincode.isValid(value), isFalse, reason: value);
        expect(IndianPincode.validate(value), IndianPincode.invalidMessage);
      }
    });
  });
}
