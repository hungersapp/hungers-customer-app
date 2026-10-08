import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/location/domain/discovery_location_kind.dart';
import 'package:customer_app/features/location/domain/entities/saved_address_book.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';

UserLocation _gps({String city = 'Coimbatore', String area = ''}) {
  return UserLocation(
    latitude: 11.0168,
    longitude: 76.9558,
    city: city,
    state: 'Tamil Nadu',
    area: area,
    updatedAt: DateTime(2026, 9, 1),
  );
}

UserLocation _complete({
  required double latitude,
  required double longitude,
  required String city,
  String area = '',
}) {
  return UserLocation(
    latitude: latitude,
    longitude: longitude,
    city: city,
    state: 'Tamil Nadu',
    pincode: '641001',
    doorNumber: '12',
    street: 'ABC Street',
    area: area,
    selectedByCustomer: true,
    updatedAt: DateTime(2026, 9, 1),
  );
}

void main() {
  test('live GPS default is labelled Current Location', () {
    final presentation = DiscoveryLocationPresentation.from(location: _gps());
    expect(presentation.kind, DiscoveryLocationKind.currentLocation);
    expect(presentation.title, 'Current Location');
    expect(presentation.subtitle, 'Coimbatore');
  });

  test('a searched area is labelled Selected Location, not a full address', () {
    final presentation = DiscoveryLocationPresentation.from(
      location: UserLocation(
        latitude: 10.0732,
        longitude: 78.7802,
        city: 'Karaikudi',
        state: 'Tamil Nadu',
        area: 'Karaikudi',
        selectedByCustomer: true,
        updatedAt: DateTime(2026, 9, 1),
      ),
    );
    expect(presentation.kind, DiscoveryLocationKind.selectedLocation);
    expect(presentation.title, 'Selected Location');
    expect(presentation.subtitle, contains('Karaikudi'));
  });

  test('complete HOME / WORK / OTHER slots use the saved slot label', () {
    final home = _complete(
      latitude: 11.0,
      longitude: 77.0,
      city: 'Coimbatore',
      area: 'RS Puram',
    );
    final work = _complete(latitude: 11.1, longitude: 77.1, city: 'Coimbatore');
    final other = _complete(
      latitude: 11.2,
      longitude: 77.2,
      city: 'Coimbatore',
    );
    final book = SavedAddressBook(home: home, work: work, other: other);

    expect(
      DiscoveryLocationPresentation.from(location: home, book: book).title,
      'Home',
    );
    expect(
      DiscoveryLocationPresentation.from(location: work, book: book).title,
      'Work',
    );
    expect(
      DiscoveryLocationPresentation.from(location: other, book: book).title,
      'Other',
    );
  });
}
