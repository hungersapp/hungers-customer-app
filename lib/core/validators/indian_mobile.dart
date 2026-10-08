/// Indian mobile number: 10 digits starting with 6-9.
class IndianMobile {
  IndianMobile._();

  static final RegExp _tenDigit = RegExp(r'^[6-9]\d{9}$');

  static const String invalidMessage =
      'Please enter a valid 10-digit mobile number.';

  static String? normalize(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }
    if (!_tenDigit.hasMatch(digits)) {
      return null;
    }
    return digits;
  }

  static bool isValid(String raw) => normalize(raw) != null;

  static String? validate(String raw) {
    if (isValid(raw)) {
      return null;
    }
    return invalidMessage;
  }

  static String toE164(String tenDigit) => '+91$tenDigit';
}
