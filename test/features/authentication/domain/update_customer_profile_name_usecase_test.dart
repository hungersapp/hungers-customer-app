import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/domain/customer_profile_name.dart';
import 'package:customer_app/features/authentication/domain/entities/auth_user.dart';
import 'package:customer_app/features/authentication/domain/phone_otp_session.dart';
import 'package:customer_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:customer_app/features/authentication/domain/usecases/update_customer_profile_name_usecase.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.profile, this.writeError});

  AuthUser? profile;
  Object? writeError;
  String? lastSavedName;
  int writeCalls = 0;

  @override
  Future<AuthUser?> getCustomerProfile(String userId) async => profile;

  @override
  Future<AuthUser?> getCurrentUser() async => profile;

  @override
  Future<void> updateCustomerProfileName({
    required String userId,
    required String name,
  }) async {
    writeCalls += 1;
    lastSavedName = name;
    if (writeError != null) {
      throw writeError!;
    }
    final current = profile;
    profile =
        (current ??
                AuthUser(uid: userId, emailVerified: false, isAnonymous: false))
            .copyWith(name: name);
  }

  @override
  Future<void> createCustomerProfile(AuthUser user) async {}

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
}

void main() {
  const existing = AuthUser(
    uid: 'user-1',
    name: 'Old Name',
    mobileNumber: '+919876543210',
    emailVerified: false,
    isAnonymous: false,
  );

  test('valid name is written and the refreshed profile is returned', () async {
    final repository = _FakeAuthRepository(profile: existing);
    final updated = await UpdateCustomerProfileNameUseCase(repository)(
      userId: 'user-1',
      name: '  Priya   Kumar  ',
    );

    expect(repository.writeCalls, 1);
    expect(repository.lastSavedName, 'Priya Kumar');
    expect(updated.name, 'Priya Kumar');
    expect(repository.profile?.name, 'Priya Kumar');
  });

  test('empty name is rejected before any Firestore write', () async {
    final repository = _FakeAuthRepository(profile: existing);

    expect(
      () => UpdateCustomerProfileNameUseCase(repository)(
        userId: 'user-1',
        name: '   ',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(repository.writeCalls, 0);
  });

  test('Firestore failure is not swallowed', () async {
    final repository = _FakeAuthRepository(
      profile: existing,
      writeError: Exception('permission-denied'),
    );

    expect(
      () => UpdateCustomerProfileNameUseCase(repository)(
        userId: 'user-1',
        name: 'Priya Kumar',
      ),
      throwsA(isA<Exception>()),
    );
    expect(repository.writeCalls, 1);
  });

  test('CustomerProfileName validation matches the save rules', () {
    expect(CustomerProfileName.validate(''), 'Enter your name.');
    expect(CustomerProfileName.validate('A'), isNotNull);
    expect(CustomerProfileName.validate('Priya Kumar'), isNull);
  });
}
