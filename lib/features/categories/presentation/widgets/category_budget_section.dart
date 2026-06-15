import 'package:flutter/material.dart';

import '../../../../theme/aiko_colors.dart';
import '../../domain/category.dart';

/// Budget sub-section embedded in the category editor sheet. Owns the
/// amount / period / rollover controls. Pulled out of
/// `category_editor_sheet.dart` so the form screen stays focused on the
/// main name / type / icon / color / group flow.
class CategoryBudgetSection extends StatelessWidget {
  const CategoryBudgetSection({
    super.key,
    required this.amountController,
    required this.period,
    required this.rolloverUnused,
    required this.currency,
    required this.onPeriodChanged,
    required this.onRolloverChanged,
  });

  final TextEditingController amountController;
  final CategoryBudgetPeriod period;
  final bool rolloverUnused;
  final String currency;
  final ValueChanged<CategoryBudgetPeriod> onPeriodChanged;
  final ValueChanged<bool> onRolloverChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart_outline,
                  color: AikoColors.warningOrange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Budget',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Optional. Leave the amount empty for no budget.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('category-budget-amount'),
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Limit',
                prefixText: '$currency ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return null;
                final parsed = num.tryParse(trimmed);
                if (parsed == null || parsed <= 0) {
                  return 'Enter a positive amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CategoryBudgetPeriod>(
              key: const Key('category-budget-period'),
              initialValue: period,
              decoration: InputDecoration(
                labelText: 'Period',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: CategoryBudgetPeriod.daily,
                  child: Text('Daily'),
                ),
                DropdownMenuItem(
                  value: CategoryBudgetPeriod.weekly,
                  child: Text('Weekly'),
                ),
                DropdownMenuItem(
                  value: CategoryBudgetPeriod.monthly,
                  child: Text('Monthly'),
                ),
                DropdownMenuItem(
                  value: CategoryBudgetPeriod.yearly,
                  child: Text('Yearly'),
                ),
              ],
              onChanged: (v) {
                if (v != null) onPeriodChanged(v);
              },
            ),
            const SizedBox(height: 8),
            // Own Material so the switch's ink/selection paints on a surface
            // above the colored DecoratedBox (avoids the ListTile assertion).
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                key: const Key('category-budget-rollover'),
                contentPadding: EdgeInsets.zero,
                value: rolloverUnused,
                onChanged: onRolloverChanged,
                title: const Text('Roll over unused budget'),
                subtitle: Text(
                  'Carries leftover into the next period only.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
