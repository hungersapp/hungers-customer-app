/// Thresholds for PROMPTS about the customer's location. They only decide
/// when to tell or ask the customer something; they never change the active
/// location (that is LocationRefreshPolicy, which does not look at distance
/// to an explicit selection at all).
class LocationHints {
  LocationHints._();

  /// A place at least this far from the phone gets the "x km away" note, the
  /// "Are you sure of the selected location?" confirmation in the selector,
  /// and the "Use current location" offer on Home.
  static const double farFromDeviceKm = 5;
}
