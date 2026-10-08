import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class GetCustomerProfileUseCase {
  const GetCustomerProfileUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthUser?> call(String userId) {
    return _repository.getCustomerProfile(userId);
  }
}
