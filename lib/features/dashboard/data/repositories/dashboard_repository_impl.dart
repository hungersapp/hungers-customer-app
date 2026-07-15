import '../../domain/entities/category.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasource/dashboard_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._datasource);

  final DashboardDatasource _datasource;

  @override
  Future<List<Category>> getCategories() async {
    return await _datasource.getCategories();
  }
}