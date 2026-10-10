import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/category.dart';
import 'category_group_editor_sheet.dart';
import 'category_names.dart';
import 'category_visual.dart';
import 'widgets/category_budget_section.dart';
import 'widgets/category_group_picker.dart';

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

  return showAikoSheet<bool>(
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

Color categoryTypeAccent(BuildContext context, CategoryType type) {
  return switch (type) {
    CategoryType.income => AikoColors.successGreen,
    CategoryType.expense => AikoColors.dangerRed,
    CategoryType.transfer => AikoColors.primaryBlue,
    CategoryType.finance => AikoColors.primaryBlue,
    CategoryType.tax => AikoColors.warningOrange,
    CategoryType.investment => AikoColors.analyticsTeal,
    CategoryType.adjustment => Theme.of(context).colorScheme.onSurfaceVariant,
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
  final _budgetAmountController = TextEditingController();

  CategoryType _selectedType = CategoryType.expense;
  String _selectedColorHex = AikoColors.kAikoPrimaryColorHex;
  String _selectedIconKey = 'category';
  String? _selectedGroupId;
  CategoryBudgetPeriod _budgetPeriod = CategoryBudgetPeriod.monthly;
  bool _rolloverUnused = false;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  /// The name shown when editing started; null for a new category.
  String? _shownName;

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
    // Built-in categories open with their translated name (see
    // storedCategoryName for how an unchanged name is saved).
    _shownName = initialCategory.displayName(currentL10n());
    _nameController.text = _shownName!;
    _selectedType = initialCategory.type;
    _selectedColorHex = initialCategory.color;
    _selectedIconKey = initialCategory.icon;
    _selectedGroupId = initialCategory.groupId;
    final limit = initialCategory.monthlyLimit;
    if (limit != null) {
      _budgetAmountController.text = limit.amount.toString();
    }
    _budgetPeriod = initialCategory.budgetPeriod;
    _rolloverUnused = initialCategory.rolloverUnused;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetAmountController.dispose();
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
      final budgetAmount = _budgetAmountController.text.trim();
      final monthlyLimit = budgetAmount.isEmpty
          ? null
          : Money.parse(budgetAmount, _baseCurrency);
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
              monthlyLimit: monthlyLimit,
              budgetPeriod: _budgetPeriod,
              rolloverUnused: _rolloverUnused,
            )
          : initialCategory.copyWith(
              name: storedCategoryName(
                original: initialCategory.name,
                shown: _shownName ?? initialCategory.name,
                edited: _nameController.text,
              ),
              type: _selectedType,
              color: _selectedColorHex,
              icon: _selectedIconKey,
              groupId: _selectedGroupId,
              monthlyLimit: monthlyLimit,
              budgetPeriod: _budgetPeriod,
              rolloverUnused: _rolloverUnused,
            );

      await ref.read(categoriesProvider.notifier).saveCategory(category);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? context.l10n.categoryUpdated(
                      category.displayName(context.l10n),
                    )
                  : context.l10n.categoryAdded(
                      category.displayName(context.l10n),
                    ),
            ),
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
                  ? context.l10n.categorySaveFailed
                  : context.l10n.categorySaveFailed,
            ),
          ),
        );
      }
    }
  }

  String get _baseCurrency {
    final profile = ref.read(profileProvider).value;
    return profile?.baseCurrency ?? 'USD';
  }

  Future<void> _confirmDelete() async {
    final category = widget.initialCategory;
    if (category == null || category.isDefault) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.l10n.categoryDeleteQuestion(
            category.displayName(context.l10n),
          ),
        ),
        content: Text(context.l10n.categoryDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AikoColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
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
            content: Text(
              context.l10n.categoryDeleted(category.displayName(context.l10n)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.categoryDeleteFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final groupsAsync = ref.watch(categoryGroupsProvider);
    // All 13 default groups are offerable as assignment targets — users can
    // file a custom category into any of them. (Groups themselves stay
    // read-only via the "Edit group" affordance in the management screen.)
    final groups = (groupsAsync.value ?? const <CategoryGroup>[]).toList(
      growable: false,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              const AikoSheetHandle(),
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
                    _isEditing
                        ? context.l10n.categoryEditTitle
                        : context.l10n.categoriesAddCategory,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_isEditing)
                    IconButton(
                      tooltip: context.l10n.categoryDeleteTooltip,
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
                      return categoryTypeAccent(context, _selectedType);
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
                segments: [
                  ButtonSegment(
                    value: CategoryType.expense,
                    label: Text(context.l10n.categoryTypeExpense),
                    icon: Icon(Icons.north_east),
                  ),
                  ButtonSegment(
                    value: CategoryType.income,
                    label: Text(context.l10n.categoryTypeIncome),
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
                  labelText: context.l10n.categoryNameLabel,
                  hintText: context.l10n.categoryNameHint,
                  prefixIcon: const Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.categoryNameRequired;
                  }
                  final list = categoriesAsync.value ?? [];
                  if (list.any(
                    (c) =>
                        c.id != widget.initialCategory?.id &&
                        c.type == _selectedType &&
                        (c.name.toLowerCase() == value.trim().toLowerCase() ||
                            c.displayName(context.l10n).toLowerCase() ==
                                value.trim().toLowerCase()),
                  )) {
                    return context.l10n.categoryNameExists;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CategoryGroupPicker(
                key: const Key('category-group-picker'),
                groups: groups,
                selectedGroupId: _selectedGroupId,
                onChanged: (id) => setState(() => _selectedGroupId = id),
                onCreateNew: () => _createGroupInline(),
                accentColor: _parseHex(_selectedColorHex),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.categorySelectColor,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                ? Theme.of(context).colorScheme.onSurface
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
              Text(
                context.l10n.categorySelectIcon,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                          : Theme.of(
                                              context,
                                            ).colorScheme.outlineVariant,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: isSelected
                                        ? activeColor
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
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
              CategoryBudgetSection(
                key: const Key('category-budget-section'),
                amountController: _budgetAmountController,
                period: _budgetPeriod,
                rolloverUnused: _rolloverUnused,
                currency: _baseCurrency,
                onPeriodChanged: (p) => setState(() => _budgetPeriod = p),
                onRolloverChanged: (v) => setState(() => _rolloverUnused = v),
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
                            ? context.l10n.categoryUpdating
                            : context.l10n.categoryAdding)
                      : (_isEditing
                            ? context.l10n.categoryUpdate
                            : context.l10n.categorySave),
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
      // After save, the new group will be at the tail of the user groups —
      // pick the most-recent one (the one we just created) as the new
      // selection. The 13 default groups always sort after user groups.
      final userGroups = (ref.read(categoryGroupsProvider).value ?? const [])
          .where((group) => !group.isSystem)
          .toList(growable: false);
      if (userGroups.isNotEmpty) {
        setState(() => _selectedGroupId = userGroups.last.id);
      }
    }
  }
}
