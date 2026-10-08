import '../entities/active_delivery_zone.dart';
import '../entities/serviceability_result.dart';

abstract class ServiceabilityRepository {
  /// Asks the trusted backend whether [pincode] is serviceable.
  ///
  /// [pincode] must already be a valid 6-digit value. The repository does not
  /// read Firestore serviceability collections from the client.
  Future<ServiceabilityResult> checkPincode(String pincode);

  /// Active delivery-zone radius records from `serviceability_zones`.
  ///
  /// The datasource queries `isActive == true`. Callers must treat load
  /// failure as fail-closed, never as serviceable.
  Future<List<ActiveDeliveryZone>> getActiveDeliveryZones();
}
