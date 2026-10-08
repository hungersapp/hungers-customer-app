import '../../../location/data/services/device_location_service.dart';
import '../../../location/domain/exceptions/location_exception.dart';
import '../../../serviceability/domain/location_serviceability_decision.dart';
import '../../../serviceability/domain/repositories/serviceability_repository.dart';
import '../../../serviceability/domain/serviceability_read_exception.dart';
import '../entities/auth_user.dart';
import '../new_customer_registration_result.dart';
import '../repositories/auth_repository.dart';
import '../zone_gate_diagnostics.dart';

/// Fail-closed new-customer gate: GPS + active zone radius, then profile create.
class RegisterNewCustomerIfServiceableUseCase {
  const RegisterNewCustomerIfServiceableUseCase({
    required this.authRepository,
    required this.serviceabilityRepository,
    required this.deviceLocationService,
  });

  final AuthRepository authRepository;
  final ServiceabilityRepository serviceabilityRepository;
  final DeviceLocationService deviceLocationService;

  Future<NewCustomerRegistrationResult> call(AuthUser user) async {
    final existing = await authRepository.getCustomerProfile(user.uid);
    if (existing != null) {
      return const NewCustomerRegistrationResult(
        status: NewCustomerRegistrationStatus.existingCustomer,
        profileCreated: false,
      );
    }

    late final ({double latitude, double longitude}) coordinates;
    try {
      await deviceLocationService.ensurePermission();
      coordinates = await deviceLocationService.getCurrentCoordinates();
    } on LocationPermissionPermanentlyDeniedException {
      ZoneGateDiagnostics.log(ZoneGateDiagnostics.locationPermission);
      return const NewCustomerRegistrationResult(
        status: NewCustomerRegistrationStatus.locationPermissionDenied,
        profileCreated: false,
      );
    } on LocationPermissionDeniedException {
      ZoneGateDiagnostics.log(ZoneGateDiagnostics.locationPermission);
      return const NewCustomerRegistrationResult(
        status: NewCustomerRegistrationStatus.locationPermissionDenied,
        profileCreated: false,
      );
    } on LocationServiceDisabledException {
      ZoneGateDiagnostics.log(ZoneGateDiagnostics.locationServices);
      return const NewCustomerRegistrationResult(
        status: NewCustomerRegistrationStatus.locationServicesDisabled,
        profileCreated: false,
      );
    } on LocationPositionUnavailableException {
      ZoneGateDiagnostics.log(ZoneGateDiagnostics.locationFetch);
      return const NewCustomerRegistrationResult(
        status: NewCustomerRegistrationStatus.gpsUnavailable,
        profileCreated: false,
      );
    } catch (_) {
      ZoneGateDiagnostics.log(ZoneGateDiagnostics.locationFetch);
      return const NewCustomerRegistrationResult(
        status: NewCustomerRegistrationStatus.gpsUnavailable,
        profileCreated: false,
      );
    }

    try {
      final zones = await serviceabilityRepository.getActiveDeliveryZones();
      ZoneGateDiagnostics.log(ZoneGateDiagnostics.zoneCalculation);
      final outcome = LocationServiceabilityDecision.evaluate(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        zones: zones,
      );

      switch (outcome) {
        case LocationServiceabilityOutcome.insideActiveZone:
          await authRepository.createCustomerProfile(user);
          return const NewCustomerRegistrationResult(
            status: NewCustomerRegistrationStatus.created,
            profileCreated: true,
          );
        case LocationServiceabilityOutcome.outsideAllZones:
          return const NewCustomerRegistrationResult(
            status: NewCustomerRegistrationStatus.outsideZone,
            profileCreated: false,
          );
        case LocationServiceabilityOutcome.noActiveZones:
        case LocationServiceabilityOutcome.invalidCoordinates:
          return const NewCustomerRegistrationResult(
            status: NewCustomerRegistrationStatus.noActiveZones,
            profileCreated: false,
          );
      }
    } on ServiceabilityReadException {
      ZoneGateDiagnostics.log(ZoneGateDiagnostics.serviceabilityRead);
      return const NewCustomerRegistrationResult(
        status: NewCustomerRegistrationStatus.serviceabilityUnavailable,
        profileCreated: false,
      );
    } catch (_) {
      ZoneGateDiagnostics.log(ZoneGateDiagnostics.serviceabilityRead);
      return const NewCustomerRegistrationResult(
        status: NewCustomerRegistrationStatus.serviceabilityUnavailable,
        profileCreated: false,
      );
    }
  }
}
