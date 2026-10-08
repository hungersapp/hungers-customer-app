import 'dart:async';

import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';

import '../domain/online_payment_launcher.dart';
import 'datasources/online_payment_functions_datasource.dart';

/// Cashfree Payment Gateway web checkout (official flutter_cashfree_pg_sdk).
///
/// Only the backend-issued payment_session_id and Cashfree order_id are
/// used here — no Cashfree credentials exist in the app. The SDK's
/// "verifyPayment" callback is only a signal to go and ask the backend; it
/// is never treated as success on its own.
class CashfreePaymentLauncher implements OnlinePaymentLauncher {
  CashfreePaymentLauncher({CFPaymentGatewayService? service})
      : _service = service ?? CFPaymentGatewayService();

  final CFPaymentGatewayService _service;

  @override
  Future<OnlinePaymentLaunchResult> launch(OnlinePaymentSession session) async {
    final providerOrderId = session.providerOrderId;
    final paymentSessionId = session.paymentSessionId;
    final CFEnvironment environment;
    switch (session.environment) {
      case 'PRODUCTION':
        environment = CFEnvironment.PRODUCTION;
      case 'SANDBOX':
        environment = CFEnvironment.SANDBOX;
      default:
        return const OnlinePaymentLaunchResult(
          OnlinePaymentLaunchOutcome.errored,
          message: 'Online payment is not available in this environment.',
        );
    }
    if (providerOrderId == null || paymentSessionId == null) {
      return const OnlinePaymentLaunchResult(
        OnlinePaymentLaunchOutcome.errored,
        message: 'Unable to start the payment. Please try again.',
      );
    }

    final completer = Completer<OnlinePaymentLaunchResult>();
    _service.setCallback(
      (String _) {
        if (!completer.isCompleted) {
          completer.complete(
            const OnlinePaymentLaunchResult(OnlinePaymentLaunchOutcome.returned),
          );
        }
      },
      (CFErrorResponse error, String _) {
        if (!completer.isCompleted) {
          completer.complete(
            OnlinePaymentLaunchResult(
              OnlinePaymentLaunchOutcome.errored,
              message: error.getMessage(),
            ),
          );
        }
      },
    );
    try {
      // providerOrderId / paymentSessionId / environment come from the
      // backend createCustomerPayment result (Cashfree's order_id and
      // payment_session_id, and the gateway environment). Not the
      // Firestore order document id.
      final cfSession = CFSessionBuilder()
          .setEnvironment(environment)
          .setOrderId(providerOrderId)
          .setPaymentSessionId(paymentSessionId)
          .build();
      final checkout = CFWebCheckoutPaymentBuilder().setSession(cfSession).build();
      _service.doPayment(checkout);
    } on CFException catch (error) {
      return OnlinePaymentLaunchResult(
        OnlinePaymentLaunchOutcome.errored,
        message: error.message,
      );
    }
    return completer.future;
  }
}
