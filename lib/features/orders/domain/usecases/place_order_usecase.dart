import 'dart:math';

import '../../../../core/validators/indian_mobile.dart';
import '../../../cart/domain/entities/cart_entity.dart';
import '../../../foods/domain/repositories/food_repository.dart';
import '../../../location/domain/entities/user_location.dart';
import '../../../offers/domain/offer_failure.dart';
import '../../../restaurants/domain/repositories/restaurant_repository.dart';
import '../../data/datasources/order_functions_datasource.dart';
import '../../data/datasources/pending_order_attempt_datasource.dart';
import '../entities/placed_order.dart';
import '../exceptions/place_order_functions_exception.dart';
import 'get_order_by_id_usecase.dart';

/// The `placeOrder` callable reported success and returned [orderId], but
/// the confirming read of `orders/{orderId}` afterward failed. The order
/// was created — this is not a creation failure, and callers must not treat
/// it as one (no retry-by-recreating, no "order failed" messaging). The
/// customer can still find the order via order history using [orderId].
///
/// This extends [PlaceOrderFunctionsException] to stay inside the existing
/// placeOrder failure hierarchy rather than starting a new one. Its more
/// natural home is alongside the other failure types in
/// `domain/exceptions/place_order_functions_exception.dart`, but that file
/// was out of scope for this change — see the phase report for the
/// follow-up this leaves open.
class PlaceOrderCreatedButUnreadableException
    extends PlaceOrderFunctionsException {
  const PlaceOrderCreatedButUnreadableException(this.orderId)
    : super(
        'Your order was placed successfully, but we could not load its '
        'details right now. Check My Orders to view it.',
      );

  /// The id of the order that was actually created. Present so a caller can
  /// still navigate to it (e.g. via order history) instead of losing track
  /// of a real, successfully-placed order.
  final String orderId;
}

class PlaceOrderUseCase {
  const PlaceOrderUseCase(
    this._functionsDatasource, {
    required this._restaurantRepository,
    required this._foodRepository,
    required this._getOrderByIdUseCase,
    required this._pendingAttemptDatasource,
  });

  final OrderFunctionsDatasource _functionsDatasource;
  final RestaurantRepository _restaurantRepository;
  final FoodRepository _foodRepository;
  final GetOrderByIdUseCase _getOrderByIdUseCase;
  final PendingOrderAttemptDatasource _pendingAttemptDatasource;

