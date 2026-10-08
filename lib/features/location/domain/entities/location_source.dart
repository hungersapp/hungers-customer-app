import 'saved_address_book.dart';

/// Whether the customer explicitly chose their active location.
enum LocationSelectionIntent {
  /// The customer picked this place. Only the customer changes it.
  explicit,

  /// GPS, or a legacy location nobody explicitly selected. GPS may replace it.
  implicit,
}

/// Where the customer's ACTIVE location came from.
///
/// The active location (`users/{uid}.location`) is the single source of truth
/// for serviceability, restaurant discovery, distance and delivery fee. Saved
/// HOME / WORK / OTHER addresses are only places the customer may pick — they
/// become the active location when (and only when) the customer selects one.
enum LocationSource {
  /// Read from the phone's GPS (app launch / resume / movement, or the
  /// customer tapping "Use Current Location").
  deviceGps('DEVICE_GPS'),

  /// A place the customer searched for or pinned on the map.
  manualSelection('MANUAL_SELECTION'),

  /// The saved Home address, explicitly selected.
  savedHome('SAVED_HOME'),

  /// The saved Work address, explicitly selected.
  savedWork('SAVED_WORK'),

  /// Another saved address, explicitly selected.
  otherSavedAddress('OTHER_SAVED_ADDRESS');

  const LocationSource(this.firestoreValue);

  /// The value stored in `users/{uid}.location.source`.
  final String firestoreValue;

  /// True for every source except [deviceGps]: the customer chose the place.
  bool get isCustomerSelected => this != LocationSource.deviceGps;

  static LocationSource? fromFirestore(Object? value) {
    for (final source in LocationSource.values) {
      if (source.firestoreValue == value) {
        return source;
      }
    }
    return null;
  }

  static LocationSource forSavedSlot(SavedAddressSlot slot) {
    switch (slot) {
      case SavedAddressSlot.home:
        return LocationSource.savedHome;
      case SavedAddressSlot.work:
        return LocationSource.savedWork;
      case SavedAddressSlot.other:
        return LocationSource.otherSavedAddress;
    }
  }
}
