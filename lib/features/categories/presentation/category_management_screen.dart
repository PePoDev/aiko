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
        return Icons.restaurant_outlined;
      case 'housing':
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
        return Icons.trending_up_outlined;
      case 'gym':
        return Icons.fitness_center_outlined;
      case 'salary':
        return Icons.attach_money_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
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

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final categoryColor = _parseHexColor(category.color);
              final categoryIcon = _getIconData(category.icon);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: FinanceCard(
                  title: category.name,
                  icon: categoryIcon,
                  accentColor: categoryColor,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AikoColors.mutedText,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _CategoryDetailScreen(
                        category: category,
                        categoryIcon: categoryIcon,
                        categoryColor: categoryColor,
                        typeLabel: _getTypeLabel(category.type),
                        groupLabel: _getGroupLabel(category.group),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_getGroupLabel(category.group)} • ${_getTypeLabel(category.type)}',
                        style: const TextStyle(color: AikoColors.mutedText),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: category.budgetEnabled
                              ? AikoColors.successGreen.withValues(alpha: 0.1)
                              : AikoColors.mutedText.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category.budgetEnabled ? 'Budget On' : 'Budget Off',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: category.budgetEnabled
                                ? AikoColors.successGreen
                                : AikoColors.mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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

class _CategoryDetailScreen extends StatelessWidget {
  const _CategoryDetailScreen({
    required this.category,
    required this.categoryIcon,
    required this.categoryColor,
    required this.typeLabel,
    required this.groupLabel,
  });

  final Category category;
  final IconData categoryIcon;
  final Color categoryColor;
  final String typeLabel;
  final String groupLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Category details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FinanceCard(
            title: category.name,
            icon: categoryIcon,
            accentColor: categoryColor,
            prominent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryStatusPill(
                  label: category.isActive ? 'Active' : 'Archived',
                  color: category.isActive
                      ? AikoColors.successGreen
                      : AikoColors.mutedText,
                ),
                const SizedBox(height: 16),
                _CategoryDetailRow(label: 'Type', value: typeLabel),
                const Divider(),
                _CategoryDetailRow(label: 'Group', value: groupLabel),
                const Divider(),
                _CategoryDetailRow(
                  label: 'Budget',
                  value: category.budgetEnabled ? 'Enabled' : 'Disabled',
                ),
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

class _AddCategoryBottomSheet extends ConsumerStatefulWidget {
  const _AddCategoryBottomSheet();

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
  bool _budgetEnabled = true;
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final category = Category(
        id: const Uuid().v4(),
        userId: '', // Populated by repository
        name: _nameController.text.trim(),
        type: _selectedType,
        group: _selectedGroup,
        color: _selectedColorHex,
        icon: _selectedIconKey,
        budgetEnabled: _budgetEnabled,
      );

      await ref.read(categoriesProvider.notifier).addCategory(category);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "${category.name}" added successfully!'),
            backgroundColor: AikoColors.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add category: $e'),
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
                    'Add Category',
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
                    (c) => c.name.toLowerCase() == value.trim().toLowerCase(),
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
              const SizedBox(height: 16),
              // Budget Enabled Toggle Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Include in Budgets',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Enables setting up spending budget rules for this category',
                ),
                value: _budgetEnabled,
                activeThumbColor: AikoColors.primaryBlue,
                onChanged: (val) => setState(() => _budgetEnabled = val),
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
                  _isSubmitting ? 'Adding Category...' : 'Save Category',
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
