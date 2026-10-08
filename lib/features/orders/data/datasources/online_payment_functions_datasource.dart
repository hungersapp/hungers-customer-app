import 'package:cloud_functions/cloud_functions.dart';

/// A Cashfree payment session the backend created (or reused) for one
/// "awaiting_payment" order. The amount is the server-computed order total;
/// the app never sends or decides an amount.
class OnlinePaymentSession {
  const OnlinePaymentSession({
    required this.orderId,
    required this.amount,
    required this.environment,
    required this.alreadyPaid,
    this.paymentId,
    this.providerOrderId,
    this.paymentSessionId,
  });

  final String orderId;
  final double amount;

  /// SANDBOX / PRODUCTION (or MOCK in the local emulator).
  final String environment;
  final bool alreadyPaid;
  final String? paymentId;

  /// The Cashfree order_id the SDK session is for.
  final String? providerOrderId;
  final String? paymentSessionId;
}

/// What the backend verified with Cashfree after the SDK returned.
class OnlinePaymentVerification {
  const OnlinePaymentVerification({
    required this.orderId,
    required this.paymentStatus,
    required this.orderStatus,
    this.latestAttemptStatus,
    this.failureReason,
  });

  final String orderId;

  /// orders.paymentStatus — "paid" only after server-side verification.
  final String paymentStatus;
  final String orderStatus;
  final String? latestAttemptStatus;
  final String? failureReason;

  bool get isPaid => paymentStatus == 'paid';
  bool get isFailed => !isPaid && latestAttemptStatus == 'FAILED';
}

class OnlinePaymentException implements Exception {
  const OnlinePaymentException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

abstract class OnlinePaymentFunctionsDatasource {
  Future<OnlinePaymentSession> createPayment({
    required String orderId,
    required String paymentMethod,
  });

  Future<OnlinePaymentVerification> verifyPayment({required String orderId});
}

class FirebaseOnlinePaymentFunctionsDatasource
    implements OnlinePaymentFunctionsDatasource {
  FirebaseOnlinePaymentFunctionsDatasource({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  static const String createCallableName = 'createCustomerPayment';
  static const String verifyCallableName = 'verifyCustomerPayment';

  @override
  Future<OnlinePaymentSession> createPayment({
    required String orderId,
    required String paymentMethod,
  }) async {
    final map = await _call(createCallableName, {
      'orderId': orderId,
      'paymentMethod': paymentMethod,
    });
    return OnlinePaymentSession(
      orderId: _string(map['orderId']) ?? orderId,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      environment: _string(map['environment']) ?? '',
      alreadyPaid: map['alreadyPaid'] == true,
      paymentId: _string(map['paymentId']),
      providerOrderId: _string(map['providerOrderId']),
      paymentSessionId: _string(map['paymentSessionId']),
    );
  }

  @override
  Future<OnlinePaymentVerification> verifyPayment({
    required String orderId,
  }) async {
    final map = await _call(verifyCallableName, {'orderId': orderId});
    return OnlinePaymentVerification(
      orderId: _string(map['orderId']) ?? orderId,
      paymentStatus: _string(map['paymentStatus']) ?? '',
      orderStatus: _string(map['orderStatus']) ?? '',
      latestAttemptStatus: _string(map['latestAttemptStatus']),
      failureReason: _string(map['failureReason']),
    );
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call<dynamic>(payload);
      final data = result.data;
      if (data is! Map) {
        throw const OnlinePaymentException(
          'Unable to process the payment. Please try again.',
        );
      }
      return Map<String, dynamic>.from(data);
    } on FirebaseFunctionsException catch (error) {
      throw _map(error);
    }
  }

  static String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  OnlinePaymentException _map(FirebaseFunctionsException error) {
    final details = error.details;
    final code = details is Map && details['code'] is String
        ? details['code'] as String
        : null;
    switch (code) {
      case 'ONLINE_PAYMENTS_UNAVAILABLE':
        return OnlinePaymentException(
          'Online payment is not available right now. Please choose Cash on Delivery.',
          code: code,
        );
      case 'CUSTOMER_PHONE_REQUIRED':
        return OnlinePaymentException(
          'A verified mobile number is required for online payment.',
          code: code,
        );
      case 'TOO_MANY_PAYMENT_ATTEMPTS':
        return OnlinePaymentException(
          'Too many payment attempts for this order. Please contact support.',
          code: code,
        );
      case 'PAYMENT_PROVIDER_UNAVAILABLE':
        return OnlinePaymentException(
          'Unable to start the payment. Please try again.',
          code: code,
        );
      default:
        final message = error.message?.trim();
        return OnlinePaymentException(
          message != null && message.isNotEmpty
              ? message
              : 'Unable to process the payment. Please try again.',
          code: code ?? error.code,
        );
    }
  }
}