  Future<PlacedOrder> call(PlaceOrderRequest request) async {
    if (request.userId.isEmpty) {
      throw StateError('User must be signed in to place an order.');
    }
    if (request.items.isEmpty) {
      throw StateError('Cart is empty.');
    }

    final location = request.deliveryLocation;
    if (location == null || !location.isCompleteForCheckout) {
      throw StateError(
        'A complete delivery address is required before placing an order.',
      );
    }

    var recipientName = request.recipientName?.trim();
    var recipientPhone = request.recipientPhone;
    if (request.orderForOther) {
      if (recipientName == null || recipientName.isEmpty) {
        throw StateError('Recipient name is required.');
      }
      final phone = IndianMobile.normalize(recipientPhone ?? '');
      if (phone == null) {
        throw StateError(IndianMobile.invalidMessage);
      }
      recipientPhone = phone;
    } else {
      recipientName = null;
      recipientPhone = null;
    }

    final restaurantId = request.items.first.restaurantId.trim();
    if (restaurantId.isEmpty) {
      throw StateError('Restaurant is required to place an order.');
    }

    // Fast-fail client-side checks. The server independently re-validates
    // restaurant eligibility and food status/pricing as the authoritative
    // source — these calls exist only to give the customer a quicker,
    // friendlier error before spending a network round trip on a callable
    // that would reject the same thing anyway. Kept unchanged by this
    // migration; the server checks are not duplicated here.
    final restaurant = await _restaurantRepository.getRestaurantById(
      restaurantId,
    );
    if (restaurant == null) {
      throw StateError(
        'This restaurant is not available for new orders right now.',
      );
    }

    await _assertCartFoodsStillOrderable(
      restaurantId: restaurantId,
      items: request.items,
    );

    final idempotencyKey = await _resolveIdempotencyKey(
      userId: request.userId,
      restaurantId: restaurantId,
      items: request.items,
      orderForOther: request.orderForOther,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      location: location,
      paymentMethod: request.paymentMethod,
      offerIds: request.offerIds,
    );

    // Server-authoritative placement: pricing, GST, delivery fee,
    // serviceability, restaurant eligibility, and food validation are all
    // computed/re-checked by the callable, not here. Only enough is sent to
    // identify what the customer wants — no price, name, or image fields.
    final PlaceOrderFunctionResult result;
    try {
      final lines = request.items
          .map(
            (item) => PlaceOrderLineRequest(
              foodId: item.foodId,
              quantity: item.quantity,
            ),
          )
          .toList();
      final datasource = _functionsDatasource;
      if (request.offerIds.isEmpty) {
        result = await datasource.placeOrder(
          restaurantId: restaurantId,
          items: lines,
          deliveryAddress: deliveryAddressRequestFor(location),
          orderForOther: request.orderForOther,
          recipientName: recipientName,
          recipientPhone: recipientPhone,
          idempotencyKey: idempotencyKey,
          paymentMethod: request.paymentMethod.placeOrderValue,
        );
      } else if (datasource
          case final OfferAwareOrderFunctionsDatasource offerAware) {
        result = await offerAware.placeOrderWithOffers(
          restaurantId: restaurantId,
          items: lines,
          deliveryAddress: deliveryAddressRequestFor(location),
          offerIds: request.offerIds,
          orderForOther: request.orderForOther,
          recipientName: recipientName,
          recipientPhone: recipientPhone,
          idempotencyKey: idempotencyKey,
          paymentMethod: request.paymentMethod.placeOrderValue,
        );
      } else {
        // Never place a full-price order the customer was shown a discount
        // for: refuse, so checkout can drop the offer and re-quote.
        throw const PlaceOrderOfferRejectedException(
          'OFFER_UNSUPPORTED',
          OfferFailureMessages.unavailable,
        );
      }
    } on PlaceOrderFunctionsException catch (error) {
      // PlaceOrderServerException covers the callable's own generic/
      // "unavailable" catch-all (and any other unrecognized code) — the
      // server outcome is genuinely unknown in that case, so the pending
      // attempt must survive for a retry to reuse the same key. Every
      // other, more specific subtype means the server gave a definitive
      // business/auth rejection and never created an order, so the key is
      // safe (and pointless) to keep — clear it so the next attempt starts
      // fresh. Any exception that isn't even a PlaceOrderFunctionsException
      // (e.g. a raw transport/timeout failure that never reached a
      // recognized server response) is not caught here at all, so it
      // reaches the caller with the pending attempt left untouched — the
      // same "unknown outcome, keep the key" behavior, by construction.
      if (error is! PlaceOrderServerException) {
        await _pendingAttemptDatasource.clearPendingAttempt(request.userId);
      }
      rethrow;
    }

    // The order now definitely exists (fresh or replayed) — clear the
    // pending attempt before attempting the follow-up read, so a read
    // failure below can never leave a stale key pointing at an order the
    // customer has already been told about.
    await _pendingAttemptDatasource.clearPendingAttempt(request.userId);

    // Do not construct a PlacedOrder from the callable's response — it only
    // returns {orderId, replayed, summary}, not a complete order. The
    // existing Firestore read path is the single source of truth for what
    // a placed order looks like, reused as-is here (same for a replayed
    // placement as for a fresh one — the order document already exists
    // either way, so no special-casing is needed).
    try {
      return await _getOrderByIdUseCase.call(
        orderId: result.orderId,
        userId: request.userId,
      );
    } catch (_) {
      // The order was created (we have a real orderId); only the follow-up
      // read failed. Never return null/partial data or claim the order
      // does not exist.
      throw PlaceOrderCreatedButUnreadableException(result.orderId);
    }
  }

