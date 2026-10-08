import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/orders/data/models/rider_location_model.dart';
import 'package:customer_app/features/orders/domain/rider_location_freshness.dart';

void main() {
  group('RiderLocationModel.parseRiderLocation', () {
    test('parses latitude, longitude, and updatedAt', () {
      final location = RiderLocationModel.parseRiderLocation({
        'latitude': 10.78,
        'longitude': 79.13,
        'updatedAt': DateTime.utc(2026, 9, 22, 11, 30),
      });

      expect(location, isNotNull);
      expect(location!.latitude, 10.78);
      expect(location.longitude, 79.13);
      expect(location.updatedAt, DateTime.utc(2026, 9, 22, 11, 30));
    });

    test('accepts Timestamp-like toDate() values', () {
      final location = RiderLocationModel.parseRiderLocation({
        'latitude': 13.08,
        'longitude': 80.27,
        'updatedAt': _FakeTimestamp(DateTime.utc(2026, 9, 22, 12)),
      });

      expect(location!.updatedAt, DateTime.utc(2026, 9, 22, 12));
    });

    test('rejects 0,0 and missing updatedAt', () {
      expect(
        RiderLocationModel.parseRiderLocation({
          'latitude': 0,
          'longitude': 0,
          'updatedAt': DateTime.utc(2026, 9, 22),
        }),
        isNull,
      );
      expect(
        RiderLocationModel.parseRiderLocation({
          'latitude': 10.78,
          'longitude': 79.13,
        }),
        isNull,
      );
    });
  });

  test('fromJobDocument keeps job status and optional location', () {
    final tracking = RiderLocationModel.fromJobDocument('order-1', {
      'status': 'assigned',
      'riderLocation': {
        'latitude': 10.78,
        'longitude': 79.13,
        'updatedAt': DateTime.utc(2026, 9, 22, 11),
      },
    });

    expect(tracking!.orderId, 'order-1');
    expect(tracking.status, 'assigned');
    expect(tracking.isLiveTrackingActive, isTrue);
    expect(tracking.riderLocation!.latitude, 10.78);
  });

  test('delivered jobs are not live-tracking', () {
    final tracking = RiderLocationModel.fromJobDocument('order-1', {
      'status': 'delivered',
    });
    expect(tracking!.isLiveTrackingActive, isFalse);
    expect(tracking.riderLocation, isNull);
  });

  group('RiderLocationFreshness', () {
    final updatedAt = DateTime.utc(2026, 9, 22, 12, 0, 0);

    test('is fresh within 60 seconds', () {
      expect(
        RiderLocationFreshness.isFresh(
          updatedAt,
          updatedAt.add(const Duration(seconds: 60)),
        ),
        isTrue,
      );
    });

    test('is stale after 60 seconds', () {
      expect(
        RiderLocationFreshness.isFresh(
          updatedAt,
          updatedAt.add(const Duration(seconds: 61)),
        ),
        isFalse,
      );
    });
  });
}

class _FakeTimestamp {
  _FakeTimestamp(this._date);

  final DateTime _date;

  DateTime toDate() => _date;
}
