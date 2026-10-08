import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../serviceability/domain/geo_distance.dart';
import '../../../serviceability/domain/indian_pincode.dart';
import '../../domain/entities/saved_address_book.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/exceptions/location_exception.dart';
import '../../domain/location_hints.dart';
import '../providers/location_provider.dart';
import '../widgets/location_permission_dialog.dart';
import 'saved_addresses_screen.dart';

/// Chooses the customer's location.
///
/// Two modes share one map-confirmation step:
///
///  * the location selector (Home "Deliver To"): Use Current Location, search
///    any area / address, or pick a saved Home / Work / Other address or a
///    recently searched place;
///  * the checkout address editor: the same, plus door / street / pincode.
///
/// GPS or area search only picks an approximate starting point; the customer
/// then drags the map under a fixed center pin to confirm the exact delivery
/// location, since GPS/geocoding alone is not precise enough for delivery.
/// Confirmed coordinates are never shown as raw lat/lng.
class DeliveryAddressEditorScreen extends ConsumerStatefulWidget {
  const DeliveryAddressEditorScreen({
    super.key,
    this.initial,
    this.saveToProfile = true,
    this.requireAddressDetails = true,
  });

  final UserLocation? initial;

  /// When true, persists to the single `users/{uid}.location` slot after confirm.
  final bool saveToProfile;

  /// True (checkout): a complete order address — door and street included.
  /// False (Home "Deliver To"): the customer is only choosing WHERE to browse
  /// restaurants for — current location, any searched place confirmed on the
  /// map, or a saved address — so only the place itself (coordinates, city,
  /// state) is asked for. No pincode is requested: serviceability comes from
  /// the coordinates. Door and street are collected at checkout.
  final bool requireAddressDetails;

  @override
  ConsumerState<DeliveryAddressEditorScreen> createState() =>
      _DeliveryAddressEditorScreenState();
}

