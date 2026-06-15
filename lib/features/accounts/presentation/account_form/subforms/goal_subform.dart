import 'package:flutter/material.dart';

import '../../../../../core/money/money.dart';
import '../../../domain/account.dart';

/// Subform shown when an [Account] has `type = AccountType.goal`. The
/// subform owns the goal-only fields: target amount, target date, and
/// priority. The shared account form (`account_form_screen.dart`) embeds
/// this widget when the user selects `type = goal`.
class GoalSubform extends StatefulWidget {
  const GoalSubform({
    super.key,
    required this.initial,
    required this.currency,
    required this.onChanged,
  });

  final Account initial;
  final String currency;
  final ValueChanged<Account> onChanged;

  @override
  State<GoalSubform> createState() => GoalSubformState();
}

class GoalSubformState extends State<GoalSubform> {
  late final TextEditingController _targetController;
  late final TextEditingController _currentController;
  late DateTime? _targetDate;
  late GoalPriority _priority;

  @override
  void initState() {
    super.initState();
    _targetController = TextEditingController(
      text: widget.initial.targetAmount?.amount.toString() ?? '',
    );
    _currentController = TextEditingController(
      text: widget.initial.currentBalance.amount.toString(),
    );
    _targetDate = widget.initial.targetDate;
    _priority = widget.initial.priority;
  }

  @override
  void dispose() {
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Account _build() {
    final target = _targetController.text.trim();
    final current = _currentController.text.trim();
    return widget.initial.copyWith(
      currentBalance: current.isEmpty
          ? widget.initial.currentBalance
          : Money.parse(current, widget.currency),
      targetAmount: target.isEmpty
          ? null
          : Money.parse(target, widget.currency),
      targetDate: _targetDate,
      priority: _priority,
    );
  }

  /// Public read-only accessors for the parent account form. The form's
  /// submit path uses these to read the latest typed values without
  /// reaching into private fields.
  TextEditingController get targetController => _targetController;
  TextEditingController get currentController => _currentController;
  DateTime? get targetDate => _targetDate;
  GoalPriority get priority => _priority;

  void _emit() => widget.onChanged(_build());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 30)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
      _emit();
    }
  }

  String? _validate() {
    final target = _targetController.text.trim();
    final current = _currentController.text.trim();
    if (target.isNotEmpty) {
      final parsed = num.tryParse(target);
      if (parsed == null || parsed <= 0) {
        return 'Target amount must be greater than zero';
      }
    }
    if (current.isNotEmpty) {
      final parsed = num.tryParse(current);
      if (parsed == null || parsed < 0) {
        return 'Current saved amount must be zero or more';
      }
    }
    if (target.isNotEmpty && _targetDate == null) {
      return 'Pick a target date when a target amount is set';
    }
    return null;
  }

  /// Public hook for the form to call submit-time validation. Returns an
  /// error string or null.
  String? validate() => _validate();

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
                  Icons.flag_outlined,
                  color: AikoColorsForGoals.purple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Goal details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Required for a SMART savings goal. The saved amount is the '
              "account's current balance.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _targetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Target amount',
                      prefixText: '${widget.currency} ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _currentController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Saved so far',
                      prefixText: '${widget.currency} ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              readOnly: true,
              controller: TextEditingController(
                text: _targetDate == null
                    ? ''
                    : '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}',
              ),
              onTap: _pickDate,
              decoration: InputDecoration(
                labelText: 'Target date',
                hintText: 'Pick the date you want to reach this goal',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<GoalPriority>(
              segments: const [
                ButtonSegment(value: GoalPriority.low, label: Text('Low')),
                ButtonSegment(
                  value: GoalPriority.medium,
                  label: Text('Medium'),
                ),
                ButtonSegment(value: GoalPriority.high, label: Text('High')),
              ],
              selected: {_priority},
              onSelectionChanged: (set) {
                setState(() => _priority = set.first);
                _emit();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience class so the goal subform can reference the brand color
/// without taking a hard import path on the global [AikoColors] in
/// production code paths.
class AikoColorsForGoals {
  static const purple = Color(0xFF7C3AED);
}
