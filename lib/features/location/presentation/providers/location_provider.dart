import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/location_firestore_datasource.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../data/repositories/recent_location_repository_impl.dart';
import '../../data/services/device_location_service.dart';
import '../../data/repositories/saved_address_repository_impl.dart';
import '../../domain/entities/saved_address_book.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/exceptions/location_exception.dart';
import '../../domain/location_refresh_policy.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/repositories/recent_location_repository.dart';
import '../../domain/repositories/saved_address_repository.dart';
import '../../domain/usecases/get_user_location_usecase.dart';
import '../../domain/usecases/save_delivery_pincode_usecase.dart';
import '../../domain/usecases/save_user_location_usecase.dart';
import '../../domain/usecases/select_delivery_location_usecase.dart';

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final deviceLocationServiceProvider = Provider<DeviceLocationService>(
  (ref) => const DeviceLocationService(),
);

final locationFirestoreDatasourceProvider =
    Provider<LocationFirestoreDatasource>(
      (ref) => LocationFirestoreDatasource(ref.watch(firestoreProvider)),
    );

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) =>
      LocationRepositoryImpl(ref.watch(locationFirestoreDatasourceProvider)),
);

final getUserLocationUseCaseProvider = Provider<GetUserLocationUseCase>(
  (ref) => GetUserLocationUseCase(ref.watch(locationRepositoryProvider)),
);

final saveDeliveryPincodeUseCaseProvider = Provider<SaveDeliveryPincodeUseCase>(
  (ref) => SaveDeliveryPincodeUseCase(ref.watch(locationRepositoryProvider)),
);

final saveUserLocationUseCaseProvider = Provider<SaveUserLocationUseCase>(
  (ref) => SaveUserLocationUseCase(ref.watch(locationRepositoryProvider)),
);

final selectDeliveryLocationUseCaseProvider =
    Provider<SelectDeliveryLocationUseCase>(
      (ref) =>
          SelectDeliveryLocationUseCase(ref.watch(locationRepositoryProvider)),
    );

final locationRefreshPolicyProvider = Provider<LocationRefreshPolicy>(
  (ref) => const LocationRefreshPolicy(),
);

/// Loads the customer's ACTIVE location (`users/{uid}.location`) from
/// Firestore: the single source of truth that serviceability, restaurant
/// discovery, distance and delivery fee are worked out from. It is the phone's
/// GPS position, or a place the customer chose — see [LocationRefreshPolicy].
final userLocationProvider = FutureProvider.family<UserLocation?, String>((
  ref,
  userId,
) async {
  return ref.watch(getUserLocationUseCaseProvider).call(userId);
});

/// The phone's most recent GPS reading, kept in memory only.
///
/// Restaurant discovery and checkout never read this directly — they read the
/// active location ([userLocationProvider]), which [LocationSetupNotifier]
/// updates from each reading as [LocationRefreshPolicy] allows. This copy
/// exists so a customer's choice can record where the phone was, and so
/// screens can show how far a place is from the phone.
final currentGpsLocationProvider = StateProvider<UserLocation?>((ref) => null);

/// Whether the phone's current location could be read on the last attempt.
enum DeviceLocationStatus {
  /// No read has finished yet.
  unknown,

  /// GPS was read and resolved to an address.
  available,

  /// The customer declined the location permission (it can be asked again).
  permissionDenied,

  /// The permission is denied for good; only app settings can change it.
  permissionDeniedForever,

  /// Location services are switched off on the device.
  serviceDisabled,

  /// Permission and services are fine but no position / address came back.
  unavailable;

  /// True when the current location is known NOT to be available, so the UI
  /// must say so and offer manual selection instead of implying GPS.
  bool get isFailure =>
      this != DeviceLocationStatus.unknown &&
      this != DeviceLocationStatus.available;
}

/// Result of the most recent device-location read. The home header uses it to
/// say why the current location is not being used and what the customer can
/// do about it — a saved address is never passed off as the GPS location.
final deviceLocationStatusProvider = StateProvider<DeviceLocationStatus>(
  (ref) => DeviceLocationStatus.unknown,
);

/// Saved 6-digit delivery pincode, from location or the user document.
final deliveryPincodeProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) async {
  final location = await ref.watch(userLocationProvider(userId).future);
  if (location?.pincode != null) {
    return location!.pincode;
  }
  return ref.watch(locationRepositoryProvider).getDeliveryPincode(userId);
});

