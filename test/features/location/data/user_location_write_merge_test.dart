import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/location/data/models/user_location_model.dart';

import '../../../helpers/fake_user_location_document.dart';

void main() {
  group('UserLocationModel.toMap', () {
    final gpsWithoutPincode =
        FakeUserLocationDocument.chennaiGpsWithoutPincode();

    test('omits the optional address fields the location does not carry', () {
      final map = gpsWithoutPincode.toMap();

      expect(map.containsKey('pincode'), isFalse);
      expect(map.containsKey('doorNumber'), isFalse);
      expect(map.containsKey('street'), isFalse);
      expect(map.containsKey('area'), isFalse);
    });

    test(
      'clearStaleAddressDetails writes the omitted fields as explicit blanks',
      () {
        final map = gpsWithoutPincode.toMap(clearStaleAddressDetails: true);

        expect(map.containsKey('pincode'), isTrue);
        expect(map['pincode'], isNull);
        expect(map['doorNumber'], '');
        expect(map['street'], '');
        expect(map['area'], '');
        // The location itself is still written normally.
        expect(map['city'], 'Chennai');
        expect(map['latitude'], 13.0827);
      },
    );

    test('keeps writing present values when clearing stale details', () {
      final complete = UserLocationModel(
        latitude: 9.9195,
        longitude: 78.1193,
        city: 'Madurai',
        state: 'Tamil Nadu',
        pincode: '625001',
        doorNumber: '12A',
        street: 'Bypass Road',
        area: 'Vandiyur',
        updatedAt: DateTime(2026, 1, 1),
      );

      final map = complete.toMap(clearStaleAddressDetails: true);

      expect(map['pincode'], '625001');
      expect(map['doorNumber'], '12A');
      expect(map['street'], 'Bypass Road');
      expect(map['area'], 'Vandiyur');
    });
  });

  group('cross-city GPS refresh with no postal code', () {
    test(
      'a plain merge write retains the previous city pincode and door/street',
      () {
        final document = FakeUserLocationDocument.maduraiManualAddress();

        document.saveLocation(
          FakeUserLocationDocument.chennaiGpsWithoutPincode(),
        );

        // Documents exactly why the clearing flag is needed: the merge keeps
        // every key the payload omitted.
        final stored = document.getLocation()!;
        expect(stored.city, 'Chennai');
        expect(stored.pincode, '625001');
        expect(stored.doorNumber, '12A');
        expect(document.deliveryPincode, '625001');
      },
    );

    test('clearing stale details leaves no Madurai pincode behind', () {
      final document = FakeUserLocationDocument.maduraiManualAddress();

      document.saveLocation(
        FakeUserLocationDocument.chennaiGpsWithoutPincode(),
        clearStaleAddressDetails: true,
      );

      final stored = document.getLocation()!;
      expect(stored.city, 'Chennai');
      expect(stored.pincode, isNull);
      expect(stored.doorNumber, '');
      expect(stored.street, '');
      expect(stored.area, '');
      // Neither the nested field nor the top-level fallback may serve 625001.
      expect(document.rawLocationPincode, isNull);
      expect(document.deliveryPincode, isNull);
      // An incomplete address must not look checkout-ready.
      expect(stored.isCompleteForCheckout, isFalse);
    });

    test(
      'a GPS reading that does have a postal code overwrites the old one',
      () {
        final document = FakeUserLocationDocument.maduraiManualAddress();

        document.saveLocation(
          UserLocationModel(
            latitude: 13.0827,
            longitude: 80.2707,
            city: 'Chennai',
            state: 'Tamil Nadu',
            pincode: '600001',
            updatedAt: DateTime(2026, 2, 1),
          ),
          clearStaleAddressDetails: true,
        );

        expect(document.getLocation()!.pincode, '600001');
        expect(document.deliveryPincode, '600001');
      },
    );

    test(
      'a manually typed pincode still survives a same-city refresh (merge)',
      () {
        final document = FakeUserLocationDocument.maduraiManualAddress();
        document.saveDeliveryPincode('625020');

        // Same city: the refresh path keeps merging, so the typed pincode and
        // the manual door/street stay in place.
        document.saveLocation(
          UserLocationModel(
            latitude: 9.93,
            longitude: 78.12,
            city: 'Madurai',
            state: 'Tamil Nadu',
            updatedAt: DateTime(2026, 2, 1),
          ),
        );

        final stored = document.getLocation()!;
        expect(stored.pincode, '625020');
        expect(stored.doorNumber, '12A');
        expect(document.deliveryPincode, '625020');
      },
    );
  });
}
