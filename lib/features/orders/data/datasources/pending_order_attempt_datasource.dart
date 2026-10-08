import 'package:cloud_firestore/cloud_firestore.dart';

/// A customer's in-flight order-placement attempt, kept only long enough to
/// safely resend the same `idempotencyKey` if the outcome of a `placeOrder`
/// call is ambiguous (e.g. a timeout). [fingerprint] is an opaque, caller-
/// computed string identifying the logical order this key belongs to (see
/// `PlaceOrderUseCase`) — this datasource never inspects or builds it.
class PendingOrderAttempt {
  const PendingOrderAttempt({
    required this.idempotencyKey,
    required this.fingerprint,
    required this.createdAt,
  });

  final String idempotencyKey;
  final String fingerprint;
  final DateTime createdAt;

  /// True once [now] is more than [maxAge] (default 30 minutes, matching
  /// the locked implementation value) past [createdAt].
  bool isStaleAt(
    DateTime now, {
    Duration maxAge = const Duration(minutes: 30),
  }) {
    return now.difference(createdAt) > maxAge;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'idempotencyKey': idempotencyKey,
    'fingerprint': fingerprint,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static PendingOrderAttempt? fromMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final key = raw['idempotencyKey'];
    final fingerprint = raw['fingerprint'];
    final createdAtRaw = raw['createdAt'];
    if (key is! String || key.trim().isEmpty) {
      return null;
    }
    if (fingerprint is! String) {
      return null;
    }
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : (createdAtRaw is DateTime ? createdAtRaw : null);
    if (createdAt == null) {
      return null;
    }
    return PendingOrderAttempt(
      idempotencyKey: key,
      fingerprint: fingerprint,
      createdAt: createdAt,
    );
  }
}

/// Reads/writes the single `pendingOrderAttempt` field on `users/{uid}` —
/// the same document and merge-write style already used by
/// `LocationFirestoreDatasource` for `location`. Never reads or writes any
/// other field on that document.
abstract class PendingOrderAttemptDatasource {
  Future<PendingOrderAttempt?> getPendingAttempt(String userId);

  Future<void> savePendingAttempt({
    required String userId,
    required PendingOrderAttempt attempt,
  });

  Future<void> clearPendingAttempt(String userId);
}

class FirestorePendingOrderAttemptDatasource
    implements PendingOrderAttemptDatasource {
  FirestorePendingOrderAttemptDatasource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _field = 'pendingOrderAttempt';

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  @override
  Future<PendingOrderAttempt?> getPendingAttempt(String userId) async {
    final snapshot = await _userDoc(userId).get();
    if (!snapshot.exists) {
      return null;
    }
    return PendingOrderAttempt.fromMap(snapshot.data()?[_field]);
  }

  @override
  Future<void> savePendingAttempt({
    required String userId,
    required PendingOrderAttempt attempt,
  }) async {
    await _userDoc(
      userId,
    ).set(<String, dynamic>{_field: attempt.toMap()}, SetOptions(merge: true));
  }

  @override
  Future<void> clearPendingAttempt(String userId) async {
    await _userDoc(userId).set(<String, dynamic>{
      _field: FieldValue.delete(),
    }, SetOptions(merge: true));
  }
}
