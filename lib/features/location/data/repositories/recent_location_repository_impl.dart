import '../../domain/entities/user_location.dart';
import '../../domain/repositories/recent_location_repository.dart';
import '../datasources/location_firestore_datasource.dart';
import '../models/user_location_model.dart';

class RecentLocationRepositoryImpl implements RecentLocationRepository {
  const RecentLocationRepositoryImpl(this._datasource);

  final LocationFirestoreDatasource _datasource;

  @override
  Future<List<UserLocation>> getRecentSearches(String userId) {
    return _datasource.getRecentSearches(userId);
  }

  @override
  Future<void> addRecentSearch({
    required String userId,
    required UserLocation location,
  }) async {
    final existing = await _datasource.getRecentSearches(userId);
    final updated = <UserLocationModel>[
      UserLocationModel.fromEntity(
        // A remembered place, not a selection: no door / street / intent.
        UserLocation(
          latitude: location.latitude,
          longitude: location.longitude,
          city: location.city,
          state: location.state,
          pincode: location.pincode,
          area: location.area,
          updatedAt: DateTime.now(),
        ),
      ),
      for (final entry in existing)
        if (entry.latitude != location.latitude ||
            entry.longitude != location.longitude)
          entry,
    ];
    await _datasource.saveRecentSearches(
      userId: userId,
      locations: updated
          .take(RecentLocationRepository.maxEntries)
          .toList(growable: false),
    );
  }
}
