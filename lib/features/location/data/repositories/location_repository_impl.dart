import '../../domain/entities/user_location.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_firestore_datasource.dart';
import '../models/user_location_model.dart';

class LocationRepositoryImpl implements LocationRepository {
  const LocationRepositoryImpl(this._firestoreDatasource);

  final LocationFirestoreDatasource _firestoreDatasource;

  @override
  Future<UserLocation?> getUserLocation(String userId) {
    return _firestoreDatasource.getLocation(userId);
  }

  @override
  Future<void> saveUserLocation({
    required String userId,
    required UserLocation location,
    bool clearStaleAddressDetails = false,
  }) {
    return _firestoreDatasource.saveLocation(
      userId: userId,
      location: UserLocationModel.fromEntity(location),
      clearStaleAddressDetails: clearStaleAddressDetails,
    );
  }

  @override
  Future<void> saveDeliveryPincode({
    required String userId,
    required String pincode,
  }) {
    return _firestoreDatasource.saveDeliveryPincode(
      userId: userId,
      pincode: pincode,
    );
  }

  @override
  Future<String?> getDeliveryPincode(String userId) {
    return _firestoreDatasource.getDeliveryPincode(userId);
  }
}
