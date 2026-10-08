import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'package:customer_app/features/authentication/domain/entities/auth_user.dart';
import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:customer_app/features/location/data/services/device_location_service.dart';
import 'package:customer_app/features/location/domain/entities/saved_address_book.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/exceptions/location_exception.dart';
import 'package:customer_app/features/location/domain/repositories/recent_location_repository.dart';
import 'package:customer_app/features/location/presentation/helpers/open_delivery_location_chooser.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/location/presentation/screens/delivery_address_editor_screen.dart';
import 'package:customer_app/features/location/presentation/screens/saved_addresses_screen.dart';

import '../../../helpers/destination_fakes.dart';
import '../../../helpers/fake_google_maps_flutter_platform.dart';

/// Stands in for GPS + geocoding: what "use current location" and a search
/// resolve to, and what the confirmed map pin reverse-geocodes to.
class _FakeDevice implements DeviceLocationService {
  _FakeDevice({this.gps, this.places = const [], this.reverse, this.gpsError});

  UserLocation? gps;

  /// What a search returns, in order.
  List<UserLocation> places;
  ({String city, String state, String? pincode, String area})? reverse;

  /// When set, reading the current location fails with it.
  Object? gpsError;

  final List<String> searches = [];

  @override
  Future<void> ensurePermission() async {}

  @override
  Future<({double latitude, double longitude})> getCurrentCoordinates() =>
      throw UnimplementedError();

  @override
  Future<UserLocation> getCurrentUserLocation() async {
    final error = gpsError;
    if (error != null) {
      throw error;
    }
    return gps!;
  }

  @override
  Future<List<UserLocation>> searchPlaces(String query) async {
    searches.add(query);
    return places;
  }

  @override
  Future<UserLocation> searchArea(String query) => throw UnimplementedError();

  @override
  Future<({String city, String state, String? pincode, String area})>
  reverseGeocode({required double latitude, required double longitude}) async =>
      reverse!;

  @override
  Stream<UserLocation> watchSignificantMoves({
    int distanceFilterMeters = 200,
  }) => const Stream.empty();
}

/// In-memory "Recently searched".
class _FakeRecents implements RecentLocationRepository {
  _FakeRecents([List<UserLocation>? initial]) : entries = [...?initial];

  final List<UserLocation> entries;

  @override
  Future<List<UserLocation>> getRecentSearches(String userId) async => [
    ...entries,
  ];

  @override
  Future<void> addRecentSearch({
    required String userId,
    required UserLocation location,
  }) async {
    entries
      ..removeWhere(
        (e) =>
            e.latitude == location.latitude &&
            e.longitude == location.longitude,
      )
      ..insert(0, location);
  }
}

class _SignedInAuth extends AuthNotifier {
  _SignedInAuth(super.ref) {
    state = const AsyncData(
      AuthUser(uid: _userId, emailVerified: false, isAnonymous: false),
    );
  }
}

const _userId = 'user-1';

UserLocation _place(
  double latitude,
  double longitude,
  String city, {
  String area = '',
  String? pincode,
  String door = '',
  String street = '',
  bool selected = false,
}) => UserLocation(
  latitude: latitude,
  longitude: longitude,
  city: city,
  state: 'Tamil Nadu',
  pincode: pincode,
  area: area,
  doorNumber: door,
  street: street,
  selectedByCustomer: selected,
  updatedAt: DateTime(2026, 1, 1),
);

UserLocation _chennai() =>
    _place(13.0827, 80.2707, 'Chennai', area: 'Parrys', pincode: '600001');

UserLocation _chennaiEgmore() =>
    _place(13.0732, 80.2609, 'Chennai', area: 'Egmore', pincode: '600008');

UserLocation _maduraiGps() =>
    _place(9.9252, 78.1198, 'Madurai', area: 'Anna Nagar', pincode: '625001');

UserLocation _savedHome() => _place(
  9.9312,
  78.1215,
  'Madurai',
  area: 'KK Nagar',
  pincode: '625020',
  door: '12A',
  street: 'Bypass Road',
  selected: true,
);

UserLocation _savedWork() => _place(
  11.0168,
  76.9558,
  'Coimbatore',
  area: 'Gandhipuram',
  pincode: '641001',
  door: '4',
  street: 'Avinashi Road',
  selected: true,
);

