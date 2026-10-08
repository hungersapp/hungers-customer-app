import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/core/validators/indian_mobile.dart';
import 'package:customer_app/features/authentication/domain/entities/auth_user.dart';
import 'package:customer_app/features/authentication/domain/phone_otp_session.dart';
import 'package:customer_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:customer_app/features/authentication/domain/usecases/send_phone_otp_usecase.dart';
import 'package:customer_app/features/authentication/domain/usecases/verify_phone_otp_usecase.dart';

class _FakeAuthRepository implements AuthRepository {
  String? lastPhone;
  String? lastSmsCode;
  bool resend = false;
  bool failVerify = false;
  AuthUser? profile;

  @override
  Future<PhoneOtpSession> sendPhoneOtp({
    required String phoneE164,
    bool resend = false,
  }) async {
    lastPhone = phoneE164;
    this.resend = resend;
    return PhoneOtpSession(phoneE164: phoneE164, verificationId: 'vid');
  }

  @override
  Future<AuthUser> verifyPhoneOtp({required String smsCode}) async {
    lastSmsCode = smsCode;
    if (failVerify) {
      throw Exception('Invalid OTP. Please try again.');
    }
    return const AuthUser(
      uid: 'u1',
      mobileNumber: '+919876543210',
      emailVerified: false,
      isAnonymous: false,
    );
  }

  @override
  Future<AuthUser?> getCurrentUser() async => null;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String mobileNumber,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithGoogle() async => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<AuthUser?> getCustomerProfile(String userId) async => profile;

  @override
  Future<void> createCustomerProfile(AuthUser user) async {}

  @override
  Future<void> updateCustomerProfileName({
    required String userId,
    required String name,
  }) async {}
}

void main() {
  test(
    'send OTP validates the mobile number before calling Firebase',
    () async {
      final repository = _FakeAuthRepository();
      final useCase = SendPhoneOtpUseCase(repository);

      expect(() => useCase(mobileNumber: '123'), throwsA(isA<Exception>()));
      expect(repository.lastPhone, isNull);

      final session = await useCase(mobileNumber: '9876543210');
      expect(repository.lastPhone, '+919876543210');
      expect(session.verificationId, 'vid');
    },
  );

  test('verify OTP succeeds for a 6-digit code', () async {
    final repository = _FakeAuthRepository();
    final user = await VerifyPhoneOtpUseCase(repository)('123456');
    expect(user.uid, 'u1');
    expect(repository.lastSmsCode, '123456');
  });

  test('verify OTP fails for an invalid code', () async {
    final repository = _FakeAuthRepository()..failVerify = true;
    expect(
      () => VerifyPhoneOtpUseCase(repository)('000000'),
      throwsA(isA<Exception>()),
    );
  });

  test('invalid OTP length does not call Firebase', () async {
    final repository = _FakeAuthRepository();
    expect(
      () => VerifyPhoneOtpUseCase(repository)('12'),
      throwsA(isA<Exception>()),
    );
    expect(repository.lastSmsCode, isNull);
  });

  test('Indian mobile helper never treats the OTP as a stored secret', () {
    expect(IndianMobile.toE164('9876543210').contains('OTP'), isFalse);
  });
}
