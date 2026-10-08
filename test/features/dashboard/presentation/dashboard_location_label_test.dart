import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/domain/entities/auth_user.dart';
import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:customer_app/features/location/domain/entities/saved_address_book.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';

import '../../../helpers/destination_fakes.dart';

const _userId = 'user-1';

class _SignedInAuth extends AuthNotifier {
  _SignedInAuth(super.ref) {
    state = const AsyncData(
      AuthUser(uid: _userId, emailVerified: false, isAnonymous: false),
    );
  }
}

UserLocation _gps() => UserLocation(
  latitude: 11.0168,
  longitude: 76.9558,
  city: 'Coimbatore',
  state: 'Tamil Nadu',
  updatedAt: DateTime(2026, 9, 1),
);

UserLocation _home() => UserLocation(
  latitude: 11.0168,
  longitude: 76.9558,
  city: 'Coimbatore',
  state: 'Tamil Nadu',
  pincode: '641001',
  doorNumber: '12',
  street: 'ABC Street',
  selectedByCustomer: true,
  updatedAt: DateTime(2026, 9, 1),
);

UserLocation _search() => UserLocation(
  latitude: 10.0732,
  longitude: 78.7802,
  city: 'Karaikudi',
  state: 'Tamil Nadu',
  area: 'Karaikudi',
  selectedByCustomer: true,
  updatedAt: DateTime(2026, 9, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  required UserLocation location,
  SavedAddressBook book = const SavedAddressBook(),
  FakeLocationRepository? repository,
  FakeGps? gps,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (gps != null) deviceLocationServiceProvider.overrideWithValue(gps),
        currentUserIdProvider.overrideWithValue(_userId),
        authProvider.overrideWith(_SignedInAuth.new),
        locationRepositoryProvider.overrideWithValue(
          repository ?? FakeLocationRepository(location),
        ),
        savedAddressRepositoryProvider.overrideWithValue(
          FakeSavedAddressRepository(book),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardAppBar())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('current GPS default shows Current Location', (tester) async {
    await _pump(tester, location: _gps());
    expect(find.text('Current Location'), findsOneWidget);
    expect(find.text('Coimbatore'), findsOneWidget);
  });

  testWidgets('saved HOME shows the slot, not a searched-area label', (
    tester,
  ) async {
    await _pump(
      tester,
      location: _home(),
      book: SavedAddressBook(home: _home()),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Current Location'), findsNothing);
    expect(find.text('Selected Location'), findsNothing);
  });

  testWidgets('a searched area shows Selected Location', (tester) async {
    await _pump(tester, location: _search());
    expect(find.text('Selected Location'), findsOneWidget);
    expect(find.textContaining('Karaikudi'), findsWidgets);
    expect(find.text('Current Location'), findsNothing);
  });

  group('when the current location cannot be read', () {
    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(DashboardAppBar)));

    Future<void> setStatus(
      WidgetTester tester,
      DeviceLocationStatus status,
    ) async {
      containerOf(tester).read(deviceLocationStatusProvider.notifier).state =
          status;
      await tester.pumpAndSettle();
    }

    testWidgets('no banner while GPS is available or not yet read', (
      tester,
    ) async {
      await _pump(tester, location: _gps());
      expect(find.text('Select location'), findsNothing);

      await setStatus(tester, DeviceLocationStatus.available);
      expect(find.text('Select location'), findsNothing);
      expect(find.text('Current Location'), findsOneWidget);
    });

    testWidgets('permission denied: says so, offers Allow and manual '
        'selection, and a stale GPS location is not called current', (
      tester,
    ) async {
      await _pump(tester, location: _gps());
      await setStatus(tester, DeviceLocationStatus.permissionDenied);

      expect(
        find.text('Allow location access to see restaurants near you.'),
        findsOneWidget,
      );
      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Select location'), findsOneWidget);
      expect(find.text('Current Location'), findsNothing);
      expect(find.text('Last known location'), findsOneWidget);
    });

    testWidgets('permission denied for good: offers app settings', (
      tester,
    ) async {
      await _pump(
        tester,
        location: _home(),
        book: SavedAddressBook(home: _home()),
      );
      await setStatus(tester, DeviceLocationStatus.permissionDeniedForever);

      // The explicitly selected address stays, labelled as what it is.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Current Location'), findsNothing);

      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();
      expect(find.text('Location Permission Required'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('location services off: offers to turn them on', (
      tester,
    ) async {
      await _pump(tester, location: _search());
      await setStatus(tester, DeviceLocationStatus.serviceDisabled);

      expect(
        find.text('Location is turned off on this device.'),
        findsOneWidget,
      );
      // A manual selection is still shown as the customer's selection.
      expect(find.text('Selected Location'), findsOneWidget);

      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(find.text('Location Services Disabled'), findsOneWidget);
    });

    testWidgets('no position: offers Retry', (tester) async {
      await _pump(tester, location: _gps());
      await setStatus(tester, DeviceLocationStatus.unavailable);

      expect(
        find.text('We couldn\'t get your current location.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('"Select location" opens the location selector', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, location: _gps());
      await setStatus(tester, DeviceLocationStatus.permissionDenied);

      await tester.tap(find.text('Select location'));
      await tester.pumpAndSettle();

      expect(find.text('Select Your Location'), findsOneWidget);
      expect(find.text('Use Current\nLocation'), findsOneWidget);
    });
  });

  group('an explicit selection far from the phone', () {
    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(DashboardAppBar)));

    UserLocation explicitHome() =>
        _home().copyWith(source: LocationSource.savedHome);

    UserLocation phoneIn(double latitude, double longitude, String city) =>
        UserLocation(
          latitude: latitude,
          longitude: longitude,
          city: city,
          state: 'Tamil Nadu',
          updatedAt: DateTime(2026, 9, 1),
        );

    Future<void> setPhone(WidgetTester tester, UserLocation reading) async {
      final container = containerOf(tester);
      container.read(deviceLocationStatusProvider.notifier).state =
          DeviceLocationStatus.available;
      container.read(currentGpsLocationProvider.notifier).state = reading;
      await tester.pumpAndSettle();
    }

    testWidgets('is kept, and the customer is OFFERED the current location — '
        'nothing changes until they tap', (tester) async {
      final repository = FakeLocationRepository(explicitHome());
      final madurai = phoneIn(9.9252, 78.1198, 'Madurai');
      await _pump(
        tester,
        location: explicitHome(),
        book: SavedAddressBook(home: _home()),
        repository: repository,
        gps: FakeGps(madurai),
      );
      await setPhone(tester, madurai);

      // Still Home (Coimbatore), with an offer — not a silent switch.
      expect(find.text('Home'), findsOneWidget);
      expect(find.textContaining('from where you are now'), findsOneWidget);
      expect(repository.saves, isEmpty);

      await tester.tap(find.text('Use current location'));
      await tester.pumpAndSettle();

      expect(repository.saves.single.city, 'Madurai');
      expect(repository.saves.single.source, LocationSource.deviceGps);
      expect(find.text('Current Location'), findsOneWidget);
      expect(find.textContaining('from where you are now'), findsNothing);
    });

    testWidgets('no offer when the phone is near the selection, or when the '
        'active location is GPS itself', (tester) async {
      await _pump(
        tester,
        location: explicitHome(),
        book: SavedAddressBook(home: _home()),
      );
      // ~2 km from Home.
      await setPhone(tester, phoneIn(11.0348, 76.9558, 'Coimbatore'));
      expect(find.textContaining('from where you are now'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        location: _gps().copyWith(source: LocationSource.deviceGps),
      );
      await setPhone(tester, phoneIn(9.9252, 78.1198, 'Madurai'));
      expect(find.textContaining('from where you are now'), findsNothing);
    });
  });
}
