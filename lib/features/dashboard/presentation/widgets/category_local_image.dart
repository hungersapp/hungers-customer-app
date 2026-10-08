/// Maps live Firestore category names to bundled local food images only.
///
/// Matching is case-insensitive and ignores spaces/punctuation so
/// "Non-Veg Meals" and "Non Veg Meals" both resolve to the same asset.
/// Filenames follow the actual files on disk (e.g. biriyani.png, idle.png).
class CategoryLocalImage {
  CategoryLocalImage._();

  static const String _dir = 'assets/images/categories';

  static const Map<String, String> _assetsByNormalizedName = {
    'biriyani': '$_dir/biriyani.png',
    'biryani': '$_dir/biriyani.png',
    'burger': '$_dir/burger.png',
    'dessert': '$_dir/desserts.png',
    'desserts': '$_dir/desserts.png',
    'dosa': '$_dir/dosa.png',
    'idli': '$_dir/idle.png',
    'idle': '$_dir/idle.png',
    'juice': '$_dir/juice.png',
    'nonvegmeal': '$_dir/nonvegmeals.png',
    'nonvegmeals': '$_dir/nonvegmeals.png',
    'pizza': '$_dir/pizza.png',
    'vegmeal': '$_dir/vegmeals.png',
    'vegmeals': '$_dir/vegmeals.png',
  };

  static String normalize(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Returns the local asset path for [name], or null if none matches.
  static String? assetForName(String name) {
    return _assetsByNormalizedName[normalize(name)];
  }
}
