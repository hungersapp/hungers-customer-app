import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/format/inr_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/validators/indian_mobile.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../cart/domain/entities/billing_config.dart';
import '../../../cart/domain/entities/billing_summary.dart';
import '../../../cart/domain/entities/cart_entity.dart';
import '../../../cart/domain/usecases/calculate_cart_billing_usecase.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../cart/presentation/widgets/bill_details_card.dart';
import '../../../location/domain/discovery_location_kind.dart';
import '../../../location/domain/entities/user_location.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../location/presentation/screens/delivery_address_editor_screen.dart';
import '../../../restaurants/domain/entities/restaurant_entity.dart';
import '../../../restaurants/domain/restaurant_delivery_range.dart';
import '../../../restaurants/presentation/providers/restaurant_details_provider.dart';
import '../../../restaurants/presentation/providers/restaurant_provider.dart';
import '../../../serviceability/domain/geo_distance.dart';
import '../../../serviceability/presentation/providers/serviceability_provider.dart';
import '../../domain/checkout_bill_readiness.dart';
import '../../domain/entities/placed_order.dart';
import '../../../offers/domain/entities/offer.dart';
import '../../../offers/domain/offer_failure.dart';
import '../../../offers/presentation/providers/offer_providers.dart';
import '../../../offers/presentation/widgets/offers_savings_section.dart';
import '../../data/datasources/checkout_quote_datasource.dart';
import '../../data/datasources/online_payment_functions_datasource.dart';
import '../../domain/exceptions/place_order_functions_exception.dart'
    show
        PlaceOrderFunctionsException,
        PlaceOrderOfferRejectedException,
        PlaceOrderPincodeNotServiceableException;
import '../../domain/usecases/place_order_usecase.dart'
    show PlaceOrderCreatedButUnreadableException;
