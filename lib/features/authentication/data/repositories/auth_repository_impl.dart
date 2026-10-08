import '../../domain/entities/auth_user.dart';
import '../../domain/phone_otp_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasource/firebase_auth_datasource.dart';
import '../datasources/customer_profile_firestore_datasource.dart';
import '../models/auth_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._datasource, {
    this._profileDatasource,
  });

  final FirebaseAuthDatasource _datasource;
  final CustomerProfileFirestoreDatasource? _profileDatasource;

  @override
  Future<AuthUser?> getCurrentUser() {
    return _datasource.getCurrentUser();
  }

  @override
  Future<PhoneOtpSession> sendPhoneOtp({
    required String phoneE164,
    bool resend = false,
  }) {
    return _datasource.sendPhoneOtp(
      phoneE164: phoneE164,
      resend: resend,
    );
  }

  @override
  Future<AuthUser> verifyPhoneOtp({
    required String smsCode,
  }) {
    return _datasource.verifyPhoneOtp(smsCode: smsCode);
  }

  @override
  Future<AuthUser?> getCustomerProfile(String userId) {
    final profiles = _profileDatasource;
    if (profiles == null) {
      return Future.value(null);
    }
    return profiles.getCustomerProfile(userId);
  }

  @override
  Future<void> createCustomerProfile(AuthUser user) {
    final profiles = _profileDatasource;
    if (profiles == null) {
      throw StateError('Customer profile datasource is not configured.');
    }
    return profiles.createCustomerProfile(AuthUserModel.fromEntity(user));
  }

  @override
  Future<void> updateCustomerProfileName({
    required String userId,
    required String name,
  }) {
    final profiles = _profileDatasource;
    if (profiles == null) {
      throw StateError('Customer profile datasource is not configured.');
    }
    return profiles.updateCustomerName(userId: userId, name: name);
  }

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) {
    return _datasource.login(
      email: email,
      password: password,
    );
  }

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String mobileNumber,
    required String password,
  }) {
    return _datasource.register(
      name: name,
      email: email,
      mobileNumber: mobileNumber,
      password: password,
    );
  }

  @override
  Future<AuthUser> signInWithGoogle() {
    return _datasource.signInWithGoogle();
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
  }) {
    return _datasource.sendPasswordResetEmail(
      email: email,
    );
  }

  @override
  Future<void> logout() {
    return _datasource.logout();
  }

  @override
  Future<void> deleteAccount() {
    return _datasource.deleteAccount();
  }
}
