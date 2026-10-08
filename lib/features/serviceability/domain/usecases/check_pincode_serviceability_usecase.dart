import '../entities/serviceability_result.dart';
import '../indian_pincode.dart';
import '../repositories/serviceability_repository.dart';

class CheckPincodeServiceabilityUseCase {
  const CheckPincodeServiceabilityUseCase(this._repository);

  final ServiceabilityRepository _repository;

  Future<ServiceabilityResult> call(String rawPincode) async {
    final pincode = IndianPincode.normalize(rawPincode);
    if (pincode == null) {
      return ServiceabilityResult.invalidPincode(rawPincode.trim());
    }

    return _repository.checkPincode(pincode);
  }
}
