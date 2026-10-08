import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/serviceability/domain/entities/active_delivery_zone.dart';
import 'package:customer_app/features/serviceability/domain/entities/serviceability_result.dart';
import 'package:customer_app/features/serviceability/domain/repositories/serviceability_repository.dart';
import 'package:customer_app/features/serviceability/domain/usecases/check_pincode_serviceability_usecase.dart';

class _FakeRepository implements ServiceabilityRepository {
  _FakeRepository(this.onCheck);

  final Future<ServiceabilityResult> Function(String pincode) onCheck;
  int calls = 0;
  String? lastPincode;

  @override
  Future<ServiceabilityResult> checkPincode(String pincode) {
    calls += 1;
    lastPincode = pincode;
    return onCheck(pincode);
  }

  @override
  Future<List<ActiveDeliveryZone>> getActiveDeliveryZones() async => [];
}

void main() {
  test('does not call the backend for an invalid pincode', () async {
    final repository = _FakeRepository(
      (_) async => const ServiceabilityResult.serviceable('000000'),
    );
    final useCase = CheckPincodeServiceabilityUseCase(repository);

    final result = await useCase('12ab');

    expect(result.outcome, ServiceabilityOutcome.invalidPincode);
    expect(repository.calls, 0);
  });

  test('returns serviceable from the backend for a valid pincode', () async {
    final repository = _FakeRepository(
      (pincode) async => ServiceabilityResult.serviceable(pincode),
    );
    final useCase = CheckPincodeServiceabilityUseCase(repository);

    final result = await useCase('613403');

    expect(result, const ServiceabilityResult.serviceable('613403'));
    expect(repository.calls, 1);
    expect(repository.lastPincode, '613403');
  });

  test(
    'maps backend not-serviceable without treating it as an error',
    () async {
      final repository = _FakeRepository(
        (pincode) async => ServiceabilityResult.notServiceable(pincode),
      );

      final result = await CheckPincodeServiceabilityUseCase(repository)(
        '999999',
      );

      expect(result.outcome, ServiceabilityOutcome.notServiceable);
    },
  );

  test('maps backend failure to unavailable, not notServiceable', () async {
    final repository = _FakeRepository(
      (pincode) async => ServiceabilityResult.unavailable(pincode),
    );

    final result = await CheckPincodeServiceabilityUseCase(repository)(
      '613403',
    );

    expect(result.outcome, ServiceabilityOutcome.unavailable);
    expect(result.outcome, isNot(ServiceabilityOutcome.notServiceable));
  });
}
