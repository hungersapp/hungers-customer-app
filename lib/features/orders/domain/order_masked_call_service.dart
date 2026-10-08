import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/datasources/masked_call_functions_datasource.dart';

enum OrderMaskedCallResult {
  started,
  unavailable,
  failed,
}

/// Outcome of asking the backend to set up a masked call.
///
/// [bridgeNumber] is the provider-issued masked number (never the rider's
/// real phone). When present the customer's phone dials it; when absent the
/// provider is expected to connect the call itself.
class OrderMaskedCallOutcome {
  const OrderMaskedCallOutcome(this.result, {this.bridgeNumber});

  final OrderMaskedCallResult result;
  final String? bridgeNumber;

  bool get started => result == OrderMaskedCallResult.started;
}

abstract class OrderMaskedCallService {
  Future<OrderMaskedCallOutcome> callRider({required String orderId});
  Future<OrderMaskedCallOutcome> callRestaurant({required String orderId});
}

class CloudOrderMaskedCallService implements OrderMaskedCallService {
  const CloudOrderMaskedCallService(
    this._datasource, {
    this.timeout = const Duration(seconds: 25),
  });

  final MaskedCallFunctionsDatasource _datasource;
  final Duration timeout;

  @override
  Future<OrderMaskedCallOutcome> callRider({required String orderId}) {
    return _create(orderId, MaskedCallTargetRole.deliveryPartner);
  }

  @override
  Future<OrderMaskedCallOutcome> callRestaurant({required String orderId}) {
    return _create(orderId, MaskedCallTargetRole.restaurant);
  }

  Future<OrderMaskedCallOutcome> _create(
    String orderId,
    MaskedCallTargetRole targetRole,
  ) async {
    try {
      final session = await _datasource
          .createSession(orderId: orderId, targetRole: targetRole)
          .timeout(timeout);
      final bridge = session.maskedNumber?.trim();
      return OrderMaskedCallOutcome(
        OrderMaskedCallResult.started,
        bridgeNumber: (bridge == null || bridge.isEmpty) ? null : bridge,
      );
    } on MaskedCallException catch (error) {
      debugPrint('masked call failed: ${error.code}');
      return OrderMaskedCallOutcome(
        error.isProviderUnavailable
            ? OrderMaskedCallResult.unavailable
            : OrderMaskedCallResult.failed,
      );
    } catch (error) {
      // Timeouts, transport errors, malformed responses: keep the technical
      // detail in debug logs only; the customer sees a safe message.
      debugPrint('masked call error: ${error.runtimeType}');
      return const OrderMaskedCallOutcome(OrderMaskedCallResult.failed);
    }
  }
}
