import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/location/presentation/providers/location_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_list_provider.dart';
import 'package:customer_app/features/restaurants/presentation/providers/restaurant_provider.dart';
import 'package:customer_app/features/serviceability/domain/entities/active_delivery_zone.dart';
import 'package:customer_app/features/serviceability/domain/entities/serviceability_result.dart';
import 'package:customer_app/features/serviceability/domain/repositories/serviceability_repository.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';

import '../../../helpers/destination_fakes.dart';
import '../../../helpers/discovery_fixtures.dart';

const _userId = 'user-1';

/// Every zone read stays pending until the test answers it, so a test can see
/// what the Home list does while a location is still being checked.
class _ControlledZones implements ServiceabilityRepository {
  final List<Completer<List<ActiveDeliveryZone>>> pending = [];

  void answer(int read, List<ActiveDeliveryZone> zones) =>
      pending[read].complete(zones);

  @override
  Future<List<ActiveDeliveryZone>> getActiveDeliveryZones() {
    final completer = Completer<List<ActiveDeliveryZone>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<ServiceabilityResult> checkPincode(String pincode) =>
      throw StateError('serviceability must not be decided from a pincode');
}

({
  ProviderContainer container,
  FakeLocationRepository locations,
  _ControlledZones zones,
  NationwideRestaurantRepository restaurants,
})
_setup() {
  final locations = FakeLocationRepository(destinationIn(madurai));
  final zones = _ControlledZones();
  final restaurants = NationwideRestaurantRepository([
    restaurantIn(madurai, 'a2b'),
    restaurantIn(chennai, 'chennai-1'),
  ]);
  final container = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue(_userId),
      locationRepositoryProvider.overrideWithValue(locations),
      restaurantRepositoryProvider.overrideWithValue(restaurants),
      serviceabilityRepositoryProvider.overrideWithValue(zones),
    ],
  );
  addTearDown(container.dispose);
  // The Home list is on screen.
  container.listen(restaurantListProvider, (_, _) {});
  return (
    container: container,
    locations: locations,
    zones: zones,
    restaurants: restaurants,
  );
}

List<String> _ids(ProviderContainer c) =>
    (c.read(restaurantListProvider).valueOrNull ?? const [])
        .map((r) => r.id)
        .toList();

void main() {
  test(
    'restaurant query is blocked while the location is being checked',
    () async {
      final s = _setup();
      await pumpEventQueue();

      // The zones were asked for, and have not answered yet.
      expect(s.zones.pending, hasLength(1));
      expect(s.container.read(restaurantListProvider).isLoading, isTrue);
      expect(s.restaurants.getAllCalls, 0);
      expect(s.restaurants.discoverableCalls, 0);
    },
  );

  test('restaurant query is blocked when the location is not served — the '
      'restaurants are not even read', () async {
    final s = _setup();
    await pumpEventQueue();

    // Tukkito operates in Chennai only; the customer's location is Madurai.
    s.zones.answer(0, [zoneAround(chennai)]);
    await pumpEventQueue();

    expect(_ids(s.container), isEmpty);
    expect(s.container.read(restaurantListProvider).hasValue, isTrue);
    expect(s.restaurants.getAllCalls, 0);
    expect(s.restaurants.discoverableCalls, 0);
  });

  test('restaurant query runs only after a served result, and lists only '
      'what serves the location', () async {
    final s = _setup();
    await pumpEventQueue();
    expect(s.restaurants.getAllCalls, 0);

    s.zones.answer(0, [zoneAround(madurai)]);
    await pumpEventQueue();

    expect(s.restaurants.getAllCalls, 0);
    expect(s.restaurants.discoverableCalls, 1);
    expect(_ids(s.container), ['a2b']);
  });

  test('a previously served location does not leak its restaurants into a '
      'newly chosen one while that is being checked', () async {
    final s = _setup();
    await pumpEventQueue();
    s.zones.answer(0, [zoneAround(madurai)]);
    await pumpEventQueue();
    expect(_ids(s.container), ['a2b']);
    expect(s.restaurants.getAllCalls, 0);
    expect(s.restaurants.discoverableCalls, 1);

    // The customer chooses Chennai; its check is still running.
    s.locations.stored = destinationIn(chennai);
    s.container.invalidate(userLocationProvider(_userId));
    await pumpEventQueue();

    expect(s.zones.pending, hasLength(2));
    expect(s.container.read(restaurantListProvider).isLoading, isTrue);
    expect(s.restaurants.getAllCalls, 0);
    expect(s.restaurants.discoverableCalls, 1);

    // Chennai turns out not to be served: nothing, and Madurai's restaurants
    // are not offered as a fallback.
    s.zones.answer(1, [zoneAround(madurai)]);
    await pumpEventQueue();

    expect(_ids(s.container), isEmpty);
    expect(s.restaurants.getAllCalls, 0);
    expect(s.restaurants.discoverableCalls, 1);
  });
}
