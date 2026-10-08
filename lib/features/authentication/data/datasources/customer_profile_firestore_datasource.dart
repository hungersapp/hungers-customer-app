import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/auth_user_model.dart';

/// Existing Customer Firestore contract: `users/{uid}`.
class CustomerProfileFirestoreDatasource {
  CustomerProfileFirestoreDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  Future<AuthUserModel?> getCustomerProfile(String userId) async {
    final snapshot = await _userDoc(userId).get();
    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return AuthUserModel.fromMap({
      ...data,
      'uid': data['uid'] ?? userId,
    });
  }

  Future<void> createCustomerProfile(AuthUserModel user) async {
    await _userDoc(user.uid).set(
      {
        ...user.toMap(),
        'profileCreated': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateCustomerName({
    required String userId,
    required String name,
  }) async {
    await _userDoc(userId).set(
      {
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
