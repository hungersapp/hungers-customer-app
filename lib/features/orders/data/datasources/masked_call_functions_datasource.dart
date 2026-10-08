import 'package:cloud_functions/cloud_functions.dart';

enum MaskedCallTargetRole {
  customer('CUSTOMER'),
  deliveryPartner('DELIVERY_PARTNER'),
  restaurant('RESTAURANT');

  const MaskedCallTargetRole(this.wireValue);
  final String wireValue;
}

class MaskedCallSessionResult {
  const MaskedCallSessionResult({
    required this.sessionId,
    required this.status,
    this.maskedNumber,
    this.expiresAt,
  });

  final String sessionId;
  final String status;
  final String? maskedNumber;
  final String? expiresAt;
}

class MaskedCallException implements Exception {
  const MaskedCallException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  bool get isProviderUnavailable =>
      code == 'MASKED_CALL_PROVIDER_NOT_CONFIGURED';

  String get userMessage =>
      'Calling is temporarily unavailable. Please try again later.';
}

abstract class MaskedCallFunctionsDatasource {
  Future<MaskedCallSessionResult> createSession({
    required String orderId,
    required MaskedCallTargetRole targetRole,
  });
}

class FirebaseMaskedCallFunctionsDatasource
    implements MaskedCallFunctionsDatasource {
  FirebaseMaskedCallFunctionsDatasource({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  static const String createCallableName = 'createMaskedCallSession';

  @override
  Future<MaskedCallSessionResult> createSession({
    required String orderId,
    required MaskedCallTargetRole targetRole,
  }) async {
    try {
      final callable = _functions.httpsCallable(createCallableName);
      final result = await callable.call<dynamic>({
        'orderId': orderId.trim(),
        'targetRole': targetRole.wireValue,
      });
      final raw = result.data;
      if (raw is! Map) {
        throw const MaskedCallException(
          code: 'INVALID_RESPONSE',
          message: 'Calling is temporarily unavailable. Please try again later.',
        );
      }
      final map = Map<String, dynamic>.from(raw);
      final sessionId = (map['sessionId'] as String?)?.trim() ?? '';
      final status = (map['status'] as String?)?.trim() ?? '';
      if (sessionId.isEmpty || status.isEmpty) {
        throw const MaskedCallException(
          code: 'INVALID_RESPONSE',
          message: 'Calling is temporarily unavailable. Please try again later.',
        );
      }
      final masked = (map['maskedNumber'] as String?)?.trim();
      return MaskedCallSessionResult(
        sessionId: sessionId,
        status: status,
        maskedNumber: (masked == null || masked.isEmpty) ? null : masked,
        expiresAt: (map['expiresAt'] as String?)?.trim(),
      );
    } on FirebaseFunctionsException catch (error) {
      throw MaskedCallException(
        code: _readDetailCode(error.details) ?? error.code,
        message: 'Calling is temporarily unavailable. Please try again later.',
      );
    }
  }

  static String? _readDetailCode(Object? details) {
    if (details is Map) {
      final code = details['code'];
      if (code is String && code.trim().isNotEmpty) {
        return code.trim();
      }
    }
    return null;
  }
}
