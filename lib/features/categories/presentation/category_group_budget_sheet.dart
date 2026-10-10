import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/category.dart';
import 'category_names.dart';

/// Compact bottom sheet for setting a [CategoryGroup]'s own monthly budget —
/// an envelope across the whole group, separate from its categories' limits.
/// Reached from the budget pill on each group header (works for the read-only
/// default groups too: saved as a per-user budget overlay row).
Future<bool?> showCategoryGroupBudgetSheet(
  BuildContext context, {
  required CategoryGroup group,
}) {
  return showAikoSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _GroupBudgetSheet(group: group),
  );
}

class _GroupBudgetSheet extends ConsumerStatefulWidget {
  const _GroupBudgetSheet({required this.group});

  final CategoryGroup group;

  @override
  ConsumerState<_GroupBudgetSheet> createState() => _GroupBudgetSheetState();
}

class _GroupBudgetSheetState extends ConsumerState<_GroupBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final limit = widget.group.budgetLimit;
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
      final updated = widget.group.copyWith(
        budgetLimit: amount.isEmpty ? null : Money.parse(amount, _baseCurrency),
      );
      await ref.read(categoryGroupsProvider.notifier).saveGroup(updated);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              amount.isEmpty
                  ? context.l10n.budgetRemovedFrom(
                      widget.group.displayName(context.l10n),
                    )
                  : context.l10n.budgetSetFor(
                      widget.group.displayName(context.l10n),
                    ),
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
            content: Text(context.l10n.budgetSaveFailed),
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
              const AikoSheetHandle(),
              Text(
                context.l10n.groupBudgetSheetTitle(
                  widget.group.displayName(context.l10n),
                ),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.groupBudgetExplanation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: context.l10n.groupBudgetMonthlyLimit(
                    _baseCurrency,
                  ),
                  hintText: context.l10n.groupBudgetLeaveEmpty,
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null; // empty == remove budget
                  final parsed = double.tryParse(text);
                  if (parsed == null || parsed < 0) {
                    return context.l10n.enterValidAmount;
                  }
                  return null;
                },
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
                  _saving
                      ? context.l10n.savingEllipsis
                      : context.l10n.budgetSave,
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