  /// Resolves the idempotency key to send with this attempt: reuse a
  /// persisted one only if it matches the current order exactly and isn't
  /// stale, otherwise generate a fresh key and persist it before the
  /// callable is ever invoked — so it survives even if the callable call
  /// itself times out.
  Future<String> _resolveIdempotencyKey({
    required String userId,
    required String restaurantId,
    required List<CartEntity> items,
    required bool orderForOther,
    String? recipientName,
    String? recipientPhone,
    required UserLocation location,
    required OrderPaymentMethod paymentMethod,
    List<String> offerIds = const [],
  }) async {
    final fingerprint = _buildFingerprint(
      restaurantId: restaurantId,
      items: items,
      orderForOther: orderForOther,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      location: location,
      paymentMethod: paymentMethod,
      offerIds: offerIds,
    );

    final now = DateTime.now();
    final existing = await _pendingAttemptDatasource.getPendingAttempt(userId);
    if (existing != null &&
        !existing.isStaleAt(now) &&
        existing.fingerprint == fingerprint) {
      return existing.idempotencyKey;
    }

    final key = _generateIdempotencyKey();
    await _pendingAttemptDatasource.savePendingAttempt(
      userId: userId,
      attempt: PendingOrderAttempt(
        idempotencyKey: key,
        fingerprint: fingerprint,
        createdAt: now,
      ),
    );
    return key;
  }

  /// A deterministic string identifying this logical order attempt. Two
  /// calls with the same restaurant, cart contents, order-for-other
  /// recipient, and delivery address always produce the same fingerprint;
  /// changing any of them changes it. Plain string equality is enough here
  /// — no hashing is needed for a fingerprint that's only ever compared for
  /// equality, and the project has no hashing dependency to reuse.
  String _buildFingerprint({
    required String restaurantId,
    required List<CartEntity> items,
    required bool orderForOther,
    String? recipientName,
    String? recipientPhone,
    required UserLocation location,
    required OrderPaymentMethod paymentMethod,
    List<String> offerIds = const [],
  }) {
    final sortedItems =
        items.map((item) => '${item.foodId}:${item.quantity}').toList()..sort();
    final addressPart = [
      location.pincode ?? '',
      location.doorNumber,
      location.street,
      location.city,
      location.state,
      location.latitude.toStringAsFixed(6),
      location.longitude.toStringAsFixed(6),
      location.area,
    ].join('|');
    final recipientPart = orderForOther
        ? '${recipientName ?? ''}|${recipientPhone ?? ''}'
        : '';

    return [
      restaurantId,
      sortedItems.join(','),
      orderForOther.toString(),
      recipientPart,
      addressPart,
      // COD keeps its historical fingerprint (no suffix) so an in-flight
      // COD retry still matches; a different payment method must never
      // replay a previous attempt's order.
      if (paymentMethod.isOnline) paymentMethod.placeOrderValue,
      // Same rule for offers: no suffix without one, and an attempt priced
      // with one offer must never be replayed for another (or for none).
      if (offerIds.isNotEmpty) 'offers=${([...offerIds]..sort()).join(',')}',
    ].join('::');
  }

  /// Dependency-free UUID-v4-style identifier (36 chars, well under the
  /// server's 128-char limit) using Dart's cryptographically secure RNG.
  /// No UUID package exists in this project's dependencies.
  static String _generateIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10xx
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  /// The `deliveryAddress` payload for [location]; shared with the checkout
  /// quote so both callables price exactly the same destination.
  static PlaceOrderDeliveryAddressRequest deliveryAddressRequestFor(
    UserLocation location,
  ) {
    final detail = location.detailedAddressLine.trim();
    final address = detail.isNotEmpty ? detail : location.displayAddress;
    final area = location.area.trim();
    return PlaceOrderDeliveryAddressRequest(
      address: address,
      city: location.city,
      state: location.state,
      pincode: location.pincode ?? '',
      latitude: location.latitude,
      longitude: location.longitude,
      doorNumber: location.doorNumber,
      street: location.street,
      area: area.isNotEmpty ? area : null,
    );
  }

  Future<void> _assertCartFoodsStillOrderable({
    required String restaurantId,
    required List<CartEntity> items,
  }) async {
    const unavailableMessage =
        'One or more items in your cart are no longer available. '
        'Please update your cart and try again.';

    for (final item in items) {
      final foodId = item.foodId.trim();
      final itemRestaurantId = item.restaurantId.trim();
      if (foodId.isEmpty || itemRestaurantId != restaurantId) {
        throw StateError(unavailableMessage);
      }

      final food = await _foodRepository.getFoodDocumentById(foodId);
      if (food == null ||
          food.restaurantId.trim() != restaurantId ||
          !food.isCustomerVisibleFood) {
        throw StateError(unavailableMessage);
      }
    }
  }
}
