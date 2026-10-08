import '../repositories/location_repository.dart';

class SaveDeliveryPincodeUseCase {
  const SaveDeliveryPincodeUseCase(this._repository);

  final LocationRepository _repository;

  Future<void> call({required String userId, required String pincode}) {
    return _repository.saveDeliveryPincode(userId: userId, pincode: pincode);
  }
}
