import '../../serviceability/domain/geo_distance.dart';
import 'entities/user_location.dart';

/// Decides what a fresh device GPS reading (app start, login, resume, or
/// movement while the app is open) does to the customer's ACTIVE location.
///
/// THE ACTIVE LOCATION is `users/{uid}.location`: the one place
/// serviceability, restaurant discovery, distance and delivery fee are worked
/// out from. What GPS may do to it depends on ONE thing — whether the customer
/// explicitly chose it ([UserLocation.selectionIntent]) — and never on how far
/// the phone is from it:
///
///  * EXPLICIT — the customer selected a searched / pinned place or a saved
///    Home / Work / Other address. It stays active until the customer changes
///    it. GPS never replaces it: not on resume (returning from UPI, a browser
///    or any other app), not on the next launch, not after the phone has
///    moved any distance. Ordering to an address across town — or in another
///    city — keeps working.
///  * IMPLICIT — the phone's own GPS position ([LocationSource.deviceGps],
///    including the customer tapping "Use Current Location"), or a LEGACY
///    location saved before the source was recorded (an old Home address that
///    simply stayed active). A valid GPS reading replaces it, so an old Home
///    address can never keep the customer from seeing where they are now.
///
/// When GPS is NOT available nothing here runs, so the active location stays
/// exactly as it was — it is never swapped for Home behind the customer's
/// back.
///
/// Whenever GPS does replace the active location it is replaced as ONE
/// coherent reading: see [shouldClearStaleAddressDetails].
class LocationRefreshPolicy {
  const LocationRefreshPolicy();

  /// A GPS move smaller than this is noise, not a new place (about a city
  /// block). Below it a GPS-derived location is left alone, so an app resume
  /// does not rewrite the user document — or reload restaurant discovery — for
  /// a few metres of drift. It only paces GPS following GPS; it plays no part
  /// in whether an explicit selection is kept.
  static const double significantMoveKm = 0.2;

  /// May [current] (a fresh GPS reading) be written over [saved]?
  ///
  ///  * nothing saved yet → yes (first current location);
  ///  * an explicit selection → NEVER;
  ///  * a GPS-derived or legacy location → yes.
  bool shouldReplace({
    required UserLocation? saved,
    required UserLocation current,
  }) {
    if (saved == null) {
      return true;
    }
    return !saved.isExplicitSelection;
  }

  /// For a location [shouldReplace] allows GPS to replace: is writing
  /// [current] worth it?
  ///
  /// A legacy address always is — it must give way to the current location,
  /// and be re-recorded as GPS, on the first valid reading. A GPS-derived
  /// location only follows a meaningfully different reading (another place,
  /// another pincode, or a real move), not the same spot again.
  bool isSignificantChange({
    required UserLocation saved,
    required UserLocation current,
  }) {
    if (saved.isLegacyAddress) {
      return true;
    }
    if (!isSamePlace(saved: saved, current: current)) {
      return true;
    }
    final currentPincode = current.pincode?.trim() ?? '';
    if (currentPincode.isNotEmpty &&
        currentPincode != (saved.pincode?.trim() ?? '')) {
      return true;
    }
    final movedKm = GeoDistance.calculateDistanceKm(
      latitude1: saved.latitude,
      longitude1: saved.longitude,
      latitude2: current.latitude,
      longitude2: current.longitude,
    );
    return movedKm == null || movedKm >= significantMoveKm;
  }

  /// True when saving [current] over [saved] must be a full replacement: the
  /// saved pincode / door / street / area (and the customer-selected marker)
  /// belong to the old place and must be cleared rather than merged into the
  /// new one (fresh GPS coordinates must never be mixed with stale address
  /// fields). That is the case when GPS takes over from an address the
  /// customer once entered, or when the location moves to a different
  /// city/state. A GPS location refreshed within the same city/state keeps
  /// merging, so a pincode the customer typed survives a GPS reading that
  /// carries no postal code.
  bool shouldClearStaleAddressDetails({
    required UserLocation? saved,
    required UserLocation current,
  }) {
    if (saved == null) {
      return false;
    }
    return isManuallyEntered(saved) ||
        !isSamePlace(saved: saved, current: current);
  }

  /// True when [location] holds an address the customer entered or picked
  /// (rather than a bare GPS reading): [UserLocation.selectedByCustomer], or
  /// a door / street. It says what the location CONTAINS, not whether it is
  /// an explicit selection — that is [UserLocation.selectionIntent].
  bool isManuallyEntered(UserLocation location) {
    return location.selectedByCustomer ||
        location.doorNumber.trim().isNotEmpty ||
        location.street.trim().isNotEmpty;
  }

  /// True when both locations resolve to the same city and state.
  bool isSamePlace({
    required UserLocation saved,
    required UserLocation current,
  }) {
    return _matches(saved.city, current.city) &&
        _matches(saved.state, current.state);
  }

  bool _matches(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }
}
