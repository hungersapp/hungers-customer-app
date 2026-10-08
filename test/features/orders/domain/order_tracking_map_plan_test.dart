import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/domain/order_tracking_map_plan.dart';

void main() {
  const pickup = OrderPickupLocation(
    latitude: 10.79,
    longitude: 79.14,
    restaurantName: 'A2B',
  );
  const delivery = OrderDeliveryAddress(
    latitude: 10.80,
    longitude: 79.16,
    address: '12 Market Street',
  );

  test('rejects 0,0 and missing coordinates', () {
    expect(hasUsableMapCoordinates(null, 79.14), isFalse);
    expect(hasUsableMapCoordinates(10.79, null), isFalse);
    expect(hasUsableMapCoordinates(0, 0), isFalse);
    expect(hasUsableMapCoordinates(10.79, 79.14), isTrue);
  });

  test('restaurant pin prefers order pickup over restaurant fallback', () {
    final point = restaurantMapPoint(
      pickup: pickup,
      restaurantLatitude: 13.08,
      restaurantLongitude: 80.27,
      restaurantName: 'Fallback',
    );
    expect(point?.latitude, 10.79);
    expect(point?.longitude, 79.14);
    expect(point?.label, 'A2B');
  });

  test('restaurant pin uses restaurant entity when pickup is missing', () {
    final point = restaurantMapPoint(
      pickup: null,
      restaurantLatitude: 13.08,
      restaurantLongitude: 80.27,
      restaurantName: 'A2B Restaurant',
    );
    expect(point?.latitude, 13.08);
    expect(point?.longitude, 80.27);
  });

  test('customer pin comes from the order delivery snapshot', () {
    final point = customerMapPoint(delivery);
    expect(point?.latitude, 10.80);
    expect(point?.longitude, 79.16);
  });

  test('restaurant stages show restaurant only, not customer GPS', () {
    for (final status in [
      OrderStatus.placed,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
    ]) {
      final plan = buildOrderTrackingMapPlan(
        status: status,
        pickup: pickup,
        deliveryAddress: delivery,
      );
      expect(plan.restaurant?.latitude, 10.79, reason: status.name);
      expect(plan.customer, isNull, reason: status.name);
      expect(plan.rider, isNull, reason: status.name);
      expect(plan.routeKind, OrderTrackingRouteKind.none, reason: status.name);
    }
  });

  test('out for delivery draws restaurant to snapshotted customer', () {
    final plan = buildOrderTrackingMapPlan(
      status: OrderStatus.outForDelivery,
      pickup: pickup,
      deliveryAddress: delivery,
    );
    expect(plan.restaurant?.latitude, 10.79);
    expect(plan.customer?.latitude, 10.80);
    expect(plan.rider, isNull);
    expect(plan.routeKind, OrderTrackingRouteKind.restaurantToCustomer);
  });

  test(
    'rider heading to restaurant only when rider coords exist before pickup',
    () {
      final plan = buildOrderTrackingMapPlan(
        status: OrderStatus.ready,
        pickup: pickup,
        deliveryAddress: delivery,
        riderLatitude: 10.78,
        riderLongitude: 79.13,
      );
      expect(plan.rider?.latitude, 10.78);
      expect(plan.routeKind, OrderTrackingRouteKind.riderToRestaurant);
    },
  );

  test('trackingMapStatus keeps restaurant stage while job is assigned', () {
    expect(
      trackingMapStatus(
        orderStatus: OrderStatus.ready,
        deliveryJobStatus: 'assigned',
      ),
      OrderStatus.ready,
    );
  });

  test('trackingMapStatus switches to customer stage after pickup', () {
    expect(
      trackingMapStatus(
        orderStatus: OrderStatus.ready,
        deliveryJobStatus: 'picked_up',
      ),
      OrderStatus.outForDelivery,
    );
    expect(
      trackingMapStatus(
        orderStatus: OrderStatus.ready,
        deliveryJobStatus: 'out_for_delivery',
      ),
      OrderStatus.outForDelivery,
    );
  });

  test('trackingMapStatus clears the map when the job is delivered', () {
    expect(
      trackingMapStatus(
        orderStatus: OrderStatus.outForDelivery,
        deliveryJobStatus: 'delivered',
      ),
      OrderStatus.delivered,
    );
  });

  test('delivered and cancelled keep the map empty', () {
    expect(
      buildOrderTrackingMapPlan(
        status: OrderStatus.delivered,
        pickup: pickup,
        deliveryAddress: delivery,
      ).isEmpty,
      isTrue,
    );
    expect(
      buildOrderTrackingMapPlan(
        status: OrderStatus.cancelled,
        pickup: pickup,
        deliveryAddress: delivery,
      ).isEmpty,
      isTrue,
    );
  });
}
