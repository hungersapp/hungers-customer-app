import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class GoogleSignInUseCase {
  const GoogleSignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call() {
    return _repository.signInWithGoogle();
  }
}
