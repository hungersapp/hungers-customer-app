import '../entities/auth_user.dart';

abstract class AuthRepository {

  /// Current Logged In User
  Future<AuthUser?> getCurrentUser();

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