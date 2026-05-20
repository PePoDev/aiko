import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/budget.dart';

class BudgetFormScreen extends ConsumerStatefulWidget {
  const BudgetFormScreen({super.key});

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitBudget() async {
    final category = _categoryController.text.trim();
    final amountText = _amountController.text.trim();

    if (category.isEmpty) {
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

    setState(() => _isSubmitting = true);
    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month);
    final periodEnd = DateTime(now.year, now.month + 1, 0);
    final categoryId = category
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    final budget = Budget(
      id: const Uuid().v4(),
      userId: AikoSupabase.tryClient()?.auth.currentUser?.id ?? 'demo-user',
      name: category,
      categoryId: categoryId.isEmpty ? 'custom' : categoryId,
      amount: Money(amount: amount, currency: 'USD'),
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    await ref.read(budgetsProvider.notifier).addBudget(budget);
    if (!mounted) {
      return;
    }

    final state = ref.read(budgetsProvider);
    if (state.hasError) {
      setState(() => _isSubmitting = false);
      _showMessage('Unable to save this budget right now.');
      return;
    }

    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New budget')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FinanceCard(
            title: 'Budget details',
            icon: Icons.pie_chart_outline,
            accentColor: AikoColors.warningOrange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                  textInputAction: TextInputAction.next,
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Monthly amount',
                    prefixText: r'$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  enabled: !_isSubmitting,
                  onSubmitted: (_) => _isSubmitting ? null : _submitBudget(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitBudget,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isSubmitting ? 'Saving...' : 'Save budget'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
