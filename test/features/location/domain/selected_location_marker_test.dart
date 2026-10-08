import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/location/data/models/user_location_model.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/location_refresh_policy.dart';

UserLocation _place(
  String city, {
  bool selected = false,
  String door = '',
  String street = '',
  double latitude = 9.9252,
  double longitude = 78.1198,
}) {
  return UserLocation(
    latitude: latitude,
    longitude: longitude,
    city: city,
    state: 'Tamil Nadu',
    pincode: '625001',
    doorNumber: door,
    street: street,
    selectedByCustomer: selected,
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  const policy = LocationRefreshPolicy();
  final gpsInChennai = _place('Chennai', latitude: 13.0827, longitude: 80.2707);

  group('what GPS may replace', () {
    test('a place chosen in the location selector (source recorded) is an '
        'explicit selection: GPS never replaces it', () {
      final chosen = _place(
        'Madurai',
        selected: true,
      ).copyWith(source: LocationSource.manualSelection);

      expect(policy.isManuallyEntered(chosen), isTrue);
      expect(chosen.isExplicitSelection, isTrue);
      expect(
        policy.shouldReplace(saved: chosen, current: _place('Madurai')),
        isFalse,
      );
      expect(
        policy.shouldReplace(saved: chosen, current: gpsInChennai),
        isFalse,
      );
    });

    test('an address saved before the source was recorded is LEGACY, marker '
        'or not: GPS may replace it', () {
      for (final legacy in [
        _place('Madurai', door: '12A', street: 'Main Road'),
        _place('Madurai', selected: true),
      ]) {
        expect(policy.isManuallyEntered(legacy), isTrue);
        expect(legacy.isExplicitSelection, isFalse);
        expect(legacy.isLegacyAddress, isTrue);
        expect(
          policy.shouldReplace(saved: legacy, current: gpsInChennai),
          isTrue,
        );
      }
    });

    test(
      'the GPS-derived default is NOT protected: it may follow the phone',
      () {
        final gpsDefault = _place('Madurai');

        expect(policy.isManuallyEntered(gpsDefault), isFalse);
        expect(
          policy.shouldReplace(saved: gpsDefault, current: gpsInChennai),
          isTrue,
        );
      },
    );

    test(
      'nothing saved yet → the first current-location default may be seeded',
      () {
        expect(
          policy.shouldReplace(saved: null, current: gpsInChennai),
          isTrue,
        );
      },
    );
  });

  group('the marker is persisted with the location', () {
    test('a chosen place writes selectedByCustomer: true', () {
      final map = UserLocationModel.fromEntity(
        _place('Madurai', selected: true),
      ).toMap();

      expect(map['selectedByCustomer'], isTrue);
    });

    test('a GPS default writes no marker in a normal write (merge keeps any '
        'existing one)', () {
      final map = UserLocationModel.fromEntity(_place('Madurai')).toMap();

      expect(map.containsKey('selectedByCustomer'), isFalse);
    });

    test('a full replacement writes the marker explicitly, so a merge cannot '
        'leave the previous place\'s flag behind', () {
      final asDefault = UserLocationModel.fromEntity(
        _place('Madurai'),
      ).toMap(clearStaleAddressDetails: true);
      final asChosen = UserLocationModel.fromEntity(
        _place('Madurai', selected: true),
      ).toMap(clearStaleAddressDetails: true);

      expect(asDefault['selectedByCustomer'], isFalse);
      expect(asChosen['selectedByCustomer'], isTrue);
    });

    test('reads the marker back; a document without it is not selected', () {
      Map<String, dynamic> stored({Object? marker}) => {
        'latitude': 9.9,
        'longitude': 78.1,
        'city': 'Madurai',
        'state': 'Tamil Nadu',
        'pincode': '625001',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'selectedByCustomer': ?marker,
      };

      expect(
        UserLocationModel.fromMap(stored(marker: true)).selectedByCustomer,
        isTrue,
      );
      expect(
        UserLocationModel.fromMap(stored(marker: false)).selectedByCustomer,
        isFalse,
      );
      expect(UserLocationModel.fromMap(stored()).selectedByCustomer, isFalse);
      expect(
        UserLocationModel.fromMap(stored(marker: 'yes')).selectedByCustomer,
        isFalse,
      );
    });
  });

  group('the source is persisted with the location', () {
    test('a chosen place writes its source', () {
      final map = UserLocationModel.fromEntity(
        _place(
          'Madurai',
          selected: true,
        ).copyWith(source: LocationSource.savedHome),
      ).toMap(clearStaleAddressDetails: true);

      expect(map['source'], 'SAVED_HOME');
      expect(map['selectedByCustomer'], isTrue);
    });

    test('a GPS replacement overwrites the previous source, so the old '
        'explicit intent cannot survive the merge', () {
      final map = UserLocationModel.fromEntity(
        _place('Chennai').copyWith(source: LocationSource.deviceGps),
      ).toMap(clearStaleAddressDetails: true);

      expect(map['source'], 'DEVICE_GPS');
      expect(map['selectedByCustomer'], isFalse);
    });

    test('a full replacement with no source writes it as null explicitly', () {
      final map = UserLocationModel.fromEntity(
        _place('Chennai'),
      ).toMap(clearStaleAddressDetails: true);

      expect(map.containsKey('source'), isTrue);
      expect(map['source'], isNull);
    });

    test('reads it back; unknown or missing values are null (legacy)', () {
      Map<String, dynamic> stored(Map<String, dynamic> extra) => {
        'latitude': 9.9,
        'longitude': 78.1,
        'city': 'Madurai',
        'state': 'Tamil Nadu',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        ...extra,
      };

      final work = UserLocationModel.fromMap(stored({'source': 'SAVED_WORK'}));
      expect(work.source, LocationSource.savedWork);
      expect(work.isExplicitSelection, isTrue);

      final legacy = UserLocationModel.fromMap(
        stored({'selectedByCustomer': true}),
      );
      expect(legacy.source, isNull);
      expect(legacy.isExplicitSelection, isFalse);
      expect(legacy.isLegacyAddress, isTrue);

      expect(
        UserLocationModel.fromMap(stored({'source': 'HOME'})).source,
        isNull,
      );
    });

    test('every source has a distinct stored value', () {
      expect(LocationSource.values.map((s) => s.firestoreValue).toSet(), {
        'DEVICE_GPS',
        'MANUAL_SELECTION',
        'SAVED_HOME',
        'SAVED_WORK',
        'OTHER_SAVED_ADDRESS',
      });
      expect(LocationSource.deviceGps.isCustomerSelected, isFalse);
      expect(LocationSource.savedHome.isCustomerSelected, isTrue);
    });
  });

  group('isCompleteForDiscovery needs a place, not a full address', () {
    test('a chosen place without door / street is complete for discovery but '
        'not for checkout', () {
      final place = _place('Madurai', selected: true);

      expect(place.isCompleteForDiscovery, isTrue);
      expect(place.isCompleteForCheckout, isFalse);
    });

    test('unusable coordinates are not', () {
      expect(
        _place('X', latitude: 0, longitude: 0).isCompleteForDiscovery,
        isFalse,
      );
      expect(_place('X', latitude: 95).isCompleteForDiscovery, isFalse);
      expect(_place('X', longitude: 500).isCompleteForDiscovery, isFalse);
    });

    test('a missing pincode does not matter — it is only metadata', () {
      final place = _place('Madurai').copyWith(clearPincode: true);

      expect(place.pincode, isNull);
      expect(place.isCompleteForDiscovery, isTrue);
    });
  });
}
