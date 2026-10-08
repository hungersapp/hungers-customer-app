import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';
import '../customer_profile_name.dart';

class UpdateCustomerProfileNameUseCase {
  const UpdateCustomerProfileNameUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call({
    required String userId,
    required String name,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      throw StateError('You must be signed in to save your name.');
    }
    final error = CustomerProfileName.validate(name);
    if (error != null) {
      throw ArgumentError(error);
    }
    final normalized = CustomerProfileName.normalize(name);
    await _repository.updateCustomerProfileName(
      userId: trimmedUserId,
      name: normalized,
    );
    final profile = await _repository.getCustomerProfile(trimmedUserId);
    if (profile != null) {
      return profile;
    }
    final session = await _repository.getCurrentUser();
    if (session != null && session.uid == trimmedUserId) {
      return session.copyWith(name: normalized);
    }
    throw StateError('Unable to load your profile after saving.');
  }
}
