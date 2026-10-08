import '../entities/category.dart';
import '../repositories/dashboard_repository.dart';

class GetCategoriesUseCase {
  const GetCategoriesUseCase(this._repository);

  final DashboardRepository _repository;

  Future<List<Category>> call() async {
    return await _repository.getCategories();
  }
}
