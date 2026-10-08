import 'package:customer_app/core/location/bearing_calculator.dart';
import 'package:customer_app/features/orders/domain/entities/placed_order.dart';
import 'package:customer_app/features/orders/domain/order_tracking_map_plan.dart';
import 'package:customer_app/features/orders/presentation/rider_marker_visual.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RiderMarkerVisual visual() => RiderMarkerVisual();

  group('raw GPS stays separate from display pose', () {
    test('holds the marker for small stationary GPS noise', () {
      final marker = visual();
      marker.apply(latitude: 10.1, longitude: 79.2);
      marker.apply(latitude: 10.10007, longitude: 79.2);

      expect(marker.displayLatitude, 10.1);
      expect(marker.displayLongitude, 79.2);
      expect(marker.rawLatitude, 10.10007);
      expect(marker.rawLongitude, 79.2);
    });

    test('moves the marker for genuine displacement beyond the 15m hold', () {
      final marker = visual();
      marker.apply(latitude: 10.1, longitude: 79.2);
      marker.apply(latitude: 10.1002, longitude: 79.2);

      expect(marker.displayLatitude, 10.1002);
      expect(marker.rawLatitude, 10.1002);
    });
  });

  group('heading selection', () {
    test('uses a reliable GPS heading when it matches travel', () {
      final marker = visual();
      marker.apply(latitude: 10.1, longitude: 79.2);
      marker.apply(
        latitude: 10.11,
        longitude: 79.2,
        heading: 0,
        headingAccuracy: 15,
      );

      expect(_heading0to360(marker.heading), closeTo(0, 1));
    });

    test('falls back to track bearing when GPS heading is unavailable', () {
      final marker = visual();
      marker.apply(latitude: 10.1, longitude: 79.2);
      marker.apply(latitude: 10.11, longitude: 79.2);

      expect(_heading0to360(marker.heading), closeTo(0, 1));
    });

    test(
      'ignores a reliable GPS heading that points opposite the actual displacement',
      () {
        final marker = visual();
        marker.apply(latitude: 10.1, longitude: 79.2);
        marker.apply(
          latitude: 10.11,
          longitude: 79.2,
          heading: 180,
          headingAccuracy: 15,
        );

        expect(_heading0to360(marker.heading), closeTo(0, 1));
      },
    );

    test(
      'does not rotate for small displacement even when GPS heading is present',
      () {
        final marker = visual();
        marker.apply(latitude: 10.1, longitude: 79.2);
        final heading = marker.heading;
        marker.apply(
          latitude: 10.10007,
          longitude: 79.2,
          heading: 90,
          headingAccuracy: 15,
        );

        expect(marker.displayLatitude, 10.1);
        expect(marker.heading, heading);
        expect(marker.rawLatitude, 10.10007);
      },
    );
  });

  group('visual marker direction cases', () {
    test('CASE A: stationary GPS jitter does not move or rotate the bike', () {
      final marker = visual();
      marker.apply(latitude: 10.1, longitude: 79.2);
      final originLat = marker.displayLatitude;
      final originLng = marker.displayLongitude;
      final heading = marker.heading;

      for (var i = 1; i <= 8; i++) {
        marker.apply(
          latitude: 10.1 + (i.isEven ? 0.00004 : -0.00003),
          longitude: 79.2 + (i.isOdd ? 0.00004 : -0.00002),
          heading: 40.0 * i,
          headingAccuracy: 20,
        );
      }

      expect(marker.displayLatitude, originLat);
      expect(marker.displayLongitude, originLng);
      expect(marker.heading, heading);
    });

    test('CASE B: moving north moves the marker and points north', () {
      final marker = visual();
      marker.apply(latitude: 10.1, longitude: 79.2);
      marker.apply(latitude: 10.1002, longitude: 79.2);

      expect(marker.displayLatitude, 10.1002);
      expect(marker.displayLongitude, 79.2);
      expect(_heading0to360(marker.heading), closeTo(0, 5));
    });

    test('CASE C: turning east updates heading toward 90°', () {
      final marker = visual();
      marker.apply(latitude: 10.1, longitude: 79.2);
      marker.apply(latitude: 10.1002, longitude: 79.2);
      marker.apply(latitude: 10.1002, longitude: 79.2002);

      expect(_heading0to360(marker.heading), closeTo(90, 8));
    });

    test('CASE D: turning west updates heading toward 270°', () {
      final marker = visual();
      marker.apply(latitude: 10.1, longitude: 79.2);
      marker.apply(latitude: 10.1002, longitude: 79.2);
      marker.apply(latitude: 10.1002, longitude: 79.1998);

      expect(_heading0to360(marker.heading), closeTo(270, 8));
    });

    test('CASE E: stopping keeps the last stable position and heading', () {
      final marker = visual();
      marker.apply(latitude: 10.1, longitude: 79.2);
      marker.apply(latitude: 10.1002, longitude: 79.2);
      final parkedLat = marker.displayLatitude;
      final parkedLng = marker.displayLongitude;
      final heading = marker.heading;

      marker.apply(
        latitude: 10.10022,
        longitude: 79.20001,
        heading: 200,
        headingAccuracy: 25,
      );

      expect(marker.displayLatitude, parkedLat);
      expect(marker.displayLongitude, parkedLng);
      expect(marker.heading, heading);
    });

    test('CASE F: 0°/360° wrap uses the short arc, not a full spin', () {
      final marker = visual();
      marker.apply(latitude: 10.1, longitude: 79.2);
      marker.apply(
        latitude: 10.15,
        longitude: 79.2,
        heading: 350,
        headingAccuracy: 8,
      );
      final afterFirst = marker.heading;

      marker.apply(
        latitude: 10.20,
        longitude: 79.2,
        heading: 10,
        headingAccuracy: 8,
      );

      expect(shortestHeadingDelta(350, 10).abs(), closeTo(20, 0.001));
      expect((marker.heading - afterFirst).abs(), lessThan(30));
      expect(_heading0to360(marker.heading), closeTo(10, 8));
    });

    test(
      'CASE G: Stage A (rider → restaurant) uses the same visual filter',
      () {
        final marker = visual();
        const pickupLat = 10.79;
        const pickupLng = 79.14;
        marker.apply(latitude: pickupLat - 0.002, longitude: pickupLng);
        marker.apply(latitude: pickupLat - 0.001, longitude: pickupLng);

        expect(marker.displayLatitude, pickupLat - 0.001);
        expect(_heading0to360(marker.heading), closeTo(0, 5));
        expect(
          trackingMapStatus(
            orderStatus: OrderStatus.ready,
            deliveryJobStatus: 'assigned',
          ),
          OrderStatus.ready,
        );
      },
    );

    test('CASE H: Stage B (rider → customer) uses the same visual filter', () {
      final marker = visual();
      const customerLat = 10.80;
      const customerLng = 79.16;
      marker.apply(latitude: customerLat - 0.002, longitude: customerLng);
      marker.apply(latitude: customerLat - 0.0018, longitude: customerLng);
      marker.apply(
        latitude: customerLat - 0.0018,
        longitude: customerLng + 0.0002,
      );

      expect(_heading0to360(marker.heading), closeTo(90, 8));
      expect(
        trackingMapStatus(
          orderStatus: OrderStatus.ready,
          deliveryJobStatus: 'out_for_delivery',
        ),
        OrderStatus.outForDelivery,
      );
    });
  });

  test('reset drops display pose so a later first fix is accepted', () {
    final marker = visual();
    marker.apply(latitude: 10.1, longitude: 79.2);
    marker.apply(latitude: 10.1002, longitude: 79.2);
    marker.reset();
    marker.apply(latitude: 13.08, longitude: 80.27);

    expect(marker.displayLatitude, 13.08);
    expect(marker.displayLongitude, 80.27);
    expect(marker.heading, 0);
  });
}

double _heading0to360(double degrees) => ((degrees % 360) + 360) % 360;
