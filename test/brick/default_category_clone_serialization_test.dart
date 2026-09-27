import 'package:aiko/brick/model_dictionary.dart';
import 'package:aiko/brick/models/category.model.dart';
import 'package:aiko/brick/models/category_group.model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('category clone writes template_id to Firestore', () async {
    final row = await OfflineCategoryAdapter().toFirestore(
      OfflineCategory(
        id: 'category-clone',
        userId: 'user',
        templateId: 'category-template',
        name: 'Coffee',
        type: 'expense',
        categoryGroup: 'wants',
      ),
      provider: null,
    );

    expect(row['template_id'], 'category-template');
  });

  test('group clone writes template_id to Firestore', () async {
    final row = await OfflineCategoryGroupAdapter().toFirestore(
      OfflineCategoryGroup(
        id: 'group-clone',
        userId: 'user',
        templateId: 'group-template',
        name: 'Food & Drink',
      ),
      provider: null,
    );

    expect(row['template_id'], 'group-template');
  });
}
