import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/presentation/providers/location_provider.dart';
import '../../serviceability/presentation/providers/serviceability_provider.dart';
import '../domain/usecases/register_new_customer_if_serviceable_usecase.dart';
import 'auth_provider.dart';

final registerNewCustomerIfServiceableUseCaseProvider =
    Provider<RegisterNewCustomerIfServiceableUseCase>(
  (ref) => RegisterNewCustomerIfServiceableUseCase(
    authRepository: ref.watch(authRepositoryProvider),
    serviceabilityRepository: ref.watch(serviceabilityRepositoryProvider),
    deviceLocationService: ref.watch(deviceLocationServiceProvider),
  ),
);
