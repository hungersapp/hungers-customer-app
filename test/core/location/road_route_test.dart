import 'package:customer_app/core/location/encoded_polyline.dart';
import 'package:customer_app/core/location/google_directions_route.dart';
import 'package:customer_app/core/location/road_polylines.dart';
import 'package:customer_app/core/location/road_route_session.dart';
import 'package:customer_app/features/orders/domain/order_tracking_map_plan.dart';
import 'package:customer_app/features/orders/presentation/widgets/order_tracking_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Google's documented sample. It is a path, not a two-point segment.
const _samplePolyline = r'_p~iF~ps|U_ulLnnqC_mqNvxq`@';

void main() {
  test('decodes a road polyline into more than two coordinates', () {
    final points = decodeEncodedPolyline(_samplePolyline);

    expect(points.length, 3);
    expect(points.first.latitude, closeTo(38.5, 0.001));
    expect(points.first.longitude, closeTo(-120.2, 0.001));
    expect(points.last.latitude, closeTo(43.252, 0.001));
    expect(points.last.longitude, closeTo(-126.453, 0.001));
  });

  test('directions overview polyline becomes the rendered road points', () {
    final parsed = parseDirectionsBody('''
{
  "status": "OK",
  "routes": [
    {
      "overview_polyline": { "points": "$_samplePolyline" },
      "legs": [ { "distance": { "value": 2104 } } ]
    }
  ]
}
''');

    expect(parsed.isRoadRoute, isTrue);
    expect(parsed.distanceMeters, 2104);
    expect(parsed.points.length, greaterThan(2));
    final drawn = roadPolylines(
      points: parsed.points,
      color: const Color(0xFFE23744),
      id: 'tracking-route',
    );
    expect(drawn.length, 2);
    expect(drawn.every((polyline) => polyline.width >= 5), isTrue);
    expect(drawn.every((polyline) => polyline.points.length > 2), isTrue);
  });

  test('a failed directions response does not invent a straight line', () {
    final parsed = parseDirectionsBody('''
{
  "status": "REQUEST_DENIED",
  "error_message": "restricted"
}
''');

    expect(parsed.isRoadRoute, isFalse);
    expect(parsed.points, isEmpty);
    expect(
      roadPolylines(
        points: const [
          LatLng(9.9, 78.1),
          LatLng(9.95, 78.15),
        ],
        color: const Color(0xFFE23744),
        id: 'tracking-route',
      ),
      isEmpty,
    );
  });

  test('session keeps one road path until the rider moves far enough', () async {
    final session = RoadRouteSession();
    var fetches = 0;
    Future<DrivingRoute> fetch(LatLng origin, LatLng destination) async {
      fetches++;
      return DrivingRoute(
        points: [
          origin,
          const LatLng(9.93, 78.12),
          destination,
        ],
        distanceMeters: 2500,
      );
    }

    const origin = LatLng(9.9252, 78.1198);
    const destination = LatLng(9.94, 78.13);
    await session.update(
      origin: origin,
      destination: destination,
      fetch: fetch,
    );
    await session.update(
      origin: const LatLng(9.9253, 78.1198),
      destination: destination,
      fetch: fetch,
    );

    expect(fetches, 1);
    expect(session.points.length, 3);

    await session.update(
      origin: const LatLng(9.93, 78.1198),
      destination: destination,
      fetch: fetch,
    );

    expect(fetches, 2);
    session.dispose();
  });

  test('tracking route uses rider to restaurant, then restaurant to customer', () {
    const restaurant = OrderMapPoint(
      latitude: 9.91,
      longitude: 78.11,
      label: 'Kitchen',
    );
    const customer = OrderMapPoint(
      latitude: 9.95,
      longitude: 78.16,
      label: 'Home',
    );
    const rider = OrderMapPoint(
      latitude: 9.90,
      longitude: 78.10,
      label: 'Rider',
    );

    final toRestaurant = trackingRoadEndpoints(
      const OrderTrackingMapPlan(
        restaurant: restaurant,
        customer: customer,
        rider: rider,
        routeKind: OrderTrackingRouteKind.riderToRestaurant,
      ),
    );
    expect(toRestaurant.origin, const LatLng(9.90, 78.10));
    expect(toRestaurant.destination, const LatLng(9.91, 78.11));

    final toCustomer = trackingRoadEndpoints(
      const OrderTrackingMapPlan(
        restaurant: restaurant,
        customer: customer,
        rider: rider,
        routeKind: OrderTrackingRouteKind.restaurantToCustomer,
      ),
    );
    expect(toCustomer.origin, const LatLng(9.91, 78.11));
    expect(toCustomer.destination, const LatLng(9.95, 78.16));
  });
}
