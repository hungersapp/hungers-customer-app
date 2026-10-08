import '../../serviceability/domain/geo_distance.dart';
import 'entities/placed_order.dart';

/// A map coordinate that came from order/restaurant data — never live GPS.
class OrderMapPoint {
  const OrderMapPoint({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
}

enum OrderTrackingRouteKind {
  none,
  riderToRestaurant,
  restaurantToCustomer,
}

/// What the customer tracking map can render from data that already exists.
///
/// [rider] is populated from live `delivery_jobs/{orderId}.riderLocation`
/// when the customer app has a real GPS snapshot for this order.
class OrderTrackingMapPlan {
  const OrderTrackingMapPlan({
    this.restaurant,
    this.customer,
    this.rider,
    this.routeKind = OrderTrackingRouteKind.none,
    this.riderUpdatedAt,
    this.riderLocationFresh = true,
  });

  final OrderMapPoint? restaurant;
  final OrderMapPoint? customer;
  final OrderMapPoint? rider;
  final OrderTrackingRouteKind routeKind;

  /// `delivery_jobs.riderLocation.updatedAt` for the rider pin. Null when
  /// no live fix is on the plan.
  final DateTime? riderUpdatedAt;

  /// Existing 30-second freshness rule. A stale pin is shown but not
  /// animated, so old GPS does not look like a live ride.
  final bool riderLocationFresh;

  bool get isEmpty =>
      restaurant == null && customer == null && rider == null;

  bool get hasRiderLocation => rider != null;
}

/// True when lat/lng can be shown as an exact pin (rejects 0,0 placeholders).
bool hasUsableMapCoordinates(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) {
    return false;
  }
  if (!GeoDistance.isValidLatitude(latitude) ||
      !GeoDistance.isValidLongitude(longitude)) {
    return false;
  }
  if (latitude == 0 && longitude == 0) {
    return false;
  }
  return true;
}

OrderMapPoint? restaurantMapPoint({
  required OrderPickupLocation? pickup,
  double? restaurantLatitude,
  double? restaurantLongitude,
  String restaurantName = 'Restaurant',
}) {
  if (hasUsableMapCoordinates(pickup?.latitude, pickup?.longitude)) {
    final name = pickup?.restaurantName?.trim();
    return OrderMapPoint(
      latitude: pickup!.latitude!,
      longitude: pickup.longitude!,
      label: (name != null && name.isNotEmpty) ? name : restaurantName,
    );
  }
  if (hasUsableMapCoordinates(restaurantLatitude, restaurantLongitude)) {
    return OrderMapPoint(
      latitude: restaurantLatitude!,
      longitude: restaurantLongitude!,
      label: restaurantName,
    );
  }
  return null;
}

OrderMapPoint? customerMapPoint(OrderDeliveryAddress? address) {
  if (!hasUsableMapCoordinates(address?.latitude, address?.longitude)) {
    return null;
  }
  return OrderMapPoint(
    latitude: address!.latitude!,
    longitude: address.longitude!,
    label: 'Delivery',
  );
}

/// Builds the map plan from existing order status and coordinates.
///
/// [riderLatitude]/[riderLongitude] come from the live rider-location
/// stream when a rider is assigned; pass null when there is no GPS yet.
OrderTrackingMapPlan buildOrderTrackingMapPlan({
  required OrderStatus status,
  OrderPickupLocation? pickup,
  OrderDeliveryAddress? deliveryAddress,
  double? restaurantLatitude,
  double? restaurantLongitude,
  String restaurantName = 'Restaurant',
  double? riderLatitude,
  double? riderLongitude,
  DateTime? riderUpdatedAt,
  bool riderLocationFresh = true,
}) {
  if (status == OrderStatus.delivered ||
      status == OrderStatus.cancelled ||
      status == OrderStatus.awaitingPayment) {
    return const OrderTrackingMapPlan();
  }

  final restaurant = restaurantMapPoint(
    pickup: pickup,
    restaurantLatitude: restaurantLatitude,
    restaurantLongitude: restaurantLongitude,
    restaurantName: restaurantName,
  );
  final customer = customerMapPoint(deliveryAddress);
  final rider = hasUsableMapCoordinates(riderLatitude, riderLongitude)
      ? OrderMapPoint(
          latitude: riderLatitude!,
          longitude: riderLongitude!,
          label: 'Rider',
        )
      : null;

  switch (status) {
    case OrderStatus.placed:
    case OrderStatus.confirmed:
    case OrderStatus.preparing:
    case OrderStatus.ready:
      return OrderTrackingMapPlan(
        restaurant: restaurant,
        rider: rider,
        riderUpdatedAt: rider == null ? null : riderUpdatedAt,
        riderLocationFresh: riderLocationFresh,
        routeKind: rider != null && restaurant != null
            ? OrderTrackingRouteKind.riderToRestaurant
            : OrderTrackingRouteKind.none,
      );
    case OrderStatus.outForDelivery:
      return OrderTrackingMapPlan(
        restaurant: restaurant,
        customer: customer,
        rider: rider,
        riderUpdatedAt: rider == null ? null : riderUpdatedAt,
        riderLocationFresh: riderLocationFresh,
        routeKind: restaurant != null && customer != null
            ? OrderTrackingRouteKind.restaurantToCustomer
            : OrderTrackingRouteKind.none,
      );
    case OrderStatus.awaitingPayment:
    case OrderStatus.delivered:
    case OrderStatus.cancelled:
      return const OrderTrackingMapPlan();
  }
}

/// Maps an active delivery-job status onto the existing order-stage plan.
/// `assigned` keeps the restaurant-stage plan (Stage A). Pickup / out for
/// delivery switches to the customer-stage plan (Stage B). `delivered`
/// clears the map.
OrderStatus trackingMapStatus({
  required OrderStatus orderStatus,
  String? deliveryJobStatus,
}) {
  switch (deliveryJobStatus) {
    case 'picked_up':
    case 'out_for_delivery':
      return OrderStatus.outForDelivery;
    case 'delivered':
      return OrderStatus.delivered;
    default:
      return orderStatus;
  }
}
