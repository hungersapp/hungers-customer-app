import '../entities/user_location.dart';

abstract class LocationRepository {
  /// Reads the saved delivery location (the delivery DESTINATION) for
  /// [userId] from Firestore.
  Future<UserLocation?> getUserLocation(String userId);

  /// Saves the customer's single delivery destination (overwrites the only
  /// slot).
  ///
  /// Pass [clearStaleAddressDetails] whenever [location] is a different place
  /// from the stored one, so none of the previous place's pincode / door /
  /// street / area is left attached to the new coordinates.
  ///
  /// There is deliberately NO "fetch GPS and save" operation on this
  /// repository: reading the device's current position must never write the
  /// destination by itself. Callers read GPS through `DeviceLocationService`
  /// and decide with `LocationRefreshPolicy` whether it may be saved here.
  Future<void> saveUserLocation({
    required String userId,
    required UserLocation location,
    bool clearStaleAddressDetails = false,
  });

  /// Persists the customer's delivery pincode on their user document.
  Future<void> saveDeliveryPincode({
    required String userId,
    required String pincode,
  });

  /// Reads the saved delivery pincode, if any.
  Future<String?> getDeliveryPincode(String userId);
}
