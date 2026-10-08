import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/domain/entities/auth_user.dart';
import 'package:customer_app/features/authentication/domain/phone_otp_session.dart';
import 'package:customer_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:customer_app/features/authentication/domain/usecases/get_customer_profile_usecase.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.profile);

  final AuthUser? profile;

  @override
  Future<AuthUser?> getCustomerProfile(String userId) async => profile;

  @override
  Future<AuthUser?> getCurrentUser() async => null;

  @override
  Future<PhoneOtpSession> sendPhoneOtp({
    required String phoneE164,
    bool resend = false,
  }) async => PhoneOtpSession(phoneE164: phoneE164);

  @override
  Future<AuthUser> verifyPhoneOtp({required String smsCode}) async {
    throw UnimplementedError();
  }

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
  Future<void> createCustomerProfile(AuthUser user) async {}

  @override
  Future<void> updateCustomerProfileName({
    required String userId,
    required String name,
  }) async {}
}

void main() {
  const existing = AuthUser(
    uid: 'user-1',
    mobileNumber: '+919876543210',
    emailVerified: false,
    isAnonymous: false,
  );

  test('existing customer is recognized from Firestore profile', () async {
    final profile = await GetCustomerProfileUseCase(
      _FakeAuthRepository(existing),
    )('user-1');
    expect(profile, existing);
  });

  test('new customer has no Firestore profile', () async {
    final profile = await GetCustomerProfileUseCase(_FakeAuthRepository(null))(
      'user-2',
    );
    expect(profile, isNull);
  });
}
