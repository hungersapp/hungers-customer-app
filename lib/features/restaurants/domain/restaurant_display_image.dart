/// Resolves the Customer App restaurant display image URL.
///
/// Canonical field: Firestore `restaurantImages` (List&lt;String&gt;).
/// Priority:
/// 1. first valid HTTPS URL in [restaurantImages]
/// 2. [coverImageUrl] if valid HTTPS
/// 3. [logoUrl] if valid HTTPS
/// 4. empty string → existing UI placeholder
class RestaurantDisplayImage {
  RestaurantDisplayImage._();

  static bool isValidHttpsUrl(String? raw) {
    final value = raw?.trim() ?? '';
    return value.startsWith('https://');
  }

  static String? firstValidHttpsUrl(Iterable<String?> values) {
    for (final raw in values) {
      final value = raw?.trim() ?? '';
      if (isValidHttpsUrl(value)) {
        return value;
      }
    }
    return null;
  }

  static String resolve({
    List<String> restaurantImages = const [],
    String coverImageUrl = '',
    String logoUrl = '',
  }) {
    return firstValidHttpsUrl(restaurantImages) ??
        firstValidHttpsUrl([coverImageUrl, logoUrl]) ??
        '';
  }
}
