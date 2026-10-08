import 'package:customer_app/core/location/bearing_calculator.dart';
import 'package:customer_app/core/location/rider_scooter_motion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t0 = DateTime.utc(2026, 10, 3, 8);

  RiderScooterMotion motion() => RiderScooterMotion();

  group('position interpolation', () {
    test('glides halfway between two GPS fixes', () {
      final ride = motion();
      ride.offer(
        latitude: 10,
        longitude: 79,
        heading: 0,
        now: t0,
        sampleTime: t0,
      );
      final t1 = t0.add(const Duration(milliseconds: 800));
      expect(
        ride.offer(
          latitude: 10.01,
          longitude: 79,
          heading: 0,
          now: t1,
          sampleTime: t1,
        ),
        isTrue,
      );

      final mid = ride.poseAt(t1.add(const Duration(milliseconds: 400)));
      expect(mid, isNotNull);
      expect(mid!.latitude, closeTo(10.005, 0.0000001));
      expect(mid.longitude, closeTo(79, 0.0000001));
    });
  });

  group('bearing', () {
    test('track bearing for a northbound fix is about 0°', () {
      final bearing = resolveBearing(
        currentLatitude: 10.01,
        currentLongitude: 79,
        currentHeading: null,
        currentHeadingAccuracy: null,
        previousLatitude: 10,
        previousLongitude: 79,
        fallbackBearing: 90,
      );
      expect(bearing, closeTo(0, 1));
      expect(
        Geolocator.bearingBetween(10, 79, 10.01, 79),
        closeTo(0, 1),
      );
    });

    test('350° to 10° turns about +20°, not −340°', () {
      final ride = motion();
      ride.offer(
        latitude: 10,
        longitude: 79,
        heading: 350,
        now: t0,
        sampleTime: t0,
      );
      final t1 = t0.add(const Duration(milliseconds: 800));
      ride.offer(
        latitude: 10.01,
        longitude: 79,
        heading: 10,
        now: t1,
        sampleTime: t1,
      );

      expect(shortestHeadingDelta(350, 10), closeTo(20, 0.001));
      final mid = ride.poseAt(t1.add(const Duration(milliseconds: 400)))!;
      expect(mid.heading - 350, closeTo(10, 0.5));
      final end = ride.poseAt(t1.add(const Duration(milliseconds: 800)))!;
      expect(end.heading - 350, closeTo(20, 0.5));
      expect(_heading0to360(end.heading), closeTo(10, 0.5));
    });

    test('10° to 350° turns about −20°, not +340°', () {
      final ride = motion();
      ride.offer(
        latitude: 10,
        longitude: 79,
        heading: 10,
        now: t0,
        sampleTime: t0,
      );
      final t1 = t0.add(const Duration(milliseconds: 800));
      ride.offer(
        latitude: 10.01,
        longitude: 79,
        heading: 350,
        now: t1,
        sampleTime: t1,
      );

      expect(shortestHeadingDelta(10, 350), closeTo(-20, 0.001));
      final mid = ride.poseAt(t1.add(const Duration(milliseconds: 400)))!;
      expect(mid.heading - 10, closeTo(-10, 0.5));
      final end = ride.poseAt(t1.add(const Duration(milliseconds: 800)))!;
      expect(end.heading - 10, closeTo(-20, 0.5));
      expect(_heading0to360(end.heading), closeTo(350, 0.5));
    });

    test('a turn retargets from the current pose along the short arc', () {
      final ride = motion();
      ride.offer(
        latitude: 10,
        longitude: 79,
        heading: 0,
        now: t0,
        sampleTime: t0,
      );
      final t1 = t0.add(const Duration(seconds: 1));
      ride.offer(
        latitude: 10.01,
        longitude: 79,
        heading: 0,
        now: t1,
        sampleTime: t1,
      );
      final t2 = t1.add(const Duration(milliseconds: 400));
      ride.offer(
        latitude: 10.01,
        longitude: 79.01,
        heading: 90,
        now: t2,
        sampleTime: t2,
      );

      final later = ride.poseAt(t2.add(const Duration(milliseconds: 225)))!;
      expect(later.heading, greaterThan(20));
      expect(later.heading, lessThan(90));
      expect(later.longitude, greaterThan(79));
      expect(later.longitude, lessThan(79.01));
    });
  });

  group('gps sample guards', () {
    test('a duplicate fix does not start another ride', () {
      final ride = motion();
      ride.offer(
        latitude: 10,
        longitude: 79,
        heading: 0,
        now: t0,
        sampleTime: t0,
      );
      final accepted = ride.offer(
        latitude: 10,
        longitude: 79,
        heading: 40,
        now: t0.add(const Duration(seconds: 2)),
        sampleTime: t0.add(const Duration(seconds: 2)),
      );

      expect(accepted, isFalse);
      expect(ride.isAnimating, isFalse);
      expect(ride.pose!.latitude, 10);
      expect(ride.pose!.heading, 0);
    });

    test('about 1 m of jitter does not move the scooter', () {
      final ride = motion();
      ride.offer(
        latitude: 10,
        longitude: 79,
        heading: 0,
        now: t0,
        sampleTime: t0,
      );
      final accepted = ride.offer(
        latitude: 10.00001,
        longitude: 79,
        heading: 90,
        now: t0.add(const Duration(seconds: 1)),
        sampleTime: t0.add(const Duration(seconds: 1)),
        accuracyMeters: 4,
      );

      expect(accepted, isFalse);
      expect(ride.pose!.latitude, 10);
      expect(ride.pose!.heading, 0);
    });

    test('a large accuracy value still accepts a real move', () {
      final ride = motion();
      ride.offer(
        latitude: 10,
        longitude: 79,
        heading: 0,
        now: t0,
        sampleTime: t0,
      );
      final accepted = ride.offer(
        latitude: 10.001,
        longitude: 79,
        heading: 0,
        now: t0.add(const Duration(milliseconds: 800)),
        sampleTime: t0.add(const Duration(milliseconds: 800)),
        accuracyMeters: 40,
      );

      expect(accepted, isTrue);
      expect(ride.isAnimating, isTrue);
    });

    test('an older fix does not pull the scooter backwards', () {
      final ride = motion();
      ride.offer(
        latitude: 10,
        longitude: 79,
        heading: 0,
        now: t0,
        sampleTime: t0,
      );
      final t1 = t0.add(const Duration(seconds: 2));
      ride.offer(
        latitude: 10.01,
        longitude: 79,
        heading: 0,
        now: t1,
        sampleTime: t1,
      );
      final accepted = ride.offer(
        latitude: 9.99,
        longitude: 79,
        heading: 180,
        now: t1.add(const Duration(milliseconds: 100)),
        sampleTime: t0.subtract(const Duration(seconds: 5)),
      );
      final settled = ride.poseAt(t1.add(const Duration(seconds: 2)))!;

      expect(accepted, isFalse);
      expect(settled.latitude, closeTo(10.01, 0.0000001));
      expect(_heading0to360(settled.heading), closeTo(0, 1));
    });

    test('stopping freezes the scooter and does not finish the old glide', () {
      final ride = motion();
      ride.offer(
        latitude: 10,
        longitude: 79,
        heading: 0,
        now: t0,
        sampleTime: t0,
      );
      final t1 = t0.add(const Duration(milliseconds: 800));
      ride.offer(
        latitude: 10.01,
        longitude: 79,
        heading: 0,
        now: t1,
        sampleTime: t1,
      );
      final stopAt = t1.add(const Duration(milliseconds: 200));
      ride.offer(
        latitude: 10.01,
        longitude: 79,
        heading: 0,
        now: stopAt,
        sampleTime: stopAt,
        stopped: true,
      );
      final frozen = ride.pose!.latitude;
      final later = ride.poseAt(t1.add(const Duration(seconds: 5)))!;

      expect(ride.isAnimating, isFalse);
      expect(frozen, greaterThan(10));
      expect(frozen, lessThan(10.005));
      expect(later.latitude, frozen);
    });

    test('a stale fix stops the glide and stays put', () {
      final ride = motion();
      ride.offer(
        latitude: 10,
        longitude: 79,
        heading: 0,
        now: t0,
        sampleTime: t0,
      );
      final t1 = t0.add(const Duration(milliseconds: 800));
      ride.offer(
        latitude: 10.01,
        longitude: 79,
        heading: 0,
        now: t1,
        sampleTime: t1,
      );
      final staleAt = t1.add(const Duration(milliseconds: 200));
      ride.offer(
        latitude: 10.01,
        longitude: 79,
        heading: 0,
        now: staleAt,
        sampleTime: staleAt,
        stale: true,
      );
      final frozen = ride.pose!.latitude;
      final later = ride.poseAt(t1.add(const Duration(seconds: 5)))!;

      expect(ride.isStale, isTrue);
      expect(ride.isAnimating, isFalse);
      expect(later.latitude, frozen);
      expect(later.latitude, lessThan(10.01));
    });
  });

  test('dispose stops the ride and rejects later fixes', () {
    final ride = motion();
    ride.offer(
      latitude: 10,
      longitude: 79,
      heading: 0,
      now: t0,
      sampleTime: t0,
    );
    final t1 = t0.add(const Duration(milliseconds: 800));
    ride.offer(
      latitude: 10.01,
      longitude: 79,
      heading: 0,
      now: t1,
      sampleTime: t1,
    );
    final mid = ride.poseAt(t1.add(const Duration(milliseconds: 200)))!;
    ride.dispose();

    expect(ride.isDisposed, isTrue);
    expect(ride.isAnimating, isFalse);
    expect(
      ride.offer(
        latitude: 11,
        longitude: 80,
        heading: 90,
        now: t1.add(const Duration(seconds: 1)),
        sampleTime: t1.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(
      ride.poseAt(t1.add(const Duration(seconds: 5)))!.latitude,
      mid.latitude,
    );
    ride.tick(t1.add(const Duration(seconds: 5)));
  });
}

double _heading0to360(double degrees) => ((degrees % 360) + 360) % 360;
