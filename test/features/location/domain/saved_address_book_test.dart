import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/location/domain/entities/saved_address_book.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/repositories/saved_address_repository.dart';

class _MemorySavedAddresses implements SavedAddressRepository {
  SavedAddressBook book = const SavedAddressBook();

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

UserLocation _loc(String city) {
  return UserLocation(
    latitude: 9.92,
    longitude: 78.11,
    city: city,
    state: 'TN',
    updatedAt: DateTime(2026, 9, 24),
    pincode: '625001',
    selectedByCustomer: true,
  );
}

void main() {
  test('home, work, and other slots persist independently', () async {
    final repo = _MemorySavedAddresses();
    await repo.saveAddress(
      userId: 'u1',
      slot: SavedAddressSlot.home,
      location: _loc('Madurai'),
    );
    await repo.saveAddress(
      userId: 'u1',
      slot: SavedAddressSlot.work,
      location: _loc('Chennai'),
    );
    await repo.saveAddress(
      userId: 'u1',
      slot: SavedAddressSlot.other,
      location: _loc('Salem'),
    );

    final book = await repo.getSavedAddresses('u1');
    expect(book.home?.city, 'Madurai');
    expect(book.work?.city, 'Chennai');
    expect(book.other?.city, 'Salem');

    await repo.deleteAddress(userId: 'u1', slot: SavedAddressSlot.work);
    final after = await repo.getSavedAddresses('u1');
    expect(after.work, isNull);
    expect(after.home?.city, 'Madurai');
  });

  test('matchingSlot finds HOME / WORK / OTHER by stored coordinates', () {
    final home = _loc('Madurai').copyWith(latitude: 9.92, longitude: 78.11);
    final work = _loc('Chennai').copyWith(latitude: 13.08, longitude: 80.27);
    final other = _loc('Salem').copyWith(latitude: 11.65, longitude: 78.16);
    final book = SavedAddressBook(home: home, work: work, other: other);

    expect(book.matchingSlot(home), SavedAddressSlot.home);
    expect(book.matchingSlot(work), SavedAddressSlot.work);
    expect(book.matchingSlot(other), SavedAddressSlot.other);
    expect(
      book.matchingSlot(
        _loc('Karaikudi').copyWith(latitude: 10.07, longitude: 78.78),
      ),
      isNull,
    );
  });
}
