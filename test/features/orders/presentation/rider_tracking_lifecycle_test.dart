import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/orders/domain/entities/rider_location.dart';
import 'package:customer_app/features/orders/domain/repositories/rider_location_repository.dart';
import 'package:customer_app/features/orders/domain/usecases/watch_rider_location_usecase.dart';
import 'package:customer_app/features/orders/presentation/providers/rider_location_provider.dart';

class _LifecycleRepository implements RiderLocationRepository {
  int cancelCalls = 0;
  int watchCalls = 0;
  final List<StreamController<DeliveryJobRiderTracking?>> controllers = [];

  @override
  Stream<DeliveryJobRiderTracking?> watchByOrderId(String orderId) {
    watchCalls += 1;
    final controller = StreamController<DeliveryJobRiderTracking?>();
    controller.onCancel = () {
      cancelCalls += 1;
    };
    controllers.add(controller);
    return controller.stream;
  }

  Future<void> closeAll() async {
    for (final controller in controllers) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }
}

void main() {
  test('disposing Order Details cancels the rider location listener', () async {
    final repository = _LifecycleRepository();
    final container = ProviderContainer(
      overrides: [
        watchRiderLocationUseCaseProvider.overrideWith(
          (ref) => WatchRiderLocationUseCase(repository),
        ),
      ],
    );

    container.read(riderTrackingProvider('order-1'));
    expect(repository.watchCalls, 1);

    container.dispose();
    await pumpEventQueue();
    expect(repository.cancelCalls, 1);
    await repository.closeAll();
  });

  test(
    're-opening tracking does not stack listeners on the previous stream',
    () async {
      final repository = _LifecycleRepository();

      for (var i = 0; i < 3; i++) {
        final container = ProviderContainer(
          overrides: [
            watchRiderLocationUseCaseProvider.overrideWith(
              (ref) => WatchRiderLocationUseCase(repository),
            ),
          ],
        );
        container.read(riderTrackingProvider('order-1'));
        container.dispose();
        await pumpEventQueue();
      }

      expect(repository.watchCalls, 3);
      expect(repository.cancelCalls, 3);
      await repository.closeAll();
    },
  );

  test(
    '10 Order Details open/close cycles cancel every rider listener',
    () async {
      final repository = _LifecycleRepository();

      for (var i = 0; i < 10; i++) {
        final container = ProviderContainer(
          overrides: [
            watchRiderLocationUseCaseProvider.overrideWith(
              (ref) => WatchRiderLocationUseCase(repository),
            ),
          ],
        );
        container.read(riderTrackingProvider('order-1'));
        container.dispose();
        await pumpEventQueue();
      }

      expect(repository.watchCalls, 10);
      expect(repository.cancelCalls, 10);
      await repository.closeAll();
    },
  );
}
