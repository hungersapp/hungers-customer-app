import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/app/app_routes.dart';
import 'package:customer_app/features/authentication/domain/entities/auth_user.dart';
import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/location/data/services/device_location_service.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/exceptions/location_exception.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/location/presentation/widgets/current_location_refresher.dart';
import 'package:customer_app/features/serviceability/presentation/providers/destination_serviceability_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';
import 'package:customer_app/features/splash/presentation/splash_screen.dart';

import '../../helpers/destination_fakes.dart';
import '../../helpers/discovery_fixtures.dart';

const _userId = 'user-1';
const _user = AuthUser(uid: _userId, emailVerified: false, isAnonymous: false);

/// A restored, signed-in session with a customer profile.
class _SignedInAuth extends AuthNotifier {
  _SignedInAuth(super.ref);

  @override
  Future<void> loadCurrentUser() async {
    state = const AsyncData(_user);
  }

  @override
  Future<AuthUser?> loadCustomerProfile(String userId) async => _user;
}

/// The phone's GPS: counts reads, can be held open, can fail.
class _Gps implements DeviceLocationService {
  _Gps(this.location, {this.error, this.gate});

  UserLocation location;
  Object? error;
  Completer<void>? gate;
  int reads = 0;
  int watches = 0;

  @override
  Future<UserLocation> getCurrentUserLocation() async {
    reads += 1;
    await gate?.future;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return location;
  }

  @override
  Stream<UserLocation> watchSignificantMoves({int distanceFilterMeters = 200}) {
    watches += 1;
    return const Stream.empty();
  }

  @override
  Future<void> ensurePermission() async {}

  @override
  Future<({double latitude, double longitude})> getCurrentCoordinates() =>
      throw UnimplementedError();

  @override
  Future<({String city, String state, String? pincode, String area})>
  reverseGeocode({required double latitude, required double longitude}) =>
      throw UnimplementedError();

  @override
  Future<UserLocation> searchArea(String query) => throw UnimplementedError();

  @override
  Future<List<UserLocation>> searchPlaces(String query) =>
      throw UnimplementedError();
}

/// What Home saw the instant it was first built — the thing the customer
/// would see flash by if the location were still wrong.
class _HomeProbe {
  String? firstCity;
  DestinationServiceability? firstServiceability;
  bool built = false;
}

class _Home extends ConsumerWidget {
  const _Home(this.probe);

  final _HomeProbe probe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(userLocationProvider(_userId)).valueOrNull;
    if (!probe.built) {
      probe
        ..built = true
        ..firstCity = location?.city
        ..firstServiceability = ref
            .read(destinationServiceabilityProvider)
            .valueOrNull;
    }
    return CurrentLocationRefresher(
      child: Scaffold(body: Text('home: ${location?.city ?? 'no location'}')),
    );
  }
}

UserLocation _gpsAt(City city, String pincode) =>
    destinationIn(city, selected: false, pincode: pincode);

