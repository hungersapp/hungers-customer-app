import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformViewCreatedCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/location/data/services/device_location_service.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/location/domain/exceptions/location_exception.dart';
import 'package:customer_app/features/location/domain/repositories/location_repository.dart';
import 'package:customer_app/features/location/domain/usecases/save_user_location_usecase.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/location/presentation/screens/delivery_address_editor_screen.dart';

/// Minimal fake standing in for the real Google Maps platform channel so
/// `GoogleMap` can build in a widget test without a device/emulator. It only
/// implements what `google_maps_flutter`'s widget unconditionally touches on
/// first build (`init`, the map view itself, every event stream
/// `GoogleMapController._connectStreams` subscribes to regardless of which
/// callbacks the widget sets, and `updateTileOverlays`) — every other member
/// keeps the base class's `UnimplementedError` since production code here
/// never calls markers/polygons/camera-query APIs.
class _FakeGoogleMapsFlutterPlatform extends GoogleMapsFlutterPlatform {
  int? lastInitMapId;
  final Map<int, StreamController<CameraMoveEvent>> _moveControllers = {};
  final Map<int, StreamController<CameraIdleEvent>> _idleControllers = {};
  final Set<int> _createdViews = {};

  StreamController<CameraMoveEvent> _moveController(int mapId) =>
      _moveControllers.putIfAbsent(
        mapId,
        StreamController<CameraMoveEvent>.broadcast,
      );

  StreamController<CameraIdleEvent> _idleController(int mapId) =>
      _idleControllers.putIfAbsent(
        mapId,
        StreamController<CameraIdleEvent>.broadcast,
      );

  /// Simulates the user dragging the map to [target] and letting go.
  void panTo(int mapId, LatLng target) {
    emitCameraMove(mapId, target);
    emitCameraIdle(mapId);
  }

  /// Simulates the camera moving mid-drag, without the drag ending yet.
  void emitCameraMove(int mapId, LatLng target) {
    _moveController(
      mapId,
    ).add(CameraMoveEvent(mapId, CameraPosition(target: target, zoom: 17)));
  }

  /// Simulates the drag gesture ending (finger lifted) on the currently
  /// tracked camera position.
  void emitCameraIdle(int mapId) {
    _idleController(mapId).add(CameraIdleEvent(mapId));
  }

