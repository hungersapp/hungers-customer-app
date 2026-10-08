/// Live rider GPS the customer may read for their own active order.
///
/// Sourced from `delivery_jobs/{orderId}.riderLocation` — latitude,
/// longitude, and [updatedAt] only. No rider profile fields.
class RiderLocation {
  const RiderLocation({
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime updatedAt;
}

/// Snapshot of the assigned delivery job fields needed for tracking.
class DeliveryJobRiderTracking {
  const DeliveryJobRiderTracking({
    required this.orderId,
    required this.status,
    this.riderLocation,
    this.riderPhone,
    this.riderDisplayName,
    this.riderRating,
    this.riderPhotoUrl,
  });

  final String orderId;
  final String status;
  final RiderLocation? riderLocation;

  /// Assigned rider's phone from `delivery_jobs/{orderId}.riderPhone`. Used
  /// ONLY as the tel: target of "Call Rider" — never rendered, logged or
  /// stored by this app.
  final String? riderPhone;

  final String? riderDisplayName;
  final double? riderRating;
  final String? riderPhotoUrl;

  bool get isAssigned =>
      status == 'assigned' ||
      status == 'picked_up' ||
      status == 'out_for_delivery';

  bool get isLiveTrackingActive => isAssigned;
}
