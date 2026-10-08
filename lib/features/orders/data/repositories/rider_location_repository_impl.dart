import '../../domain/entities/rider_location.dart';
import '../../domain/repositories/rider_location_repository.dart';
import '../datasources/rider_location_firestore_datasource.dart';

class RiderLocationRepositoryImpl implements RiderLocationRepository {
  const RiderLocationRepositoryImpl(this._datasource);

  final RiderLocationFirestoreDatasource _datasource;

  @override
  Stream<DeliveryJobRiderTracking?> watchByOrderId(String orderId) async* {
    try {
      yield* _datasource.watchByOrderId(orderId);
    } catch (_) {
      yield null;
    }
  }
}
