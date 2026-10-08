import '../entities/auth_user.dart';
import '../phone_otp_session.dart';

abstract class AuthRepository {

  /// Current Logged In User
  Future<AuthUser?> getCurrentUser();

  /// Sends a Firebase Phone Auth OTP. Does not store the OTP.
  Future<PhoneOtpSession> sendPhoneOtp({
    required String phoneE164,
    bool resend = false,
  });

  /// Completes Phone Auth with the SMS code entered by the customer.
  Future<AuthUser> verifyPhoneOtp({
    required String smsCode,
  });

  /// Existing `users/{uid}` customer profile, if any.
  Future<AuthUser?> getCustomerProfile(String userId);

  /// Creates the customer profile after the new-user zone gate passes.
  Future<void> createCustomerProfile(AuthUser user);

  /// Updates `users/{uid}.name` for the authenticated customer.
  Future<void> updateCustomerProfileName({
    required String userId,
    required String name,
  });

  /// Email & Password Login
  Future<AuthUser> login({
    required String email,
    required String password,
  });

  /// Register New User
  Future<AuthUser> register({
    required String name,
    required String email,
    required String mobileNumber,
    required String password,
  });

  /// Google Sign In
  Future<AuthUser> signInWithGoogle();

  /// Send Password Reset Email
  Future<void> sendPasswordResetEmail({
    required String email,
  });

  /// Logout
  Future<void> logout();

  /// Delete Account (Future Use)
  Future<void> deleteAccount();
}