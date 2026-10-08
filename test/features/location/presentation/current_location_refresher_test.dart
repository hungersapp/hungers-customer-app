import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show StringCodec;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/location/data/services/device_location_service.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/exceptions/location_exception.dart';
import 'package:customer_app/features/location/domain/repositories/location_repository.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/location/domain/entities/saved_address_book.dart';
import 'package:customer_app/features/location/presentation/widgets/current_location_refresher.dart';

import '../../../helpers/destination_fakes.dart';

const _userId = 'user-1';

/// Stands in for GPS + reverse geocoding so tests control what the phone
/// "currently" reports, without touching geolocator/geocoding plugins.
class _FakeDeviceLocationService implements DeviceLocationService {
  _FakeDeviceLocationService({required this.location, this.error, this.gate});

  UserLocation location;
  Object? error;

  /// When set, the GPS read only finishes once the test completes it, so two
  /// refreshes can be kept in flight at the same time.
  Completer<void>? gate;
  int getCurrentUserLocationCallCount = 0;
  Stream<UserLocation> moves = const Stream.empty();
  int watchStartCount = 0;
  Object? watchError;

  @override
  Future<UserLocation> getCurrentUserLocation() async {
    getCurrentUserLocationCallCount += 1;
    final pending = gate;
    if (pending != null) {
      await pending.future;
    }
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return location;
  }

  @override
  Future<void> ensurePermission() async {}

  @override
  Future<({double latitude, double longitude})> getCurrentCoordinates() {
    throw UnimplementedError();
  }

  @override
  Future<({String city, String state, String? pincode, String area})>
  reverseGeocode({required double latitude, required double longitude}) {
    throw UnimplementedError();
  }

  @override
  Future<List<UserLocation>> searchPlaces(String query) =>
      throw UnimplementedError();

  @override
  Future<UserLocation> searchArea(String query) {
    throw UnimplementedError();
  }

  @override
  Stream<UserLocation> watchSignificantMoves({int distanceFilterMeters = 200}) {
    watchStartCount += 1;
    final failure = watchError;
    if (failure != null) {
      return Stream.error(failure);
    }
    return moves;
  }
}

/// In-memory stand-in for the Firestore-backed `users/{uid}.location` document.
class _InMemoryLocationRepository implements LocationRepository {
  _InMemoryLocationRepository(this._stored);

  UserLocation? _stored;
  final List<UserLocation> savedLocations = [];

  /// The `clearStaleAddressDetails` flag of each save, in order.
  final List<bool> clearFlags = [];

  @override
  Future<UserLocation?> getUserLocation(String userId) async => _stored;

  @override
  Future<void> saveUserLocation({
    required String userId,
    required UserLocation location,
    bool clearStaleAddressDetails = false,
  }) async {
    savedLocations.add(location);
    clearFlags.add(clearStaleAddressDetails);
    _stored = location;
  }

  @override
  Future<String?> getDeliveryPincode(String userId) async => _stored?.pincode;

  @override
  Future<void> saveDeliveryPincode({
    required String userId,
    required String pincode,
  }) async {}
}

UserLocation _location({
  required String city,
  String state = 'Tamil Nadu',
  double latitude = 9.9195,
  double longitude = 78.1193,
  String? pincode = '625020',
  String doorNumber = '',
  String street = '',
  LocationSource? source,
}) {
  return UserLocation(
    latitude: latitude,
    longitude: longitude,
    city: city,
    state: state,
    pincode: pincode,
    doorNumber: doorNumber,
    street: street,
    selectedByCustomer: source?.isCustomerSelected ?? false,
    source: source,
    updatedAt: DateTime(2026, 1, 1),
  );
}

final _nativeLocation = _location(city: 'Madurai');

final _travelledLocation = _location(
  city: 'Bengaluru',
  state: 'Karnataka',
  latitude: 12.9716,
  longitude: 77.5946,
  pincode: '560001',
);

Future<void> _setLifecycleState(AppLifecycleState state) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage(state.toString()),
        (_) {},
      );
}

/// Sends the platform lifecycle sequence for backgrounding the app and
/// bringing it back to the foreground.
Future<void> _backgroundThenResume(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    await _setLifecycleState(state);
  }
  await tester.pumpAndSettle();
}

