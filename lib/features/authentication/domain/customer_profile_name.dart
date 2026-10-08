/// Customer display name stored on `users/{uid}.name`.
class CustomerProfileName {
  CustomerProfileName._();

  static const int minLength = 2;
  static const int maxLength = 50;

  static String normalize(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Null when [raw] is a valid display name.
  static String? validate(String raw) {
    final name = normalize(raw);
    if (name.isEmpty) {
      return 'Enter your name.';
    }
    if (name.length < minLength) {
      return 'Enter at least $minLength characters.';
    }
    if (name.length > maxLength) {
      return 'Enter a shorter name.';
    }
    return null;
  }
}
