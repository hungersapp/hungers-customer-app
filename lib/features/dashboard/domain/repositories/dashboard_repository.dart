import '../entities/category.dart';

abstract class DashboardRepository {
  Future<List<Category>> getCategories();
}