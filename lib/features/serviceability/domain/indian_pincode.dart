/// V1 Indian pincode: exactly 6 numeric digits.
class IndianPincode {
  IndianPincode._();

  static final RegExp _pattern = RegExp(r'^\d{6}$');

  static const String invalidMessage =
      'Please enter a valid 6-digit pincode.';

  static String? normalize(String raw) {
    final trimmed = raw.trim();
    if (!_pattern.hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  static bool isValid(String raw) => normalize(raw) != null;

  /// Returns null when valid, otherwise [invalidMessage].
  static String? validate(String raw) {
    if (isValid(raw)) {
      return null;
    }
    return invalidMessage;
  }
}
