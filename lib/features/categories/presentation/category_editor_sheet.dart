import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/category.dart';
import 'category_group_editor_sheet.dart';
import 'category_visual.dart';

/// Shows the bottom sheet for creating or editing a [Category]. Returns
/// `true` on save, `false` on cancel, or `null` if dismissed. The sheet is
/// a no-op for default/system categories — they cannot be edited.
Future<bool?> showCategoryEditorSheet(
  BuildContext context, {
  Category? initialCategory,
  CategoryType initialType = CategoryType.expense,
  String? groupIdHint,
}) {
  if (initialCategory?.isDefault ?? false) {
    return Future.value(false);
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CategoryEditorSheet(
      initialCategory: initialCategory,
      initialType: initialType,
      groupIdHint: groupIdHint,
    ),
  );
}

Color categoryTypeAccent(CategoryType type) {
  return switch (type) {
    CategoryType.income => AikoColors.successGreen,
    CategoryType.expense => AikoColors.dangerRed,
    CategoryType.transfer => AikoColors.primaryBlue,
    CategoryType.finance => AikoColors.primaryBlue,
    CategoryType.tax => AikoColors.warningOrange,
    CategoryType.investment => AikoColors.analyticsTeal,
    CategoryType.adjustment => AikoColors.mutedText,
  };
}

class _CategoryEditorSheet extends ConsumerStatefulWidget {
  const _CategoryEditorSheet({
    this.initialCategory,
    this.initialType = CategoryType.expense,
    this.groupIdHint,
  });

  final Category? initialCategory;
  final CategoryType initialType;

  /// When adding a new category from inside a group section, the group the
  /// user was viewing is passed through here so the new category lands in
  /// the same group by default.
  final String? groupIdHint;

