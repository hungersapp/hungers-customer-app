import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cart/domain/entities/cart_entity.dart';
import '../../../location/domain/entities/user_location.dart';
import '../../../orders/data/datasources/checkout_quote_datasource.dart';
import '../../../orders/data/datasources/order_functions_datasource.dart';
import '../../../orders/domain/usecases/place_order_usecase.dart';
import '../../data/datasources/offer_datasource.dart';
import '../../domain/entities/offer.dart';

final offerDatasourceProvider = Provider<OfferDatasource>(
  (ref) => FirestoreOfferDatasource(),
);

/// Callable bridge to the backend's authoritative price (`quoteOrder`).
final checkoutQuoteDatasourceProvider = Provider<CheckoutQuoteDatasource>(
  (ref) => FirebaseCheckoutQuoteDatasource(),
);

final activeOffersProvider = FutureProvider.autoDispose<List<Offer>>(
  (ref) => ref.watch(offerDatasourceProvider).getActiveOffers(),
);

/// Offers worth listing for a restaurant right now (display filter only).
final restaurantOffersProvider =
    Provider.autoDispose.family<AsyncValue<List<Offer>>, String>((
  ref,
  restaurantId,
) {
  final now = DateTime.now();
  return ref.watch(activeOffersProvider).whenData(
        (offers) => [
          for (final offer in offers)
            if (offer.isListedFor(restaurantId, now)) offer,
        ],
      );
});

/// The offer the customer has applied, and the restaurant's cart it was
/// applied to. Only one offer at a time: stacking is decided by the backend
/// and is off unless an offer is explicitly marked stackable.
class AppliedOffer {
  const AppliedOffer({required this.offer, required this.restaurantId});

  final Offer offer;
  final String restaurantId;
}

/// Shared by the cart and checkout. Anything reading it must ignore an
/// entry whose [AppliedOffer.restaurantId] is not the current cart's.
final appliedOfferProvider = StateProvider<AppliedOffer?>((ref) => null);

/// The applied offer for [restaurantId]'s cart, or null.
Offer? appliedOfferFor(AppliedOffer? applied, String restaurantId) {
  if (applied == null || applied.restaurantId != restaurantId) {
    return null;
  }
  return applied.offer;
}

/// Asks the backend to price [items] delivered to [location]. Throws
/// `OfferRejectedException` / `CheckoutQuoteUnavailableException`.
Future<CheckoutQuote> requestCheckoutQuote(
  CheckoutQuoteDatasource datasource, {
  required List<CartEntity> items,
  required UserLocation location,
  required String paymentMethod,
  Offer? offer,
}) {
  return datasource.quoteOrder(
    restaurantId: items.first.restaurantId.trim(),
    items: [
      for (final item in items)
        PlaceOrderLineRequest(foodId: item.foodId, quantity: item.quantity),
    ],
    deliveryAddress: PlaceOrderUseCase.deliveryAddressRequestFor(location),
    paymentMethod: paymentMethod,
    offerIds: [if (offer != null) offer.id],
  );
}
