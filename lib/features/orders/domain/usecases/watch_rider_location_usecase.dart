import '../entities/rider_location.dart';
import '../repositories/rider_location_repository.dart';

class WatchRiderLocationUseCase {
  const WatchRiderLocationUseCase(this._repository);

  final RiderLocationRepository _repository;

  Stream<DeliveryJobRiderTracking?> call(String orderId) {
    if (orderId.trim().isEmpty) {
      return Stream<DeliveryJobRiderTracking?>.value(null);
    }
    return _repository.watchByOrderId(orderId);
  }
}
