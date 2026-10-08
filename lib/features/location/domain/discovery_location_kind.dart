import 'entities/saved_address_book.dart';
import 'entities/user_location.dart';

/// How the customer's discovery location should be described in the UI.
///
/// These are related but not the same thing:
///  * [currentLocation] — live GPS used as the default discovery point;
///  * [savedAddress] — a complete HOME / WORK / OTHER destination;
///  * [selectedLocation] — a searched area used to browse restaurants, which
///    may still need a complete delivery address before checkout.
enum DiscoveryLocationKind { currentLocation, savedAddress, selectedLocation }

/// Labels for the dashboard "Deliver To" row and checkout address card.
class DiscoveryLocationPresentation {
  const DiscoveryLocationPresentation({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.slot,
  });

  final DiscoveryLocationKind kind;
  final String title;
  final String subtitle;
  final SavedAddressSlot? slot;

  factory DiscoveryLocationPresentation.from({
    required UserLocation location,
    SavedAddressBook? book,
  }) {
    final slot = book?.matchingSlot(location);
    final saved = slot == null ? null : book![slot];
    if (slot != null && saved != null && saved.isCompleteForCheckout) {
      final firstLine = location.checkoutDisplayBlock.split('\n').first.trim();
      return DiscoveryLocationPresentation(
        kind: DiscoveryLocationKind.savedAddress,
        title: slot.label,
        subtitle: firstLine.isNotEmpty ? firstLine : location.displayAddress,
        slot: slot,
      );
    }
    if (location.isLiveGpsDefault) {
      return DiscoveryLocationPresentation(
        kind: DiscoveryLocationKind.currentLocation,
        title: 'Current Location',
        subtitle: location.city.trim().isNotEmpty
            ? location.city.trim()
            : location.displayAddress,
      );
    }
    final areaOrCity = [
      if (location.area.trim().isNotEmpty) location.area.trim(),
      location.city.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    return DiscoveryLocationPresentation(
      kind: DiscoveryLocationKind.selectedLocation,
      title: 'Selected Location',
      subtitle: areaOrCity.isNotEmpty ? areaOrCity : location.displayAddress,
    );
  }
}
