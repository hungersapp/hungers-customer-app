import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/location_refresh_policy.dart';

UserLocation _location({
  required String city,
  String state = 'Tamil Nadu',
  double latitude = 9.9195,
  double longitude = 78.1193,
  String doorNumber = '',
  String street = '',
  String? pincode = '625020',
  bool selectedByCustomer = false,
  LocationSource? source,
}) {
  return UserLocation(
    latitude: latitude,
    longitude: longitude,
    city: city,
    state: state,
    pincode: pincode,
    doorNumber: doorNumber,
    street: street,
    selectedByCustomer: selectedByCustomer,
    source: source,
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  const policy = LocationRefreshPolicy();

  final gpsInBengaluru = _location(
    city: 'Bengaluru',
    state: 'Karnataka',
    latitude: 12.9716,
    longitude: 77.5946,
    pincode: '560001',
  );

  /// Every GPS reading an explicit selection must survive: the same spot, a
  /// few hundred metres, across town, another city.
  final readings = <String, UserLocation>{
    'the same spot': _location(city: 'Madurai'),
    '~500 m away': _location(city: 'Madurai', latitude: 9.9240),
    '~1.2 km away': _location(
      city: 'Madurai',
      latitude: 9.93,
      longitude: 78.12,
    ),
    '~8 km away': _location(city: 'Madurai', latitude: 9.9915),
    'another city': gpsInBengaluru,
  };

  test('replaces when nothing is saved yet', () {
    expect(policy.shouldReplace(saved: null, current: gpsInBengaluru), isTrue);
  });

  group('selection intent', () {
    test('a searched place and saved Home / Work / Other are explicit', () {
      for (final source in [
        LocationSource.manualSelection,
        LocationSource.savedHome,
        LocationSource.savedWork,
        LocationSource.otherSavedAddress,
      ]) {
        final location = _location(city: 'Madurai', source: source);
        expect(location.selectionIntent, LocationSelectionIntent.explicit);
        expect(location.isExplicitSelection, isTrue);
        expect(location.isLegacyAddress, isFalse);
      }
    });

    test('the GPS location is implicit', () {
      final gps = _location(city: 'Madurai', source: LocationSource.deviceGps);
      expect(gps.selectionIntent, LocationSelectionIntent.implicit);
      expect(gps.isLegacyAddress, isFalse);
    });

    test('a location saved before the source was recorded is implicit, '
        'whatever address it holds', () {
      final legacyHome = _location(
        city: 'Madurai',
        doorNumber: '12A',
        street: 'Bypass Road',
        selectedByCustomer: true,
      );
      expect(legacyHome.selectionIntent, LocationSelectionIntent.implicit);
      expect(legacyHome.isExplicitSelection, isFalse);
      expect(legacyHome.isLegacyAddress, isTrue);

      final legacyGps = _location(city: 'Madurai');
      expect(legacyGps.selectionIntent, LocationSelectionIntent.implicit);
      expect(legacyGps.isLegacyAddress, isFalse);
    });
  });

  group('GPS NEVER replaces an explicit selection, at any distance', () {
    for (final source in [
      LocationSource.manualSelection,
      LocationSource.savedHome,
      LocationSource.savedWork,
      LocationSource.otherSavedAddress,
    ]) {
      for (final entry in readings.entries) {
        test('${source.firestoreValue} — phone at ${entry.key}', () {
          final selected = _location(
            city: 'Madurai',
            doorNumber: '12A',
            street: 'Bypass Road',
            selectedByCustomer: true,
            source: source,
          );
          expect(
            policy.shouldReplace(saved: selected, current: entry.value),
            isFalse,
          );
        });
      }
    }
  });

  group('GPS replaces an implicit / legacy location', () {
    // The production bug: an old Home address in Madurai stayed the active
    // location after the customer travelled to another city.
    test('a legacy Home address, phone in another city', () {
      final legacyHome = _location(
        city: 'Madurai',
        doorNumber: '12A',
        street: 'Bypass Road',
      );
      expect(
        policy.shouldReplace(saved: legacyHome, current: gpsInBengaluru),
        isTrue,
      );
      expect(
        policy.isSignificantChange(saved: legacyHome, current: gpsInBengaluru),
        isTrue,
      );
    });

    test('a legacy address gives way to ANY valid reading — even one taken at '
        'the address itself — so it is re-recorded as GPS', () {
      final legacyHome = _location(
        city: 'Madurai',
        doorNumber: '12A',
        street: 'Bypass Road',
        selectedByCustomer: true,
      );
      for (final current in readings.values) {
        expect(
          policy.shouldReplace(saved: legacyHome, current: current),
          isTrue,
        );
        expect(
          policy.isSignificantChange(saved: legacyHome, current: current),
          isTrue,
        );
      }
    });

    test('a GPS-derived location from another city', () {
      expect(
        policy.shouldReplace(
          saved: _location(city: 'Madurai', source: LocationSource.deviceGps),
          current: gpsInBengaluru,
        ),
        isTrue,
      );
    });

    test('a GPS-derived location in the same city (fresh coordinates)', () {
      expect(
        policy.shouldReplace(
          saved: _location(city: 'Madurai'),
          current: _location(city: 'Madurai', latitude: 9.93, longitude: 78.12),
        ),
        isTrue,
      );
    });
  });

  test(
    'distance plays no part in the decision: there is no travel threshold',
    () {
      final explicit = _location(
        city: 'Madurai',
        source: LocationSource.savedHome,
        selectedByCustomer: true,
      );
      final legacy = _location(city: 'Madurai', selectedByCustomer: true);
      for (final current in readings.values) {
        expect(
          policy.shouldReplace(saved: explicit, current: current),
          isFalse,
        );
        expect(policy.shouldReplace(saved: legacy, current: current), isTrue);
      }
    },
  );

  group('shouldClearStaleAddressDetails', () {
    test('never clears when nothing is saved yet', () {
      expect(
        policy.shouldClearStaleAddressDetails(
          saved: null,
          current: gpsInBengaluru,
        ),
        isFalse,
      );
    });

    test('clears when the city or state changes', () {
      expect(
        policy.shouldClearStaleAddressDetails(
          saved: _location(city: 'Madurai'),
          current: gpsInBengaluru,
        ),
        isTrue,
      );
      expect(
        policy.shouldClearStaleAddressDetails(
          saved: _location(city: 'Palani'),
          current: _location(city: 'Palani', state: 'Kerala'),
        ),
        isTrue,
      );
    });

    test('clears when GPS takes over from a legacy address, even in the same '
        'city (its door / street must not follow)', () {
      expect(
        policy.shouldClearStaleAddressDetails(
          saved: _location(
            city: 'Madurai',
            doorNumber: '12A',
            street: 'Bypass Road',
          ),
          current: _location(city: 'Madurai', latitude: 9.95),
        ),
        isTrue,
      );
    });

    test('keeps merging in the same city so a typed pincode survives', () {
      expect(
        policy.shouldClearStaleAddressDetails(
          saved: _location(city: 'Madurai', pincode: '625020'),
          current: _location(city: 'madurai', pincode: null),
        ),
        isFalse,
      );
    });
  });

  test('a GPS-only location is not treated as manually entered', () {
    expect(policy.isManuallyEntered(_location(city: 'Madurai')), isFalse);
  });

  group(
    'isSignificantChange (a GPS-derived location only follows real moves)',
    () {
      final saved = _location(
        city: 'Madurai',
        source: LocationSource.deviceGps,
      );

      test('another city is significant', () {
        expect(
          policy.isSignificantChange(saved: saved, current: gpsInBengaluru),
          isTrue,
        );
      });

      test('the very same reading is not significant', () {
        expect(
          policy.isSignificantChange(
            saved: saved,
            current: _location(city: 'Madurai'),
          ),
          isFalse,
        );
      });

      test('GPS drift of a few metres is not significant', () {
        expect(
          policy.isSignificantChange(
            saved: saved,
            // ~55 m north.
            current: _location(city: 'Madurai', latitude: 9.9200),
          ),
          isFalse,
        );
      });

      test('moving about a kilometre inside the same city is significant', () {
        expect(
          policy.isSignificantChange(
            saved: saved,
            current: _location(
              city: 'Madurai',
              latitude: 9.93,
              longitude: 78.12,
            ),
          ),
          isTrue,
        );
      });

      test('the same spot resolving to a different pincode is significant', () {
        expect(
          policy.isSignificantChange(
            saved: saved,
            current: _location(city: 'Madurai', pincode: '625001'),
          ),
          isTrue,
        );
      });

      test(
        'a reading with no postal code does not, by itself, change the pincode',
        () {
          expect(
            policy.isSignificantChange(
              saved: saved,
              current: _location(city: 'Madurai', pincode: null),
            ),
            isFalse,
          );
        },
      );
    },
  );
}