void main() {
  /// The saved Home / Work / Other slots behind the container last built.
  late FakeSavedAddressRepository savedAddresses;

  ProviderContainer buildContainer({
    required _FakeDeviceLocationService service,
    required _InMemoryLocationRepository repository,
    String? userId = _userId,
    Duration gpsRefreshInterval = Duration.zero,
    SavedAddressBook book = const SavedAddressBook(),
  }) {
    savedAddresses = FakeSavedAddressRepository(book);
    final container = ProviderContainer(
      overrides: [
        savedAddressRepositoryProvider.overrideWithValue(savedAddresses),
        currentUserIdProvider.overrideWithValue(userId),
        deviceLocationServiceProvider.overrideWithValue(service),
        locationRepositoryProvider.overrideWithValue(repository),
        locationSetupProvider.overrideWith(
          (ref) => LocationSetupNotifier(
            ref,
            gpsRefreshInterval: gpsRefreshInterval,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Keeps the home-screen provider alive exactly like DashboardAppBar /
    // RestaurantSection watching it.
    container.listen<AsyncValue<UserLocation?>>(
      userLocationProvider(_userId),
      (_, _) {},
      fireImmediately: true,
    );
    return container;
  }

  Future<void> pumpRefresher(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CurrentLocationRefresher(
            child: Scaffold(body: Text('dashboard')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'returning user opening the app persists and exposes the current GPS city',
    (tester) async {
      final service = _FakeDeviceLocationService(location: _travelledLocation);
      final repository = _InMemoryLocationRepository(_nativeLocation);
      final container = buildContainer(
        service: service,
        repository: repository,
      );

      expect(
        (await container.read(userLocationProvider(_userId).future))?.city,
        'Madurai',
      );

      await pumpRefresher(tester, container);

      expect(service.getCurrentUserLocationCallCount, 1);
      expect(repository.savedLocations.single.city, 'Bengaluru');
      expect(
        container.read(userLocationProvider(_userId)).value?.city,
        'Bengaluru',
      );
      // Restaurant discovery / distance reads the same provider value.
      expect(
        container.read(userLocationProvider(_userId)).value?.latitude,
        12.9716,
      );
      // Serviceability keeps its own rules, but now on the current pincode.
      expect(
        await container.read(deliveryPincodeProvider(_userId).future),
        '560001',
      );
    },
  );

  testWidgets('resuming from the background refreshes the location again', (
    tester,
  ) async {
    final service = _FakeDeviceLocationService(location: _nativeLocation);
    final repository = _InMemoryLocationRepository(_nativeLocation);
    final container = buildContainer(service: service, repository: repository);

    await pumpRefresher(tester, container);
    expect(service.getCurrentUserLocationCallCount, 1);

    service.location = _travelledLocation;
    await _backgroundThenResume(tester);

    expect(service.getCurrentUserLocationCallCount, 2);
    expect(repository.savedLocations.last.city, 'Bengaluru');
    expect(
      container.read(userLocationProvider(_userId)).value?.city,
      'Bengaluru',
    );
  });

  testWidgets(
    'repeated resume events inside the refresh interval do not poll',
    (tester) async {
      final service = _FakeDeviceLocationService(location: _travelledLocation);
      final repository = _InMemoryLocationRepository(_nativeLocation);
      final container = buildContainer(
        service: service,
        repository: repository,
        gpsRefreshInterval: const Duration(minutes: 2),
      );

      await pumpRefresher(tester, container);
      await _backgroundThenResume(tester);
      await _backgroundThenResume(tester);

      expect(service.getCurrentUserLocationCallCount, 1);
    },
  );

  // Plain `test` on purpose: this exercises the notifier's guard directly, so
  // it needs real async rather than the widget binding's fake clock.
  test('concurrent refreshes share a single GPS read', () async {
    final gate = Completer<void>();
    final service = _FakeDeviceLocationService(
      location: _travelledLocation,
      gate: gate,
    );
    final repository = _InMemoryLocationRepository(_nativeLocation);
    final container = buildContainer(service: service, repository: repository);

    final notifier = container.read(locationSetupProvider.notifier);
    final first = notifier.refreshCurrentLocation(_userId);
    final second = notifier.refreshCurrentLocation(_userId);
    await Future<void>.delayed(Duration.zero);

    expect(service.getCurrentUserLocationCallCount, 1);

    gate.complete();
    await first;
    await second;

    expect(service.getCurrentUserLocationCallCount, 1);
    expect(repository.savedLocations.length, 1);
  });

  for (final MapEntry(key: failure, value: expectedStatus)
      in <LocationException, DeviceLocationStatus>{
        LocationPermissionDeniedException():
            DeviceLocationStatus.permissionDenied,
        LocationPermissionPermanentlyDeniedException():
            DeviceLocationStatus.permissionDeniedForever,
        LocationServiceDisabledException():
            DeviceLocationStatus.serviceDisabled,
        LocationPositionUnavailableException():
            DeviceLocationStatus.unavailable,
        LocationGeocodingException(): DeviceLocationStatus.unavailable,
      }.entries) {
    testWidgets('keeps the stored location, stays usable and reports why on '
        '${failure.runtimeType}', (tester) async {
      final service = _FakeDeviceLocationService(
        location: _travelledLocation,
        error: failure,
      );
      final repository = _InMemoryLocationRepository(_nativeLocation);
      final container = buildContainer(
        service: service,
        repository: repository,
      );

      await pumpRefresher(tester, container);

      expect(tester.takeException(), isNull);
      expect(find.text('dashboard'), findsOneWidget);
      expect(repository.savedLocations, isEmpty);
      expect(
        container.read(userLocationProvider(_userId)).value?.city,
        'Madurai',
      );
      // The reason is exposed so the UI can offer the fix or manual
      // selection instead of implying the location is current.
      expect(container.read(deviceLocationStatusProvider), expectedStatus);
      expect(container.read(deviceLocationStatusProvider).isFailure, isTrue);
    });
  }

  testWidgets(
    'when GPS is unavailable a previously selected location stays active — '
    'it is not swapped for anything else',
    (tester) async {
      final selected = _location(
        city: 'Madurai',
        doorNumber: '12A',
        street: 'Bypass Road',
        source: LocationSource.savedHome,
      );
      final service = _FakeDeviceLocationService(
        location: _travelledLocation,
        error: const LocationPermissionDeniedException(),
      );
      final repository = _InMemoryLocationRepository(selected);
      final container = buildContainer(
        service: service,
        repository: repository,
      );

      await pumpRefresher(tester, container);
      await _backgroundThenResume(tester);

      expect(repository.savedLocations, isEmpty);
      final active = container.read(userLocationProvider(_userId)).value;
      expect(active?.city, 'Madurai');
      expect(active?.doorNumber, '12A');
    },
  );

  testWidgets('a successful read after a failure clears the failure status', (
    tester,
  ) async {
    final service = _FakeDeviceLocationService(
      location: _nativeLocation,
      error: const LocationServiceDisabledException(),
    );
    final repository = _InMemoryLocationRepository(_nativeLocation);
    final container = buildContainer(service: service, repository: repository);

    await pumpRefresher(tester, container);
    expect(
      container.read(deviceLocationStatusProvider),
      DeviceLocationStatus.serviceDisabled,
    );

    // The customer turns location on and returns to the app.
    service
      ..error = null
      ..location = _travelledLocation;
    await _backgroundThenResume(tester);

    expect(
      container.read(deviceLocationStatusProvider),
      DeviceLocationStatus.available,
    );
    expect(
      container.read(userLocationProvider(_userId)).value?.city,
      'Bengaluru',
    );
  });

  testWidgets('a Firestore failure during refresh does not crash the app', (
    tester,
  ) async {
    final service = _FakeDeviceLocationService(location: _travelledLocation);
    final repository = _ThrowingLocationRepository();
    final container = buildContainer(service: service, repository: repository);

    await pumpRefresher(tester, container);

    expect(tester.takeException(), isNull);
    expect(find.text('dashboard'), findsOneWidget);
  });

  group('location decision — explicit vs legacy', () {
    /// ~3.4 km from the Madurai addresses used below: well over 1 km.
    UserLocation movedAcrossTown() =>
        _location(city: 'Madurai', latitude: 9.95, pincode: '625002');

    UserLocation address(LocationSource? source) => _location(
      city: 'Madurai',
      doorNumber: '12A',
      street: 'Bypass Road',
      source: source,
    );

    // Test 1 — the production bug.
    testWidgets('Test 1: a LEGACY Home location + the customer travels more '
        'than 1 km → GPS replaces it, and Home stays a saved shortcut', (
      tester,
    ) async {
      for (final current in [movedAcrossTown(), _travelledLocation]) {
        final service = _FakeDeviceLocationService(location: current);
        final repository = _InMemoryLocationRepository(address(null));
        final container = buildContainer(
          service: service,
          repository: repository,
        );

        await pumpRefresher(tester, container);

        final active = container.read(userLocationProvider(_userId)).value;
        expect(active?.latitude, current.latitude);
        expect(active?.longitude, current.longitude);
        expect(active?.city, current.city);
        expect(active?.source, LocationSource.deviceGps);
        expect(active?.isExplicitSelection, isFalse);
        // One coherent GPS reading: nothing of the Home address rides along.
        expect(active?.doorNumber, isEmpty);
        expect(active?.street, isEmpty);
        expect(repository.clearFlags.single, isTrue);
        // The address the customer typed is kept, one tap away.
        expect(savedAddresses.book.home?.doorNumber, '12A');
        expect(savedAddresses.book.home?.street, 'Bypass Road');

        await tester.pumpWidget(const SizedBox());
      }
    });

    for (final (number, label, source) in [
      (2, 'Home', LocationSource.savedHome),
      (3, 'Work', LocationSource.savedWork),
      (4, 'a searched delivery address', LocationSource.manualSelection),
    ]) {
      testWidgets('Test $number: explicitly selected $label + the customer '
          'travels more than 1 km → it remains active', (tester) async {
        for (final current in [movedAcrossTown(), _travelledLocation]) {
          final service = _FakeDeviceLocationService(location: current);
          final repository = _InMemoryLocationRepository(address(source));
          final container = buildContainer(
            service: service,
            repository: repository,
          );

          // Launch, then a resume, then movement while the app is open.
          await pumpRefresher(tester, container);
          await _backgroundThenResume(tester);
          await container
              .read(locationSetupProvider.notifier)
              .applyDeviceLocation(_userId, current);
          await tester.pumpAndSettle();

          expect(service.getCurrentUserLocationCallCount, greaterThan(0));
          expect(repository.savedLocations, isEmpty);
          final active = container.read(userLocationProvider(_userId)).value;
          expect(active?.city, 'Madurai');
          expect(active?.latitude, 9.9195);
          expect(active?.doorNumber, '12A');
          expect(active?.source, source);
          // GPS is known (for distance hints) — it just does not take over.
          expect(
            container.read(currentGpsLocationProvider)?.city,
            current.city,
          );

          await tester.pumpWidget(const SizedBox());
        }
      });
    }

    testWidgets('Test 5: the customer taps "Use Current Location" → GPS '
        'becomes active, and keeps following the phone afterwards', (
      tester,
    ) async {
      final service = _FakeDeviceLocationService(location: movedAcrossTown());
      final repository = _InMemoryLocationRepository(
        address(LocationSource.savedHome),
      );
      final container = buildContainer(
        service: service,
        repository: repository,
      );
      await pumpRefresher(tester, container);
      expect(repository.savedLocations, isEmpty);

      await container
          .read(locationSetupProvider.notifier)
          .useCurrentLocation(_userId);
      await tester.pumpAndSettle();

      var active = container.read(userLocationProvider(_userId)).value;
      expect(active?.latitude, 9.95);
      expect(active?.source, LocationSource.deviceGps);
      expect(active?.isExplicitSelection, isFalse);
      expect(active?.doorNumber, isEmpty);

      // Having chosen the current location, the next launch / resume in
      // another city follows GPS there.
      service.location = _travelledLocation;
      await _backgroundThenResume(tester);

      active = container.read(userLocationProvider(_userId)).value;
      expect(active?.city, 'Bengaluru');
      expect(active?.source, LocationSource.deviceGps);
    });

    testWidgets('Test 6: the app resumes after UPI / payment / a browser → '
        'the explicitly selected delivery location is unchanged', (
      tester,
    ) async {
      // Delivering to an address 8+ km from where the phone is.
      final service = _FakeDeviceLocationService(
        location: _location(city: 'Madurai', latitude: 9.9915),
      );
      final selected = address(LocationSource.manualSelection);
      final repository = _InMemoryLocationRepository(selected);
      final container = buildContainer(
        service: service,
        repository: repository,
      );
      await pumpRefresher(tester, container);

      // Leave for the payment app and come back, several times.
      for (var i = 0; i < 3; i++) {
        await _backgroundThenResume(tester);
      }

      expect(service.getCurrentUserLocationCallCount, greaterThan(1));
      expect(repository.savedLocations, isEmpty);
      expect(container.read(userLocationProvider(_userId)).value, selected);
    });

    testWidgets('Test 7: GPS permission denied → the explicit location stays '
        'active and the status is reported for the banner', (tester) async {
      for (final failure in <LocationException>[
        const LocationPermissionDeniedException(),
        const LocationPermissionPermanentlyDeniedException(),
      ]) {
        final service = _FakeDeviceLocationService(
          location: _travelledLocation,
          error: failure,
        );
        final selected = address(LocationSource.savedHome);
        final repository = _InMemoryLocationRepository(selected);
        final container = buildContainer(
          service: service,
          repository: repository,
        );

        await pumpRefresher(tester, container);

        expect(repository.savedLocations, isEmpty);
        expect(container.read(userLocationProvider(_userId)).value, selected);
        expect(container.read(deviceLocationStatusProvider).isFailure, isTrue);

        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('Test 8: GPS unavailable (services off / no fix) → the '
        'explicit location stays active', (tester) async {
      for (final failure in <LocationException>[
        const LocationServiceDisabledException(),
        const LocationPositionUnavailableException(),
        const LocationGeocodingException(),
      ]) {
        final service = _FakeDeviceLocationService(
          location: _travelledLocation,
          error: failure,
        );
        final selected = address(LocationSource.manualSelection);
        final repository = _InMemoryLocationRepository(selected);
        final container = buildContainer(
          service: service,
          repository: repository,
        );

        await pumpRefresher(tester, container);
        await _backgroundThenResume(tester);

        expect(repository.savedLocations, isEmpty);
        expect(container.read(userLocationProvider(_userId)).value, selected);
        expect(container.read(deviceLocationStatusProvider).isFailure, isTrue);

        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('Test 9: a legacy location + a fresh valid GPS reading → GPS '
        'becomes active, even when the phone has not moved', (tester) async {
      // The phone is AT the legacy address: the reading still takes over, so
      // the location is recorded as GPS and follows the phone from now on.
      final service = _FakeDeviceLocationService(location: _nativeLocation);
      final repository = _InMemoryLocationRepository(address(null));
      final container = buildContainer(
        service: service,
        repository: repository,
      );

      await pumpRefresher(tester, container);

      final active = container.read(userLocationProvider(_userId)).value;
      expect(active?.source, LocationSource.deviceGps);
      expect(active?.latitude, _nativeLocation.latitude);
      expect(active?.doorNumber, isEmpty);
      expect(savedAddresses.book.home?.doorNumber, '12A');
    });

    testWidgets('a legacy address already saved as Home / Work is not saved a '
        'second time, and nothing saved is overwritten', (tester) async {
      final legacy = address(null);
      final otherHome = _location(
        city: 'Madurai',
        latitude: 9.90,
        doorNumber: '7',
        street: 'West Street',
      );

      // Already the saved Work address.
      var repository = _InMemoryLocationRepository(legacy);
      var container = buildContainer(
        service: _FakeDeviceLocationService(location: _travelledLocation),
        repository: repository,
        book: SavedAddressBook(work: legacy),
      );
      await pumpRefresher(tester, container);
      expect(repository.savedLocations.single.city, 'Bengaluru');
      expect(savedAddresses.book.home, isNull);
      expect(savedAddresses.book.other, isNull);
      await tester.pumpWidget(const SizedBox());

      // Home is taken by a different address: it goes to Other instead.
      repository = _InMemoryLocationRepository(legacy);
      container = buildContainer(
        service: _FakeDeviceLocationService(location: _travelledLocation),
        repository: repository,
        book: SavedAddressBook(home: otherHome),
      );
      await pumpRefresher(tester, container);
      expect(savedAddresses.book.home?.doorNumber, '7');
      expect(savedAddresses.book.other?.doorNumber, '12A');
    });
  });

  testWidgets(
    'a GPS refresh never mixes fresh coordinates with a stale typed address',
    (tester) async {
      // A GPS-derived default whose pincode the customer typed by hand, then
      // the phone travels to another city whose reverse geocode has no postal
      // code. The new place must not inherit the old pincode.
      final service = _FakeDeviceLocationService(
        location: _location(
          city: 'Bengaluru',
          state: 'Karnataka',
          latitude: 12.9716,
          longitude: 77.5946,
          pincode: null,
        ),
      );
      final repository = _InMemoryLocationRepository(
        _location(city: 'Madurai', pincode: '625020'),
      );
      final container = buildContainer(
        service: service,
        repository: repository,
      );

      await pumpRefresher(tester, container);

      expect(repository.savedLocations.single.city, 'Bengaluru');
      expect(repository.clearFlags.single, isTrue);
    },
  );

  testWidgets(
    'the same place keeps merging so a typed pincode survives a refresh',
    (tester) async {
      final service = _FakeDeviceLocationService(
        location: _location(
          city: 'Madurai',
          latitude: 9.93,
          longitude: 78.12,
          pincode: null,
        ),
      );
      final repository = _InMemoryLocationRepository(
        _location(city: 'Madurai', pincode: '625020'),
      );
      final container = buildContainer(
        service: service,
        repository: repository,
      );

      await pumpRefresher(tester, container);

      expect(repository.savedLocations, hasLength(1));
      expect(repository.clearFlags.single, isFalse);
    },
  );

  testWidgets('a few metres of GPS drift does not rewrite the saved location', (
    tester,
  ) async {
    final service = _FakeDeviceLocationService(
      location: _location(city: 'Madurai', latitude: 9.9200),
    );
    final repository = _InMemoryLocationRepository(_nativeLocation);
    final container = buildContainer(service: service, repository: repository);

    await pumpRefresher(tester, container);

    expect(service.getCurrentUserLocationCallCount, 1);
    expect(repository.savedLocations, isEmpty);
  });

  testWidgets('the first ever refresh seeds the current-location default', (
    tester,
  ) async {
    final service = _FakeDeviceLocationService(location: _nativeLocation);
    final repository = _InMemoryLocationRepository(null);
    final container = buildContainer(service: service, repository: repository);

    await pumpRefresher(tester, container);

    expect(repository.savedLocations.single.city, 'Madurai');
    expect(repository.clearFlags.single, isFalse);
  });

  group('login (setupLocationAfterLogin)', () {
    test('logging in from another city uses the current location, not a '
        'legacy address saved back home', () async {
      final service = _FakeDeviceLocationService(location: _travelledLocation);
      final repository = _InMemoryLocationRepository(
        _location(city: 'Madurai', doorNumber: '12A', street: 'Bypass Road'),
      );
      final container = buildContainer(
        service: service,
        repository: repository,
      );

      await container
          .read(locationSetupProvider.notifier)
          .setupLocationAfterLogin(_userId);

      expect(service.getCurrentUserLocationCallCount, 1);
      expect(repository.savedLocations.single.city, 'Bengaluru');
      expect(
        (await container.read(userLocationProvider(_userId).future))?.city,
        'Bengaluru',
      );
      expect(container.read(locationSetupProvider).hasError, isFalse);
    });

    test(
      'logging in does not replace an explicitly selected address',
      () async {
        final service = _FakeDeviceLocationService(
          location: _travelledLocation,
        );
        final repository = _InMemoryLocationRepository(
          _location(
            city: 'Madurai',
            doorNumber: '12A',
            street: 'Bypass Road',
            source: LocationSource.savedHome,
          ),
        );
        final container = buildContainer(
          service: service,
          repository: repository,
        );

        await container
            .read(locationSetupProvider.notifier)
            .setupLocationAfterLogin(_userId);

        expect(repository.savedLocations, isEmpty);
        expect(
          (await container.read(
            userLocationProvider(_userId).future,
          ))?.doorNumber,
          '12A',
        );
      },
    );

    test(
      'still seeds the current-location default for a first-time user',
      () async {
        final service = _FakeDeviceLocationService(location: _nativeLocation);
        final repository = _InMemoryLocationRepository(null);
        final container = buildContainer(
          service: service,
          repository: repository,
        );

        await container
            .read(locationSetupProvider.notifier)
            .setupLocationAfterLogin(_userId);

        expect(repository.savedLocations.single.city, 'Madurai');
      },
    );

    test(
      'surfaces a GPS failure in state (for the settings dialog) without touching the saved destination',
      () async {
        final service = _FakeDeviceLocationService(
          location: _travelledLocation,
          error: const LocationPermissionPermanentlyDeniedException(),
        );
        final repository = _InMemoryLocationRepository(
          _location(city: 'Madurai', doorNumber: '12A', street: 'Bypass Road'),
        );
        final container = buildContainer(
          service: service,
          repository: repository,
        );

        await container
            .read(locationSetupProvider.notifier)
            .setupLocationAfterLogin(_userId);

        expect(
          container.read(locationSetupProvider).error,
          isA<LocationPermissionPermanentlyDeniedException>(),
        );
        expect(repository.savedLocations, isEmpty);
      },
    );

    test('a login read counts toward the refresh throttle', () async {
      final service = _FakeDeviceLocationService(location: _nativeLocation);
      final repository = _InMemoryLocationRepository(_nativeLocation);
      final container = buildContainer(
        service: service,
        repository: repository,
        gpsRefreshInterval: const Duration(minutes: 2),
      );

      final notifier = container.read(locationSetupProvider.notifier);
      await notifier.setupLocationAfterLogin(_userId);
      await notifier.refreshCurrentLocation(_userId);

      // The dashboard's first refresh right after login must not read GPS again.
      expect(service.getCurrentUserLocationCallCount, 1);
    });
  });

  testWidgets('no GPS read happens without an authenticated user', (
    tester,
  ) async {
    final service = _FakeDeviceLocationService(location: _travelledLocation);
    final repository = _InMemoryLocationRepository(_nativeLocation);
    final container = buildContainer(
      service: service,
      repository: repository,
      userId: null,
    );

    await pumpRefresher(tester, container);

    expect(service.getCurrentUserLocationCallCount, 0);
    expect(repository.savedLocations, isEmpty);
  });

  testWidgets(
    'a meaningful in-app GPS move refreshes the saved discovery location',
    (tester) async {
      final controller = StreamController<UserLocation>.broadcast();
      addTearDown(controller.close);
      final service = _FakeDeviceLocationService(location: _nativeLocation)
        ..moves = controller.stream;
      final repository = _InMemoryLocationRepository(_nativeLocation);
      final container = buildContainer(
        service: service,
        repository: repository,
      );

      await pumpRefresher(tester, container);
      expect(service.watchStartCount, 1);
      expect(repository.savedLocations, isEmpty);

      controller.add(_travelledLocation);
      await tester.pumpAndSettle();

      expect(repository.savedLocations.single.city, 'Bengaluru');
      expect(
        container.read(userLocationProvider(_userId)).value?.city,
        'Bengaluru',
      );
      expect(container.read(currentGpsLocationProvider)?.city, 'Bengaluru');
    },
  );

  testWidgets('a GPS watch error does not crash or rewrite the destination', (
    tester,
  ) async {
    final service = _FakeDeviceLocationService(location: _nativeLocation)
      ..watchError = const LocationPermissionDeniedException();
    final repository = _InMemoryLocationRepository(_nativeLocation);
    final container = buildContainer(service: service, repository: repository);

    await pumpRefresher(tester, container);

    expect(tester.takeException(), isNull);
    expect(find.text('dashboard'), findsOneWidget);
    expect(repository.savedLocations, isEmpty);
  });
}

class _ThrowingLocationRepository extends _InMemoryLocationRepository {
  _ThrowingLocationRepository() : super(_nativeLocation);

  @override
  Future<void> saveUserLocation({
    required String userId,
    required UserLocation location,
    bool clearStaleAddressDetails = false,
  }) async {
    throw StateError('permission-denied');
  }
}
