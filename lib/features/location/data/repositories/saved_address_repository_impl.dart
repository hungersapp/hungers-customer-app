import '../../domain/entities/saved_address_book.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/repositories/saved_address_repository.dart';
import '../datasources/location_firestore_datasource.dart';
import '../models/user_location_model.dart';

class SavedAddressRepositoryImpl implements SavedAddressRepository {
  const SavedAddressRepositoryImpl(this._datasource);

  final LocationFirestoreDatasource _datasource;

  @override
  Future<SavedAddressBook> getSavedAddresses(String userId) async {
    final map = await _datasource.getSavedAddresses(userId);
    return SavedAddressBook(
      home: map[SavedAddressSlot.home.firestoreKey],
      work: map[SavedAddressSlot.work.firestoreKey],
      other: map[SavedAddressSlot.other.firestoreKey],
    );
  }

  @override
  Future<void> saveAddress({
    required String userId,
    required SavedAddressSlot slot,
    required UserLocation location,
  }) {
    return _datasource.saveSavedAddress(
      userId: userId,
      slot: slot.firestoreKey,
      location: UserLocationModel.fromEntity(location),
    );
  }

  @override
  Future<void> deleteAddress({
    required String userId,
    required SavedAddressSlot slot,
  }) {
    return _datasource.deleteSavedAddress(
      userId: userId,
      slot: slot.firestoreKey,
    );
  }
}
