import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasource/firebase_auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._datasource);

  final FirebaseAuthDatasource _datasource;

  @override
  Future<AuthUser?> getCurrentUser() {
    return _datasource.getCurrentUser();
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
