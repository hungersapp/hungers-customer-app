import '../entities/user_location.dart';

/// Places the customer recently searched for and selected — shortcuts shown
/// in the location selector. They are never the active location by
/// themselves.
abstract class RecentLocationRepository {
  /// How many recent searches are kept.
  static const int maxEntries = 5;

  /// Newest first.
  Future<List<UserLocation>> getRecentSearches(String userId);

  /// Puts [location] at the front, dropping an older entry for the same spot
  /// and anything beyond [maxEntries].
  Future<void> addRecentSearch({
    required String userId,
    required UserLocation location,
  });
}
