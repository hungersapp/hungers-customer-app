import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/rider_location_firestore_datasource.dart';
import '../../data/repositories/rider_location_repository_impl.dart';
import '../../domain/entities/rider_location.dart';
import '../../domain/repositories/rider_location_repository.dart';
import '../../domain/usecases/watch_rider_location_usecase.dart';
import 'order_provider.dart';

final riderLocationDatasourceProvider =
    Provider<RiderLocationFirestoreDatasource>((ref) {
      return RiderLocationFirestoreDatasource(
        ref.watch(orderFirestoreProvider),
      );
    });

final riderLocationRepositoryProvider = Provider<RiderLocationRepository>((
  ref,
) {
  return RiderLocationRepositoryImpl(
    ref.watch(riderLocationDatasourceProvider),
  );
});

final watchRiderLocationUseCaseProvider = Provider<WatchRiderLocationUseCase>((
  ref,
) {
  return WatchRiderLocationUseCase(
    ref.watch(riderLocationRepositoryProvider),
  );
});

/// Live `delivery_jobs/{orderId}` rider GPS for the customer's own order.
///
/// The Firestore snapshot subscription is cancelled in [ref.onDispose]
/// so Home → Order Details → Back cannot leak listeners.
final riderTrackingProvider = StreamProvider.autoDispose
    .family<DeliveryJobRiderTracking?, String>((ref, orderId) {
      final stream = ref.watch(watchRiderLocationUseCaseProvider)(orderId);
      final controller = StreamController<DeliveryJobRiderTracking?>();
      final subscription = stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      ref.onDispose(() {
        subscription.cancel();
        if (!controller.isClosed) {
          controller.close();
        }
      });
      return controller.stream;
    });