/// Owns every change to the customer's ACTIVE location.
///
/// GPS readings (app start, login, resume, movement) are applied as far as
/// [LocationRefreshPolicy] allows:
///
///  * an EXPLICIT selection (a searched / pinned place, or a saved Home /
///    Work / Other address the customer picked) is never touched by GPS — it
///    stays until the customer changes it;
///  * a GPS-derived location follows the phone;
///  * a LEGACY location (saved before the source was recorded) gives way to
///    the first valid GPS reading — so an old Home address is never shown as
///    the current location in another city. Its address is kept as a saved
///    shortcut;
///  * a replacement is always one coherent reading (stale pincode / door /
///    street / area cleared) — never merged into a stale typed address.
///
/// A place the customer picks goes through [selectLocation]. When GPS cannot
/// be read the active location is left exactly as it was and
/// [deviceLocationStatusProvider] says why.
///
/// There is ONE coordinated GPS flow: [initializeForStartup] on the splash
/// screen, then [refreshCurrentLocation] on resume and a single
/// [startWatching] stream while the app is open. Concurrent calls share one
/// read. Firestore is written only when the policy says so.
class LocationSetupNotifier extends StateNotifier<AsyncValue<void>> {
  LocationSetupNotifier(
    this._ref, {
    this.gpsRefreshInterval = const Duration(minutes: 2),
    this._policy = const LocationRefreshPolicy(),
  }) : super(const AsyncData(null));

  final Ref _ref;
  final LocationRefreshPolicy _policy;

  /// Minimum gap between two successful GPS refreshes on app resume, so
  /// lifecycle churn never turns into continuous tracking.
  final Duration gpsRefreshInterval;

  Future<void>? _inFlight;
  DateTime? _lastRefreshAt;
  StreamSubscription<UserLocation>? _gpsWatch;
  String? _watchedUserId;
  bool _startupReadAttempted = false;

  /// True once the startup flow has tried to read GPS in this app session
  /// (whatever the outcome), so the Home screen does not start a second read
  /// — or a second permission prompt — the moment it appears.
  bool get startupReadAttempted => _startupReadAttempted;

  /// Initialises the active location while the splash screen is showing, so
  /// Home opens with the right location instead of showing an old one and
  /// changing it a few seconds later.
  ///
  ///  * no active location, or a GPS-derived / legacy one → permission, GPS,
  ///    reverse geocoding, then the policy-guarded save;
  ///  * an EXPLICIT selection → kept as it is. Nothing is read here, so
  ///    startup is not delayed (the Home screen reads GPS afterwards, only
  ///    for status and distance hints).
  ///
  /// Never throws: on a GPS failure the active location is left as it was and
  /// the reason is in [deviceLocationStatusProvider].
  Future<void> initializeForStartup(String userId) async {
    try {
      final saved = await _ref
          .read(locationRepositoryProvider)
          .getUserLocation(userId);
      if (saved != null && saved.isExplicitSelection) {
        return;
      }
    } catch (_) {
      // The active location could not be read; fall through to GPS, which
      // re-reads it before deciding anything.
    }
    _startupReadAttempted = true;
    await refreshCurrentLocation(userId, force: true);
  }

  /// Runs the post-login location flow: permission, GPS, geocoding, then the
  /// policy-guarded save.
  ///
  /// Login reads the current location exactly like any other refresh, under
  /// the same [LocationRefreshPolicy]. Errors are kept in [state] so
  /// the UI can show the settings dialog for a permanently denied permission;
  /// other failures leave navigation free to continue with the saved location.
  Future<void> setupLocationAfterLogin(String userId) async {
    state = const AsyncLoading();
    _startupReadAttempted = true;

    state = await AsyncValue.guard(() => _applyCurrentLocation(userId));
  }

  /// One-shot refresh for app start / resume. Never throws: a GPS, geocoding
  /// or Firestore failure simply leaves the saved location as it was.
  ///
  /// Concurrent calls join the same in-flight read, and a successful refresh
  /// is not repeated inside [gpsRefreshInterval] unless [force] is set (the
  /// customer asked for it: Retry / Allow).
  Future<void> refreshCurrentLocation(String userId, {bool force = false}) {
    final pending = _inFlight;
    if (pending != null) {
      return pending;
    }
    final last = _lastRefreshAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < gpsRefreshInterval) {
      return Future<void>.value();
    }

