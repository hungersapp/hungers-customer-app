import 'package:customer_app/features/orders/data/models/rider_location_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// `delivery_jobs/{orderId}.riderPhone` is only the tel: target of Call Rider.
void main() {
  Map<String, dynamic> job(Map<String, dynamic> extra) => {
    'status': 'out_for_delivery',
    ...extra,
  };

  test('maps a trimmed rider phone from the delivery job', () {
    final tracking = RiderLocationModel.fromJobDocument(
      'order-1',
      job({'riderPhone': ' +919222222222 '}),
    );

    expect(tracking!.riderPhone, '+919222222222');
    expect(tracking.isLiveTrackingActive, isTrue);
  });

  test(
    'a job without a rider phone maps to null (Call Rider then says unavailable)',
    () {
      final tracking = RiderLocationModel.fromJobDocument('order-1', job({}));

      expect(tracking!.riderPhone, isNull);
    },
  );

  test('blank or non-string rider phone values are ignored, never crash', () {
    for (final value in ['', '   ', 9222222222, true, null]) {
      final tracking = RiderLocationModel.fromJobDocument(
        'order-1',
        job({'riderPhone': value}),
      );
      expect(tracking!.riderPhone, isNull, reason: '$value');
    }
  });

  test('other rider-identifying fields are not mapped', () {
    final tracking = RiderLocationModel.fromJobDocument(
      'order-1',
      job({
        'riderPhone': '+919222222222',
        'partnerId': 'rider-uid',
        'partnerPhone': '+919333333333',
        'mobileNumber': '+919444444444',
      }),
    );

    expect(tracking!.riderPhone, '+919222222222');
  });
}
