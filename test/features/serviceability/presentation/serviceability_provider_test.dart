import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/serviceability/domain/entities/active_delivery_zone.dart';
import 'package:customer_app/features/serviceability/domain/entities/serviceability_result.dart';
import 'package:customer_app/features/serviceability/domain/repositories/serviceability_repository.dart';
import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';

class _FakeRepository implements ServiceabilityRepository {
  _FakeRepository();

  final Map<String, Completer<ServiceabilityResult>> pending = {};
  final List<String> calls = [];

  void complete(String pincode, ServiceabilityResult result) {
    pending[pincode]!.complete(result);
  }

  @override
  Future<ServiceabilityResult> checkPincode(String pincode) {
    calls.add(pincode);
    final completer = Completer<ServiceabilityResult>();
    pending[pincode] = completer;
    return completer.future;
  }

  @override
  Future<List<ActiveDeliveryZone>> getActiveDeliveryZones() async => [];
}

ProviderContainer _container(_FakeRepository repository) {
  return ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue(null),
      serviceabilityRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

void main() {
  test(
    'invalid pincode stays client-side and does not call the backend',
    () async {
      final repository = _FakeRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      await container.read(serviceabilityProvider.notifier).submitPincode('12');

      expect(
        container.read(serviceabilityProvider).status,
        ServiceabilityUiStatus.invalidPincode,
      );
      expect(repository.calls, isEmpty);
      expect(
        container.read(serviceabilityProvider).allowsRestaurantQuery,
        isFalse,
      );
    },
  );

  test('submit moves through checking then serviceable', () async {
    final repository = _FakeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final future = container
        .read(serviceabilityProvider.notifier)
        .submitPincode('613403');

    expect(
      container.read(serviceabilityProvider).status,
      ServiceabilityUiStatus.checking,
    );
    expect(
      container.read(serviceabilityProvider).allowsRestaurantQuery,
      isFalse,
    );

    repository.complete(
      '613403',
      const ServiceabilityResult.serviceable('613403'),
    );
    await future;

    expect(
      container.read(serviceabilityProvider).status,
      ServiceabilityUiStatus.serviceable,
    );
    expect(container.read(serviceabilityProvider).pincode, '613403');
    expect(
      container.read(serviceabilityProvider).allowsRestaurantQuery,
      isTrue,
    );
  });

  test('not-serviceable is distinct from a backend error', () async {
    final repository = _FakeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final notServiceable = container
        .read(serviceabilityProvider.notifier)
        .submitPincode('999999');
    repository.complete(
      '999999',
      const ServiceabilityResult.notServiceable('999999'),
    );
    await notServiceable;

    expect(
      container.read(serviceabilityProvider).status,
      ServiceabilityUiStatus.notServiceable,
    );

    final failed = container.read(serviceabilityProvider.notifier).retry();
    repository.complete(
      '999999',
      const ServiceabilityResult.unavailable('999999'),
    );
    await failed;

    expect(
      container.read(serviceabilityProvider).status,
      ServiceabilityUiStatus.error,
    );
    expect(
      container.read(serviceabilityProvider).status,
      isNot(ServiceabilityUiStatus.notServiceable),
    );
  });

  test('retry repeats the current pincode check', () async {
    final repository = _FakeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final first = container
        .read(serviceabilityProvider.notifier)
        .submitPincode('613403');
    repository.complete(
      '613403',
      const ServiceabilityResult.unavailable('613403'),
    );
    await first;

    final retry = container.read(serviceabilityProvider.notifier).retry();
    expect(
      container.read(serviceabilityProvider).status,
      ServiceabilityUiStatus.checking,
    );
    repository.complete(
      '613403',
      const ServiceabilityResult.serviceable('613403'),
    );
    await retry;

    expect(repository.calls, ['613403', '613403']);
    expect(
      container.read(serviceabilityProvider).status,
      ServiceabilityUiStatus.serviceable,
    );
  });

  test(
    'changing pincode invalidates the previous serviceable result immediately',
    () async {
      final repository = _FakeRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      final first = container
          .read(serviceabilityProvider.notifier)
          .submitPincode('613403');
      repository.complete(
        '613403',
        const ServiceabilityResult.serviceable('613403'),
      );
      await first;
      expect(
        container.read(serviceabilityProvider).allowsRestaurantQuery,
        isTrue,
      );

      final second = container
          .read(serviceabilityProvider.notifier)
          .submitPincode('625001');

      expect(container.read(serviceabilityProvider).pincode, '625001');
      expect(
        container.read(serviceabilityProvider).status,
        ServiceabilityUiStatus.checking,
      );
      expect(
        container.read(serviceabilityProvider).allowsRestaurantQuery,
        isFalse,
      );

      repository.complete(
        '625001',
        const ServiceabilityResult.notServiceable('625001'),
      );
      await second;

      expect(container.read(serviceabilityProvider).pincode, '625001');
      expect(
        container.read(serviceabilityProvider).status,
        ServiceabilityUiStatus.notServiceable,
      );
    },
  );
}