    final run = _refreshQuietly(userId).whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }

  Future<void> _refreshQuietly(String userId) async {
    try {
      await _applyCurrentLocation(userId);
    } catch (_) {
      // GPS could not be read (the reason is in deviceLocationStatusProvider)
      // or the save failed: the active location stays exactly as it was.
    }
  }

  /// Reads the phone's current location for a screen that wants to offer it
  /// ("Use Current Location"), recording the outcome like any other read.
  /// Does not change the active location. Throws the [LocationException].
  Future<UserLocation> readDeviceLocation() async {
    final UserLocation current;
    try {
      current = await _ref
          .read(deviceLocationServiceProvider)
          .getCurrentUserLocation();
    } catch (error) {
      _setStatus(_statusFor(error));
      rethrow;
    }
    _setStatus(DeviceLocationStatus.available);
    _ref.read(currentGpsLocationProvider.notifier).state = current;
    return current;
  }

  /// Makes [location] the active location because the customer chose it.
  ///
  /// The ONE path for every customer choice: "Use Current Location"
  /// ([LocationSource.deviceGps]), a searched / pinned place, or a saved
  /// Home / Work / Other address. Anything but GPS is recorded as an EXPLICIT
  /// selection, which only the customer changes afterwards.
  /// [withAddressDetails] is the checkout address editor, which requires a
  /// complete door / street / pincode.
  Future<void> selectLocation({
    required String userId,
    required UserLocation location,
    required LocationSource source,
    bool withAddressDetails = false,
  }) async {
    if (withAddressDetails) {
      await _ref
          .read(saveUserLocationUseCaseProvider)
          .call(userId: userId, location: location, source: source);
    } else if (source == LocationSource.deviceGps) {
      await _ref
          .read(selectDeliveryLocationUseCaseProvider)
          .followCurrentLocation(userId: userId, location: location);
    } else {
      await _ref
          .read(selectDeliveryLocationUseCaseProvider)
          .call(userId: userId, location: location, source: source);
    }
    // Everything that depends on the active location — serviceability and
    // discovery — follows this provider.
    _ref.invalidate(userLocationProvider(userId));
    _ref.invalidate(deliveryPincodeProvider(userId));
  }

  /// The customer asked for their current location ("Use current location"):
  /// reads GPS and makes it the active location, replacing whatever was
  /// selected. Throws the [LocationException] when GPS cannot be read — the
  /// active location is then left untouched.
  Future<void> useCurrentLocation(String userId) async {
    final current = await readDeviceLocation();
    await selectLocation(
      userId: userId,
      location: current,
      source: LocationSource.deviceGps,
    );
  }

  /// Remembers a place the customer searched for and selected, for the
  /// selector's "Recently searched" list. Best effort: never throws.
  Future<void> rememberSearchedPlace(String userId, UserLocation place) async {
    try {
      await _ref
          .read(recentLocationRepositoryProvider)
          .addRecentSearch(userId: userId, location: place);
      _ref.invalidate(recentLocationSearchesProvider(userId));
    } catch (_) {
      // A shortcut list only; the selection itself already succeeded.
    }
  }

  /// Starts a single in-app GPS watch for [userId]. Duplicate starts are
  /// ignored. Permission errors are swallowed so the customer can still use
  /// saved addresses and Search New Location.
  void startWatching(String userId) {
    if (_gpsWatch != null && _watchedUserId == userId) {
      return;
    }
    stopWatching();
    _watchedUserId = userId;
    _gpsWatch = _ref
        .read(deviceLocationServiceProvider)
        .watchSignificantMoves()
        .listen(
          (current) {
            final uid = _watchedUserId;
            if (uid == null) {
              return;
            }
            unawaited(applyDeviceLocation(uid, current));
          },
          onError: (Object error) => _setStatus(_statusFor(error)),
          cancelOnError: false,
        );
  }

  void stopWatching() {
    _gpsWatch?.cancel();
    _gpsWatch = null;
    _watchedUserId = null;
  }

  /// Applies an already-read GPS point: updates in-memory current GPS, and
  /// writes `users/{uid}.location` only when [LocationRefreshPolicy] says so.
  Future<void> applyDeviceLocation(String userId, UserLocation current) async {
    _setStatus(DeviceLocationStatus.available);
    _ref.read(currentGpsLocationProvider.notifier).state = current;
    try {
      await _persistIfNeeded(userId, current);
    } catch (_) {
      // Streamed GPS is convenience data; a persist failure must not crash.
    }
  }

  Future<void> _applyCurrentLocation(String userId) async {
    final current = await readDeviceLocation();
    await _persistIfNeeded(userId, current);
  }

  void _setStatus(DeviceLocationStatus status) {
    if (!mounted) {
      return;
    }
    _ref.read(deviceLocationStatusProvider.notifier).state = status;
  }

  DeviceLocationStatus _statusFor(Object error) {
    if (error is LocationPermissionPermanentlyDeniedException) {
      return DeviceLocationStatus.permissionDeniedForever;
    }
    if (error is LocationPermissionDeniedException) {
      return DeviceLocationStatus.permissionDenied;
    }
    if (error is LocationServiceDisabledException) {
      return DeviceLocationStatus.serviceDisabled;
    }
    return DeviceLocationStatus.unavailable;
  }

  Future<void> _persistIfNeeded(String userId, UserLocation current) async {
    _lastRefreshAt = DateTime.now();

    final repository = _ref.read(locationRepositoryProvider);
    final saved = await repository.getUserLocation(userId);

    if (saved != null) {
      if (!_policy.shouldReplace(saved: saved, current: current)) {
        // An explicit selection: only the customer changes it.
        return;
      }
      if (!_policy.isSignificantChange(saved: saved, current: current)) {
        return;
      }
      // A legacy address is about to give way to GPS: keep it reachable.
      await _keepLegacyAddressAsShortcut(userId, saved);
    }

    await repository.saveUserLocation(
      userId: userId,
      location: current.copyWith(
        source: LocationSource.deviceGps,
        selectedByCustomer: false,
      ),
      clearStaleAddressDetails: _policy.shouldClearStaleAddressDetails(
        saved: saved,
        current: current,
      ),
    );

    _ref.invalidate(userLocationProvider(userId));
    _ref.invalidate(deliveryPincodeProvider(userId));
  }

  /// Before GPS replaces a LEGACY active location that holds a complete
  /// address, stores that address in the customer's saved addresses (Home if
  /// empty, otherwise Other if empty) unless it is already there — so the
  /// door / street the customer typed is not lost and stays one tap away.
  /// Nothing is overwritten.
  Future<void> _keepLegacyAddressAsShortcut(
    String userId,
    UserLocation saved,
  ) async {
    if (!saved.isLegacyAddress || !saved.isCompleteForCheckout) {
      return;
    }
    final addresses = _ref.read(savedAddressRepositoryProvider);
    final book = await addresses.getSavedAddresses(userId);
    if (book.matchingSlot(saved) != null) {
      return;
    }
    for (final slot in const [SavedAddressSlot.home, SavedAddressSlot.other]) {
      if (book[slot] == null) {
        await addresses.saveAddress(
          userId: userId,
          slot: slot,
          location: saved,
        );
        _ref.invalidate(savedAddressBookProvider(userId));
        return;
      }
    }
  }

  @override
  void dispose() {
    stopWatching();
    super.dispose();
  }
}

final locationSetupProvider =
    StateNotifierProvider<LocationSetupNotifier, AsyncValue<void>>(
      (ref) => LocationSetupNotifier(ref),
    );

final savedAddressRepositoryProvider = Provider<SavedAddressRepository>(
  (ref) => SavedAddressRepositoryImpl(
    ref.watch(locationFirestoreDatasourceProvider),
  ),
);

final savedAddressBookProvider =
    FutureProvider.family<SavedAddressBook, String>((ref, userId) {
      return ref
          .watch(savedAddressRepositoryProvider)
          .getSavedAddresses(userId);
    });

final recentLocationRepositoryProvider = Provider<RecentLocationRepository>(
  (ref) => RecentLocationRepositoryImpl(
    ref.watch(locationFirestoreDatasourceProvider),
  ),
);

/// Places the customer recently searched for and selected, newest first.
final recentLocationSearchesProvider =
    FutureProvider.family<List<UserLocation>, String>((ref, userId) {
      return ref
          .watch(recentLocationRepositoryProvider)
          .getRecentSearches(userId);
    });
