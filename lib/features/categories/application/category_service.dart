import '../domain/category.dart';
import '../domain/category_defaults.dart';

class CategoryService {
  const CategoryService();

  Category archive(Category category) => category.copyWith(isActive: false);

  Category mergeInto(Category source, Category target) {
    if (source.type != target.type) {
      throw ArgumentError('Cannot merge categories with different types.');
    }
    return source.copyWith(isActive: false);
  }

  /// Returns the 81 global default categories. [userId] is unused — default
  /// categories are global (user_id = NULL in Supabase) and injected
  /// in-memory at the provider layer without per-user storage.
  List<Category> defaultCategoriesFor(String userId) => CategoryDefaults.all;
}
