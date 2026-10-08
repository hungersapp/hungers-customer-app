import '../data/datasources/online_payment_functions_datasource.dart';

/// Result of handing the customer to the payment provider's checkout UI.
///
/// Neither value means "paid": [returned] only says the provider UI closed
/// normally, [errored] says it reported an error or was dismissed. Either
/// way the app must ask the backend (verifyCustomerPayment) what Cashfree
/// actually recorded.
enum OnlinePaymentLaunchOutcome { returned, errored }

class OnlinePaymentLaunchResult {
  const OnlinePaymentLaunchResult(this.outcome, {this.message});

  final OnlinePaymentLaunchOutcome outcome;
  final String? message;
}

/// Opens the provider checkout (Cashfree SDK) for a server-created session.
abstract class OnlinePaymentLauncher {
  Future<OnlinePaymentLaunchResult> launch(OnlinePaymentSession session);
}
