import '../entities/user_location.dart';
import '../repositories/location_repository.dart';

class GetUserLocationUseCase {
  const GetUserLocationUseCase(this._repository);

  final LocationRepository _repository;

  Future<UserLocation?> call(String userId) {
    return _repository.getUserLocation(userId);
  }
}