import '../providers/order_provider.dart';
import 'order_confirmation_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const double _contentMaxWidth = 920;

  bool _isPlacing = false;
  bool _didSeedAddress = false;
  bool _orderForOther = false;

  OrderPaymentMethod _paymentMethod = OrderPaymentMethod.payOnDelivery;

  /// An online (UPI/card) order already created "awaiting_payment" whose
  /// payment has not been verified yet. Retrying pays for THIS order —
  /// never a second order.
  String? _awaitingPaymentOrderId;
  String? _paymentError;
  /// True while the address editor is open — hides the final bill so a
  /// previous fee/total cannot linger as the payable amount.
  bool _editingAddress = false;
  UserLocation? _selfAddress;
  UserLocation? _otherAddress;
  String? _addressBlockReason;
  bool _checkingServiceability = false;

  /// The backend's price (`quoteOrder`) for the inputs in [_quoteKey]. It is
  /// the bill shown and the amount on the pay button whenever it is present.
  CheckoutQuote? _quote;
  String? _quoteKey;
  String? _quoteError;
  String? _busyOfferId;
  String? _offerMessage;

  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();

  UserLocation? get _activeAddress =>
      _orderForOther ? _otherAddress : _selfAddress;

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Checkout'),
          centerTitle: true,
        ),
        body: const Center(child: Text('Please login')),
      );
    }

    final cartItems = ref.watch(cartItemsProvider(userId));
    final savedLocation = ref.watch(userLocationProvider(userId));
    final billingConfig = ref.watch(billingConfigProvider);
    final calculateBilling = ref.watch(calculateCartBillingUseCaseProvider);

    ref.listen<AsyncValue<UserLocation?>>(userLocationProvider(userId),
        (previous, next) {
      next.whenData((location) {
        if (_didSeedAddress && _selfAddress != null) {
          return;
        }
        setState(() {
          _selfAddress ??= location;
          _didSeedAddress = true;
        });
        if (!_orderForOther &&
            location != null &&
            location.isCompleteForCheckout) {
          _evaluateBeyondRange(location);
        }
      });
    });

    if (!_didSeedAddress && savedLocation.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didSeedAddress) {
          return;
        }
        final location = savedLocation.value;
        setState(() {
          _selfAddress ??= location;
          _didSeedAddress = true;
        });
        if (!_orderForOther &&
            location != null &&
            location.isCompleteForCheckout) {
          _evaluateBeyondRange(location);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        centerTitle: true,
      ),
      body: cartItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Unable to load checkout.')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Your cart is empty.'));
          }

          final restaurantId = items.first.restaurantId.trim();
          if (restaurantId.isEmpty) {
            return _checkoutScroll(
              context: context,
              userId: userId,
              items: items,
              restaurant: null,
              billingConfig: billingConfig,
              calculateBilling: calculateBilling,
            );
          }

          final restaurantAsync =
              ref.watch(restaurantDetailsProvider(restaurantId));

          return restaurantAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _checkoutScroll(
              context: context,
              userId: userId,
              items: items,
              restaurant: null,
              billingConfig: billingConfig,
              calculateBilling: calculateBilling,
            ),
            data: (restaurant) => _checkoutScroll(
              context: context,
              userId: userId,
              items: items,
              restaurant: restaurant,
              billingConfig: billingConfig,
              calculateBilling: calculateBilling,
            ),
          );
        },
      ),
    );
  }

  Widget _checkoutScroll({
    required BuildContext context,
    required String userId,
    required List<CartEntity> items,
    required RestaurantEntity? restaurant,
    required BillingConfig billingConfig,
    required CalculateCartBillingUseCase calculateBilling,
  }) {
    final address = _activeAddress;
    final feePlan = _resolveFeePlan(
      address: address,
      restaurant: restaurant,
    );

    final hasCompleteAddress =
        address != null && address.isCompleteForCheckout;
    // A complete saved/confirmed address (or one just returned from the
    // editor) counts as finalized. Opening the editor invalidates it.
    final addressFinalized = hasCompleteAddress && !_editingAddress;
    final billReady = isCheckoutFinalBillReady(
      addressFinalized: addressFinalized,
      checkingServiceability: _checkingServiceability,
      deliveryPriceable: feePlan.canQuote,
      feeBlockMessage: feePlan.blockMessage,
      addressBlockReason: _addressBlockReason,
    );

    BillingSummary? summary;
    UserLocation? placeLocation;
    if (billReady && address != null) {
      placeLocation = address;
      // Carries only the display rates into the quote below. It holds no
      // delivery fee: that is priced by the backend on the road distance.
      summary = calculateBilling(
        items: items,
        config: billingConfig,
        deliveryFee: 0,
      );
    }

    // One price, from quoteOrder. The local calculation is not a payable
    // amount: the pay button stays disabled until the backend quote arrives,
    // and a failed quote never falls back to a client-calculated total.
    final restaurantId = items.first.restaurantId.trim();
    final appliedOffer = appliedOfferFor(
      ref.watch(appliedOfferProvider),
      restaurantId,
    );
    var awaitingQuote = false;
    double? confirmedSaving;
    String? deliveryDistanceLabel;
    if (summary != null && placeLocation != null) {
      final key = _quoteKeyFor(items, placeLocation, appliedOffer);
      if (key != _quoteKey) {
        final quoteItems = items;
        final quoteLocation = placeLocation;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && key != _quoteKey) {
            _refreshQuote(key, quoteItems, quoteLocation, appliedOffer);
          }
        });
      }
      final quote = key == _quoteKey ? _quote : null;
      if (quote != null) {
        summary = quote.toBillingSummary(summary);
        final quotedKm = quote.distanceKm;
        if (quotedKm != null) {
          deliveryDistanceLabel = GeoDistance.formatKmLabel(quotedKm);
        }
        if (appliedOffer != null) {
          confirmedSaving = quote.discount;
        }
      } else if (_quoteError != null) {
        summary = null;
      } else {
        awaitingQuote = true;
        summary = null;
      }
    }

    final recipientNameOk = !_orderForOther ||
        _recipientNameController.text.trim().isNotEmpty;
    final recipientPhoneOk = !_orderForOther ||
        IndianMobile.isValid(_recipientPhoneController.text);

    VoidCallback? onPlaceOrder;
    if (summary != null &&
        placeLocation != null &&
        !_isPlacing &&
        !awaitingQuote &&
        recipientNameOk &&
        recipientPhoneOk) {
      final payableSummary = summary;
      final deliveryLocation = placeLocation;
      onPlaceOrder = () => _placeOrder(
            userId: userId,
            items: items,
            summary: payableSummary,
            location: deliveryLocation,
            offer: appliedOffer,
          );
    } else if (!hasCompleteAddress &&
        !_isPlacing &&
        !_checkingServiceability) {
      onPlaceOrder = () => _openAddressEditor(
            initial: address,
            saveToProfile: !_orderForOther,
          );
    }

    final payable = billReady && summary != null && !awaitingQuote
        ? summary.grandTotal
        : null;

    return Column(
      children: [
        Expanded(
          child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SectionCard(
              title: 'Delivering to',
              child: RadioGroup<bool>(
                groupValue: _orderForOther,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _orderForOther = value;
                    _addressBlockReason = null;
                    // Switching delivery target invalidates the prior
                    // fee/bill until the active address is re-resolved.
                    _editingAddress = false;
                  });
                  final address =
                      value ? _otherAddress : _selfAddress;
                  if (address != null && address.isCompleteForCheckout) {
                    _evaluateBeyondRange(address);
                  }
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: false,
                      activeColor: AppColors.primary,
                      title: const Text('Deliver to me'),
                    ),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: true,
                      activeColor: AppColors.primary,
                      title: const Text('Order for someone else'),
                    ),
                  ],
                ),
              ),
            ),
            if (_orderForOther) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Recipient',
                child: Column(
                  children: [
                    TextField(
                      controller: _recipientNameController,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Recipient name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _recipientPhoneController,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Recipient mobile',
                        border: OutlineInputBorder(),
                        helperText: '10-digit Indian mobile number',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _SectionCard(
              title: _orderForOther
                  ? 'Recipient delivery address'
                  : 'Delivery Address',
              child: address == null || !address.isCompleteForCheckout
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _orderForOther
                              ? 'Add the recipient delivery address. '
                                  'Your saved address will not be changed.'
                              : (address == null
                                  ? 'Add a delivery address to continue.'
                                  : 'Your saved location is incomplete. Add door, '
                                      'street, and pincode to continue.'),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () => _openAddressEditor(
                            initial: address,
                            saveToProfile: !_orderForOther,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textLight,
                          ),
                          child: Text(
                            address == null ? 'Add address' : 'Complete address',
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _orderForOther
                              ? 'Recipient'
                              : DiscoveryLocationPresentation.from(
                                  location: address,
                                  book: ref
                                      .watch(savedAddressBookProvider(userId))
                                      .valueOrNull,
                                ).title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          address.checkoutDisplayBlock,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _openAddressEditor(
                            initial: address,
                            saveToProfile: !_orderForOther,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
            ),
            if (_addressBlockReason != null || feePlan.blockMessage != null) ...[
              const SizedBox(height: 12),
              Material(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _addressBlockReason ?? feePlan.blockMessage!,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Order Summary',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (items.first.restaurantName.isNotEmpty) ...[
                    Text(
                      items.first.restaurantName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.foodName}  x${item.quantity}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            formatInr(item.totalPrice),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OffersSavingsSection(
              restaurantId: restaurantId,
              itemTotal: items.fold<double>(
                0,
                (total, item) => total + item.totalPrice,
              ),
              appliedOffer: appliedOffer,
              savedAmount: confirmedSaving,
              busyOfferId: _busyOfferId,
              message: _offerMessage,
              paymentMethod: _paymentMethod.placeOrderValue,
              onApply: (offer) => _applyOffer(
                offer,
                restaurantId: restaurantId,
                billReady: billReady,
              ),
              onRemove: _removeOffer,
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Payment Method',
              child: Column(
                children: [
                  for (final method in OrderPaymentMethod.values) ...[
                    _PaymentMethodTile(
                      key: ValueKey<String>('payment-method-${method.name}'),
                      method: method,
                      selected: _paymentMethod == method,
                      enabled: !_isPlacing,
                      onTap: () => setState(() {
                        _paymentMethod = method;
                        _paymentError = null;
                      }),
                    ),
                    if (method != OrderPaymentMethod.values.last)
                      const SizedBox(height: 8),
                  ],
                  if (_paymentError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _paymentError!,
                      key: const ValueKey<String>('checkout-payment-error'),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (awaitingQuote)
              const _SectionCard(
                title: 'Bill Details',
                child: Text('Calculating your order total…'),
              )
            else if (_quoteError != null && summary == null)
              _SectionCard(
                title: 'Bill Details',
                child: Text(
                  _quoteError!,
                  key: const ValueKey<String>('checkout-quote-error'),
                ),
              )
            else if (billReady && summary != null)
              CheckoutBillSummary(
                summary: summary,
                items: items,
                deliveryDistanceLabel: deliveryDistanceLabel,
              )
            else
              _SectionCard(
                title: 'Bill Details',
                child: Text(
                  _editingAddress
                      ? 'Confirm the delivery address to refresh the final bill.'
                      : (!hasCompleteAddress
                          ? 'Finalize your delivery address to see the final amount to pay.'
                          : (_checkingServiceability
                              ? 'Verifying delivery for this address…'
                              : (_addressBlockReason ??
                                  feePlan.blockMessage ??
                                  'Finalize your delivery address to see the final amount to pay.'))),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
          ),
        ),
        // Sticky: the amount and the action stay in view while the customer
        // scrolls the address, offers and bill above.
        Material(
          color: AppColors.surface,
          elevation: 8,
          shadowColor: AppColors.shadow,
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.center,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'To Pay',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            Text(
                              payable != null ? formatInr(payable) : '—',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: onPlaceOrder,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textLight,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.35),
                          minimumSize: const Size(160, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isPlacing ||
                                _checkingServiceability ||
                                awaitingQuote
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textLight,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    !_paymentMethod.isOnline
                                        ? 'Place Order'
                                        : (_awaitingPaymentOrderId != null
                                            ? 'Retry Payment'
                                            : 'Proceed to Pay'),
                                    key: const ValueKey<String>(
                                      'checkout-primary-action',
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  // Same figure as "To Pay": the backend's
                                  // payable for this exact cart.
                                  if (payable != null)
                                    Text(
                                      ' • ${formatInr(payable)}',
                                      key: const ValueKey<String>(
                                        'checkout-primary-amount',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _quoteKeyFor(
    List<CartEntity> items,
    UserLocation location,
    Offer? offer,
  ) {
    final lines = [
      for (final item in items) '${item.foodId}:${item.quantity}',
    ]..sort();
    return [
      items.first.restaurantId.trim(),
      lines.join(','),
      location.latitude.toStringAsFixed(6),
      location.longitude.toStringAsFixed(6),
      location.pincode ?? '',
      location.doorNumber,
      location.street,
      _paymentMethod.placeOrderValue,
      offer?.id ?? '',
    ].join('|');
  }

  Future<void> _refreshQuote(
    String key,
    List<CartEntity> items,
    UserLocation location,
    Offer? offer,
  ) async {
    setState(() {
      _quoteKey = key;
      _quote = null;
      _quoteError = null;
    });
    try {
      final quote = await requestCheckoutQuote(
        ref.read(checkoutQuoteDatasourceProvider),
        items: items,
        location: location,
        paymentMethod: _paymentMethod.placeOrderValue,
        offer: offer,
      );
      if (!mounted || _quoteKey != key) {
        return;
      }
      setState(() {
        _quote = quote;
        _busyOfferId = null;
        if (offer != null) {
          _offerMessage = null;
        }
      });
    } catch (error) {
      if (!mounted || _quoteKey != key) {
        return;
      }
      if (error is OfferRejectedException && offer != null) {
        final itemTotal = items.fold<double>(
          0,
          (total, item) => total + item.totalPrice,
        );
        ref.read(appliedOfferProvider.notifier).state = null;
        setState(() {
          _busyOfferId = null;
          _offerMessage = OfferFailureMessages.forCode(
            error.code,
            offer: offer,
            itemTotal: itemTotal,
          );
        });
        return;
      }
      if (offer != null) {
        ref.read(appliedOfferProvider.notifier).state = null;
      }
      setState(() {
        _busyOfferId = null;
        _quoteError = OfferFailureMessages.forQuoteFailure(
          error is CheckoutQuoteUnavailableException ? error.code : null,
        );
        if (offer != null) {
          _offerMessage = OfferFailureMessages.unavailable;
        }
      });
    }
  }

  void _applyOffer(
    Offer offer, {
    required String restaurantId,
    required bool billReady,
  }) {
    if (!billReady) {
      setState(() {
        _offerMessage = 'Add your delivery address to apply offers.';
      });
      return;
    }
    setState(() {
      _busyOfferId = offer.id;
      _offerMessage = null;
    });
    ref.read(appliedOfferProvider.notifier).state = AppliedOffer(
      offer: offer,
      restaurantId: restaurantId,
    );
  }

  void _dropRejectedOffer(String message) {
    ref.read(appliedOfferProvider.notifier).state = null;
    setState(() {
      _busyOfferId = null;
      _offerMessage = message;
    });
  }

  void _removeOffer() {
    ref.read(appliedOfferProvider.notifier).state = null;
    setState(() {
      _busyOfferId = null;
      _offerMessage = null;
    });
  }

  _FeePlan _resolveFeePlan({
    required UserLocation? address,
    required RestaurantEntity? restaurant,
  }) {
    if (address == null || !address.isCompleteForCheckout) {
      return const _FeePlan(
        blockMessage: 'Add a complete delivery address to see delivery fee.',
      );
    }
    if (restaurant == null ||
        !GeoDistance.isValidLatitude(restaurant.latitude) ||
        !GeoDistance.isValidLongitude(restaurant.longitude) ||
        (restaurant.latitude == 0 && restaurant.longitude == 0)) {
      return const _FeePlan(
        blockMessage:
            'Restaurant location is unavailable. Delivery fee cannot be calculated.',
      );
    }

    final km = GeoDistance.calculateDistanceKm(
      latitude1: restaurant.latitude,
      longitude1: restaurant.longitude,
      latitude2: address.latitude,
      longitude2: address.longitude,
    );
    if (km == null) {
      return const _FeePlan(
        blockMessage: 'Unable to calculate delivery distance for this address.',
      );
    }

    // The road is never shorter than the straight line, so an address more
    // than 15 km away in a straight line cannot be delivered to. Anything
    // nearer is priced by the backend on the actual road distance.
    if (km > RestaurantDeliveryRange.maxDistanceKm) {
      return _FeePlan(
        blockMessage: _addressBlockReason ??
            'This location is more than 15 km away. Verifying delivery…',
      );
    }
    return const _FeePlan(canQuote: true);
  }

  Future<void> _openAddressEditor({
    UserLocation? initial,
    required bool saveToProfile,
  }) async {
    setState(() {
      _editingAddress = true;
      _addressBlockReason = null;
    });
    final result = await Navigator.of(context).push<UserLocation>(
      MaterialPageRoute(
        builder: (_) => DeliveryAddressEditorScreen(
          initial: initial,
          saveToProfile: saveToProfile,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (result == null) {
      // Cancelled — restore prior finalized address (if any) for billing.
      setState(() => _editingAddress = false);
      return;
    }
    setState(() {
      if (_orderForOther) {
        _otherAddress = result;
      } else {
        _selfAddress = result;
      }
      _editingAddress = false;
      _addressBlockReason = null;
    });
    await _evaluateBeyondRange(result);
  }

  Future<void> _evaluateBeyondRange(UserLocation address) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      return;
    }
    final items = ref.read(cartItemsProvider(userId)).valueOrNull;
    if (items == null || items.isEmpty) {
      return;
    }
    final restaurantId = items.first.restaurantId.trim();
    if (restaurantId.isEmpty) {
      return;
    }
    final restaurant =
        await ref.read(getRestaurantByIdProvider).call(restaurantId);
    if (restaurant == null) {
      return;
    }
    final km = GeoDistance.calculateDistanceKm(
      latitude1: restaurant.latitude,
      longitude1: restaurant.longitude,
      latitude2: address.latitude,
      longitude2: address.longitude,
    );
    if (km == null || km <= RestaurantDeliveryRange.maxDistanceKm) {
      if (mounted) {
        setState(() => _addressBlockReason = null);
      }
      return;
    }

    final pin = address.pincode;
    if (pin == null) {
      return;
    }

    setState(() {
      _checkingServiceability = true;
      _addressBlockReason = null;
    });
    try {
      final result =
          await ref.read(checkPincodeServiceabilityUseCaseProvider)(pin);
      if (!mounted) {
        return;
      }
      setState(() {
        _addressBlockReason = result.isServiceable
            ? 'This location is more than 15 km away and is outside '
                'standard checkout delivery range. Please choose a closer address.'
            : 'Delivery is not available to the selected location. '
                'Please change your address.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _addressBlockReason =
              'Unable to verify delivery for this location. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _checkingServiceability = false);
      }
    }
  }

  Future<void> _placeOrder({
    required String userId,
    required List<CartEntity> items,
    required BillingSummary summary,
    required UserLocation location,
    Offer? offer,
  }) async {
    if (_isPlacing) {
      return;
    }
    final offerIds = [if (offer != null) offer.id];
    if (!location.isCompleteForCheckout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A complete delivery address is required.'),
        ),
      );
      return;
    }

    if (_paymentMethod.isOnline) {
      await _placeAndPayOnline(
        userId: userId,
        items: items,
        summary: summary,
        location: location,
        offerIds: offerIds,
      );
      return;
    }

    setState(() => _isPlacing = true);

    try {
      final order = await ref.read(placeOrderUseCaseProvider).call(
            PlaceOrderRequest(
              userId: userId,
              items: items,
              summary: summary,
              paymentMethod: OrderPaymentMethod.payOnDelivery,
              offerIds: offerIds,
              deliveryLocation: location,
              orderForOther: _orderForOther,
              recipientName: _orderForOther
                  ? _recipientNameController.text.trim()
                  : null,
              recipientPhone: _orderForOther
                  ? _recipientPhoneController.text.trim()
                  : null,
            ),
          );

      await ref
          .read(cartNotifierProvider.notifier)
          .clearCartAfterSuccessfulOrder(userId);

      if (ref.read(cartNotifierProvider).hasError) {
        await ref
            .read(cartNotifierProvider.notifier)
            .clearCartAfterSuccessfulOrder(userId);
      }

      await ref.read(cartItemsProvider(userId).future);
      ref.invalidate(customerOrdersProvider(userId));
      // The offer belonged to the cart that has just been ordered.
      ref.read(appliedOfferProvider.notifier).state = null;

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          settings: RouteSettings(
            name: AppRoutes.orderConfirmation,
            arguments: order,
          ),
          builder: (_) => OrderConfirmationScreen(order: order),
        ),
        (route) =>
            route.settings.name == AppRoutes.restaurantDetails ||
            route.settings.name == AppRoutes.dashboard ||
            route.isFirst,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (error is PlaceOrderOfferRejectedException) {
        // The backend re-checked the offer while creating the order and
        // refused it. No order exists; drop the offer so the bill re-quotes
        // at the price the customer would actually pay.
        _dropRejectedOffer(error.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        return;
      }

      if (error is PlaceOrderCreatedButUnreadableException) {
        // The order was already created successfully server-side; only the
        // confirming read afterward failed. Clear the cart the same way a
        // normal success does, so the app does not leave stale items behind
        // or invite the customer to resubmit the same order.
        await ref
            .read(cartNotifierProvider.notifier)
            .clearCartAfterSuccessfulOrder(userId);
        await ref.read(cartItemsProvider(userId).future);
        ref.invalidate(customerOrdersProvider(userId));

        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        return;
      }

      if (error is PlaceOrderPincodeNotServiceableException) {
        // A genuine rejection — no order was created, so the cart is left
        // intact, same as the generic failure path below. Only the message
        // differs, so the customer sees the actual reason instead of the
        // generic "unable to place order" fallback.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        return;
      }

      final message = error is StateError
          ? error.message
          : 'Unable to place order. Your cart was not cleared.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isPlacing = false);
      }
    }
  }

  /// UPI / credit card / debit card through Cashfree:
  ///   1. placeOrder (server prices it; order is "awaiting_payment",
  ///      invisible to the restaurant),
  ///   2. createCustomerPayment (backend creates the Cashfree session for
  ///      the server total),
  ///   3. Cashfree checkout,
  ///   4. verifyCustomerPayment — ONLY a backend-verified "paid" counts.
  /// A failed/unfinished payment keeps the cart and the same order so
  /// "Retry Payment" pays for that order instead of creating another.
  Future<void> _placeAndPayOnline({
    required String userId,
    required List<CartEntity> items,
    required BillingSummary summary,
    required UserLocation location,
    List<String> offerIds = const [],
  }) async {
    final method = _paymentMethod;
    final cashfreeMethod = method.cashfreeMethodValue!;
    setState(() {
      _isPlacing = true;
      _paymentError = null;
    });
    try {
      var orderId = _awaitingPaymentOrderId;
      if (orderId == null) {
        try {
          final order = await ref.read(placeOrderUseCaseProvider).call(
                PlaceOrderRequest(
                  userId: userId,
                  items: items,
                  summary: summary,
                  paymentMethod: method,
                  offerIds: offerIds,
                  deliveryLocation: location,
                  orderForOther: _orderForOther,
                  recipientName: _orderForOther
                      ? _recipientNameController.text.trim()
                      : null,
                  recipientPhone: _orderForOther
                      ? _recipientPhoneController.text.trim()
                      : null,
                ),
              );
          orderId = order.id;
        } on PlaceOrderCreatedButUnreadableException catch (error) {
          orderId = error.orderId;
        }
        _awaitingPaymentOrderId = orderId;
      }

      final payments = ref.read(onlinePaymentFunctionsDatasourceProvider);
      final session = await payments.createPayment(
        orderId: orderId,
        paymentMethod: cashfreeMethod,
      );
      if (!session.alreadyPaid) {
        // The launch outcome is deliberately not used to decide anything:
        // a closed/errored checkout may still have charged the customer.
        await ref.read(onlinePaymentLauncherProvider).launch(session);
        if (!mounted) {
          return;
        }
      }

      // Whatever the SDK said, the backend asks Cashfree.
      final verification = await payments.verifyPayment(orderId: orderId);
      if (!mounted) {
        return;
      }
      if (!verification.isPaid) {
        setState(() {
          _paymentError = verification.isFailed
              ? 'Payment failed. You have not been charged for this order. '
                  'Please try again or choose another payment method.'
              : 'Payment not completed yet. If money was deducted, it will '
                  'be confirmed automatically — tap Retry Payment to check.';
        });
        return;
      }

      await _completeVerifiedOnlineOrder(userId: userId, orderId: orderId);
    } on OnlinePaymentException catch (error) {
      if (mounted) {
        setState(() => _paymentError = error.message);
      }
    } on PlaceOrderOfferRejectedException catch (error) {
      if (mounted) {
        _dropRejectedOffer(error.message);
      }
    } on PlaceOrderFunctionsException catch (error) {
      if (mounted) {
        setState(() => _paymentError = error.message);
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() => _paymentError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _paymentError = 'Unable to complete the payment. Your cart was not cleared.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPlacing = false);
      }
    }
  }

  Future<void> _completeVerifiedOnlineOrder({
    required String userId,
    required String orderId,
  }) async {
    _awaitingPaymentOrderId = null;
    ref.read(appliedOfferProvider.notifier).state = null;
    await ref.read(cartNotifierProvider.notifier).clearCartAfterSuccessfulOrder(userId);
    await ref.read(cartItemsProvider(userId).future);
    ref.invalidate(customerOrdersProvider(userId));
    final PlacedOrder order;
    try {
      order = await ref.read(getOrderByIdUseCaseProvider).call(
            orderId: orderId,
            userId: userId,
          );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment received. Your order has been placed.'),
        ),
      );
      Navigator.of(context).popUntil(
        (route) =>
            route.settings.name == AppRoutes.restaurantDetails ||
            route.settings.name == AppRoutes.dashboard ||
            route.isFirst,
      );
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        settings: RouteSettings(
          name: AppRoutes.orderConfirmation,
          arguments: order,
        ),
        builder: (_) => OrderConfirmationScreen(order: order),
      ),
      (route) =>
          route.settings.name == AppRoutes.restaurantDetails ||
          route.settings.name == AppRoutes.dashboard ||
          route.isFirst,
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    super.key,
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final OrderPaymentMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  IconData get _icon {
    switch (method) {
      case OrderPaymentMethod.payOnDelivery:
        return Icons.payments_outlined;
      case OrderPaymentMethod.upi:
        return Icons.qr_code_2_rounded;
      case OrderPaymentMethod.creditCard:
      case OrderPaymentMethod.debitCard:
        return Icons.credit_card_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.25),
          ),
        ),
        child: ListTile(
          enabled: enabled,
          onTap: enabled ? onTap : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          title: Text(method.checkoutLabel),
          subtitle: Text(method.checkoutSubtitle),
          trailing: Icon(_icon, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Whether the order can be sent to the backend for pricing. It never holds
/// a delivery fee: the fee is the backend's, from the road distance.
class _FeePlan {
  const _FeePlan({
    this.canQuote = false,
    this.blockMessage,
  });

  final bool canQuote;
  final String? blockMessage;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 10),
            DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
