import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/active_delivery_zone.dart';
import '../../domain/entities/serviceability_result.dart';
import '../../domain/repositories/serviceability_repository.dart';
import '../../domain/serviceability_read_exception.dart';
import '../datasources/serviceability_functions_datasource.dart';
import '../datasources/serviceability_zones_firestore_datasource.dart';

class ServiceabilityRepositoryImpl implements ServiceabilityRepository {
  const ServiceabilityRepositoryImpl(
    this._datasource, {
    this._zonesDatasource,
  });

  final ServiceabilityFunctionsDatasource _datasource;
  final ServiceabilityZonesFirestoreDatasource? _zonesDatasource;

  @override
  Future<ServiceabilityResult> checkPincode(String pincode) async {
    try {
      final serviceable = await _datasource.checkPincode(pincode);
      if (serviceable) {
        return ServiceabilityResult.serviceable(pincode);
      }
      return ServiceabilityResult.notServiceable(pincode);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'invalid-argument') {
        return ServiceabilityResult.invalidPincode(pincode);
      }
      return ServiceabilityResult.unavailable(pincode);
    } catch (_) {
      return ServiceabilityResult.unavailable(pincode);
    }
  }

  @override
  Future<List<ActiveDeliveryZone>> getActiveDeliveryZones() async {
    final zones = _zonesDatasource;
    if (zones == null) {
      throw const ServiceabilityReadException();
    }
    try {
      return await zones.getActiveDeliveryZones();
    } catch (error) {
      throw mapZoneReadFailure(error);
    }
  }
}

ServiceabilityReadException mapZoneReadFailure(Object error) {
  if (error is FirebaseException) {
    return ServiceabilityReadException(
      permissionDenied: error.code == 'permission-denied',
    );
  }
  return const ServiceabilityReadException();
}
