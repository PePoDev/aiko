import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/category.dart';

Future<bool?> showCategoryEditorSheet(
  BuildContext context, {
  Category? initialCategory,
  CategoryType initialType = CategoryType.expense,
}) {
  if (initialCategory?.isDefault ?? false) {
    return Future.value(false);
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddCategoryBottomSheet(
      initialCategory: initialCategory,
      initialType: initialType,
    ),
  );
}

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedTabIndex = 0;

  Color get _selectedTabColor =>
      _selectedTabIndex == 0 ? AikoColors.dangerRed : AikoColors.successGreen;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (_selectedTabIndex == _tabController.index) {
      return;
    }
    setState(() => _selectedTabIndex = _tabController.index);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

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
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCategorySheet(context),
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

          final incomeCategories = categories
              .where((category) => category.type == CategoryType.income)
              .toList(growable: false);
          final expenseCategories = categories
              .where((category) => category.type == CategoryType.expense)
              .toList(growable: false);

          return Column(
            children: [
              Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: _selectedTabColor,
                  labelColor: _selectedTabColor,
                  unselectedLabelColor: AikoColors.mutedText,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.arrow_upward_outlined),
                      text: 'Expense',
                    ),
                    Tab(
                      icon: Icon(Icons.arrow_downward_outlined),
                      text: 'Income',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CategoryTypeSection(
                      categories: expenseCategories,
                      emptyTitle: 'No expense categories yet',
                      emptyMessage:
                          'Add expense categories for bills, shopping, savings, and daily spending.',
                      getIconData: _getIconData,
                      parseHexColor: _parseHexColor,
                    ),
                    _CategoryTypeSection(
                      categories: incomeCategories,
                      emptyTitle: 'No income categories yet',
                      emptyMessage:
                          'Add income categories for salary, side work, and other money coming in.',
                      getIconData: _getIconData,
                      parseHexColor: _parseHexColor,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context) {
    showCategoryEditorSheet(
      context,
      initialType: _selectedTabIndex == 0
          ? CategoryType.expense
          : CategoryType.income,
    );
  }
}

class _CategoryTypeSection extends StatelessWidget {
  const _CategoryTypeSection({
    required this.categories,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.getIconData,
    required this.parseHexColor,
  });

  final List<Category> categories;
  final String emptyTitle;
  final String emptyMessage;
  final IconData Function(String iconName) getIconData;
  final Color Function(String hexColor) parseHexColor;

  @override
  Widget build(BuildContext context) {
    final defaultCategories = categories
        .where((category) => category.isDefault)
        .toList(growable: false);
    final customCategories = categories
        .where((category) => !category.isDefault)
        .toList(growable: false);

    if (categories.isEmpty) {
      return AikoScreenState.empty(
        title: emptyTitle,
        message: emptyMessage,
        action: null,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CategoryCardGrid(
          categories: [...defaultCategories, ...customCategories],
          getIconData: getIconData,
          parseHexColor: parseHexColor,
        ),
      ],
    );
  }
}

class _CategoryCardGrid extends StatelessWidget {
  const _CategoryCardGrid({
    required this.categories,
    required this.getIconData,
    required this.parseHexColor,
  });