class _DeliveryAddressEditorScreenState
    extends ConsumerState<DeliveryAddressEditorScreen> {
  /// A confirmed pin this close to the GPS reading it started from is still
  /// "the phone's current location"; dragged further, it is a place the
  /// customer picked.
  static const double _devicePinToleranceKm = 0.05;

  /// Selector search runs this long after the customer stops typing, from
  /// this many characters.
  static const Duration _searchDebounce = Duration(milliseconds: 500);
  static const int _minSearchLength = 3;

  final _searchController = TextEditingController();
  final _doorController = TextEditingController();
  final _streetController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  UserLocation? _pinLocation;
  bool _busy = false;
  String? _error;

  /// Selector mode: the last search found nothing.
  bool _searchNotFound = false;

  /// Selector mode: matches for the current search (null = not searching).
  List<UserLocation>? _searchResults;
  bool _searching = false;
  int _searchSequence = 0;
  Timer? _searchTimer;

  // Map-confirmation step: shown after a GPS/search result is picked, before
  // it becomes the confirmed `_pinLocation`.
  bool _confirmingOnMap = false;
  UserLocation? _mapCandidate;
  LatLng? _cameraCenter;
  CameraPosition? _lastCameraPosition;
  bool _confirmBusy = false;

  /// Where the current pin came from. Live GPS stays followable; a searched
  /// area is pinned so discovery does not jump back to the phone.
  _PinOrigin _pinOrigin = _PinOrigin.existing;

  /// The GPS reading the pin started from, when [_pinOrigin] is GPS.
  UserLocation? _gpsReading;

  bool get _isSelector => !widget.requireAddressDetails;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _pinLocation = initial;
      _pinOrigin = initial.isLiveGpsDefault
          ? _PinOrigin.gps
          : _PinOrigin.existing;
      _doorController.text = initial.doorNumber;
      _streetController.text = initial.street;
      _areaController.text = initial.area;
      _cityController.text = initial.city;
      _stateController.text = initial.state;
      _pincodeController.text = initial.pincode ?? '';
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _doorController.dispose();
    _streetController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  /// Opens the map-confirmation step centered on [location], without
  /// finalizing it as the delivery pin yet.
  void _openMapFor(UserLocation location, {_PinOrigin? origin}) {
    if (origin != null) {
      _pinOrigin = origin;
    }
    final center = LatLng(location.latitude, location.longitude);
    setState(() {
      _mapCandidate = location;
      _cameraCenter = center;
      _lastCameraPosition = CameraPosition(target: center, zoom: 17);
      _confirmingOnMap = true;
      _confirmBusy = false;
      _error = null;
      _searchNotFound = false;
    });
  }

  Future<void> _useCurrentGps() async {
    setState(() {
      _busy = true;
      _error = null;
      _searchNotFound = false;
    });
    try {
      final location = await ref
          .read(locationSetupProvider.notifier)
          .readDeviceLocation();
      if (!mounted) {
        return;
      }
      _gpsReading = location;
      _openMapFor(location, origin: _PinOrigin.gps);
    } on LocationPermissionPermanentlyDeniedException {
      setState(() {
        _error = 'Location permission is required.';
        _busy = false;
      });
      if (_isSelector && mounted) {
        await showLocationPermissionDialog(context);
      }
    } on LocationPermissionDeniedException {
      setState(() => _error = 'Location permission is required.');
    } on LocationServiceDisabledException {
      setState(() {
        _error = 'Enable device location services to continue.';
        _busy = false;
      });
      if (_isSelector && mounted) {
        await showLocationServiceDisabledDialog(context);
      }
    } on LocationPositionUnavailableException {
      setState(() => _error = 'Unable to read your current location.');
    } on LocationGeocodingException {
      setState(() => _error = 'Unable to resolve your current location.');
    } catch (_) {
      setState(() => _error = 'Unable to use current location.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _searchArea() async {
    _searchTimer?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter an area or landmark to search.');
      return;
    }
    if (_isSelector) {
      await _searchPlaces(query);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _searchNotFound = false;
    });
    try {
      final location = await ref
          .read(deviceLocationServiceProvider)
          .searchArea(query);
      if (!mounted) {
        return;
      }
      _openMapFor(location, origin: _PinOrigin.search);
    } on LocationGeocodingException {
      setState(() => _error = 'No location found for that search.');
    } catch (_) {
      setState(() => _error = 'Unable to search that area.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Selector: search as the customer types, once they pause.
  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _clearSearch(keepText: true);
      return;
    }
    if (query.length < _minSearchLength) {
      return;
    }
    _searchTimer = Timer(_searchDebounce, () => _searchPlaces(query));
  }

  /// Selector: lists every place the geocoder offers for [query].
  Future<void> _searchPlaces(String query) async {
    final sequence = ++_searchSequence;
    setState(() {
      _searching = true;
      _error = null;
      _searchNotFound = false;
    });
    List<UserLocation> results = const [];
    String? error;
    try {
      results = await ref
          .read(deviceLocationServiceProvider)
          .searchPlaces(query);
    } on LocationGeocodingException {
      error = 'Unable to search that area.';
    } catch (_) {
      error = 'Unable to search that area.';
    }
    // A newer search (or a cleared field) has taken over.
    if (!mounted || sequence != _searchSequence) {
      return;
    }
    setState(() {
      _searching = false;
      _searchResults = results;
      _searchNotFound = error == null && results.isEmpty;
      _error = error;
    });
  }

  void _clearSearch({bool keepText = false}) {
    _searchTimer?.cancel();
    _searchSequence++;
    if (!keepText) {
      _searchController.clear();
    }
    setState(() {
      _searching = false;
      _searchResults = null;
      _searchNotFound = false;
      _error = null;
    });
  }

  Future<void> _openSavedAddresses() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
    );
  }

  /// Kilometres between the phone's last GPS reading and [latitude] /
  /// [longitude]; null when the phone's position is not known.
  double? _kmFromDevice(double latitude, double longitude) {
    final device = ref.read(currentGpsLocationProvider);
    if (device == null) {
      return null;
    }
    return GeoDistance.calculateDistanceKm(
      latitude1: device.latitude,
      longitude1: device.longitude,
      latitude2: latitude,
      longitude2: longitude,
    );
  }

  /// Asks the customer to confirm a place that is far from the phone. True
  /// when they want to continue with it.
  Future<bool> _confirmFarSelection() async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _FarLocationSheet(),
    );
    return proceed ?? false;
  }

  /// Confirms the current map center as the delivery pin, refreshing
  /// city/state/pincode/area for the dragged-to point (not the original
  /// searched/GPS coordinate).
  Future<void> _confirmMapSelection() async {
    final candidate = _mapCandidate;
    final center = _cameraCenter;
    if (candidate == null || center == null) {
      return;
    }

    if (_isSelector) {
      final km = _kmFromDevice(center.latitude, center.longitude);
      if (km != null && km >= LocationHints.farFromDeviceKm) {
        final proceed = await _confirmFarSelection();
        if (!mounted) {
          return;
        }
        if (!proceed) {
          // "No, select another location": back to the selector.
          _cancelMapConfirmation();
          return;
        }
      }
    }

    setState(() {
      _confirmBusy = true;
      _error = null;
    });

    String city = candidate.city;
    String state = candidate.state;
    String? pincode = candidate.pincode;
    String area = candidate.area;
    try {
      final resolved = await ref
          .read(deviceLocationServiceProvider)
          .reverseGeocode(
            latitude: center.latitude,
            longitude: center.longitude,
          );
      city = resolved.city;
      state = resolved.state;
      pincode = resolved.pincode;
      area = resolved.area;
    } catch (_) {
      // Keep the last known address text if this exact dropped point has no
      // indexed placemark; the confirmed lat/lng below is still
      // authoritative for delivery.
    }

    if (!mounted) {
      return;
    }

    final confirmed = candidate.copyWith(
      latitude: center.latitude,
      longitude: center.longitude,
      city: city,
      state: state,
      pincode: pincode,
      clearPincode: pincode == null,
      area: area,
    );

    setState(() {
      _pinLocation = confirmed;
      _cityController.text = city;
      _stateController.text = state;
      if (area.isNotEmpty || _isSelector) {
        _areaController.text = area;
      }
      // The pincode belongs to THIS pin: when the geocoder has none for the new
      // spot, the previous place's pincode must not linger and be saved with
      // the new coordinates.
      _pincodeController.text = pincode ?? '';
      _confirmingOnMap = false;
      _confirmBusy = false;
      _mapCandidate = null;
    });

    if (_isSelector) {
      // The selector has nothing more to ask: the confirmed pin IS the choice.
      await _save();
    }
  }

  void _cancelMapConfirmation() {
    setState(() {
      _confirmingOnMap = false;
      _mapCandidate = null;
    });
  }

  UserLocation? _buildDraft() {
    final pin = _pinLocation;
    if (pin == null) {
      return null;
    }
    final pincode = IndianPincode.normalize(_pincodeController.text);
    var door = _doorController.text.trim();
    var street = _streetController.text.trim();
    if (!widget.requireAddressDetails) {
      // Choosing a place to browse does not ask for door / street. Keep the
      // ones already saved only while the pin is still on the very same spot:
      // a different place must not inherit the old address's door / street.
      final initial = widget.initial;
      final sameSpot =
          initial != null &&
          initial.latitude == pin.latitude &&
          initial.longitude == pin.longitude;
      door = sameSpot ? initial.doorNumber : '';
      street = sameSpot ? initial.street : '';
    }
    return pin.copyWith(
      doorNumber: door,
      street: street,
      area: _areaController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: pincode,
      clearPincode: pincode == null,
      updatedAt: DateTime.now(),
    );
  }

  /// True when the confirmed [pin] is still the phone's own GPS position
  /// (Use Current Location, pin left where GPS put it).
  bool _isDevicePosition(UserLocation pin) {
    final reading = _gpsReading;
    if (_pinOrigin != _PinOrigin.gps || reading == null) {
      return false;
    }
    final km = GeoDistance.calculateDistanceKm(
      latitude1: reading.latitude,
      longitude1: reading.longitude,
      latitude2: pin.latitude,
      longitude2: pin.longitude,
    );
    return km != null && km <= _devicePinToleranceKm;
  }

  Future<void> _save() async {
    final draft = _buildDraft();
    if (draft == null) {
      setState(() => _error = 'Confirm a delivery pin first (GPS or search).');
      return;
    }
    final complete = widget.requireAddressDetails
        ? draft.isCompleteForCheckout
        : draft.isCompleteForDiscovery;
    if (!complete) {
      setState(() {
        _error = widget.requireAddressDetails
            ? (IndianPincode.validate(_pincodeController.text) ??
                  'Enter door number, street, city, state, and a valid pincode.')
            // Choosing a place never asks for a pincode: coordinates decide.
            : 'Unable to use this location. Try another area or landmark.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (widget.saveToProfile) {
        final userId = ref.read(currentUserIdProvider);
        if (userId == null) {
          setState(() => _error = 'Please login to save your address.');
          return;
        }
        await ref
            .read(locationSetupProvider.notifier)
            .selectLocation(
              userId: userId,
              location: draft,
              source: _isSelector && _isDevicePosition(draft)
                  ? LocationSource.deviceGps
                  : LocationSource.manualSelection,
              withAddressDetails: widget.requireAddressDetails,
            );
        if (_isSelector && _pinOrigin == _PinOrigin.search) {
          await ref
              .read(locationSetupProvider.notifier)
              .rememberSearchedPlace(userId, draft);
        }
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(draft);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to save this address.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Selector mode: a saved Home / Work / Other address becomes the active
  /// location because the customer tapped it — never on its own.
  Future<void> _selectSavedAddress(
    SavedAddressSlot slot,
    UserLocation address,
  ) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _error = 'Please login to use a saved address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _searchNotFound = false;
    });
    try {
      await ref
          .read(locationSetupProvider.notifier)
          .selectLocation(
            userId: userId,
            location: address,
            source: LocationSource.forSavedSlot(slot),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(address);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to use this saved address.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_confirmingOnMap && _cameraCenter != null) {
      body = _buildMapConfirmation(context, _cameraCenter!);
    } else if (_isSelector) {
      body = _buildSelector(context);
    } else {
      body = _buildForm(context);
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isSelector
              ? 'Select Your Location'
              : (widget.initial == null ? 'Add address' : 'Change address'),
        ),
        centerTitle: !_isSelector,
      ),
      body: body,
    );
  }

  Widget _buildMapConfirmation(BuildContext context, LatLng center) {
    final theme = Theme.of(context);
    final candidate = _mapCandidate;
    final device = ref.watch(currentGpsLocationProvider);
    final kmFromDevice = device == null
        ? null
        : GeoDistance.calculateDistanceKm(
            latitude1: device.latitude,
            longitude1: device.longitude,
            latitude2: center.latitude,
            longitude2: center.longitude,
          );
    final pinMoved =
        candidate != null &&
        (candidate.latitude != center.latitude ||
            candidate.longitude != center.longitude);
    final placeTitle = candidate == null
        ? ''
        : (candidate.area.trim().isNotEmpty
              ? candidate.area.trim()
              : candidate.city.trim());
    final placeAddress = candidate == null
        ? ''
        : [
            candidate.city.trim(),
            candidate.state.trim(),
            candidate.pincode?.trim() ?? '',
          ].where((part) => part.isNotEmpty).join(', ');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Move the map to adjust your delivery location',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _confirmBusy ? null : _cancelMapConfirmation,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            // Full width whatever the map view reports, so the overlays are
            // laid out against the screen and never clipped.
            fit: StackFit.expand,
            children: [
              GoogleMap(
                // A new starting point (e.g. "Current location") re-centres
                // the map; dragging does not rebuild it.
                key: ValueKey<String>(
                  '${candidate?.latitude},${candidate?.longitude}',
                ),
                initialCameraPosition: CameraPosition(target: center, zoom: 17),
                onCameraMove: (position) => _lastCameraPosition = position,
                onCameraIdle: () {
                  final position = _lastCameraPosition;
                  if (position == null) {
                    return;
                  }
                  setState(() => _cameraCenter = position.target);
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
              IgnorePointer(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: const Icon(
                      Icons.location_pin,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.94),
                child: Material(
                  color: AppColors.surface,
                  elevation: 2,
                  shadowColor: AppColors.shadow,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    onTap: _confirmBusy || _busy ? null : _useCurrentGps,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            'Current location',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.surface,
          elevation: 8,
          shadowColor: AppColors.shadow,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pinMoved
                        ? 'Place the pin at exact delivery location'
                        : 'Order will be delivered here',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (placeTitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            placeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (placeAddress.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      placeAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (kmFromDevice != null &&
                      kmFromDevice >= LocationHints.farFromDeviceKm) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                      ),
                      child: Text(
                        'This is ${GeoDistance.formatKmLabel(kmFromDevice)} '
                        'away from your current location',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: _confirmBusy ? null : _confirmMapSelection,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                    ),
                    child: _confirmBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textLight,
                            ),
                          )
                        : Text(
                            _isSelector
                                ? 'Confirm & proceed'
                                : 'Confirm delivery location',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Home "Deliver To": current location, search, a saved address, or a
  /// recently searched place.
  Widget _buildSelector(BuildContext context) {
    final theme = Theme.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final results = _searchResults;
    final showingSearch = results != null || _searching || _searchNotFound;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _searchArea(),
          decoration: InputDecoration(
            hintText: 'Search an area or address',
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            suffixIcon: showingSearch
                ? IconButton(
                    onPressed: _clearSearch,
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded),
                  )
                : IconButton(
                    onPressed: _busy ? null : _searchArea,
                    icon: const Icon(Icons.search_rounded),
                  ),
          ),
        ),
        if (showingSearch)
          ..._buildSearchResults(theme, results)
        else
          ..._buildSelectorHome(theme, userId),
      ],
    );
  }

  List<Widget> _buildSearchResults(
    ThemeData theme,
    List<UserLocation>? results,
  ) {
    if (_searchNotFound) {
      return [
        const SizedBox(height: AppSpacing.xxxl),
        const Icon(
          Icons.search_off_rounded,
          size: 72,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          "Uh, oh! We couldn't find this location",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Try searching for another\narea or landmark',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ];
    }
    return [
      const SizedBox(height: AppSpacing.xxl),
      _SectionLabel('SEARCH RESULTS', theme: theme),
      const SizedBox(height: AppSpacing.md),
      if (results == null || results.isEmpty)
        const Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        )
      else
        _SelectorCard(
          child: Column(
            children: [
              for (var i = 0; i < results.length; i++) ...[
                if (i > 0) const _TileDivider(),
                _PlaceTile(
                  icon: Icons.location_on_outlined,
                  place: results[i],
                  device: null,
                  onTap: () =>
                      _openMapFor(results[i], origin: _PinOrigin.search),
                ),
              ],
            ],
          ),
        ),
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.md),
        Text(_error!, style: const TextStyle(color: AppColors.error)),
      ],
    ];
  }

  List<Widget> _buildSelectorHome(ThemeData theme, String? userId) {
    final book = userId == null
        ? null
        : ref.watch(savedAddressBookProvider(userId)).valueOrNull;
    final recents = userId == null
        ? const <UserLocation>[]
        : ref.watch(recentLocationSearchesProvider(userId)).valueOrNull ??
              const <UserLocation>[];
    final device = ref.watch(currentGpsLocationProvider);
    final active = widget.initial;
    final saved = <(SavedAddressSlot, UserLocation)>[
      for (final slot in SavedAddressSlot.values)
        if (book?[slot] != null) (slot, book![slot]!),
    ];

    return [
      const SizedBox(height: AppSpacing.md),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.my_location_rounded,
                label: 'Use Current\nLocation',
                busy: _busy,
                onTap: _busy ? null : _useCurrentGps,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ActionTile(
                icon: Icons.add_box_outlined,
                label: 'Add New\nAddress',
                onTap: _busy ? null : _openSavedAddresses,
              ),
            ),
          ],
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.md),
        Text(_error!, style: const TextStyle(color: AppColors.error)),
      ],
      if (saved.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xxl),
        _SectionLabel('SAVED ADDRESSES', theme: theme),
        const SizedBox(height: AppSpacing.md),
        _SelectorCard(
          child: Column(
            children: [
              for (var i = 0; i < saved.length; i++) ...[
                if (i > 0) const _TileDivider(),
                _SavedAddressTile(
                  slot: saved[i].$1,
                  address: saved[i].$2,
                  device: device,
                  isActive:
                      active != null &&
                      active.latitude == saved[i].$2.latitude &&
                      active.longitude == saved[i].$2.longitude,
                  onTap: _busy
                      ? null
                      : () => _selectSavedAddress(saved[i].$1, saved[i].$2),
                ),
              ],
            ],
          ),
        ),
      ],
      if (recents.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xxl),
        _SectionLabel('RECENTLY SEARCHED', theme: theme),
        const SizedBox(height: AppSpacing.md),
        _SelectorCard(
          child: Column(
            children: [
              for (var i = 0; i < recents.length; i++) ...[
                if (i > 0) const _TileDivider(),
                _PlaceTile(
                  icon: Icons.history_rounded,
                  place: recents[i],
                  device: device,
                  onTap: _busy
                      ? null
                      : () =>
                            _openMapFor(recents[i], origin: _PinOrigin.search),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _buildForm(BuildContext context) {
    final pin = _pinLocation;
    final placeLabel = pin == null
        ? 'No location selected yet'
        : [
            if (pin.area.trim().isNotEmpty) pin.area.trim(),
            pin.city.trim(),
            pin.state.trim(),
          ].where((p) => p.isNotEmpty).join(', ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Confirm delivery pin',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Use your current location or search an area, then adjust the map '
          'pin to your exact delivery spot. GPS alone is not enough.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _useCurrentGps,
          icon: const Icon(Icons.my_location_rounded),
          label: const Text('Use current location'),
        ),
        const SizedBox(height: 10),
        Text(
          'Search New Location',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchArea(),
          decoration: InputDecoration(
            labelText: 'Search area / landmark',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: _busy ? null : _searchArea,
              icon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            leading: Icon(
              Icons.location_on_rounded,
              color: pin == null ? AppColors.textSecondary : AppColors.primary,
            ),
            title: Text(
              placeLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              pin == null
                  ? 'Select GPS or search to set the pin'
                  : 'Pin confirmed — enter door details below',
            ),
          ),
        ),
        if (pin != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : () => _openMapFor(pin),
              icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
              label: const Text('Adjust pin on map'),
            ),
          ),
        ],
        if (pin != null) ...[
          const SizedBox(height: 16),
          Text(
            'Delivery details',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _field(_doorController, 'Door / House number'),
          const SizedBox(height: 12),
          _field(_streetController, 'Street'),
          const SizedBox(height: 12),
          _field(_areaController, 'Area'),
          const SizedBox(height: 12),
          _field(_cityController, 'City'),
          const SizedBox(height: 12),
          _field(_stateController, 'State'),
          const SizedBox(height: 12),
          TextField(
            controller: _pincodeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'Pincode',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        if (pin != null) ...[
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textLight,
                    ),
                  )
                : Text(
                    widget.saveToProfile ? 'Save address' : 'Use this address',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

enum _PinOrigin { gps, search, existing }

class _SelectorCard extends StatelessWidget {
  const _SelectorCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: AppSpacing.lg,
      endIndent: AppSpacing.lg,
      color: AppColors.divider,
    );
  }
}

/// One of the square shortcuts under the search field.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return _SelectorCard(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 22,
                width: 22,
                child: busy
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      )
                    : Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A searched or recently searched place: name, then where it is.
class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.icon,
    required this.place,
    required this.device,
    required this.onTap,
  });

  final IconData icon;
  final UserLocation place;

  /// The phone's last GPS reading, for the "x km" badge. Null hides it.
  final UserLocation? device;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gps = device;
    final distance = gps == null
        ? null
        : GeoDistance.formatKmLabel(
            GeoDistance.calculateDistanceKm(
              latitude1: gps.latitude,
              longitude1: gps.longitude,
              latitude2: place.latitude,
              longitude2: place.longitude,
            ),
          );
    final title = place.area.trim().isNotEmpty
        ? place.area.trim()
        : place.city.trim();
    final subtitle = [
      place.city.trim(),
      place.state.trim(),
      place.pincode?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(', ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Icon(icon, size: 22, color: AppColors.textPrimary),
                  if (distance != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      distance,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Are you sure of the selected location?" — shown before a place far from
/// the phone becomes the delivery location.
class _FarLocationSheet extends StatelessWidget {
  const _FarLocationSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wrong_location_outlined,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Are you sure of the\nselected location?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your selected location seems to be a little far off from the '
              'device location',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textLight,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                ),
                child: const Text(
                  'No, select another location',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text(
                'Yes, continue with this location',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  const _SavedAddressTile({
    required this.slot,
    required this.address,
    required this.device,
    required this.isActive,
    required this.onTap,
  });

  final SavedAddressSlot slot;
  final UserLocation address;

  /// The phone's last GPS reading, for the "x km" badge. Null hides it.
  final UserLocation? device;
  final bool isActive;
  final VoidCallback? onTap;

  IconData get _icon {
    switch (slot) {
      case SavedAddressSlot.home:
        return Icons.home_outlined;
      case SavedAddressSlot.work:
        return Icons.work_outline_rounded;
      case SavedAddressSlot.other:
        return Icons.near_me_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gps = device;
    final distance = gps == null
        ? null
        : GeoDistance.formatKmLabel(
            GeoDistance.calculateDistanceKm(
              latitude1: gps.latitude,
              longitude1: gps.longitude,
              latitude2: address.latitude,
              longitude2: address.longitude,
            ),
          );
    final block = address.checkoutDisplayBlock.replaceAll('\n', ', ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Icon(_icon, size: 22, color: AppColors.textPrimary),
                  if (distance != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      distance,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    block.isNotEmpty ? block : address.displayAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppColors.freshGreen,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