  @override
  Future<void> init(int mapId) async {
    lastInitMapId = mapId;
  }

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) =>
      _moveController(mapId).stream;

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) =>
      _idleController(mapId).stream;

  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MapTapEvent> onTap({required int mapId}) => const Stream.empty();

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<GroundOverlayTapEvent> onGroundOverlayTap({required int mapId}) =>
      const Stream.empty();

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {}

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration configuration, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateMarkers(
    MarkerUpdates markerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates clusterManagerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolygons(
    PolygonUpdates polygonUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolylines(
    PolylineUpdates polylineUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateCircles(
    CircleUpdates circleUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates heatmapUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {}

  @override
  Future<void> moveCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {}

  @override
  void dispose({required int mapId}) {}

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    // `build()` re-runs on every rebuild of the enclosing widget (e.g. our
    // own `onCameraIdle` setState), but the real platform view is only
    // created once per `creationId` — guard so we don't complete the
    // controller's completer a second time.
    if (_createdViews.add(creationId)) {
      scheduleMicrotask(() => onPlatformViewCreated(creationId));
    }
    return SizedBox(key: ValueKey('fake-google-map-$creationId'));
  }
}

/// Stands in for GPS/geocoding so tests control exactly what a "search" or
/// "use current location" resolves to, without touching real plugins.
class _FakeDeviceLocationService implements DeviceLocationService {
  _FakeDeviceLocationService({
    this.gpsResult,
    this.searchResult,
    this.searchError,
    this.reverseGeocodeResult,
    this.reverseGeocodeError,
  });

  UserLocation? gpsResult;
  UserLocation? searchResult;
  Object? searchError;
  ({String city, String state, String? pincode, String area})?
  reverseGeocodeResult;
  Object? reverseGeocodeError;

  int reverseGeocodeCallCount = 0;
  double? lastReverseGeocodeLatitude;
  double? lastReverseGeocodeLongitude;

  @override
  Future<void> ensurePermission() async {}

  @override
  Future<({double latitude, double longitude})> getCurrentCoordinates() async {
    throw UnimplementedError();
  }

  @override
  Future<UserLocation> getCurrentUserLocation() async => gpsResult!;

  @override
  Future<List<UserLocation>> searchPlaces(String query) =>
      throw UnimplementedError();

  @override
  Future<UserLocation> searchArea(String query) async {
    final error = searchError;
    if (error != null) {
      throw error;
    }
    return searchResult!;
  }

  @override
  Future<({String city, String state, String? pincode, String area})>
  reverseGeocode({required double latitude, required double longitude}) async {
    reverseGeocodeCallCount += 1;
    lastReverseGeocodeLatitude = latitude;
    lastReverseGeocodeLongitude = longitude;
    final error = reverseGeocodeError;
    if (error != null) {
      throw error;
    }
    return reverseGeocodeResult ??
        (
          city: 'Madurai',
          state: 'Tamil Nadu',
          pincode: '625020',
          area: 'Vandiyur',
        );
  }

  @override
  Stream<UserLocation> watchSignificantMoves({
    int distanceFilterMeters = 200,
  }) => const Stream.empty();
}

class _FakeLocationRepository implements LocationRepository {
  @override
  Future<UserLocation?> getUserLocation(String userId) async => null;

  @override
  Future<void> saveUserLocation({
    required String userId,
    required UserLocation location,
    bool clearStaleAddressDetails = false,
  }) async {}

  @override
  Future<String?> getDeliveryPincode(String userId) async => null;

  @override
  Future<void> saveDeliveryPincode({
    required String userId,
    required String pincode,
  }) async {}
}

void main() {
  late _FakeGoogleMapsFlutterPlatform fakeMapsPlatform;
  final originalMapsPlatform = GoogleMapsFlutterPlatform.instance;

  setUp(() {
    fakeMapsPlatform = _FakeGoogleMapsFlutterPlatform();
    GoogleMapsFlutterPlatform.instance = fakeMapsPlatform;
  });

  tearDown(() {
    GoogleMapsFlutterPlatform.instance = originalMapsPlatform;
  });

  final searchedLocation = UserLocation(
    latitude: 9.9195,
    longitude: 78.1193,
    city: 'Madurai',
    state: 'Tamil Nadu',
    pincode: '625020',
    area: 'Vandiyur',
    updatedAt: DateTime(2026, 1, 1),
  );

  Widget wrap(
    Widget child, {
    _FakeDeviceLocationService? deviceLocationService,
  }) {
    return ProviderScope(
      overrides: [
        deviceLocationServiceProvider.overrideWithValue(
          deviceLocationService ?? _FakeDeviceLocationService(),
        ),
        locationRepositoryProvider.overrideWithValue(_FakeLocationRepository()),
        saveUserLocationUseCaseProvider.overrideWithValue(
          SaveUserLocationUseCase(_FakeLocationRepository()),
        ),
        currentUserIdProvider.overrideWithValue('test-user'),
      ],
      child: MaterialApp(home: child),
    );
  }

  /// Pumps the screen in a tall viewport so the whole scrollable "Delivery
  /// details" form (door/street/area/city/state/pincode + Save) is mounted
  /// by the plain `ListView`'s sliver — the default 600px test surface only
  /// materializes elements within the viewport + cache extent, which would
  /// otherwise hide fields below the fold from `find`.
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget child, {
    _FakeDeviceLocationService? deviceLocationService,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrap(child, deviceLocationService: deviceLocationService),
    );
  }

  testWidgets('searching an area opens the map centered on the result, without '
      'finalizing the pin yet', (tester) async {
    final fakeService = _FakeDeviceLocationService(
      searchResult: searchedLocation,
    );
    await pumpScreen(
      tester,
      const DeliveryAddressEditorScreen(),
      deviceLocationService: fakeService,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Search area / landmark'),
      'Vandiyur',
    );
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    // The map step is showing (not the address-detail form) with the
    // fixed center pin and instruction text, and Save is not reachable
    // yet — the coordinate is not finalized until confirmed.
    expect(
      find.text('Move the map to adjust your delivery location'),
      findsOneWidget,
    );
    expect(find.text('Confirm delivery location'), findsOneWidget);
    expect(find.byIcon(Icons.location_pin), findsOneWidget);
    expect(find.text('Save address'), findsNothing);
    expect(find.widgetWithText(TextField, 'Door / House number'), findsNothing);
  });

  testWidgets('panning the map before confirming updates the pin to the camera '
      'center, not the original searched coordinate', (tester) async {
    final fakeService = _FakeDeviceLocationService(
      searchResult: searchedLocation,
      reverseGeocodeResult: (
        city: 'Madurai',
        state: 'Tamil Nadu',
        pincode: '625014',
        area: 'Anna Nagar',
      ),
    );
    await pumpScreen(
      tester,
      const DeliveryAddressEditorScreen(),
      deviceLocationService: fakeService,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Search area / landmark'),
      'Vandiyur',
    );
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    final mapId = fakeMapsPlatform.lastInitMapId;
    expect(mapId, isNotNull);

    const pannedTo = LatLng(9.9300, 78.1300);
    fakeMapsPlatform.panTo(mapId!, pannedTo);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm delivery location'));
    await tester.pumpAndSettle();

    // Reverse geocode ran against the panned-to point (not the original
    // searched coordinate), and its result now fills the address fields.
    expect(fakeService.reverseGeocodeCallCount, 1);
    expect(
      find.widgetWithText(TextField, 'Door / House number'),
      findsOneWidget,
    );
    final areaField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Area'),
    );
    expect(areaField.controller!.text, 'Anna Nagar');
    final pincodeField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Pincode'),
    );
    expect(pincodeField.controller!.text, '625014');
  });

  testWidgets(
    'the candidate coordinate only commits on camera-idle, using the last '
    'moved-to position — not an earlier mid-drag position or the original '
    'searched coordinate',
    (tester) async {
      final fakeService = _FakeDeviceLocationService(
        searchResult: searchedLocation,
      );
      await pumpScreen(
        tester,
        const DeliveryAddressEditorScreen(),
        deviceLocationService: fakeService,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Search area / landmark'),
        'Vandiyur',
      );
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      final mapId = fakeMapsPlatform.lastInitMapId;
      expect(mapId, isNotNull);

      // Mid-drag: the camera is still moving. This must not finalize a
      // candidate the confirm button would use if tapped right now.
      fakeMapsPlatform.emitCameraMove(mapId!, const LatLng(9.9200, 78.1200));
      await tester.pump();

      // The drag continues to a second, different position before the
      // finger lifts — only this last position should ever be committed.
      fakeMapsPlatform.emitCameraMove(mapId, const LatLng(9.9400, 78.1400));
      fakeMapsPlatform.emitCameraIdle(mapId);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm delivery location'));
      await tester.pumpAndSettle();

      // The reverse geocode that determined the saved address ran for the
      // final idle position, proving the mid-drag position was discarded
      // and only the camera-idle position was ever committed.
      expect(fakeService.lastReverseGeocodeLatitude, 9.9400);
      expect(fakeService.lastReverseGeocodeLongitude, 78.1400);
    },
  );

  testWidgets(
    'if reverse-geocoding the confirmed pin fails, the previously known '
    'city/state/area/pincode are kept instead of blocking confirmation',
    (tester) async {
      final fakeService = _FakeDeviceLocationService(
        searchResult: searchedLocation,
        reverseGeocodeError: const LocationGeocodingException(),
      );
      await pumpScreen(
        tester,
        const DeliveryAddressEditorScreen(),
        deviceLocationService: fakeService,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Search area / landmark'),
        'Vandiyur',
      );
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm delivery location'));
      await tester.pumpAndSettle();

      // The confirmation still succeeds (the pin itself is authoritative);
      // the address text just falls back to the pre-pan search result.
      expect(find.text('Save address'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Area'))
            .controller!
            .text,
        'Vandiyur',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Pincode'))
            .controller!
            .text,
        '625020',
      );
    },
  );

  testWidgets(
    'confirming the map selection reveals door/street fields and requires '
    'them before Save is allowed',
    (tester) async {
      final fakeService = _FakeDeviceLocationService(
        searchResult: searchedLocation,
      );
      await pumpScreen(
        tester,
        const DeliveryAddressEditorScreen(),
        deviceLocationService: fakeService,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Search area / landmark'),
        'Vandiyur',
      );
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm delivery location'));
      await tester.pumpAndSettle();

      expect(find.text('Save address'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Door / House number'),
        findsOneWidget,
      );

      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Enter door number, street, city, state, and a valid pincode.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GPS ("Use current location") also opens the map for manual adjustment '
    'instead of finalizing the GPS fix immediately',
    (tester) async {
      final fakeService = _FakeDeviceLocationService(
        gpsResult: searchedLocation,
      );
      await pumpScreen(
        tester,
        const DeliveryAddressEditorScreen(),
        deviceLocationService: fakeService,
      );

      await tester.tap(find.text('Use current location'));
      await tester.pumpAndSettle();

      expect(
        find.text('Move the map to adjust your delivery location'),
        findsOneWidget,
      );
      expect(find.text('Confirm delivery location'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Door / House number'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a confirmed address can be adjusted again via "Adjust pin on map"',
    (tester) async {
      final fakeService = _FakeDeviceLocationService(
        searchResult: searchedLocation,
      );
      await pumpScreen(
        tester,
        const DeliveryAddressEditorScreen(),
        deviceLocationService: fakeService,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Search area / landmark'),
        'Vandiyur',
      );
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm delivery location'));
      await tester.pumpAndSettle();

      expect(find.text('Adjust pin on map'), findsOneWidget);

      await tester.tap(find.text('Adjust pin on map'));
      await tester.pumpAndSettle();

      expect(
        find.text('Move the map to adjust your delivery location'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'searching with an empty query shows a validation error and never '
    'opens the map',
    (tester) async {
      await pumpScreen(tester, const DeliveryAddressEditorScreen());

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Enter an area or landmark to search.'), findsOneWidget);
      expect(
        find.text('Move the map to adjust your delivery location'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a search that resolves nothing shows an error and never opens the map',
    (tester) async {
      final fakeService = _FakeDeviceLocationService(
        searchError: const LocationGeocodingException(),
      );
      await pumpScreen(
        tester,
        const DeliveryAddressEditorScreen(),
        deviceLocationService: fakeService,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Search area / landmark'),
        'Nowhere',
      );
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.text('No location found for that search.'), findsOneWidget);
      expect(
        find.text('Move the map to adjust your delivery location'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'editing an existing address starts already confirmed, showing the '
    'form directly (no forced re-confirmation)',
    (tester) async {
      await pumpScreen(
        tester,
        DeliveryAddressEditorScreen(initial: searchedLocation),
      );

      expect(
        find.text('Move the map to adjust your delivery location'),
        findsNothing,
      );
      expect(
        find.widgetWithText(TextField, 'Door / House number'),
        findsOneWidget,
      );
      expect(find.text('Adjust pin on map'), findsOneWidget);
    },
  );
}
