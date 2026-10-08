import '../../../serviceability/domain/indian_pincode.dart';
import '../entities/user_location.dart';
import '../repositories/location_repository.dart';

/// Saves a discovery location chosen in the location chooser.
///
/// This is what restaurant discovery is based on, so it needs only what
/// discovery needs: usable coordinates, and a city and state to show. The
/// coordinates decide serviceability. A pincode is address metadata: kept when
/// the geocoder found a well-formed one, cleared otherwise, and never asked
/// of the customer. Door and street belong to placing an order and are
/// collected at checkout ([SaveUserLocationUseCase]).
///
/// A searched area or saved HOME / WORK / OTHER slot is flagged
/// [UserLocation.selectedByCustomer] and carries its [LocationSource], which
/// makes it an EXPLICIT selection: it stays the active location until the
/// customer changes it, and GPS never replaces it (LocationRefreshPolicy).
/// [followCurrentLocation] is the customer choosing the phone's own position:
/// it is written as [LocationSource.deviceGps], so it keeps following the
/// phone.
///
/// Either path is a full replacement: nothing from the previous location
/// (pincode, door, street, area) survives the merge and gets mixed with the
/// new coordinates.
class SelectDeliveryLocationUseCase {
  const SelectDeliveryLocationUseCase(this._repository);

  final LocationRepository _repository;

  /// [source] says what the customer picked (a searched / pinned place by
  /// default, or a saved address).
  Future<void> call({
    required String userId,
    required UserLocation location,
    LocationSource source = LocationSource.manualSelection,
  }) {
    assert(source.isCustomerSelected, 'Use followCurrentLocation for GPS.');
    return _save(userId: userId, location: location, source: source);
  }

  /// Pins restaurant discovery to the phone's current GPS without treating
  /// that pin as a customer-selected destination, so later meaningful GPS
  /// movement can still follow.
  Future<void> followCurrentLocation({
    required String userId,
    required UserLocation location,
  }) {
    return _save(
      userId: userId,
      location: location,
      source: LocationSource.deviceGps,
    );
  }

  Future<void> _save({
    required String userId,
    required UserLocation location,
    required LocationSource source,
  }) {
    if (!location.isCompleteForDiscovery) {
      throw StateError('Delivery location is incomplete.');
    }
    final pincode = IndianPincode.normalize(location.pincode ?? '');
    return _repository.saveUserLocation(
      userId: userId,
      location: location.copyWith(
        updatedAt: DateTime.now(),
        selectedByCustomer: source.isCustomerSelected,
        source: source,
        pincode: pincode,
        clearPincode: pincode == null,
      ),
      clearStaleAddressDetails: true,
    );
  }
}
