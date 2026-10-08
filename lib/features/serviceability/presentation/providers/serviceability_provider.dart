import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/providers/auth_provider.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../data/datasources/serviceability_functions_datasource.dart';
import '../../data/datasources/serviceability_zones_firestore_datasource.dart';
import '../../data/repositories/serviceability_repository_impl.dart';
import '../../domain/entities/serviceability_result.dart';
import '../../domain/indian_pincode.dart';
import '../../domain/repositories/serviceability_repository.dart';
import '../../domain/usecases/check_pincode_serviceability_usecase.dart';

final functionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instance,
);

final serviceabilityDatasourceProvider =
    Provider<ServiceabilityFunctionsDatasource>(
  (ref) => ServiceabilityFunctionsDatasource(
    functions: ref.watch(functionsProvider),
  ),
);

final serviceabilityZonesDatasourceProvider =
    Provider<ServiceabilityZonesFirestoreDatasource>(
  (ref) => ServiceabilityZonesFirestoreDatasource(
    ref.watch(firestoreProvider),
  ),
);

final serviceabilityRepositoryProvider = Provider<ServiceabilityRepository>(
  (ref) => ServiceabilityRepositoryImpl(
    ref.watch(serviceabilityDatasourceProvider),
    zonesDatasource: ref.watch(serviceabilityZonesDatasourceProvider),
  ),
);

final checkPincodeServiceabilityUseCaseProvider =
    Provider<CheckPincodeServiceabilityUseCase>(
  (ref) => CheckPincodeServiceabilityUseCase(
    ref.watch(serviceabilityRepositoryProvider),
  ),
);

enum ServiceabilityUiStatus {
  initial,
  checking,
  serviceable,
  notServiceable,
  invalidPincode,
  error,
}

class ServiceabilityState {
  const ServiceabilityState({
    this.status = ServiceabilityUiStatus.initial,
    this.pincode,
  });

  final ServiceabilityUiStatus status;
  final String? pincode;

  bool get allowsRestaurantQuery =>
      status == ServiceabilityUiStatus.serviceable;

  ServiceabilityState copyWith({
    ServiceabilityUiStatus? status,
    String? pincode,
    bool clearPincode = false,
  }) {
    return ServiceabilityState(
      status: status ?? this.status,
      pincode: clearPincode ? null : (pincode ?? this.pincode),
    );
  }
}

class ServiceabilityNotifier extends StateNotifier<ServiceabilityState> {
  ServiceabilityNotifier(this._ref) : super(const ServiceabilityState());

  final Ref _ref;
  int _checkGeneration = 0;

  /// Invalidates the previous result and checks [rawPincode].
  Future<void> submitPincode(String rawPincode) async {
    final pincode = IndianPincode.normalize(rawPincode);
    if (pincode == null) {
      state = ServiceabilityState(
        status: ServiceabilityUiStatus.invalidPincode,
        pincode: rawPincode.trim().isEmpty ? null : rawPincode.trim(),
      );
      return;
    }

    await _checkPincode(pincode, persist: true);
  }

  Future<void> retry() async {
    final pincode = state.pincode;
    if (pincode == null || !IndianPincode.isValid(pincode)) {
      state = const ServiceabilityState(
        status: ServiceabilityUiStatus.invalidPincode,
      );
      return;
    }
    await _checkPincode(pincode, persist: false);
  }

  /// Applies a saved delivery pincode. No-ops when already handling it.
  Future<void> syncFromSavedPincode(String? rawPincode) async {
    final pincode = rawPincode == null ? null : IndianPincode.normalize(rawPincode);
    if (pincode == null) {
      return;
    }
    if (pincode == state.pincode &&
        (state.status == ServiceabilityUiStatus.checking ||
            state.status == ServiceabilityUiStatus.serviceable ||
            state.status == ServiceabilityUiStatus.notServiceable)) {
      return;
    }
    await _checkPincode(pincode, persist: false);
  }

  void invalidate() {
    _checkGeneration += 1;
    state = const ServiceabilityState();
  }

  Future<void> _checkPincode(
    String pincode, {
    required bool persist,
  }) async {
    final generation = ++_checkGeneration;
    state = ServiceabilityState(
      status: ServiceabilityUiStatus.checking,
      pincode: pincode,
    );

    if (persist) {
      final userId = _ref.read(currentUserIdProvider);
      if (userId != null) {
        try {
          await _ref.read(saveDeliveryPincodeUseCaseProvider).call(
                userId: userId,
                pincode: pincode,
              );
          _ref.invalidate(userLocationProvider(userId));
          _ref.invalidate(deliveryPincodeProvider(userId));
        } catch (_) {
          // Persist is best-effort. The check is the source of truth.
        }
      }
    }

    final result = await _ref.read(checkPincodeServiceabilityUseCaseProvider)(
      pincode,
    );

    if (generation != _checkGeneration) {
      return;
    }

    state = ServiceabilityState(
      status: _statusFor(result.outcome),
      pincode: pincode,
    );
  }

  ServiceabilityUiStatus _statusFor(ServiceabilityOutcome outcome) {
    switch (outcome) {
      case ServiceabilityOutcome.serviceable:
        return ServiceabilityUiStatus.serviceable;
      case ServiceabilityOutcome.notServiceable:
        return ServiceabilityUiStatus.notServiceable;
      case ServiceabilityOutcome.invalidPincode:
        return ServiceabilityUiStatus.invalidPincode;
      case ServiceabilityOutcome.unavailable:
        return ServiceabilityUiStatus.error;
    }
  }
}

final serviceabilityProvider =
    StateNotifierProvider<ServiceabilityNotifier, ServiceabilityState>((ref) {
  final notifier = ServiceabilityNotifier(ref);
  final userId = ref.watch(currentUserIdProvider);
  if (userId != null) {
    ref.read(deliveryPincodeProvider(userId)).whenData(
          notifier.syncFromSavedPincode,
        );
    ref.listen(deliveryPincodeProvider(userId), (previous, next) {
      next.whenData(notifier.syncFromSavedPincode);
    });
  }
  return notifier;
});
