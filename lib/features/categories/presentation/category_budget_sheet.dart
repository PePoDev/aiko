import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/category.dart';
import 'widgets/category_budget_section.dart';

/// Compact bottom sheet for setting just a [Category]'s budget (amount /
/// period / rollover). Reached from the budget pill on each category row, so
/// adding a limit doesn't require the full category editor — and it works for
/// the read-only default categories too (saved as a per-user budget overlay).
Future<bool?> showCategoryBudgetSheet(
  BuildContext context, {
  required Category category,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CategoryBudgetSheet(category: category),
  );
}

class _CategoryBudgetSheet extends ConsumerStatefulWidget {
  const _CategoryBudgetSheet({required this.category});

  final Category category;

  @override
  ConsumerState<_CategoryBudgetSheet> createState() =>
      _CategoryBudgetSheetState();
}

class _CategoryBudgetSheetState extends ConsumerState<_CategoryBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  late CategoryBudgetPeriod _period = widget.category.budgetPeriod;
  late bool _rollover = widget.category.rolloverUnused;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final limit = widget.category.monthlyLimit;
    if (limit != null) _amountController.text = limit.amount.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String get _baseCurrency =>
      ref.read(profileProvider).value?.baseCurrency ?? 'USD';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = _amountController.text.trim();
      final updated = widget.category.copyWith(
        monthlyLimit: amount.isEmpty
            ? null
            : Money.parse(amount, _baseCurrency),
        budgetPeriod: _period,
        rolloverUnused: _rollover,
        budgetEnabled: true,
      );
      await ref.read(categoriesProvider.notifier).saveCategory(updated);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              amount.isEmpty
                  ? 'Budget removed from "${widget.category.name}".'
                  : 'Budget set for "${widget.category.name}".',
            ),
            backgroundColor: AikoColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save budget: $e'),
            backgroundColor: AikoColors.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
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
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Budget · ${widget.category.name}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              CategoryBudgetSection(
                amountController: _amountController,
                period: _period,
                rolloverUnused: _rollover,
                currency: _baseCurrency,
                onPeriodChanged: (p) => setState(() => _period = p),
                onRolloverChanged: (v) => setState(() => _rollover = v),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AikoColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _saving
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
                  _saving ? 'Saving...' : 'Save Budget',
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