void main() {
  late _HomeProbe probe;
  late FakeLocationRepository locations;
  late FakeServiceabilityRepository serviceability;

  Future<ProviderContainer> launch(
    WidgetTester tester, {
    required UserLocation? active,
    required _Gps gps,
  }) async {
    probe = _HomeProbe();
    locations = FakeLocationRepository(active);
    serviceability = FakeServiceabilityRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_SignedInAuth.new),
          currentUserIdProvider.overrideWithValue(_userId),
          deviceLocationServiceProvider.overrideWithValue(gps),
          locationRepositoryProvider.overrideWithValue(locations),
          savedAddressRepositoryProvider.overrideWithValue(
            FakeSavedAddressRepository(),
          ),
          serviceabilityRepositoryProvider.overrideWithValue(serviceability),
        ],
        child: MaterialApp(
          initialRoute: AppRoutes.splash,
          routes: {
            AppRoutes.splash: (_) => const SplashScreen(),
            AppRoutes.dashboard: (_) => _Home(probe),
          },
        ),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(SplashScreen)));
  }

  /// Lets the brand splash (3 s) and any follow-up work finish.
  Future<void> finishSplash(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('Test A — fresh launch: GPS is obtained during the splash and '
      'Home opens with that location and its serviceability already known', (
    tester,
  ) async {
    final gps = _Gps(_gpsAt(chennai, '600001'));
    await launch(tester, active: null, gps: gps);

    // The read starts on the splash, long before Home.
    await tester.pump(const Duration(milliseconds: 100));
    expect(gps.reads, 1);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(probe.built, isFalse);

    await finishSplash(tester);

    expect(find.text('home: Chennai'), findsOneWidget);
    expect(probe.firstCity, 'Chennai', reason: 'correct on the first frame');
    expect(probe.firstServiceability, DestinationServiceability.serviceable);
    expect(locations.stored!.source, LocationSource.deviceGps);
    expect(locations.stored!.latitude, chennai.latitude);
    expect(serviceability.zoneReads, greaterThan(0));
  });

  testWidgets('Test B — travel: the previous location was A, the phone is now '
      'at B; Home opens showing B and never shows A', (tester) async {
    for (final previous in [
      // Followed GPS last time.
      _gpsAt(madurai, '625001').copyWith(source: LocationSource.deviceGps),
      // A legacy Home address that was never explicitly selected.
      destinationIn(madurai),
    ]) {
      final gps = _Gps(_gpsAt(bengaluru, '560001'));
      await launch(tester, active: previous, gps: gps);
      await finishSplash(tester);

      expect(find.text('home: Bengaluru'), findsOneWidget);
      expect(probe.firstCity, 'Bengaluru');
      expect(locations.stored!.city, 'Bengaluru');
      expect(locations.stored!.source, LocationSource.deviceGps);

      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a slow GPS fix keeps the customer on the splash with a loading '
      'state — Home is not opened with the old location meanwhile', (
    tester,
  ) async {
    final gate = Completer<void>();
    final gps = _Gps(_gpsAt(bengaluru, '560001'), gate: gate);
    await launch(tester, active: destinationIn(madurai), gps: gps);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Finding your location…'), findsOneWidget);
    expect(probe.built, isFalse, reason: 'Home must not show Madurai first');

    await tester.pump(const Duration(seconds: 5));
    expect(probe.built, isFalse);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('home: Bengaluru'), findsOneWidget);
    expect(probe.firstCity, 'Bengaluru');
  });

  testWidgets('Test C — an explicitly selected delivery location survives a '
      'relaunch with the phone somewhere else, and does not delay the splash', (
    tester,
  ) async {
    final selected = explicitly(
      destinationIn(madurai),
      LocationSource.savedHome,
    );
    // GPS would take forever: an explicit selection must not wait for it.
    final gps = _Gps(_gpsAt(bengaluru, '560001'), gate: Completer<void>());
    await launch(tester, active: selected, gps: gps);

    await tester.pump(const Duration(milliseconds: 100));
    expect(gps.reads, 0, reason: 'the splash does not read GPS for it');

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump();

    expect(find.text('home: Madurai'), findsOneWidget);
    expect(probe.firstCity, 'Madurai');
    expect(find.text('Finding your location…'), findsNothing);
    expect(locations.saves, isEmpty);
    expect(locations.stored, selected);

    // Home then reads GPS once (for status / distance hints) — and the
    // selection still stands when that reading arrives.
    expect(gps.reads, 1);
    gps.gate!.complete();
    await tester.pumpAndSettle();
    expect(locations.saves, isEmpty);
    expect(find.text('home: Madurai'), findsOneWidget);
  });

  testWidgets('Test D — after "Use Current Location", a relaunch elsewhere '
      'initialises GPS on the splash and the current location stays active', (
    tester,
  ) async {
    // The customer had an explicit selection and tapped Use Current Location.
    final gps = _Gps(_gpsAt(madurai, '625001'));
    final container = await launch(
      tester,
      active: explicitly(destinationIn(chennai), LocationSource.savedWork),
      gps: gps,
    );
    await finishSplash(tester);
    expect(find.text('home: Chennai'), findsOneWidget);

    await container
        .read(locationSetupProvider.notifier)
        .useCurrentLocation(_userId);
    await tester.pumpAndSettle();
    expect(find.text('home: Madurai'), findsOneWidget);
    final afterTap = locations.stored!;
    expect(afterTap.source, LocationSource.deviceGps);
    await tester.pumpWidget(const SizedBox());

    // Close, travel, reopen.
    final relaunchGps = _Gps(_gpsAt(bengaluru, '560001'));
    await launch(tester, active: afterTap, gps: relaunchGps);
    await finishSplash(tester);

    expect(relaunchGps.reads, 1);
    expect(probe.firstCity, 'Bengaluru');
    expect(locations.stored!.source, LocationSource.deviceGps);
  });

  testWidgets('Test E — permission denied: no location is faked; Home opens '
      'in the location-selection / permission state', (tester) async {
    final gps = _Gps(
      _gpsAt(bengaluru, '560001'),
      error: const LocationPermissionDeniedException(),
    );
    final container = await launch(tester, active: null, gps: gps);
    await finishSplash(tester);

    expect(find.text('home: no location'), findsOneWidget);
    expect(locations.saves, isEmpty);
    expect(
      container.read(deviceLocationStatusProvider),
      DeviceLocationStatus.permissionDenied,
    );
    expect(
      await container.read(destinationServiceabilityProvider.future),
      DestinationServiceability.noDestination,
    );
    // Home does not ask a second time on its own.
    expect(gps.reads, 1);
    expect(gps.watches, 0);
  });

  testWidgets('location services disabled: an explicit selection is kept; '
      'nothing is faked', (tester) async {
    final selected = explicitly(destinationIn(madurai));
    final gps = _Gps(
      _gpsAt(bengaluru, '560001'),
      error: const LocationServiceDisabledException(),
    );
    final container = await launch(tester, active: selected, gps: gps);
    await finishSplash(tester);

    expect(find.text('home: Madurai'), findsOneWidget);
    expect(locations.stored, selected);
    expect(
      container.read(deviceLocationStatusProvider),
      DeviceLocationStatus.serviceDisabled,
    );
  });

  testWidgets('one coordinated flow: the splash read is the only GPS read — '
      'Home does not start a second one', (tester) async {
    final gps = _Gps(_gpsAt(chennai, '600001'));
    await launch(tester, active: null, gps: gps);
    await finishSplash(tester);

    expect(find.text('home: Chennai'), findsOneWidget);
    expect(gps.reads, 1);
    // …and the single movement watch starts once GPS is known to work.
    expect(gps.watches, 1);
    expect(locations.saves, hasLength(1));
  });
}