  @override
  ConsumerState<_CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<_CategoryEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  CategoryType _selectedType = CategoryType.expense;
  String _selectedColorHex = '#3B82F6';
  String _selectedIconKey = 'category';
  String? _selectedGroupId;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isEditing => widget.initialCategory != null;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    final initialCategory = widget.initialCategory;
    if (initialCategory == null) {
      _selectedGroupId = widget.groupIdHint;
      return;
    }
    _nameController.text = initialCategory.name;
    _selectedType = initialCategory.type;
    _selectedColorHex = initialCategory.color;
    _selectedIconKey = initialCategory.icon;
    _selectedGroupId = initialCategory.groupId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _parseHex(String hex) => aikoHexColor(hex);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.initialCategory?.isDefault ?? false) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final initialCategory = widget.initialCategory;
      final category = initialCategory == null
          ? Category(
              id: const Uuid().v4(),
              userId: '',
              name: _nameController.text.trim(),
              type: _selectedType,
              group: CategoryBudgetGroup.custom,
              groupId: _selectedGroupId,
              color: _selectedColorHex,
              icon: _selectedIconKey,
              budgetEnabled: true,
            )
          : initialCategory.copyWith(
              name: _nameController.text.trim(),
              type: _selectedType,
              color: _selectedColorHex,
              icon: _selectedIconKey,
              groupId: _selectedGroupId,
            );

      await ref.read(categoriesProvider.notifier).saveCategory(category);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Category "${category.name}" updated successfully!'
                  : 'Category "${category.name}" added successfully!',
            ),
            backgroundColor: AikoColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Failed to update category: $e'
                  : 'Failed to add category: $e',
            ),
            backgroundColor: AikoColors.dangerRed,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final category = widget.initialCategory;
    if (category == null || category.isDefault) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text(
          'This removes the category from your list. Existing transactions keep their saved details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AikoColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await ref.read(categoriesProvider.notifier).deleteCategory(category.id);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "${category.name}" deleted.'),
            backgroundColor: AikoColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete category: $e'),
            backgroundColor: AikoColors.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final groupsAsync = ref.watch(categoryGroupsProvider);
    final groups = groupsAsync.value ?? const <CategoryGroup>[];

    return Container(
      decoration: const BoxDecoration(
        color: AikoColors.appBackgroundLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AikoColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AikoColors.primaryBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.new_label_outlined,
                      color: AikoColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Edit Category' : 'Add Category',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_isEditing)
                    IconButton(
                      tooltip: 'Delete category',
                      color: AikoColors.dangerRed,
                      onPressed: _isSubmitting || _isDeleting
                          ? null
                          : _confirmDelete,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AikoColors.dangerRed,
                              ),
                            )
                          : const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SegmentedButton<CategoryType>(
                key: const Key('category-type-selector'),
                showSelectedIcon: false,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return categoryTypeAccent(_selectedType);
                    }
                    return null;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AikoColors.white;
                    }
                    return null;
                  }),
                  iconColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AikoColors.white;
                    }
                    return null;
                  }),
                ),
                segments: const [
                  ButtonSegment(
                    value: CategoryType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.north_east),
                  ),
                  ButtonSegment(
                    value: CategoryType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.south_west),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedType = selection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g., Groceries, Rent, Gym Membership',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category name';
                  }
                  final list = categoriesAsync.value ?? [];
                  if (list.any(
                    (c) =>
                        c.id != widget.initialCategory?.id &&
                        c.type == _selectedType &&
                        c.name.toLowerCase() == value.trim().toLowerCase(),
                  )) {
                    return 'A category with this name already exists';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _GroupPicker(
                key: const Key('category-group-picker'),
                groups: groups,
                selectedGroupId: _selectedGroupId,
                onChanged: (id) => setState(() => _selectedGroupId = id),
                onCreateNew: () => _createGroupInline(),
                accentColor: _parseHex(_selectedColorHex),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Theme Color',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AikoColors.mutedText,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: aikoCategoryColorPresets.length,
                  itemBuilder: (context, idx) {
                    final item = aikoCategoryColorPresets[idx];
                    final colorHex = item['hex']!;
                    final colorVal = _parseHex(colorHex);
                    final isSelected = _selectedColorHex == colorHex;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorHex = colorHex),
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: colorVal,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.black
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Icon',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AikoColors.mutedText,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final activeColor = _parseHex(_selectedColorHex);

                  return LayoutBuilder(
                    key: const Key('category-icon-grid'),
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 420
                          ? 7
                          : constraints.maxWidth >= 340
                          ? 6
                          : 5;
                      const spacing = 8.0;
                      const tileSize = 48.0;
                      final gridWidth =
                          tileSize * crossAxisCount +
                          spacing * (crossAxisCount - 1);
                      final rowCount =
                          (aikoCategoryIconPresets.length / crossAxisCount)
                              .ceil();

                      return Center(
                        child: SizedBox(
                          width: gridWidth,
                          height:
                              tileSize * rowCount + spacing * (rowCount - 1),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                  mainAxisSpacing: spacing,
                                  crossAxisSpacing: spacing,
                                ),
                            itemCount: aikoCategoryIconPresets.length,
                            itemBuilder: (context, idx) {
                              final entry = aikoCategoryIconPresets[idx];
                              final key = entry.key;
                              final iconData = entry.value;
                              final isSelected = _selectedIconKey == key;

                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    setState(() => _selectedIconKey = key),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? activeColor.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? activeColor
                                          : AikoColors.borderSubtle,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: isSelected
                                        ? activeColor
                                        : AikoColors.mutedText,
                                    size: 23,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSubmitting || _isDeleting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AikoColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _isSubmitting
                      ? (_isEditing
                            ? 'Updating Category...'
                            : 'Adding Category...')
                      : (_isEditing ? 'Update Category' : 'Save Category'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createGroupInline() async {
    final created = await showCategoryGroupEditorSheet(context);
    if (created == true) {
      // After save, the new group will be at the tail of the list — pick
      // the most-recent one (the one we just created) as the new selection.
      final groups = ref.read(categoryGroupsProvider).value ?? const [];
      if (groups.isNotEmpty) {
        setState(() => _selectedGroupId = groups.last.id);
      }
    }
  }
}

class _GroupPicker extends StatelessWidget {
  const _GroupPicker({
    super.key,
    required this.groups,
    required this.selectedGroupId,
    required this.onChanged,
    required this.onCreateNew,
    required this.accentColor,
  });

  final List<CategoryGroup> groups;
  final String? selectedGroupId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCreateNew;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Group',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AikoColors.mutedText,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: selectedGroupId,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.folder_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          hint: const Text('Ungrouped'),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Ungrouped'),
            ),
            for (final group in groups)
              DropdownMenuItem<String?>(
                value: group.id,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: aikoHexColor(group.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            DropdownMenuItem<String?>(
              value: '__create__',
              child: Row(
                children: [
                  Icon(Icons.add, color: accentColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Create new group...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value == '__create__') {
              onCreateNew();
              return;
            }
            onChanged(value);
          },
        ),
      ],
    );
  }
}
