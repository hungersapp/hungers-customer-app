import '../entities/user_location.dart';
import '../repositories/location_repository.dart';

/// Saves an address the customer explicitly selected in the address editor
/// (current location adjusted on the map, or a searched place, plus door and
/// street) as an EXPLICIT delivery destination: it stays the active location
/// until the customer changes it (LocationRefreshPolicy).
class SaveUserLocationUseCase {
  const SaveUserLocationUseCase(this._repository);

  final LocationRepository _repository;

  Future<void> call({
    required String userId,
    required UserLocation location,
    LocationSource source = LocationSource.manualSelection,
  }) {
    if (!location.isCompleteForCheckout) {
      throw StateError('Delivery address is incomplete.');
    }
    // The editor submits a complete address, so it is a full replacement:
    // blank fields the customer left empty must not resurrect the previous
    // address's area / pincode through the merge.
    return _repository.saveUserLocation(
      userId: userId,
      location: location.copyWith(
        updatedAt: DateTime.now(),
        selectedByCustomer: true,
        source: source.isCustomerSelected
            ? source
            : LocationSource.manualSelection,
      ),
      clearStaleAddressDetails: true,
    );
  }
}
