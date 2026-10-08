import '../entities/saved_address_book.dart';
import '../entities/user_location.dart';

abstract class SavedAddressRepository {
  Future<SavedAddressBook> getSavedAddresses(String userId);

  Future<void> saveAddress({
    required String userId,
    required SavedAddressSlot slot,
    required UserLocation location,
  });

  Future<void> deleteAddress({
    required String userId,
    required SavedAddressSlot slot,
  });
}
