import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/category.dart';

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'food':
      case 'groceries':
      case 'dining':
        return Icons.restaurant_outlined;
      case 'housing':
      case 'home':
        return Icons.home_outlined;
      case 'travel':
        return Icons.flight_outlined;
      case 'coffee':
        return Icons.coffee_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'savings':
        return Icons.savings_outlined;
      case 'investing':
      case 'investment':
        return Icons.trending_up_outlined;
      case 'gym':
        return Icons.fitness_center_outlined;
      case 'salary':
        return Icons.attach_money_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'gift':
        return Icons.card_giftcard_outlined;
      case 'work':
      case 'business':
        return Icons.work_outline;
      case 'refund':
        return Icons.replay_outlined;
      case 'transport':
        return Icons.directions_bus_outlined;
      case 'fuel':
        return Icons.local_gas_station_outlined;
      case 'utilities':
        return Icons.bolt_outlined;
      case 'phone':
        return Icons.phone_android_outlined;
      case 'internet':
        return Icons.wifi_outlined;
      case 'subscriptions':
        return Icons.subscriptions_outlined;
      case 'health':
        return Icons.health_and_safety_outlined;
      case 'insurance':
        return Icons.verified_user_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'fee':
        return Icons.receipt_long_outlined;
      case 'tax':
        return Icons.request_quote_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Color _parseHexColor(String hexStr) {
    try {
      final hexColor = hexStr.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (_) {
      return AikoColors.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAikoTip(context),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const AikoScreenState.loading(),
        error: (error, stack) => AikoScreenState.error(
          title: 'Categories are unavailable',
          message: 'Aiko could not load your categories right now.',
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return AikoScreenState.empty(
              title: 'No categories yet',
              message:
                  'Create categories to organize transactions and budgets.',
              action: PrimaryActionButton(
                label: 'Add Category',
                icon: Icons.add_circle_outline,
                onPressed: () => _showAddCategorySheet(context),
              ),
            );
          }

          final incomeCategories = _sortedForDisplay(
            categories
                .where((category) => category.type == CategoryType.income)
                .toList(growable: false),
          );
          final expenseCategories = _sortedForDisplay(
            categories
                .where((category) => category.type == CategoryType.expense)
                .toList(growable: false),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              if (incomeCategories.isNotEmpty)
                _CategoryTypeSection(
                  title: 'Income',
                  categories: incomeCategories,
                  accentColor: AikoColors.successGreen,
                  getIconData: _getIconData,
                  parseHexColor: _parseHexColor,
                  getGroupLabel: _getGroupLabel,
                  getTypeLabel: _getTypeLabel,
                ),
              if (expenseCategories.isNotEmpty)
                _CategoryTypeSection(
                  title: 'Expense',
                  categories: expenseCategories,
                  accentColor: AikoColors.dangerRed,
                  getIconData: _getIconData,
                  parseHexColor: _parseHexColor,
                  getGroupLabel: _getGroupLabel,
                  getTypeLabel: _getTypeLabel,
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategorySheet(context),
        label: const Text('Add Category'),
        icon: const Icon(Icons.add),
        backgroundColor: AikoColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
    );
  }

  List<Category> _sortedForDisplay(List<Category> categories) {
    final sorted = [...categories];
    sorted.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  void _showAddCategorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddCategoryBottomSheet(),
    );
  }

  String _getGroupLabel(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.needs:
        return 'Needs';
      case CategoryGroup.wants:
        return 'Wants';
      case CategoryGroup.savings:
        return 'Savings';
      case CategoryGroup.debt:
        return 'Debt';
      case CategoryGroup.investment:
        return 'Investment';
      case CategoryGroup.tax:
        return 'Tax';
      case CategoryGroup.business:
        return 'Business';
      case CategoryGroup.custom:
        return 'Custom';
    }
  }

  String _getTypeLabel(CategoryType type) {
    switch (type) {
      case CategoryType.income:
        return 'Income';
      case CategoryType.expense:
        return 'Expense';
      case CategoryType.transfer:
        return 'Transfer';
      case CategoryType.finance:
        return 'Finance';
      case CategoryType.tax:
        return 'Tax';
      case CategoryType.investment:
        return 'Investment';
      case CategoryType.adjustment:
        return 'Adjustment';
    }
  }

  void _showAikoTip(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AikoColors.primaryBlue,
              ),
              child: const Icon(Icons.face, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            const Text('Aiko\'s Guidance'),
          ],
        ),
        content: const Text(
          'Organizing your transactions into Needs, Wants, and Savings categories helps me generate '
          'smarter insights about your spending behaviors!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I see!'),
          ),
        ],
      ),
    );
  }
}

class _CategoryTypeSection extends StatelessWidget {
  const _CategoryTypeSection({
    required this.title,
    required this.categories,
    required this.accentColor,
    required this.getIconData,
    required this.parseHexColor,
    required this.getGroupLabel,
    required this.getTypeLabel,
  });

  final String title;
  final List<Category> categories;
  final Color accentColor;
  final IconData Function(String iconName) getIconData;
  final Color Function(String hexColor) parseHexColor;
  final String Function(CategoryGroup group) getGroupLabel;
  final String Function(CategoryType type) getTypeLabel;

