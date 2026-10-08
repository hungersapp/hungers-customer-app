import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/domain/entities/auth_user.dart';
import 'package:customer_app/features/authentication/domain/new_customer_registration_result.dart';
import 'package:customer_app/features/authentication/domain/phone_otp_session.dart';
import 'package:customer_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:customer_app/features/authentication/domain/usecases/register_new_customer_if_serviceable_usecase.dart';
import 'package:customer_app/features/location/data/services/device_location_service.dart';
import 'package:customer_app/features/location/domain/exceptions/location_exception.dart';
import 'package:customer_app/features/serviceability/domain/entities/active_delivery_zone.dart';
import 'package:customer_app/features/serviceability/domain/entities/serviceability_result.dart';
import 'package:customer_app/features/serviceability/domain/repositories/serviceability_repository.dart';
import 'package:customer_app/features/serviceability/domain/serviceability_read_exception.dart';

const _user = AuthUser(
  uid: 'new-1',
  mobileNumber: '+919876543210',
  emailVerified: false,
  isAnonymous: false,
);

const _zone = ActiveDeliveryZone(
  id: 'zone-1',
  centerLatitude: 9.9252,
  centerLongitude: 78.1198,
  radiusKm: 8,
  isActive: true,
);

class _FakeAuthRepository implements AuthRepository {
  AuthUser? profile;
  int createCalls = 0;

  @override
  Future<AuthUser?> getCustomerProfile(String userId) async => profile;

  @override
  Future<void> createCustomerProfile(AuthUser user) async {
    createCalls += 1;
    profile = user;
  }

  @override
  Future<AuthUser?> getCurrentUser() async => _user;

  @override
  Future<PhoneOtpSession> sendPhoneOtp({
    required String phoneE164,
    bool resend = false,
  }) async => PhoneOtpSession(phoneE164: phoneE164);

  @override
  Future<AuthUser> verifyPhoneOtp({required String smsCode}) async => _user;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => _user;

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String mobileNumber,
    required String password,
  }) async => _user;

  @override
  Future<AuthUser> signInWithGoogle() async => _user;

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> updateCustomerProfileName({
    required String userId,
    required String name,
  }) async {}
}

class _FakeServiceabilityRepository implements ServiceabilityRepository {
  _FakeServiceabilityRepository({
    this.zones = const [_zone],
    this.throwOnLoad = false,
  });

  final List<ActiveDeliveryZone> zones;
  final bool throwOnLoad;

  @override
  Future<ServiceabilityResult> checkPincode(String pincode) async {
    return ServiceabilityResult.serviceable(pincode);
  }

  @override
  Future<List<ActiveDeliveryZone>> getActiveDeliveryZones() async {
    if (throwOnLoad) {
      throw const ServiceabilityReadException(permissionDenied: true);
    }
    return zones;
  }
}

class _FakeDeviceLocationService extends DeviceLocationService {
  _FakeDeviceLocationService({
    this.error,
    this.latitude = 9.9252,
    this.longitude = 78.1198,
  });

  final Object? error;
  final double latitude;
  final double longitude;

  @override
  Future<void> ensurePermission() async {
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<({double latitude, double longitude})> getCurrentCoordinates() async {
    if (error is LocationPositionUnavailableException) {
      throw error!;
    }
    return (latitude: latitude, longitude: longitude);
  }
}

RegisterNewCustomerIfServiceableUseCase _useCase({
  required _FakeAuthRepository auth,
  List<ActiveDeliveryZone> zones = const [_zone],
  bool throwOnLoad = false,
  Object? locationError,
  double latitude = 9.9252,
  double longitude = 78.1198,
}) {
  return RegisterNewCustomerIfServiceableUseCase(
    authRepository: auth,
    serviceabilityRepository: _FakeServiceabilityRepository(
      zones: zones,
      throwOnLoad: throwOnLoad,
    ),
    deviceLocationService: _FakeDeviceLocationService(
      error: locationError,
      latitude: latitude,
      longitude: longitude,
    ),
  );
}

void main() {
  test('existing customer is recognized and skips the zone gate', () async {
    final auth = _FakeAuthRepository()..profile = _user;
    final result = await _useCase(auth: auth)(_user);

    expect(result.status, NewCustomerRegistrationStatus.existingCustomer);
    expect(result.profileCreated, isFalse);
    expect(auth.createCalls, 0);
  });

  test('new customer inside an active zone creates the profile', () async {
    final auth = _FakeAuthRepository();
    final result = await _useCase(auth: auth)(_user);

    expect(result.status, NewCustomerRegistrationStatus.created);
    expect(result.profileCreated, isTrue);
    expect(auth.createCalls, 1);
  });

  test(
    'new unserviceable customer does not create the Customer profile',
    () async {
      final auth = _FakeAuthRepository();
      final result = await _useCase(
        auth: auth,
        latitude: 12.9716,
        longitude: 77.5946,
      )(_user);

      expect(result.status, NewCustomerRegistrationStatus.outsideZone);
      expect(result.profileCreated, isFalse);
      expect(auth.createCalls, 0);
      expect(auth.profile, isNull);
    },
  );

  test('inactive-only zones block profile creation', () async {
    final auth = _FakeAuthRepository();
    final result = await _useCase(
      auth: auth,
      zones: [_zone.copyWithInactive()],
    )(_user);

    expect(result.status, NewCustomerRegistrationStatus.noActiveZones);
    expect(result.profileCreated, isFalse);
    expect(auth.createCalls, 0);
  });

  test('no active zones blocks profile creation', () async {
    final auth = _FakeAuthRepository();
    final result = await _useCase(auth: auth, zones: const [])(_user);

    expect(result.status, NewCustomerRegistrationStatus.noActiveZones);
    expect(auth.createCalls, 0);
  });

  test('Firestore permission-denied is not treated as a GPS failure', () async {
    final auth = _FakeAuthRepository();
    final result = await _useCase(auth: auth, throwOnLoad: true)(_user);

    expect(
      result.status,
      NewCustomerRegistrationStatus.serviceabilityUnavailable,
    );
    expect(
      result.status,
      isNot(NewCustomerRegistrationStatus.locationPermissionDenied),
    );
    expect(auth.createCalls, 0);
  });

  test('location permission denied blocks profile creation', () async {
    final auth = _FakeAuthRepository();
    final result = await _useCase(
      auth: auth,
      locationError: const LocationPermissionDeniedException(),
    )(_user);

    expect(
      result.status,
      NewCustomerRegistrationStatus.locationPermissionDenied,
    );
    expect(auth.createCalls, 0);
  });

  test('GPS unavailable blocks profile creation', () async {
    final auth = _FakeAuthRepository();
    final result = await _useCase(
      auth: auth,
      locationError: const LocationPositionUnavailableException(),
    )(_user);

    expect(result.status, NewCustomerRegistrationStatus.gpsUnavailable);
    expect(auth.createCalls, 0);
  });

  test('location services disabled blocks profile creation', () async {
    final auth = _FakeAuthRepository();
    final result = await _useCase(
      auth: auth,
      locationError: const LocationServiceDisabledException(),
    )(_user);

    expect(
      result.status,
      NewCustomerRegistrationStatus.locationServicesDisabled,
    );
    expect(auth.createCalls, 0);
  });
}

extension on ActiveDeliveryZone {
  ActiveDeliveryZone copyWithInactive() {
    return ActiveDeliveryZone(
      id: id,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      radiusKm: radiusKm,
      isActive: false,
    );
  }
}
