import '../domain/category.dart';

class CategoryService {
  const CategoryService();

  Category archive(Category category) => category.copyWith(isActive: false);

  Category mergeInto(Category source, Category target) {
    if (source.type != target.type) {
      throw ArgumentError('Cannot merge categories with different types.');
    }
    return source.copyWith(isActive: false);
  }
}
