import 'package:customer_app/core/location/bearing_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isHeadingReliable', () {
    test('false when headingAccuracy is null', () {
      expect(isHeadingReliable(null), isFalse);
    });

    test(
      'false when headingAccuracy is exactly 0.0 (geolocator\'s "unavailable" sentinel)',
      () {
        expect(isHeadingReliable(0), isFalse);
      },
    );

    test('true when headingAccuracy is positive', () {
      expect(isHeadingReliable(12.5), isTrue);
    });
  });

  group('resolveBearing', () {
    test('prefers a reliable GPS heading over any positional fallback', () {
      final bearing = resolveBearing(
        currentLatitude: 13.0,
        currentLongitude: 80.0,
        currentHeading: 275,
        currentHeadingAccuracy: 10,
        previousLatitude: 12.0,
        previousLongitude: 79.0,
        fallbackBearing: 0,
      );
      expect(bearing, 275);
    });

    test('normalizes a GPS heading of 360+ into 0-360', () {
      final bearing = resolveBearing(
        currentLatitude: 13.0,
        currentLongitude: 80.0,
        currentHeading: 370,
        currentHeadingAccuracy: 10,
        previousLatitude: null,
        previousLongitude: null,
        fallbackBearing: 0,
      );
      expect(bearing, 10);
    });

    test(
      'falls back to the great-circle bearing when heading is unreliable and the rider has moved enough',
      () {
        final bearing = resolveBearing(
          currentLatitude: 13.01,
          currentLongitude: 80.0,
          currentHeading: 0,
          currentHeadingAccuracy: 0,
          previousLatitude: 13.0,
          previousLongitude: 80.0,
          fallbackBearing: 999,
        );
        expect(bearing, closeTo(0, 1));
      },
    );

    test(
      'falls back to due-east bearing (~90 degrees) for a purely eastward move',
      () {
        final bearing = resolveBearing(
          currentLatitude: 13.0,
          currentLongitude: 80.01,
          currentHeading: null,
          currentHeadingAccuracy: null,
          previousLatitude: 13.0,
          previousLongitude: 80.0,
          fallbackBearing: 999,
        );
        expect(bearing, closeTo(90, 1));
      },
    );

    test(
      'keeps the fallback bearing unchanged when there is no previous fix at all',
      () {
        final bearing = resolveBearing(
          currentLatitude: 13.0,
          currentLongitude: 80.0,
          currentHeading: null,
          currentHeadingAccuracy: null,
          previousLatitude: null,
          previousLongitude: null,
          fallbackBearing: 42,
        );
        expect(bearing, 42);
      },
    );

    test(
      'keeps the fallback bearing unchanged when the rider has barely moved (GPS jitter guard)',
      () {
        final bearing = resolveBearing(
          currentLatitude: 13.000001,
          currentLongitude: 80.0,
          currentHeading: null,
          currentHeadingAccuracy: null,
          previousLatitude: 13.0,
          previousLongitude: 80.0,
          fallbackBearing: 42,
        );
        expect(bearing, 42);
      },
    );

    test(
      'never fabricates a bearing from nothing — same-point fixes with no heading keep the fallback',
      () {
        final bearing = resolveBearing(
          currentLatitude: 13.0,
          currentLongitude: 80.0,
          currentHeading: 0,
          currentHeadingAccuracy: 0,
          previousLatitude: 13.0,
          previousLongitude: 80.0,
          fallbackBearing: 15,
        );
        expect(bearing, 15);
      },
    );
  });

  group('shortestHeadingDelta / applyShortestHeading', () {
    test('350° to 10° is a +20° turn, not a -340° spin', () {
      expect(shortestHeadingDelta(350, 10), closeTo(20, 0.001));
    });

    test('10° to 350° is a -20° turn', () {
      expect(shortestHeadingDelta(10, 350), closeTo(-20, 0.001));
    });

    test(
      'applyShortestHeading unwraps across 0°/360° so the marker does not spin',
      () {
        expect(
          applyShortestHeading(currentDegrees: 350, targetDegrees: 10),
          closeTo(370, 0.001),
        );
      },
    );

    test('deadband keeps the current heading for a tiny twitch', () {
      expect(
        applyShortestHeading(
          currentDegrees: 90,
          targetDegrees: 94,
          deadbandDegrees: 8,
        ),
        90,
      );
    });

    test('a real turn larger than the deadband is applied', () {
      expect(
        applyShortestHeading(currentDegrees: 0, targetDegrees: 90),
        closeTo(90, 0.001),
      );
    });
  });
}