UserLocation _savedOther() => _place(
  10.7905,
  78.7047,
  'Tiruchirappalli',
  pincode: '620001',
  door: '9',
  street: 'Fort Road',
  selected: true,
);

/// A button that opens the chooser exactly as Home does.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => openDeliveryLocationChooser(context, ref),
          child: const Text('open chooser'),
        ),
      ),
    );
  }
}

void main() {
  final originalMaps = GoogleMapsFlutterPlatform.instance;
  setUp(
    () => GoogleMapsFlutterPlatform.instance = FakeGoogleMapsFlutterPlatform(),
  );
  tearDown(() => GoogleMapsFlutterPlatform.instance = originalMaps);

  late _FakeRecents recents;

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget home, {
    required FakeLocationRepository locations,
    required _FakeDevice device,
    SavedAddressBook book = const SavedAddressBook(),
    List<UserLocation>? recentSearches,
    bool signedInAuth = false,
  }) async {
    // Tall enough that the whole screen is built (a ListView only builds what
    // is near the viewport).
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    recents = _FakeRecents(recentSearches);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(_userId),
          if (signedInAuth) authProvider.overrideWith(_SignedInAuth.new),
          deviceLocationServiceProvider.overrideWithValue(device),
          locationRepositoryProvider.overrideWithValue(locations),
          savedAddressRepositoryProvider.overrideWithValue(
            FakeSavedAddressRepository(book),
          ),
          recentLocationRepositoryProvider.overrideWithValue(recents),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
  }

  Future<void> openChooser(WidgetTester tester) async {
    await tester.tap(find.text('open chooser'));
    await tester.pumpAndSettle();
  }

  /// Type a query and submit it: the results list appears.
  Future<void> searchFor(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
  }

  /// Search, pick the first result ([title]) and land on the map step.
  Future<void> searchAndOpenMap(
    WidgetTester tester, {
    String title = 'Parrys',
  }) async {
    await searchFor(tester, 'Chennai');
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> confirmPin(WidgetTester tester) async {
    await tester.tap(find.text('Confirm & proceed'));
    await tester.pumpAndSettle();
  }

  final chennaiPin = (
    city: 'Chennai',
    state: 'Tamil Nadu',
    pincode: '600001' as String?,
    area: 'Parrys',
  );

  testWidgets('Home "Deliver To" opens the location selector: search, current '
      'location, add address — never a bare pincode box', (tester) async {
    await pump(
      tester,
      const Scaffold(body: DashboardAppBar()),
      locations: FakeLocationRepository(null),
      device: _FakeDevice(),
      signedInAuth: true,
    );

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(DeliveryAddressEditorScreen), findsOneWidget);
    expect(find.text('Select Your Location'), findsOneWidget);
    expect(find.text('Search an area or address'), findsOneWidget);
    expect(find.text('Use Current\nLocation'), findsOneWidget);
    expect(find.text('Add New\nAddress'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Enter your delivery pincode'), findsNothing);
    // Nothing is saved or searched yet, so those sections are absent.
    expect(find.text('SAVED ADDRESSES'), findsNothing);
    expect(find.text('RECENTLY SEARCHED'), findsNothing);
  });

  group('search', () {
    testWidgets('lists every match; the picked one is confirmed on the map '
        'and saved as an EXPLICIT selection — no door, street or pincode '
        'asked', (tester) async {
      final locations = FakeLocationRepository(null);
      final device = _FakeDevice(
        places: [_chennai(), _chennaiEgmore()],
        reverse: chennaiPin,
      );
      await pump(tester, const _Host(), locations: locations, device: device);

      await openChooser(tester);
      await searchFor(tester, 'Chennai');

      // The results list, like the reference: name, then where it is.
      expect(device.searches, ['Chennai']);
      expect(find.text('SEARCH RESULTS'), findsOneWidget);
      expect(find.text('Parrys'), findsOneWidget);
      expect(find.text('Egmore'), findsOneWidget);
      expect(find.text('Chennai, Tamil Nadu, 600001'), findsOneWidget);
      expect(locations.saves, isEmpty, reason: 'a result is not a selection');

      await tester.tap(find.text('Parrys'));
      await tester.pumpAndSettle();

      // The map step shows where the order will go; nothing else is asked.
      expect(find.text('Order will be delivered here'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Door / House number'),
        findsNothing,
      );
      expect(find.widgetWithText(TextField, 'Pincode'), findsNothing);

      await confirmPin(tester);

      expect(locations.saves, hasLength(1));
      final saved = locations.saves.single;
      expect(saved.city, 'Chennai');
      expect(saved.pincode, '600001');
      expect(saved.area, 'Parrys');
      // The chosen result's coordinates ARE the selected location.
      expect(saved.latitude, _chennai().latitude);
      expect(saved.longitude, _chennai().longitude);
      expect(saved.selectedByCustomer, isTrue);
      expect(saved.source, LocationSource.manualSelection);
      expect(saved.isExplicitSelection, isTrue);
      expect(saved.doorNumber, isEmpty);
      expect(saved.street, isEmpty);
      // The chooser closes; Home follows the saved location.
      expect(find.byType(DeliveryAddressEditorScreen), findsNothing);
    });

    testWidgets('runs as the customer types, once they pause', (tester) async {
      final device = _FakeDevice(places: [_chennai()]);
      await pump(
        tester,
        const _Host(),
        locations: FakeLocationRepository(null),
        device: device,
      );
      await openChooser(tester);

      // Too short to search.
      await tester.enterText(find.byType(TextField), 'Ch');
      await tester.pump(const Duration(seconds: 1));
      expect(device.searches, isEmpty);

      await tester.enterText(find.byType(TextField), 'Chen');
      await tester.pump(const Duration(milliseconds: 200));
      expect(device.searches, isEmpty, reason: 'still typing');
      await tester.enterText(find.byType(TextField), 'Chenn');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(device.searches, ['Chenn']);
      expect(find.text('Parrys'), findsOneWidget);

      // Clearing the search brings the shortcuts back.
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('SEARCH RESULTS'), findsNothing);
      expect(find.text('Use Current\nLocation'), findsOneWidget);
    });

    testWidgets('a search that finds nothing says so and saves nothing', (
      tester,
    ) async {
      final locations = FakeLocationRepository(null);
      await pump(
        tester,
        const _Host(),
        locations: locations,
        device: _FakeDevice(),
      );

      await openChooser(tester);
      await searchFor(tester, 'zzzz');

      expect(
        find.text("Uh, oh! We couldn't find this location"),
        findsOneWidget,
      );
      expect(
        find.text('Try searching for another\narea or landmark'),
        findsOneWidget,
      );
      expect(locations.saves, isEmpty);
    });

    testWidgets('a place the geocoder found no pincode for is saved all the '
        'same — the customer is never asked to type one', (tester) async {
      final locations = FakeLocationRepository(null);
      await pump(
        tester,
        const _Host(),
        locations: locations,
        device: _FakeDevice(
          places: [_chennai()],
          // Reverse geocoding of the confirmed pin found no postal code.
          reverse: (
            city: 'Chennai',
            state: 'Tamil Nadu',
            pincode: null,
            area: 'Parrys',
          ),
        ),
      );

      await openChooser(tester);
      await searchAndOpenMap(tester);
      await confirmPin(tester);

      expect(find.byType(DeliveryAddressEditorScreen), findsNothing);
      final saved = locations.saves.single;
      expect(saved.pincode, isNull);
      expect(saved.city, 'Chennai');
      expect(saved.selectedByCustomer, isTrue);
    });

    testWidgets('choosing a DIFFERENT place does not carry the old address\'s '
        'door, street, area or pincode over to it', (tester) async {
      final locations = FakeLocationRepository(
        _place(
          9.9252,
          78.1198,
          'Madurai',
          area: 'Anna Nagar',
          pincode: '625001',
          door: '12A',
          street: 'Main Road',
        ),
      );
      final container = await pump(
        tester,
        const _Host(),
        locations: locations,
        device: _FakeDevice(
          places: [_chennai()],
          reverse: (
            city: 'Chennai',
            state: 'Tamil Nadu',
            pincode: null,
            // No named area at the new pin.
            area: '',
          ),
        ),
      );
      await container.read(userLocationProvider(_userId).future);

      await openChooser(tester);
      await searchAndOpenMap(tester);
      await confirmPin(tester);

      final saved = locations.saves.single;
      expect(saved.city, 'Chennai');
      expect(saved.doorNumber, isEmpty);
      expect(saved.street, isEmpty);
      expect(saved.area, isEmpty);
      expect(saved.pincode, isNull);
    });
  });

  group('recently searched', () {
    testWidgets('a searched place that was selected is remembered and offered '
        'next time', (tester) async {
      final locations = FakeLocationRepository(null);
      await pump(
        tester,
        const _Host(),
        locations: locations,
        device: _FakeDevice(places: [_chennai()], reverse: chennaiPin),
      );

      await openChooser(tester);
      expect(find.text('RECENTLY SEARCHED'), findsNothing);
      await searchAndOpenMap(tester);
      await confirmPin(tester);

      expect(recents.entries.single.area, 'Parrys');

      await openChooser(tester);
      expect(find.text('RECENTLY SEARCHED'), findsOneWidget);
      expect(find.text('Parrys'), findsOneWidget);
    });

    testWidgets('tapping a recent place goes to the map and selects it '
        'explicitly', (tester) async {
      final locations = FakeLocationRepository(null);
      await pump(
        tester,
        const _Host(),
        locations: locations,
        device: _FakeDevice(reverse: chennaiPin),
        recentSearches: [_chennai()],
      );

      await openChooser(tester);
      await tester.tap(find.text('Parrys'));
      await tester.pumpAndSettle();
      expect(find.text('Order will be delivered here'), findsOneWidget);
      expect(locations.saves, isEmpty);

      await confirmPin(tester);

      final saved = locations.saves.single;
      expect(saved.city, 'Chennai');
      expect(saved.source, LocationSource.manualSelection);
    });

    testWidgets('"Use Current Location" and saved addresses are not recorded '
        'as searches', (tester) async {
      final locations = FakeLocationRepository(null);
      await pump(
        tester,
        const _Host(),
        locations: locations,
        device: _FakeDevice(gps: _chennai(), reverse: chennaiPin),
        book: SavedAddressBook(home: _savedHome()),
      );

      await openChooser(tester);
      await tester.tap(find.text('Use Current\nLocation'));
      await tester.pumpAndSettle();
      await confirmPin(tester);
      await openChooser(tester);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(locations.saves, hasLength(2));
      expect(recents.entries, isEmpty);
    });
  });

  // Test 5 (selector path).
  testWidgets('"Use Current Location" makes the device GPS position the '
      'active location, replacing an explicit selection', (tester) async {
    final locations = FakeLocationRepository(
      _savedHome().copyWith(source: LocationSource.savedHome),
    );
    final container = await pump(
      tester,
      const _Host(),
      locations: locations,
      device: _FakeDevice(gps: _chennai(), reverse: chennaiPin),
    );

    await openChooser(tester);
    await tester.tap(find.text('Use Current\nLocation'));
    await tester.pumpAndSettle();
    await confirmPin(tester);

    final saved = locations.saves.single;
    expect(saved.city, 'Chennai');
    // The device's current coordinates ARE the selected location.
    expect(saved.latitude, _chennai().latitude);
    expect(saved.longitude, _chennai().longitude);
    expect(saved.selectedByCustomer, isFalse);
    expect(saved.source, LocationSource.deviceGps);
    // Nothing of the previously active Home address rides along.
    expect(saved.doorNumber, isEmpty);
    expect(saved.street, isEmpty);
    expect(
      container.read(deviceLocationStatusProvider),
      DeviceLocationStatus.available,
    );
    expect(find.byType(DeliveryAddressEditorScreen), findsNothing);
  });

  testWidgets('cancelling changes nothing — saved addresses are offered, never '
      'applied on their own', (tester) async {
    final locations = FakeLocationRepository(null);
    await pump(
      tester,
      const _Host(),
      locations: locations,
      device: _FakeDevice(),
      book: SavedAddressBook(home: _savedHome(), work: _savedWork()),
    );

    await openChooser(tester);
    expect(find.text('SAVED ADDRESSES'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(DeliveryAddressEditorScreen), findsNothing);
    expect(locations.saves, isEmpty);
  });

  testWidgets('"Add New Address" opens the saved-addresses screen', (
    tester,
  ) async {
    await pump(
      tester,
      const _Host(),
      locations: FakeLocationRepository(null),
      device: _FakeDevice(),
    );

    await openChooser(tester);
    await tester.tap(find.text('Add New\nAddress'));
    await tester.pumpAndSettle();

    expect(find.byType(SavedAddressesScreen), findsOneWidget);
  });

  group('saved addresses are selected explicitly', () {
    for (final (label, slot, address, source) in [
      ('Home', SavedAddressSlot.home, _savedHome(), LocationSource.savedHome),
      ('Work', SavedAddressSlot.work, _savedWork(), LocationSource.savedWork),
      (
        'Other',
        SavedAddressSlot.other,
        _savedOther(),
        LocationSource.otherSavedAddress,
      ),
    ]) {
      testWidgets('tapping $label makes it the active location — an explicit '
          'selection with its full address', (tester) async {
        // The active location is the phone's GPS position (Chennai).
        final locations = FakeLocationRepository(
          _chennai().copyWith(source: LocationSource.deviceGps),
        );
        final container = await pump(
          tester,
          const _Host(),
          locations: locations,
          device: _FakeDevice(),
          book: SavedAddressBook(
            home: slot == SavedAddressSlot.home ? address : null,
            work: slot == SavedAddressSlot.work ? address : null,
            other: slot == SavedAddressSlot.other ? address : null,
          ),
        );
        container.read(currentGpsLocationProvider.notifier).state = _chennai();

        await openChooser(tester);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        final saved = locations.saves.single;
        expect(saved.source, source);
        expect(saved.selectedByCustomer, isTrue);
        expect(saved.isExplicitSelection, isTrue);
        expect(saved.latitude, address.latitude);
        expect(saved.longitude, address.longitude);
        expect(saved.city, address.city);
        expect(saved.pincode, address.pincode);
        expect(saved.doorNumber, address.doorNumber);
        expect(saved.street, address.street);
        expect(find.byType(DeliveryAddressEditorScreen), findsNothing);
        // …and it is what the rest of the app now reads.
        expect(
          (await container.read(userLocationProvider(_userId).future))?.city,
          address.city,
        );

        // GPS, still in Chennai hundreds of km away, does not take it back.
        await container
            .read(locationSetupProvider.notifier)
            .applyDeviceLocation(_userId, _chennai());
        expect(locations.saves, hasLength(1));
        expect(locations.stored!.source, source);
      });
    }

    testWidgets('each saved address shows how far it is from the phone', (
      tester,
    ) async {
      final container = await pump(
        tester,
        const _Host(),
        locations: FakeLocationRepository(null),
        device: _FakeDevice(),
        book: SavedAddressBook(home: _savedHome()),
      );
      container.read(currentGpsLocationProvider.notifier).state = _maduraiGps();

      await openChooser(tester);

      // Home is ~0.7 km from the phone.
      expect(find.text('0.7 km'), findsOneWidget);
    });
  });

  group('"Are you sure of the selected location?"', () {
    Future<(ProviderContainer, FakeLocationRepository)> farPlaceOnMap(
      WidgetTester tester,
    ) async {
      final locations = FakeLocationRepository(null);
      final container = await pump(
        tester,
        const _Host(),
        locations: locations,
        device: _FakeDevice(places: [_chennai()], reverse: chennaiPin),
      );
      // The phone is in Madurai; Chennai is hundreds of km away.
      container.read(currentGpsLocationProvider.notifier).state = _maduraiGps();
      await openChooser(tester);
      await searchAndOpenMap(tester);
      return (container, locations);
    }

    testWidgets('the map step says how far the place is from the phone', (
      tester,
    ) async {
      await farPlaceOnMap(tester);

      expect(
        find.textContaining('away from your current location'),
        findsOneWidget,
      );
    });

    testWidgets('confirming a far place asks first; "Yes, continue" selects '
        'it', (tester) async {
      final (_, locations) = await farPlaceOnMap(tester);

      await confirmPin(tester);

      expect(
        find.text('Are you sure of the\nselected location?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your selected location seems to be a little far off from the '
          'device location',
        ),
        findsOneWidget,
      );
      expect(locations.saves, isEmpty, reason: 'nothing is saved before yes');

      await tester.tap(find.text('Yes, continue with this location'));
      await tester.pumpAndSettle();

      expect(locations.saves.single.city, 'Chennai');
      expect(locations.saves.single.source, LocationSource.manualSelection);
      expect(find.byType(DeliveryAddressEditorScreen), findsNothing);
    });

    testWidgets('"No, select another location" goes back to the selector and '
        'saves nothing', (tester) async {
      final (_, locations) = await farPlaceOnMap(tester);

      await confirmPin(tester);
      await tester.tap(find.text('No, select another location'));
      await tester.pumpAndSettle();

      expect(locations.saves, isEmpty);
      expect(find.byType(DeliveryAddressEditorScreen), findsOneWidget);
      expect(find.text('Confirm & proceed'), findsNothing);
      // Back on the results, ready to pick another.
      expect(find.text('SEARCH RESULTS'), findsOneWidget);
    });

    testWidgets('a nearby place, or an unknown phone position, is not '
        'questioned', (tester) async {
      final locations = FakeLocationRepository(null);
      await pump(
        tester,
        const _Host(),
        locations: locations,
        device: _FakeDevice(places: [_chennai()], reverse: chennaiPin),
      );

      await openChooser(tester);
      await searchAndOpenMap(tester);
      expect(
        find.textContaining('away from your current location'),
        findsNothing,
      );
      await confirmPin(tester);

      expect(
        find.text('Are you sure of the\nselected location?'),
        findsNothing,
      );
      expect(locations.saves.single.city, 'Chennai');
    });
  });

  group('GPS failure in the selector', () {
    testWidgets('permission denied: says so, saves nothing, and the customer '
        'can still choose a place by hand', (tester) async {
      final locations = FakeLocationRepository(null);
      final container = await pump(
        tester,
        const _Host(),
        locations: locations,
        device: _FakeDevice(
          gpsError: const LocationPermissionDeniedException(),
          places: [_chennai()],
          reverse: chennaiPin,
        ),
        book: SavedAddressBook(home: _savedHome()),
      );

      await openChooser(tester);
      await tester.tap(find.text('Use Current\nLocation'));
      await tester.pumpAndSettle();

      expect(find.text('Location permission is required.'), findsOneWidget);
      expect(
        locations.saves,
        isEmpty,
        reason: 'Home is NOT used as a stand-in',
      );
      expect(
        container.read(deviceLocationStatusProvider),
        DeviceLocationStatus.permissionDenied,
      );

      await searchAndOpenMap(tester);
      await confirmPin(tester);

      final saved = locations.saves.single;
      expect(saved.city, 'Chennai');
      expect(saved.source, LocationSource.manualSelection);
    });

    testWidgets('permission permanently denied: offers app settings', (
      tester,
    ) async {
      final locations = FakeLocationRepository(null);
      await pump(
        tester,
        const _Host(),
        locations: locations,
        device: _FakeDevice(
          gpsError: const LocationPermissionPermanentlyDeniedException(),
        ),
      );

      await openChooser(tester);
      await tester.tap(find.text('Use Current\nLocation'));
      await tester.pumpAndSettle();

      expect(find.text('Location Permission Required'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      // Still in the selector, free to search or pick a saved address.
      expect(find.byType(DeliveryAddressEditorScreen), findsOneWidget);
      expect(locations.saves, isEmpty);
    });

    testWidgets('location services disabled: offers to turn them on', (
      tester,
    ) async {
      final locations = FakeLocationRepository(null);
      final container = await pump(
        tester,
        const _Host(),
        locations: locations,
        device: _FakeDevice(gpsError: const LocationServiceDisabledException()),
      );

      await openChooser(tester);
      await tester.tap(find.text('Use Current\nLocation'));
      await tester.pumpAndSettle();

      expect(find.text('Location Services Disabled'), findsOneWidget);
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enable device location services to continue.'),
        findsOneWidget,
      );
      expect(locations.saves, isEmpty);
      expect(
        container.read(deviceLocationStatusProvider),
        DeviceLocationStatus.serviceDisabled,
      );
    });
  });
}
