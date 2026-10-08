/// Allowed reasons for deleting a user's persisted Firestore cart.
enum CartClearReason {
  /// Checkout/payment succeeded and the order was created in the backend.
  orderCompletedSuccessfully,

  /// The customer explicitly confirmed "Clear Cart & Add" when adding an
  /// item from a different restaurant. Never implied by navigation.
  customerConfirmedRestaurantSwitch,
}

/// Guards cart deletion so navigation, refresh, and failed checkout never
/// wipe persisted items.
class CartClearPolicy {
  const CartClearPolicy();

  static const Set<CartClearReason> _allowedReasons = {
    CartClearReason.orderCompletedSuccessfully,
    CartClearReason.customerConfirmedRestaurantSwitch,
  };

  bool canClear(CartClearReason reason) {
    return _allowedReasons.contains(reason);
  }
}

/// Startup hook for the cart feature. Intentionally does not clear carts.
class CartStartupHandler {
  const CartStartupHandler();

  Future<void> onAppStart() async {
    // Cart items live in Firestore under the authenticated user ID.
    // App start, provider recreation, and session restore must only READ.
  }
}
