import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasource/dashboard_datasource.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../domain/entities/category.dart';
import '../domain/usecases/get_categories_usecase.dart';

/// Datasource
final dashboardDatasourceProvider = Provider<DashboardDatasource>(
  (ref) => DashboardDatasource(),
);

/// Repository
final dashboardRepositoryProvider = Provider<DashboardRepositoryImpl>(
  (ref) => DashboardRepositoryImpl(ref.read(dashboardDatasourceProvider)),
);

/// UseCase
final getCategoriesUseCaseProvider = Provider<GetCategoriesUseCase>(
  (ref) => GetCategoriesUseCase(ref.read(dashboardRepositoryProvider)),
);

/// Dashboard Notifier
class DashboardNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  DashboardNotifier(this._ref) : super(const AsyncValue.loading());

  final Ref _ref;

  Future<void> loadCategories() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      return _ref.read(getCategoriesUseCaseProvider).call();
    });
  }
}

/// Dashboard Provider
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, AsyncValue<List<Category>>>(
      (ref) => DashboardNotifier(ref),
    );