  @override
  Widget build(BuildContext context) {
    final defaultCategories = categories
        .where((category) => category.isDefault)
        .toList(growable: false);
    final customCategories = categories
        .where((category) => !category.isDefault)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                title == 'Income'
                    ? Icons.arrow_downward_outlined
                    : Icons.arrow_upward_outlined,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...defaultCategories.map(
            (category) => _CategoryListCard(
              category: category,
              categoryIcon: getIconData(category.icon),
              categoryColor: parseHexColor(category.color),
              groupLabel: getGroupLabel(category.group),
              typeLabel: getTypeLabel(category.type),
            ),
          ),
          if (defaultCategories.isNotEmpty && customCategories.isNotEmpty)
            const SizedBox(height: 2),
          ...customCategories.map(
            (category) => _CategoryListCard(
              category: category,
              categoryIcon: getIconData(category.icon),
              categoryColor: parseHexColor(category.color),
              groupLabel: getGroupLabel(category.group),
              typeLabel: getTypeLabel(category.type),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryListCard extends StatelessWidget {
  const _CategoryListCard({
    required this.category,
    required this.categoryIcon,
    required this.categoryColor,
    required this.groupLabel,
    required this.typeLabel,
  });

  final Category category;
  final IconData categoryIcon;
  final Color categoryColor;
  final String groupLabel;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    final originColor = category.isDefault
        ? AikoColors.primaryBlue
        : AikoColors.analyticsTeal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          minLeadingWidth: 32,
          minVerticalPadding: 6,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  (category.isDefault
                          ? categoryColor.withValues(alpha: 0.72)
                          : categoryColor)
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              categoryIcon,
              color: category.isDefault
                  ? categoryColor.withValues(alpha: 0.72)
                  : categoryColor,
              size: 18,
            ),
          ),
          title: Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '$groupLabel - $typeLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CategoryStatusPill(
                label: category.isDefault ? 'Default' : 'Custom',
                color: originColor,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CategoryDetailScreen(
                category: category,
                categoryIcon: categoryIcon,
                categoryColor: categoryColor,
                typeLabel: typeLabel,
                groupLabel: groupLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({
    required this.category,
    required this.categoryIcon,
    required this.categoryColor,
    required this.typeLabel,
    required this.groupLabel,
    super.key,
  });

  final Category category;
  final IconData categoryIcon;
  final Color categoryColor;
  final String typeLabel;
  final String groupLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailColor = _categoryTypeColor(category.type);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category details'),
        actions: category.isDefault
            ? null
            : [
                IconButton(
                  tooltip: 'Edit category',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditCategorySheet(context),
                ),
                IconButton(
                  tooltip: 'Delete category',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FinanceCard(
            title: category.name,
            icon: categoryIcon,
            accentColor: detailColor,
            prominent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryStatusPill(
                  label: category.isDefault
                      ? 'Default category'
                      : (category.isActive ? 'Active' : 'Archived'),
                  color: category.isDefault
                      ? AikoColors.primaryBlue
                      : category.isActive
                      ? AikoColors.successGreen
                      : AikoColors.mutedText,
                ),
                const SizedBox(height: 16),
                _CategoryDetailRow(label: 'Type', value: typeLabel),
                const Divider(),
                _CategoryDetailRow(label: 'Group', value: groupLabel),
                if (category.parentId != null) ...[
                  const Divider(),
                  _CategoryDetailRow(
                    label: 'Parent',
                    value: category.parentId!,
                  ),
                ],
                const Divider(),
                _CategoryDetailRow(label: 'Color', value: category.color),
                const Divider(),
                _CategoryDetailRow(label: 'Icon', value: category.icon),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditCategorySheet(BuildContext context) async {
    if (category.isDefault) {
      return;
    }

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddCategoryBottomSheet(initialCategory: category),
    );

    if (updated == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    if (category.isDefault) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'This removes "${category.name}" from your category list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AikoColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref.read(categoriesProvider.notifier).deleteCategory(category.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Category "${category.name}" deleted.'),
          backgroundColor: AikoColors.successGreen,
        ),
      );
      if (context.mounted) {
        navigator.pop();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete category: $e'),
          backgroundColor: AikoColors.dangerRed,
        ),
      );
    }
  }
}

class _CategoryStatusPill extends StatelessWidget {
  const _CategoryStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CategoryDetailRow extends StatelessWidget {
  const _CategoryDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AikoColors.mutedText),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

Color _categoryTypeColor(CategoryType type) {
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

class _AddCategoryBottomSheet extends ConsumerStatefulWidget {
  const _AddCategoryBottomSheet({this.initialCategory});

  final Category? initialCategory;

  @override
  ConsumerState<_AddCategoryBottomSheet> createState() =>
      _AddCategoryBottomSheetState();
}

class _AddCategoryBottomSheetState
    extends ConsumerState<_AddCategoryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  CategoryType _selectedType = CategoryType.expense;
  CategoryGroup _selectedGroup = CategoryGroup.wants;
  String _selectedColorHex = '#3B82F6'; // Default: Aiko Blue
  String _selectedIconKey = 'category'; // Default generic
  bool _isSubmitting = false;

  final List<Map<String, String>> _colorsPreset = const [
    {'name': 'Blue', 'hex': '#3B82F6'},
    {'name': 'Green', 'hex': '#16A34A'},
    {'name': 'Orange', 'hex': '#F59E0B'},
    {'name': 'Red', 'hex': '#DC2626'},
    {'name': 'Purple', 'hex': '#7C3AED'},
    {'name': 'Teal', 'hex': '#0D9488'},
    {'name': 'Pink', 'hex': '#EC4899'},
    {'name': 'Indigo', 'hex': '#6366F1'},
  ];

  final List<Map<String, dynamic>> _iconsPreset = const [
    {'key': 'category', 'icon': Icons.category_outlined},
    {'key': 'food', 'icon': Icons.restaurant_outlined},
    {'key': 'housing', 'icon': Icons.home_outlined},
    {'key': 'travel', 'icon': Icons.flight_outlined},
    {'key': 'coffee', 'icon': Icons.coffee_outlined},
    {'key': 'shopping', 'icon': Icons.shopping_bag_outlined},
    {'key': 'savings', 'icon': Icons.savings_outlined},
    {'key': 'investing', 'icon': Icons.trending_up_outlined},
    {'key': 'gym', 'icon': Icons.fitness_center_outlined},
    {'key': 'salary', 'icon': Icons.attach_money_outlined},
    {'key': 'entertainment', 'icon': Icons.movie_outlined},
  ];

  bool get _isEditing => widget.initialCategory != null;

  @override
  void initState() {
    super.initState();
    final initialCategory = widget.initialCategory;
    if (initialCategory == null) {
      return;
    }

    _nameController.text = initialCategory.name;
    _selectedType = initialCategory.type;
    _selectedGroup = initialCategory.group;
    _selectedColorHex = initialCategory.color;
    _selectedIconKey = initialCategory.icon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

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
              userId: '', // Populated by repository
              name: _nameController.text.trim(),
              type: _selectedType,
              group: _selectedGroup,
              color: _selectedColorHex,
              icon: _selectedIconKey,
              budgetEnabled: true,
            )
          : initialCategory.copyWith(
              name: _nameController.text.trim(),
              type: _selectedType,
              group: _selectedGroup,
              color: _selectedColorHex,
              icon: _selectedIconKey,
              budgetEnabled: true,
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
      setState(() => _isSubmitting = false);
      if (mounted) {
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

  String _getGroupLabel(CategoryGroup group) {
    switch (group) {
      case CategoryGroup.needs:
        return 'Needs (e.g. rent, bills)';
      case CategoryGroup.wants:
        return 'Wants (e.g. dining out, fun)';
      case CategoryGroup.savings:
        return 'Savings (e.g. goals, emergency)';
      case CategoryGroup.debt:
        return 'Debt Repayment';
      case CategoryGroup.investment:
        return 'Investments';
      case CategoryGroup.tax:
        return 'Tax Related';
      case CategoryGroup.business:
        return 'Business Expenses';
      case CategoryGroup.custom:
        return 'Other Custom';
    }
  }

  String _getTypeLabel(CategoryType type) {
    switch (type) {
      case CategoryType.income:
        return 'Income (Money In)';
      case CategoryType.expense:
        return 'Expense (Money Out)';
      case CategoryType.transfer:
        return 'Transfer (Account to Account)';
      case CategoryType.finance:
        return 'Financial Operations';
      case CategoryType.tax:
        return 'Tax Category';
      case CategoryType.investment:
        return 'Investment Operations';
      case CategoryType.adjustment:
        return 'Balance Adjustment';
    }
  }

  Color _parseHex(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

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
                ],
              ),
              const SizedBox(height: 24),
              // Category Name
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
              // Category Type
              DropdownButtonFormField<CategoryType>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Category Type',
                  prefixIcon: const Icon(Icons.swap_horiz_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: CategoryType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getTypeLabel(type)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 16),
              // Category Group
              DropdownButtonFormField<CategoryGroup>(
                initialValue: _selectedGroup,
                decoration: InputDecoration(
                  labelText: 'Category Group (50/30/20 Rule)',
                  prefixIcon: const Icon(Icons.grid_view_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: CategoryGroup.values.map((group) {
                  return DropdownMenuItem(
                    value: group,
                    child: Text(_getGroupLabel(group)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedGroup = val);
                },
              ),
              const SizedBox(height: 20),
              // Beautiful Color Picker
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
                  itemCount: _colorsPreset.length,
                  itemBuilder: (context, idx) {
                    final item = _colorsPreset[idx];
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
              // Beautiful Icon Picker
              const Text(
                'Select Icon',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AikoColors.mutedText,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _iconsPreset.length,
                  itemBuilder: (context, idx) {
                    final item = _iconsPreset[idx];
                    final key = item['key'] as String;
                    final iconData = item['icon'] as IconData;
                    final isSelected = _selectedIconKey == key;
                    final activeColor = _parseHex(_selectedColorHex);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedIconKey = key),
                      child: Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.only(right: 12),
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
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Save Button
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
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
}
