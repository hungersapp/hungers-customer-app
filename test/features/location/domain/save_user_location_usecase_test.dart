import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/repositories/location_repository.dart';
import 'package:customer_app/features/location/domain/usecases/save_user_location_usecase.dart';

class _RecordingRepository implements LocationRepository {
  final List<({UserLocation location, bool clear})> saves = [];

  @override
  Future<void> saveUserLocation({
    required String userId,
    required UserLocation location,
    bool clearStaleAddressDetails = false,
  }) async {
    saves.add((location: location, clear: clearStaleAddressDetails));
  }

  @override
  Future<UserLocation?> getUserLocation(String userId) async => null;

  @override
  Future<String?> getDeliveryPincode(String userId) async => null;

  @override
  Future<void> saveDeliveryPincode({
    required String userId,
    required String pincode,
  }) async {}
}

UserLocation _location({String door = '12A', String street = 'Main Road'}) {
  return UserLocation(
    latitude: 9.9252,
    longitude: 78.1198,
    city: 'Madurai',
    state: 'Tamil Nadu',
    pincode: '625001',
    doorNumber: door,
    street: street,
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test(
    'saves the selected address as a full replacement (no stale fields)',
    () async {
      final repository = _RecordingRepository();

      await SaveUserLocationUseCase(repository)(
        userId: 'user-1',
        location: _location(),
      );

      expect(repository.saves, hasLength(1));
      // Merge-write must blank whatever the previous address left behind.
      expect(repository.saves.single.clear, isTrue);
      expect(repository.saves.single.location.doorNumber, '12A');
      expect(repository.saves.single.location.city, 'Madurai');
    },
  );

  test('stamps the save time', () async {
    final repository = _RecordingRepository();

    await SaveUserLocationUseCase(repository)(
      userId: 'user-1',
      location: _location(),
    );

    expect(
      repository.saves.single.location.updatedAt.isAfter(DateTime(2026, 1, 1)),
      isTrue,
    );
  });

  test(
    'rejects an address without door / street — nothing is written',
    () async {
      final repository = _RecordingRepository();
      final useCase = SaveUserLocationUseCase(repository);

      expect(
        () => useCase(
          userId: 'user-1',
          location: _location(door: '', street: ''),
        ),
        throwsStateError,
      );
      expect(repository.saves, isEmpty);
    },
  );
}
