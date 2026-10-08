/// Failures raised by the `placeOrder` Cloud Function callable.
///
/// Mirrors the existing `LocationException` pattern
/// (`features/location/domain/exceptions/location_exception.dart`): a base
/// class carrying a human-readable [message], with one `const` subclass per
/// distinct failure reason so callers can branch on type when needed while
/// still being able to show [message] directly, the same way the orders
/// feature already surfaces `StateError.message` in checkout_screen.dart.
class PlaceOrderFunctionsException implements Exception {
  const PlaceOrderFunctionsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The caller is not signed in. Mirrors the message already used by
/// `PlaceOrderUseCase` for the same condition.
class PlaceOrderUnauthenticatedException extends PlaceOrderFunctionsException {
  const PlaceOrderUnauthenticatedException()
      : super('User must be signed in to place an order.');
}

/// A generic permission failure (for example, reusing another attempt's
/// idempotency key). Idempotency is not implemented by any caller yet, so
/// this is expected to be unreachable in practice today.
class PlaceOrderPermissionDeniedException extends PlaceOrderFunctionsException {
  const PlaceOrderPermissionDeniedException()
      : super('You are not allowed to complete this order. Please try again.');
}

/// The restaurant does not exist. Mirrors `PlaceOrderUseCase`'s existing
/// message for a missing restaurant.
class PlaceOrderRestaurantNotFoundException extends PlaceOrderFunctionsException {
  const PlaceOrderRestaurantNotFoundException()
      : super('This restaurant is not available for new orders right now.');
}

/// The restaurant exists but currently fails the server's acceptance gate
/// (closed, inactive, not customer-visible, unapproved, or has no approved
/// menu items). Same customer-facing wording as "not found" — from the
/// customer's perspective both mean "you cannot order from this restaurant
/// right now" — kept as a distinct type in case the two ever need to diverge.
class PlaceOrderRestaurantNotAcceptingException
    extends PlaceOrderFunctionsException {
  const PlaceOrderRestaurantNotAcceptingException()
      : super('This restaurant is not available for new orders right now.');
}

/// One or more cart items could not be ordered (missing, belongs to a
/// different restaurant, not approved, unavailable, or has invalid pricing
/// data). Reuses the exact message `PlaceOrderUseCase` already shows for
/// this class of failure today.
class PlaceOrderItemsUnavailableException extends PlaceOrderFunctionsException {
  const PlaceOrderItemsUnavailableException()
      : super(
          'One or more items in your cart are no longer available. '
          'Please update your cart and try again.',
        );
}

/// The delivery distance exceeds the server's automatic pricing range
/// (currently 15km). Matches the wording already shown by the checkout
/// screen's own >15km serviceability check.
class PlaceOrderNotServiceableException extends PlaceOrderFunctionsException {
  const PlaceOrderNotServiceableException()
      : super(
          'This location is more than 15 km away and is outside standard '
          'checkout delivery range. Please choose a closer address.',
        );
}

/// The delivery pincode is not configured/active, or its zone is missing or
/// inactive, per the server's authoritative pincode+zone master data (V1-B).
/// Independent of [PlaceOrderNotServiceableException], which is the
/// unrelated restaurant-distance (>15km) condition.
class PlaceOrderPincodeNotServiceableException
    extends PlaceOrderFunctionsException {
  const PlaceOrderPincodeNotServiceableException()
      : super(
          'Delivery is not available in this pincode. '
          'Please choose another delivery location.',
        );
}

/// The delivery address is missing required fields or has invalid
/// coordinates/pincode. Mirrors `PlaceOrderUseCase`'s existing message for
/// an incomplete delivery address.
class PlaceOrderInvalidAddressException extends PlaceOrderFunctionsException {
  const PlaceOrderInvalidAddressException()
      : super('A complete delivery address is required before placing an order.');
}

/// The "order for other" recipient name/phone failed validation. Carries the
/// server's own message, which is already written for a customer audience
/// (e.g. the same wording as `IndianMobile.invalidMessage`).
class PlaceOrderInvalidRecipientException extends PlaceOrderFunctionsException {
  const PlaceOrderInvalidRecipientException(super.message);
}

/// A generic invalid-argument failure not covered by a more specific case
/// above. Carries the server's own message when one is available.
class PlaceOrderInvalidArgumentException extends PlaceOrderFunctionsException {
  const PlaceOrderInvalidArgumentException(super.message);
}

/// UPI/card was chosen but online payment (Cashfree) is not configured on
/// the backend. No order was created; Cash on Delivery still works.
class PlaceOrderOnlinePaymentUnavailableException
    extends PlaceOrderFunctionsException {
  const PlaceOrderOnlinePaymentUnavailableException()
      : super('Online payment is not available right now. Please choose Cash on Delivery.');
}

/// The backend re-validated the applied offer while creating the order and
/// refused it (expired, limit reached, minimum not met, wrong payment
/// method…). No order was created. [code] is the backend's rejection code;
/// [message] is customer wording, never raw backend text.
class PlaceOrderOfferRejectedException extends PlaceOrderFunctionsException {
  const PlaceOrderOfferRejectedException(this.code, super.message);

  final String code;
}

/// Anything else: transient/unexpected server error, or a response shape
/// the client did not recognize.
class PlaceOrderServerException extends PlaceOrderFunctionsException {
  const PlaceOrderServerException()
      : super('Unable to place order. Please try again.');
}
