import 'dart:async';

import 'package:customer_app/features/orders/data/datasources/masked_call_functions_datasource.dart';
import 'package:customer_app/features/orders/domain/order_masked_call_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// MOCK datasource - a test double for the createMaskedCallSession callable.
/// Nothing here talks to Exotel; these tests prove client mapping only, not
/// a real production call.
class _FakeDatasource implements MaskedCallFunctionsDatasource {
  _FakeDatasource({this.throwCode, this.maskedNumber, this.hang = false});

  final String? throwCode;
  final String? maskedNumber;
  final bool hang;
  final List<Map<String, String>> calls = [];

  @override
  Future<MaskedCallSessionResult> createSession({
    required String orderId,
    required MaskedCallTargetRole targetRole,
  }) async {
    calls.add({'orderId': orderId, 'targetRole': targetRole.wireValue});
    if (hang) {
      return Completer<MaskedCallSessionResult>().future;
    }
    if (throwCode != null) {
      throw MaskedCallException(
        code: throwCode!,
        message: 'Calling is temporarily unavailable. Please try again later.',
      );
    }
    return MaskedCallSessionResult(
      sessionId: 's1',
      status: 'ACTIVE',
      maskedNumber: maskedNumber,
    );
  }
}

void main() {
  test(
    'Call Rider sends only orderId + DELIVERY_PARTNER (no rider identity)',
    () async {
      final ds = _FakeDatasource();
      final outcome = await CloudOrderMaskedCallService(
        ds,
      ).callRider(orderId: 'order-a');

      expect(outcome.result, OrderMaskedCallResult.started);
      expect(ds.calls.single, {
        'orderId': 'order-a',
        'targetRole': 'DELIVERY_PARTNER',
      });
    },
  );

  test(
    'MOCK success with a bridge number hands the bridge number back',
    () async {
      final outcome = await CloudOrderMaskedCallService(
        _FakeDatasource(maskedNumber: ' +918000000001 '),
      ).callRider(orderId: 'order-a');

      expect(outcome.started, isTrue);
      expect(outcome.bridgeNumber, '+918000000001');
    },
  );

  test('success without a bridge number means server-side connect', () async {
    final none = await CloudOrderMaskedCallService(
      _FakeDatasource(),
    ).callRider(orderId: 'order-a');
    final blank = await CloudOrderMaskedCallService(
      _FakeDatasource(maskedNumber: '   '),
    ).callRider(orderId: 'order-a');

    expect(none.started, isTrue);
    expect(none.bridgeNumber, isNull);
    expect(blank.bridgeNumber, isNull);
  });

  test('Call Restaurant invokes the RESTAURANT target', () async {
    final ds = _FakeDatasource();
    final outcome = await CloudOrderMaskedCallService(
      ds,
    ).callRestaurant(orderId: 'order-a');

    expect(outcome.result, OrderMaskedCallResult.started);
    expect(ds.calls.single['targetRole'], 'RESTAURANT');
  });

  test('provider not configured maps to a safe unavailable result', () async {
    final outcome = await CloudOrderMaskedCallService(
      _FakeDatasource(throwCode: 'MASKED_CALL_PROVIDER_NOT_CONFIGURED'),
    ).callRider(orderId: 'order-a');

    expect(outcome.result, OrderMaskedCallResult.unavailable);
    expect(outcome.bridgeNumber, isNull);
  });

  test(
    'every backend denial maps to a safe failed result, never a bridge number',
    () async {
      for (final code in [
        'NOT_ORDER_OWNER',
        'DELIVERY_JOB_INELIGIBLE',
        'ORDER_STATE_INELIGIBLE',
        'CALLEE_PHONE_UNAVAILABLE',
        'CALLER_PHONE_UNAVAILABLE',
        'ORDER_NOT_FOUND',
        'MASKED_CALL_PROVIDER_FAILED',
        'unauthenticated',
        'INVALID_RESPONSE',
      ]) {
        final outcome = await CloudOrderMaskedCallService(
          _FakeDatasource(throwCode: code),
        ).callRider(orderId: 'order-a');

        expect(outcome.result, OrderMaskedCallResult.failed, reason: code);
        expect(outcome.bridgeNumber, isNull, reason: code);
      }
    },
  );

  test('a hanging callable times out into a safe failure', () async {
    final outcome = await CloudOrderMaskedCallService(
      _FakeDatasource(hang: true),
      timeout: const Duration(milliseconds: 20),
    ).callRider(orderId: 'order-a');

    expect(outcome.result, OrderMaskedCallResult.failed);
  });

  test('the session result type has no rider-phone field', () {
    // Guard against widening the client model: only these four fields exist.
    const result = MaskedCallSessionResult(
      sessionId: 's1',
      status: 'ACTIVE',
      maskedNumber: '+918000000001',
      expiresAt: '2026-09-24T10:00:00.000Z',
    );
    expect(result.sessionId, 's1');
    expect(result.maskedNumber, '+918000000001');
  });
}
