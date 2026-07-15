import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call({
    required String email,
    required String password,
  }) {
    return _repository.login(
      email: email.trim(),
      password: password,
    );
  }
}
