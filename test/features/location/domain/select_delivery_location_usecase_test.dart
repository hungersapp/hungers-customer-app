import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/repositories/location_repository.dart';
import 'package:customer_app/features/location/domain/usecases/select_delivery_location_usecase.dart';

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

/// A place found by search or GPS: coordinates, city, state, pincode — and no
/// door or street, because the customer is only choosing where to browse.
UserLocation _place({
  double latitude = 13.0827,
  double longitude = 80.2707,
  String city = 'Chennai',
  String state = 'Tamil Nadu',
  String? pincode = '600001',
  String door = '',
  String street = '',
}) {
  return UserLocation(
    latitude: latitude,
    longitude: longitude,
    city: city,
    state: state,
    pincode: pincode,
    doorNumber: door,
    street: street,
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('saves the chosen place WITHOUT door or street, flagged as selected, '
      'as a full replacement', () async {
    final repository = _RecordingRepository();

    await SelectDeliveryLocationUseCase(repository)(
      userId: 'user-1',
      location: _place(),
    );

    expect(repository.saves, hasLength(1));
    final saved = repository.saves.single;
    expect(saved.location.selectedByCustomer, isTrue);
    expect(saved.location.city, 'Chennai');
    expect(saved.location.doorNumber, isEmpty);
    expect(saved.location.street, isEmpty);
    // Nothing from the previous location may survive the merge.
    expect(saved.clear, isTrue);
  });

  test('works for any place in India, not just one region', () async {
    final repository = _RecordingRepository();
    final useCase = SelectDeliveryLocationUseCase(repository);

    for (final place in [
      _place(city: 'Srinagar', state: 'Jammu and Kashmir', pincode: '190001'),
      _place(city: 'Guwahati', state: 'Assam', pincode: '781001'),
      _place(city: 'Kochi', state: 'Kerala', pincode: '682001'),
    ]) {
      await useCase(userId: 'user-1', location: place);
    }

    expect(repository.saves.map((s) => s.location.city), [
      'Srinagar',
      'Guwahati',
      'Kochi',
    ]);
  });

  test('stamps the time of the choice', () async {
    final repository = _RecordingRepository();

    await SelectDeliveryLocationUseCase(repository)(
      userId: 'user-1',
      location: _place(),
    );

    expect(
      repository.saves.single.location.updatedAt.isAfter(DateTime(2026, 1, 1)),
      isTrue,
    );
  });

  group('refuses a place discovery could not use — nothing is written', () {
    final invalid = <String, UserLocation>{
      'the (0,0) placeholder': _place(latitude: 0, longitude: 0),
      'latitude out of range': _place(latitude: 123),
      'longitude out of range': _place(longitude: 500),
      'no city': _place(city: ' '),
      'no state': _place(state: ''),
    };

    for (final entry in invalid.entries) {
      test(entry.key, () {
        final repository = _RecordingRepository();

        expect(
          () => SelectDeliveryLocationUseCase(repository)(
            userId: 'user-1',
            location: entry.value,
          ),
          throwsStateError,
        );
        expect(repository.saves, isEmpty);
      });
    }
  });

  group(
    'the pincode is metadata — never required, never a reason to refuse',
    () {
      test(
        'a place with NO pincode is saved (coordinates are what matter)',
        () async {
          final repository = _RecordingRepository();

          await SelectDeliveryLocationUseCase(repository)(
            userId: 'user-1',
            location: _place(pincode: null),
          );

          expect(repository.saves, hasLength(1));
          expect(repository.saves.single.location.pincode, isNull);
          expect(repository.saves.single.location.selectedByCustomer, isTrue);
        },
      );

      test('a well-formed pincode the geocoder found is kept', () async {
        final repository = _RecordingRepository();

        await SelectDeliveryLocationUseCase(repository)(
          userId: 'user-1',
          location: _place(pincode: ' 600001 '),
        );

        expect(repository.saves.single.location.pincode, '600001');
      });

      test(
        'a malformed pincode is dropped, not stored and not a refusal',
        () async {
          final repository = _RecordingRepository();

          await SelectDeliveryLocationUseCase(repository)(
            userId: 'user-1',
            location: _place(pincode: '6000'),
          );

          expect(repository.saves.single.location.pincode, isNull);
        },
      );
    },
  );

  test('door and street are passed through when the place still carries them '
      '(same spot re-confirmed)', () async {
    final repository = _RecordingRepository();

    await SelectDeliveryLocationUseCase(repository)(
      userId: 'user-1',
      location: _place(door: '12A', street: 'Main Road'),
    );

    expect(repository.saves.single.location.doorNumber, '12A');
    expect(repository.saves.single.location.selectedByCustomer, isTrue);
  });

  test(
    'followCurrentLocation writes GPS as the followable discovery default',
    () async {
      final repository = _RecordingRepository();

      await SelectDeliveryLocationUseCase(
        repository,
      ).followCurrentLocation(userId: 'user-1', location: _place());

      expect(repository.saves, hasLength(1));
      expect(repository.saves.single.location.selectedByCustomer, isFalse);
      expect(repository.saves.single.location.city, 'Chennai');
      expect(repository.saves.single.clear, isTrue);
    },
  );

  test('followCurrentLocation refuses an unusable GPS reading', () {
    final repository = _RecordingRepository();

    expect(
      () => SelectDeliveryLocationUseCase(repository).followCurrentLocation(
        userId: 'user-1',
        location: _place(latitude: 0, longitude: 0),
      ),
      throwsStateError,
    );
    expect(repository.saves, isEmpty);
  });
}
