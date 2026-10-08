import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class CreateCustomerProfileUseCase {
  const CreateCustomerProfileUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(AuthUser user) {
    return _repository.createCustomerProfile(user);
  }
}
