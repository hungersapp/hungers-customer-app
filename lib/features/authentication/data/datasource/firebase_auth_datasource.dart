import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/phone_otp_session.dart';
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

  ConfirmationResult? _webConfirmation;
  String? _verificationId;
  int? _resendToken;

  Future<PhoneOtpSession> sendPhoneOtp({
    required String phoneE164,
    bool resend = false,
  }) async {

    if (kIsWeb) {
      _webConfirmation = await _firebaseAuth.signInWithPhoneNumber(phoneE164);
      return PhoneOtpSession(phoneE164: phoneE164);
    }

    final completer = Completer<PhoneOtpSession>();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      forceResendingToken: resend ? _resendToken : null,
      verificationCompleted: (credential) async {
        try {
          final result = await _firebaseAuth.signInWithCredential(credential);
          if (!completer.isCompleted) {
            completer.complete(
              PhoneOtpSession(
                phoneE164: phoneE164,
                autoVerifiedUser: _mapUser(result.user!),
              ),
            );
          }
        } on FirebaseAuthException catch (error) {
          if (!completer.isCompleted) {
            completer.completeError(Exception(_phoneAuthError(error)));
          }
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(_phoneAuthError(error)));
        }
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!completer.isCompleted) {
          completer.complete(
            PhoneOtpSession(
              phoneE164: phoneE164,
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );

    return completer.future;
  }

  Future<AuthUserModel> verifyPhoneOtp({
    required String smsCode,
  }) async {
    try {
      if (kIsWeb) {
        final confirmation = _webConfirmation;
        if (confirmation == null) {
          throw Exception('OTP session expired. Please request a new code.');
        }
        final result = await confirmation.confirm(smsCode);
        _webConfirmation = null;
        return _mapUser(result.user!);
      }

      final verificationId = _verificationId;
      if (verificationId == null || verificationId.isEmpty) {
        throw Exception('OTP session expired. Please request a new code.');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final result = await _firebaseAuth.signInWithCredential(credential);
      return _mapUser(result.user!);
    } on FirebaseAuthException catch (error) {
      throw Exception(_phoneAuthError(error));
    }
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

  String _phoneAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid mobile number.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return 'Invalid OTP. Please try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new code.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      default:
        return 'Unable to verify your mobile number. Please try again.';
    }
  }
}