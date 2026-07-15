import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';


import '../models/auth_user_model.dart';

class FirebaseAuthDatasource {
  FirebaseAuthDatasource({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Future<AuthUserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    return _mapUser(user);
  }

  Future<AuthUserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return _mapUser(credential.user!);
    } on FirebaseAuthException catch (e) {
  debugPrint("========== FIREBASE LOGIN ERROR ==========");
  debugPrint("Code    : ${e.code}");
  debugPrint("Message : ${e.message}");
  debugPrint("=========================================");

  throw Exception(_firebaseError(e));
}
  }

  Future<AuthUserModel> register({
    required String name,
    required String email,
    required String password,
    required String mobileNumber,
  }) async {
    try {
      final credential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user!.updateDisplayName(name);
      await credential.user!.reload();

      return _mapUser(_firebaseAuth.currentUser!);
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    }
  }

  Future<AuthUserModel> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();

      final account = await _googleSignIn.authenticate();

      final authentication = account.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: authentication.idToken,
      );

      final result = await _firebaseAuth.signInWithCredential(
        credential,
      );

      return _mapUser(result.user!);
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    }
  }

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(
        email: email.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e));
    }
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;

    if (user != null) {
      await user.delete();
    }
  }

  AuthUserModel _mapUser(User user) {
    return AuthUserModel(
      uid: user.uid,
      name: user.displayName,
      email: user.email,
      mobileNumber: user.phoneNumber,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
    );
  }

  String _firebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'User not found';

      case 'wrong-password':
        return 'Invalid password';

      case 'invalid-email':
        return 'Invalid email address';

      case 'email-already-in-use':
        return 'Email already registered';

      case 'weak-password':
        return 'Password is too weak';

      case 'network-request-failed':
        return 'Please check your internet connection';

      default:
        return e.message ?? 'Authentication failed';
    }
  }
}