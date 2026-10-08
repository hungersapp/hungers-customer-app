import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/location/presentation/screens/delivery_address_editor_screen.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/presentation/providers/popular_restaurant_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';
import 'package:customer_app/features/restaurants/presentation/widgets/restaurant_section.dart';
import 'package:customer_app/features/serviceability/presentation/providers/destination_serviceability_provider.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart'
    show
        ServiceabilityState,
        ServiceabilityUiStatus,
        serviceabilityRepositoryProvider;

import '../../../helpers/destination_fakes.dart';
import '../../../helpers/discovery_fixtures.dart';

/// Nothing delivers to the selected location.
class _NoPopularRestaurants extends PopularRestaurantNotifier {
  @override
  Future<List<RestaurantEntity>> build() async => const [];
}

Future<void> _pump(
  WidgetTester tester,
  ServiceabilityState state, {
  bool nothingDelivers = false,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        locationRepositoryProvider.overrideWithValue(
          FakeLocationRepository(null),
        ),
        // What the selected location's coordinates came out as.
        deliveryServiceabilityProvider.overrideWithValue(state),
        if (nothingDelivers)
          popularRestaurantProvider.overrideWith(_NoPopularRestaurants.new),
      ],
      child: const MaterialApp(home: Scaffold(body: RestaurantSection())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a location Tukkito does not serve: "Sorry, no restaurants '
      'available in this location", and no restaurants', (tester) async {
    await _pump(
      tester,
      const ServiceabilityState(
        status: ServiceabilityUiStatus.notServiceable,
        pincode: '999999',
      ),
    );

    expect(
      find.text('Sorry, no restaurants available in this location.'),
      findsOneWidget,
    );
    expect(find.text('Popular Near You'), findsNothing);
  });

  testWidgets('"Change location" opens the location chooser', (tester) async {
    await _pump(
      tester,
      const ServiceabilityState(
        status: ServiceabilityUiStatus.notServiceable,
        pincode: '999999',
      ),
    );

    await tester.tap(find.text('Change location'));
    await tester.pumpAndSettle();

    expect(find.byType(DeliveryAddressEditorScreen), findsOneWidget);
    expect(find.text('Select Your Location'), findsOneWidget);
  });

  testWidgets('no location chosen yet: the customer is asked to choose one, '
      'and no restaurants are listed', (tester) async {
    await _pump(tester, const ServiceabilityState());

    expect(find.text('Choose your delivery location'), findsOneWidget);
    expect(find.text('Popular Near You'), findsNothing);
    // Never a pincode box: the location is chosen, not typed.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Enter your delivery pincode'), findsNothing);

    await tester.tap(find.text('Choose location'));
    await tester.pumpAndSettle();

    expect(find.byType(DeliveryAddressEditorScreen), findsOneWidget);
  });

  testWidgets('a served location where no restaurant delivers shows the same '
      'message and can change location', (tester) async {
    await _pump(
      tester,
      const ServiceabilityState(
        status: ServiceabilityUiStatus.serviceable,
        pincode: '625001',
      ),
      nothingDelivers: true,
    );

    expect(find.text('Popular Near You'), findsOneWidget);
    expect(
      find.text('Sorry, no restaurants available in this location.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Change location'));
    await tester.pumpAndSettle();

    expect(find.byType(DeliveryAddressEditorScreen), findsOneWidget);
  });

  group('wired to the selected location\'s coordinates (real providers)', () {
    Future<void> pumpReal(
      WidgetTester tester, {
      required FakeLocationRepository locations,
      required FakeServiceabilityRepository serviceability,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('user-1'),
            locationRepositoryProvider.overrideWithValue(locations),
            serviceabilityRepositoryProvider.overrideWithValue(serviceability),
            restaurantRepositoryProvider.overrideWithValue(
              NationwideRestaurantRepository([restaurantIn(chennai, 'far')]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: RestaurantSection())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a location outside every active zone shows the not-served '
        'card — by coordinates, with no pincode involved', (tester) async {
      final serviceability = FakeServiceabilityRepository(
        zones: [zoneAround(madurai)],
      );
      await pumpReal(
        tester,
        // Chennai coordinates, carrying a Madurai pincode: still not served.
        locations: FakeLocationRepository(
          destinationIn(chennai, pincode: '625001'),
        ),
        serviceability: serviceability,
      );

      expect(
        find.text('Sorry, no restaurants available in this location.'),
        findsOneWidget,
      );
      expect(find.text('Popular Near You'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(serviceability.pincodeChecks, 0);
    });

    testWidgets('a location inside an active zone shows the restaurant '
        'section; with none in range it says so and offers Change location', (
      tester,
    ) async {
      await pumpReal(
        tester,
        // No pincode at all — served by its coordinates.
        locations: FakeLocationRepository(
          destinationIn(madurai, pincode: null),
        ),
        serviceability: FakeServiceabilityRepository(
          zones: [zoneAround(madurai)],
        ),
      );

      expect(find.text('Popular Near You'), findsOneWidget);
      expect(
        find.text('Sorry, no restaurants available in this location.'),
        findsOneWidget,
      );
      expect(find.text('Change location'), findsOneWidget);
    });

    testWidgets('zones that cannot be read show a retryable error, never a '
        'restaurant list', (tester) async {
      await pumpReal(
        tester,
        locations: FakeLocationRepository(destinationIn(madurai)),
        serviceability: FakeServiceabilityRepository(
          readError: StateError('offline'),
        ),
      );

      expect(
        find.text('Unable to check availability. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Popular Near You'), findsNothing);
    });
  });
}
