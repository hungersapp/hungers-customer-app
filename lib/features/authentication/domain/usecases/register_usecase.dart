import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  const RegisterUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call({
    required String name,
    required String email,
    required String mobileNumber,
    required String password,
  }) {
    return _repository.register(
      name: name.trim(),
      email: email.trim(),
      mobileNumber: mobileNumber.trim(),
      password: password,
    );
  }
}
