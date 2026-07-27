import 'package:aiko/brick/brick.g.dart';
import 'package:aiko/brick/models/category.model.dart';
import 'package:aiko/brick/models/category_group.model.dart';
import 'package:brick_supabase/brick_supabase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final provider = SupabaseProvider(
    SupabaseClient('https://offline.aiko.local', 'offline-anon-key'),
    modelDictionary: supabaseModelDictionary,
  );

  test('category clone writes template_id to Supabase', () async {
    final row = await OfflineCategoryAdapter().toSupabase(
      OfflineCategory(
        id: 'category-clone',
        userId: 'user',
        templateId: 'category-template',
        name: 'Coffee',
        type: 'expense',
        categoryGroup: 'wants',
      ),
      provider: provider,
    );

    expect(row['template_id'], 'category-template');
  });

  test('group clone writes template_id to Supabase', () async {
    final row = await OfflineCategoryGroupAdapter().toSupabase(
      OfflineCategoryGroup(
        id: 'group-clone',
        userId: 'user',
        templateId: 'group-template',
        name: 'Food & Drink',
      ),
      provider: provider,
    );

    expect(row['template_id'], 'group-template');
  });
}