  final List<Category> categories;
  final IconData Function(String iconName) getIconData;
  final Color Function(String hexColor) parseHexColor;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 520
            ? 3
            : constraints.maxWidth >= 340
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
            crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: categories
              .map(
                (category) => SizedBox(
                  width: cardWidth,
                  child: _CategoryListCard(
                    category: category,
                    categoryIcon: getIconData(category.icon),
                    categoryColor: parseHexColor(category.color),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _CategoryListCard extends StatelessWidget {
  const _CategoryListCard({
    required this.category,
    required this.categoryIcon,
    required this.categoryColor,
  });

  final Category category;
  final IconData categoryIcon;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = categoryColor;

    return Card(
      color: theme.cardColor,
      child: InkWell(
        onTap: category.isDefault
            ? null
            : () => _showEditCategorySheet(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(categoryIcon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (category.isDefault) ...[
                  const Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: AikoColors.mutedText,
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditCategorySheet(BuildContext context) async {
    await showCategoryEditorSheet(context, initialCategory: category);
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
  const _AddCategoryBottomSheet({
    this.initialCategory,
    this.initialType = CategoryType.expense,
  });

  final Category? initialCategory;
  final CategoryType initialType;

  @override
  ConsumerState<_AddCategoryBottomSheet> createState() =>
      _AddCategoryBottomSheetState();
}

class _AddCategoryBottomSheetState
    extends ConsumerState<_AddCategoryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  CategoryType _selectedType = CategoryType.expense;
  String _selectedColorHex = '#3B82F6'; // Default: Aiko Blue
  String _selectedIconKey = 'category'; // Default generic
  bool _isSubmitting = false;
  bool _isDeleting = false;

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
    {'key': 'transport', 'icon': Icons.directions_bus_outlined},
    {'key': 'fuel', 'icon': Icons.local_gas_station_outlined},
    {'key': 'travel', 'icon': Icons.flight_outlined},
    {'key': 'coffee', 'icon': Icons.coffee_outlined},
    {'key': 'shopping', 'icon': Icons.shopping_bag_outlined},
    {'key': 'utilities', 'icon': Icons.bolt_outlined},
    {'key': 'phone', 'icon': Icons.phone_android_outlined},
    {'key': 'internet', 'icon': Icons.wifi_outlined},
    {'key': 'subscriptions', 'icon': Icons.subscriptions_outlined},
    {'key': 'health', 'icon': Icons.health_and_safety_outlined},
    {'key': 'insurance', 'icon': Icons.verified_user_outlined},
    {'key': 'education', 'icon': Icons.school_outlined},
    {'key': 'savings', 'icon': Icons.savings_outlined},
    {'key': 'investing', 'icon': Icons.trending_up_outlined},
    {'key': 'gym', 'icon': Icons.fitness_center_outlined},
    {'key': 'salary', 'icon': Icons.attach_money_outlined},
    {'key': 'fee', 'icon': Icons.receipt_long_outlined},
    {'key': 'tax', 'icon': Icons.request_quote_outlined},
    {'key': 'entertainment', 'icon': Icons.movie_outlined},
    {'key': 'gift', 'icon': Icons.card_giftcard_outlined},
    {'key': 'business', 'icon': Icons.work_outline},
  ];

  bool get _isEditing => widget.initialCategory != null;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    final initialCategory = widget.initialCategory;
    if (initialCategory == null) {
      return;
    }

    _nameController.text = initialCategory.name;
    _selectedType = initialCategory.type;
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
              group: CategoryGroup.custom,
              color: _selectedColorHex,
              icon: _selectedIconKey,
              budgetEnabled: true,
            )
          : initialCategory.copyWith(
              name: _nameController.text.trim(),
              type: _selectedType,
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

  Future<void> _confirmDelete() async {
    final category = widget.initialCategory;
    if (category == null || category.isDefault) {
      return;
    }

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

    if (confirmed != true) {
      return;
    }

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
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete category: $e'),
            backgroundColor: AikoColors.dangerRed,
          ),
        );
      }
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
              // Category Type
              SegmentedButton<CategoryType>(
                key: const Key('category-type-selector'),
                showSelectedIcon: false,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return _categoryTypeColor(_selectedType);
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
                      final rowCount = (_iconsPreset.length / crossAxisCount)
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
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: spacing,
                                  crossAxisSpacing: spacing,
                                ),
                            itemCount: _iconsPreset.length,
                            itemBuilder: (context, idx) {
                              final item = _iconsPreset[idx];
                              final key = item['key'] as String;
                              final iconData = item['icon'] as IconData;
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
              // Save Button
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
}
