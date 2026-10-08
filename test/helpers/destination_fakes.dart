import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' show pumpEventQueue;

import 'package:customer_app/features/location/data/services/device_location_service.dart';
import 'package:customer_app/features/location/domain/entities/saved_address_book.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/repositories/location_repository.dart';
import 'package:customer_app/features/location/domain/repositories/saved_address_repository.dart';
import 'package:customer_app/features/serviceability/domain/entities/active_delivery_zone.dart';
import 'package:customer_app/features/serviceability/domain/entities/serviceability_result.dart';
import 'package:customer_app/features/serviceability/domain/repositories/serviceability_repository.dart';
import 'package:customer_app/features/serviceability/presentation/providers/destination_serviceability_provider.dart';

import 'discovery_fixtures.dart' show City;

/// Stands in for `users/{uid}.location`, the customer's delivery destination.
class FakeLocationRepository implements LocationRepository {
  FakeLocationRepository(this.stored);

  UserLocation? stored;

  /// Every destination write, so a test can prove GPS never wrote one.
  final List<UserLocation> saves = [];

  @override
  Future<UserLocation?> getUserLocation(String userId) async => stored;

  @override
  Future<void> saveUserLocation({
    required String userId,
    required UserLocation location,
    bool clearStaleAddressDetails = false,
  }) async {
    saves.add(location);
    stored = location;
  }

  @override
  Future<String?> getDeliveryPincode(String userId) async => stored?.pincode;

  @override
  Future<void> saveDeliveryPincode({
    required String userId,
    required String pincode,
  }) async {}
}

/// Stands in for the phone's GPS + reverse geocoding.
class FakeGps implements DeviceLocationService {
  FakeGps(this.location);

  UserLocation location;

  @override
  Future<UserLocation> getCurrentUserLocation() async => location;

  @override
  Future<void> ensurePermission() async {}

  @override
  Future<({double latitude, double longitude})> getCurrentCoordinates() =>
      throw UnimplementedError();

  @override
  Future<({String city, String state, String? pincode, String area})>
  reverseGeocode({required double latitude, required double longitude}) =>
      throw UnimplementedError();

  @override
  Future<List<UserLocation>> searchPlaces(String query) =>
      throw UnimplementedError();

  @override
  Future<UserLocation> searchArea(String query) => throw UnimplementedError();

  @override
  Stream<UserLocation> watchSignificantMoves({
    int distanceFilterMeters = 200,
  }) {
    watchStartCount += 1;
    return moves;
  }

  Stream<UserLocation> moves = const Stream.empty();
  int watchStartCount = 0;
}

/// In-memory HOME / WORK / OTHER slots.
class FakeSavedAddressRepository implements SavedAddressRepository {
  FakeSavedAddressRepository([this.book = const SavedAddressBook()]);

  SavedAddressBook book;

  @override
  Future<SavedAddressBook> getSavedAddresses(String userId) async => book;

  @override
  Future<void> saveAddress({
    required String userId,
    required SavedAddressSlot slot,
    required UserLocation location,
  }) async {
    book = switch (slot) {
      SavedAddressSlot.home => book.copyWith(home: location),
      SavedAddressSlot.work => book.copyWith(work: location),
      SavedAddressSlot.other => book.copyWith(other: location),
    };
  }

  @override
  Future<void> deleteAddress({
    required String userId,
    required SavedAddressSlot slot,
  }) async {
    book = switch (slot) {
      SavedAddressSlot.home => book.copyWith(clearHome: true),
      SavedAddressSlot.work => book.copyWith(clearWork: true),
      SavedAddressSlot.other => book.copyWith(clearOther: true),
    };
  }
}

/// One zone big enough to serve every place a test uses (the whole of India).
const ActiveDeliveryZone indiaWideZone = ActiveDeliveryZone(
  id: 'zone-india',
  centerLatitude: 22.0,
  centerLongitude: 79.0,
  radiusKm: 3500,
  isActive: true,
);

/// An active zone of [radiusKm] around [city] — a place Tukkito serves.
ActiveDeliveryZone zoneAround(City city, {double radiusKm = 50}) {
  return ActiveDeliveryZone(
    id: 'zone-${city.name.toLowerCase()}',
    centerLatitude: city.latitude,
    centerLongitude: city.longitude,
    radiusKm: radiusKm,
    isActive: true,
  );
}

/// Stands in for Tukkito's serviceability master data.
///
/// A location is served when its coordinates are inside one of [zones]
/// (default: everywhere in India). [readError] makes the zone read fail.
///
/// The customer app never decides serviceability from a pincode any more, so
/// [pincodeChecks] must stay 0 — tests assert that.
class FakeServiceabilityRepository implements ServiceabilityRepository {
  FakeServiceabilityRepository({
    List<ActiveDeliveryZone>? zones,
    this.readError,
  }) : zones = zones ?? const [indiaWideZone];

  final List<ActiveDeliveryZone> zones;
  final Object? readError;

  /// How many times the zones were read.
  int zoneReads = 0;

  /// How many times the pincode callable was asked. Discovery must not.
  int pincodeChecks = 0;

  @override
  Future<List<ActiveDeliveryZone>> getActiveDeliveryZones() async {
    zoneReads += 1;
    final error = readError;
    if (error != null) {
      throw error;
    }
    return zones;
  }

  @override
  Future<ServiceabilityResult> checkPincode(String pincode) async {
    pincodeChecks += 1;
    return ServiceabilityResult.serviceable(pincode);
  }
}

/// Lets the serviceability of the CURRENT location finish.
///
/// In the app it is worked out in the background and discovery follows when it
/// completes. A test that reads a discovery provider once would otherwise see
/// the "still checking" (empty) answer, so it settles that first.
Future<void> settleServiceability(ProviderContainer container) async {
  await container.read(destinationServiceabilityProvider.future);
  await pumpEventQueue();
}
