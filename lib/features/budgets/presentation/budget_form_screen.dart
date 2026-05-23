import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/budget.dart';
import '../../categories/domain/category.dart';

class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({this.initialBudget, super.key});

  final Budget? initialBudget;

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  // Custom Budget Mode controllers
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();

  // Preset Mode controllers
  final _incomeController = TextEditingController(text: '3000');

  // Dynamic allocators for Zero-Based & Envelope
  final Map<String, TextEditingController> _allocatorControllers = {};
  final Set<String> _includedCategoryIds = {};

  String _mode = 'custom'; // 'custom', 'preset'
  String _presetType = '50_30_20'; // '50_30_20', 'zero_based', 'envelope'
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final budget = widget.initialBudget;
    if (budget != null) {
      _categoryController.text = budget.name;
      _amountController.text = budget.amount.amount.toString();
      _includedCategoryIds.addAll(budget.includedCategoryIds);
      if (budget.isDailySpending &&
          _includedCategoryIds.isEmpty &&
          budget.categoryId != Budget.dailySpendingCategoryId) {
        _includedCategoryIds.add(budget.categoryId);
      }
    }
    _incomeController.addListener(_onIncomeChanged);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _incomeController.dispose();
    for (final controller in _allocatorControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onIncomeChanged() {
    if (_presetType == 'zero_based' || _presetType == 'envelope') {
      _reallocatePresets();
    }
  }

  Future<List<Category>> _ensurePresetCategories() async {
    final categories = await ref.read(categoriesProvider.future);
    final List<Category> active = categories.where((c) => c.isActive).toList();

    // Map by groups
    final hasNeeds = active.any((c) => c.group == CategoryGroup.needs);
    final hasWants = active.any((c) => c.group == CategoryGroup.wants);
    final hasSavings = active.any((c) => c.group == CategoryGroup.savings);

    final List<Category> updatedList = List.from(active);

    if (!hasNeeds) {
      final newCat = Category(
        id: const Uuid().v4(),
        userId: '',
        name: 'Needs (General)',
        type: CategoryType.expense,
        group: CategoryGroup.needs,
        icon: 'house',
        color: '#3B82F6',
      );
      await ref.read(categoriesProvider.notifier).addCategory(newCat);
      updatedList.add(newCat);
    }
    if (!hasWants) {
      final newCat = Category(
        id: const Uuid().v4(),
        userId: '',
        name: 'Wants (General)',
        type: CategoryType.expense,
        group: CategoryGroup.wants,
        icon: 'movie',
        color: '#EC4899',
      );
      await ref.read(categoriesProvider.notifier).addCategory(newCat);
      updatedList.add(newCat);
    }
    if (!hasSavings) {
      final newCat = Category(
        id: const Uuid().v4(),
        userId: '',
        name: 'Savings Plan',
        type: CategoryType.expense,
        group: CategoryGroup.savings,
        icon: 'savings',
        color: '#10B981',
      );
      await ref.read(categoriesProvider.notifier).addCategory(newCat);
      updatedList.add(newCat);
    }

    return updatedList;
  }

  void _reallocatePresets() async {
    final categories = await _ensurePresetCategories();
    final double income = double.tryParse(_incomeController.text) ?? 0.0;

    if (_presetType == 'zero_based') {
      // Divide equally among first 4 categories as default
      final targetCats = categories.take(4).toList();
      final split = income / (targetCats.isNotEmpty ? targetCats.length : 1);

      for (final cat in targetCats) {
        if (!_allocatorControllers.containsKey(cat.id)) {
          _allocatorControllers[cat.id] = TextEditingController();
        }
        _allocatorControllers[cat.id]!.text = split.toStringAsFixed(0);
      }
      setState(() {});
    } else if (_presetType == 'envelope') {
      // Envelope preset standard envelopes: Groceries, Housing, Dining, Entertainment
      final groceryCat = categories.firstWhere(
        (c) =>
            c.name.toLowerCase().contains('grocer') ||
            c.group == CategoryGroup.needs,
        orElse: () => categories.first,
      );
      final housingCat = categories.firstWhere(
        (c) =>
            c.name.toLowerCase().contains('rent') ||
            c.name.toLowerCase().contains('hous') ||
            c.group == CategoryGroup.needs,
        orElse: () => categories.first,
      );
      final savingsCat = categories.firstWhere(
        (c) =>
            c.name.toLowerCase().contains('sav') ||
            c.group == CategoryGroup.savings,
        orElse: () => categories.first,
      );

      final targets = [groceryCat, housingCat, savingsCat];
      final allocations = [income * 0.20, income * 0.50, income * 0.30];

      for (int i = 0; i < targets.length; i++) {
        final cat = targets[i];
        if (!_allocatorControllers.containsKey(cat.id)) {
          _allocatorControllers[cat.id] = TextEditingController();
        }
        _allocatorControllers[cat.id]!.text = allocations[i].toStringAsFixed(0);
      }
      setState(() {});
    }
  }

  Future<void> _submitCustomBudget() async {
    final existingBudget = widget.initialBudget;
    final isDailySpending = existingBudget?.isDailySpending ?? false;
    final category = _categoryController.text.trim();
    final amountText = _amountController.text.trim();

    if (!isDailySpending && category.isEmpty) {
      _showMessage('Enter a category name.');
      return;
    }

    final Decimal amount;
    try {
      amount = Decimal.parse(amountText);
    } on FormatException {
      _showMessage('Enter a valid monthly amount.');
      return;
    }

    if (amount <= Decimal.zero) {
      _showMessage('Monthly amount must be positive.');
      return;
    }

    final categories = await ref.read(categoriesProvider.future);
    if (isDailySpending && _includedCategoryIds.isEmpty) {
      _showMessage('Select at least one category for Daily Spending.');
      return;
    }

    final matchingCategories = categories
        .where(
          (item) =>
              item.isActive &&
              item.name.toLowerCase() == category.toLowerCase(),
        )
        .toList();
    if (!isDailySpending && matchingCategories.isEmpty) {
      _showMessage('Create this category before assigning a budget to it.');
      return;
    }

    setState(() => _isSubmitting = true);
    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month);
    final periodEnd = DateTime(now.year, now.month + 1, 0);

    final budget = Budget(
      id: existingBudget?.id ?? const Uuid().v4(),
      userId: existingBudget?.userId ?? '',
      name: isDailySpending ? 'Daily Spending' : category,
      categoryId: isDailySpending
          ? _includedCategoryIds.first
          : matchingCategories.first.id,
      amount: Money(amount: amount, currency: 'THB'),
      periodStart: isDailySpending
          ? DateTime(now.year, now.month, now.day)
          : existingBudget?.periodStart ?? periodStart,
      periodEnd: isDailySpending
          ? DateTime(now.year, now.month, now.day, 23, 59, 59)
          : existingBudget?.periodEnd ?? periodEnd,
      period: isDailySpending
          ? BudgetPeriod.daily
          : existingBudget?.period ?? BudgetPeriod.monthly,
      alertThresholds:
          existingBudget?.alertThresholds ?? const [50, 75, 90, 100],
      status: existingBudget?.status ?? BudgetStatus.active,
      includedCategoryIds: isDailySpending
          ? _includedCategoryIds.toList(growable: false)
          : const [],
      isAppDefined: existingBudget?.isAppDefined ?? false,
    );

    await ref.read(budgetsProvider.notifier).saveBudget(budget);
    if (!mounted) return;

    final state = ref.read(budgetsProvider);
    if (state.hasError) {
      setState(() => _isSubmitting = false);
      _showMessage('Unable to save this budget right now.');
      return;
    }

    Navigator.of(context).pop(budget);
  }

  Future<void> _submitPresetBudgets() async {
    final incomeText = _incomeController.text.trim();
    final double income = double.tryParse(incomeText) ?? 0.0;
    if (income <= 0) {
      _showMessage('Please enter a valid monthly income.');
      return;
    }

    setState(() => _isSubmitting = true);
    final categories = await _ensurePresetCategories();
    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month);
    final periodEnd = DateTime(now.year, now.month + 1, 0);

    try {
      final presetBudgets = <Budget>[];
      if (_presetType == '50_30_20') {
        // Needs category budget (50%)
        final needsCat = categories.firstWhere(
          (c) => c.group == CategoryGroup.needs,
        );
        final needsBudget = Budget(
          id: const Uuid().v4(),
          userId: '',
          name: needsCat.name,
          categoryId: needsCat.id,
          amount: Money(
            amount: Decimal.parse((income * 0.50).toStringAsFixed(2)),
            currency: 'THB',
          ),
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
        presetBudgets.add(needsBudget);

        // Wants category budget (30%)
        final wantsCat = categories.firstWhere(
          (c) => c.group == CategoryGroup.wants,
        );
        final wantsBudget = Budget(
          id: const Uuid().v4(),
          userId: '',
          name: wantsCat.name,
          categoryId: wantsCat.id,
          amount: Money(
            amount: Decimal.parse((income * 0.30).toStringAsFixed(2)),
            currency: 'THB',
          ),
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
        presetBudgets.add(wantsBudget);

        // Savings category budget (20%)
        final savingsCat = categories.firstWhere(
          (c) => c.group == CategoryGroup.savings,
        );
        final savingsBudget = Budget(
          id: const Uuid().v4(),
          userId: '',
          name: savingsCat.name,
          categoryId: savingsCat.id,
          amount: Money(
            amount: Decimal.parse((income * 0.20).toStringAsFixed(2)),
            currency: 'THB',
          ),
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
        presetBudgets.add(savingsBudget);
      } else {
        // Zero-Based or Envelope
        double totalAllocated = 0;

        for (final entry in _allocatorControllers.entries) {
          final amt = double.tryParse(entry.value.text) ?? 0.0;
          if (amt > 0) {
            totalAllocated += amt;
            final cat = categories.firstWhere((c) => c.id == entry.key);
            presetBudgets.add(
              Budget(
                id: const Uuid().v4(),
                userId: '',
                name: cat.name,
                categoryId: cat.id,
                amount: Money(
                  amount: Decimal.parse(amt.toStringAsFixed(2)),
                  currency: 'THB',
                ),
                periodStart: periodStart,
                periodEnd: periodEnd,
              ),
            );
          }
        }

        if (_presetType == 'zero_based' &&
            (totalAllocated - income).abs() > 0.01) {
          setState(() => _isSubmitting = false);
          _showMessage(
            'In Zero-Based budgeting, total allocated must equal monthly income.',
          );
          return;
        }
      }

      final existingBudgets = await ref.read(budgetsProvider.future);
      final duplicates = presetBudgets.where((budget) {
        return existingBudgets.any(
          (existing) =>
              existing.status != BudgetStatus.archived &&
              existing.categoryId == budget.categoryId &&
              _isSameBudgetPeriod(existing, budget),
        );
      }).toList();
      final budgetsToCreate = [
        for (final budget in presetBudgets)
          if (!duplicates.any(
            (duplicate) => duplicate.categoryId == budget.categoryId,
          ))
            budget,
      ];

      if (budgetsToCreate.isEmpty) {
        setState(() => _isSubmitting = false);
        _showMessage('These preset budgets already exist for this month.');
        return;
      }

      for (final budget in budgetsToCreate) {
        await ref.read(budgetsProvider.notifier).addBudget(budget);
      }

      final skipped = duplicates.length;
      _showMessage(
        skipped == 0
            ? 'Preset budgets initialized successfully!'
            : 'Created ${budgetsToCreate.length} preset budgets. Skipped $skipped already created.',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showMessage('Failed to save preset budgets.');
    }
  }

  bool _isSameBudgetPeriod(Budget existing, Budget incoming) {
    return existing.period == incoming.period &&
        existing.periodStart.year == incoming.periodStart.year &&
        existing.periodStart.month == incoming.periodStart.month &&
        existing.periodStart.day == incoming.periodStart.day &&
        existing.periodEnd.year == incoming.periodEnd.year &&
        existing.periodEnd.month == incoming.periodEnd.month &&
        existing.periodEnd.day == incoming.periodEnd.day;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final initialBudget = widget.initialBudget;
    final isDailySpending = initialBudget?.isDailySpending ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isDailySpending
              ? 'Daily Spending'
              : widget.initialBudget != null
              ? 'Edit budget'
              : _mode == 'custom'
              ? 'New budget'
              : 'Preset budgets',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.initialBudget == null) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'custom',
                  label: Text('Custom Entry'),
                  icon: Icon(Icons.edit_note),
                ),
                ButtonSegment(
                  value: 'preset',
                  label: Text('Aiko Presets'),
                  icon: Icon(Icons.auto_awesome),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() {
                  _mode = selection.first;
                  if (_mode == 'preset') {
                    _reallocatePresets();
                  }
                });
              },
            ),
            const SizedBox(height: 16),
          ],

          if (_mode == 'custom') ...[
            FinanceCard(
              title: isDailySpending
                  ? 'Daily spending limit'
                  : 'Budget details',
              icon: isDailySpending
                  ? Icons.today_outlined
                  : Icons.pie_chart_outline,
              accentColor: AikoColors.warningOrange,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isDailySpending) ...[
                    TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                      textInputAction: TextInputAction.next,
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: isDailySpending
                          ? 'Daily limit'
                          : 'Monthly amount',
                      prefixText: r'$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    enabled: !_isSubmitting,
                    onSubmitted: (_) =>
                        _isSubmitting ? null : _submitCustomBudget(),
                  ),
                  const SizedBox(height: 16),
                  if (isDailySpending) ...[
                    _DailySpendingCategorySelector(
                      selectedCategoryIds: _includedCategoryIds,
                      onChanged: (categoryId, selected) {
                        setState(() {
                          if (selected) {
                            _includedCategoryIds.add(categoryId);
                          } else {
                            _includedCategoryIds.remove(categoryId);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitCustomBudget,
                    icon: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _isSubmitting
                          ? 'Saving...'
                          : widget.initialBudget == null
                          ? 'Save budget'
                          : 'Save changes',
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Preset Selection Hub
            FinanceCard(
              title: 'Select Allocation Template',
              icon: Icons.splitscreen_outlined,
              accentColor: AikoColors.premiumPurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _presetType,
                    decoration: const InputDecoration(
                      labelText: 'Template Presets',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '50_30_20',
                        child: Text('50/30/20 Rule'),
                      ),
                      DropdownMenuItem(
                        value: 'zero_based',
                        child: Text('Zero-Based (Assign Every Dollar)'),
                      ),
                      DropdownMenuItem(
                        value: 'envelope',
                        child: Text('Envelope Allocation'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _presetType = val;
                          _reallocatePresets();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _incomeController,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Income / Budget',
                      prefixText: r'$ ',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isSubmitting,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dynamic presentation based on Preset Type chosen
            if (_presetType == '50_30_20') ...[
              FinanceCard(
                title: '50/30/20 Allocation Summary',
                icon: Icons.pie_chart,
                accentColor: AikoColors.successGreen,
                child: Builder(
                  builder: (context) {
                    final inc = double.tryParse(_incomeController.text) ?? 0.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPresetAllocationLine(
                          'Needs (50%)',
                          inc * 0.5,
                          AikoColors.deepBlue,
                          textTheme,
                        ),
                        const SizedBox(height: 12),
                        _buildPresetAllocationLine(
                          'Wants (30%)',
                          inc * 0.3,
                          AikoColors.warningOrange,
                          textTheme,
                        ),
                        const SizedBox(height: 12),
                        _buildPresetAllocationLine(
                          'Savings (20%)',
                          inc * 0.2,
                          AikoColors.successGreen,
                          textTheme,
                        ),
                        const Divider(height: 32),
                        const Text(
                          'Aiko Advice: Splits your income into Needs (Housing/Food), Wants (Fun/Dining), and Savings/Debt payoff automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ] else if (_presetType == 'zero_based') ...[
              FinanceCard(
                title: 'Zero-Based Allocation',
                icon: Icons.balance_outlined,
                accentColor: AikoColors.analyticsTeal,
                child: FutureBuilder<List<Category>>(
                  future: ref.read(categoriesProvider.future),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final cats = snapshot.data!
                        .where((c) => c.isActive)
                        .take(4)
                        .toList();
                    final double inc =
                        double.tryParse(_incomeController.text) ?? 0.0;
                    final double allocated = _allocatorControllers.entries
                        .where((e) => cats.any((c) => c.id == e.key))
                        .fold(
                          0.0,
                          (sum, e) =>
                              sum + (double.tryParse(e.value.text) ?? 0.0),
                        );
                    final double remaining = inc - allocated;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Remaining to allocate:',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${remaining.toStringAsFixed(0)}',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: remaining == 0
                                    ? AikoColors.successGreen
                                    : AikoColors.dangerRed,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (final cat in cats) ...[
                          Row(
                            children: [
                              Expanded(child: Text(cat.name)),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _allocatorControllers[cat.id],
                                  decoration: const InputDecoration(
                                    prefixText: r'$ ',
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ] else if (_presetType == 'envelope') ...[
              FinanceCard(
                title: 'Cash Envelope Limits',
                icon: Icons.mail_outline,
                accentColor: AikoColors.warningOrange,
                child: FutureBuilder<List<Category>>(
                  future: ref.read(categoriesProvider.future),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final cats = snapshot.data!
                        .where((c) => c.isActive)
                        .take(3)
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Input cash limits for your core discretionary envelopes. Aiko will track these envelopes in real-time.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        for (final cat in cats) ...[
                          Row(
                            children: [
                              Expanded(child: Text('${cat.name} Envelope')),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _allocatorControllers[cat.id],
                                  decoration: const InputDecoration(
                                    prefixText: r'$ ',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitPresetBudgets,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.done_all),
              label: Text(
                _isSubmitting ? 'Saving Presets...' : 'Save Preset Budgets',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetAllocationLine(
    String title,
    double amount,
    Color color,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        Container(width: 8, height: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
        Text(
          '\$${amount.toStringAsFixed(0)}',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _DailySpendingCategorySelector extends ConsumerWidget {
  const _DailySpendingCategorySelector({
    required this.selectedCategoryIds,
    required this.onChanged,
  });

  final Set<String> selectedCategoryIds;
  final void Function(String categoryId, bool selected) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text('Unable to load categories.'),
      data: (categories) {
        final activeExpenseCategories = categories
            .where((category) => category.isActive)
            .where((category) => category.type == CategoryType.expense)
            .toList(growable: false);
        if (activeExpenseCategories.isEmpty) {
          return const Text(
            'Create an expense category before editing this budget.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Included categories',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final category in activeExpenseCategories)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selectedCategoryIds.contains(category.id),
                title: Text(category.name),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (selected) =>
                    onChanged(category.id, selected ?? false),
              ),
          ],
        );
      },
    );
  }
}
