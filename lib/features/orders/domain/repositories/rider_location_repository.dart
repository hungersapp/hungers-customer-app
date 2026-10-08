import '../entities/rider_location.dart';

abstract class RiderLocationRepository {
  /// Live snapshots of `delivery_jobs/{orderId}` for customer tracking.
  /// Emits null when the document is missing or unreadable.
  Stream<DeliveryJobRiderTracking?> watchByOrderId(String orderId);
}
