import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/goal.dart';

class GoalsOverviewScreen extends ConsumerWidget {
  const GoalsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAikoTip(context),
          ),
        ],
      ),
      body: goalsAsync.when(
        loading: () => const AikoScreenState.loading(),
        error: (error, stack) => AikoScreenState.error(
          title: 'Goals are unavailable',
          message: 'Aiko could not load your goals right now.',
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return AikoScreenState.empty(
              title: 'No goals yet',
              message: 'Create a SMART goal to track your progress and let Aiko guide you.',
              action: PrimaryActionButton(
                label: 'Add SMART Goal',
                icon: Icons.add_task,
                onPressed: () => _showAddGoalSheet(context),
              ),
            );
          }

          final accounts = accountsAsync.value ?? [];

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              final linkedAccount = accounts.isEmpty
                  ? null
                  : accounts.where((a) => a.id == goal.linkedAccountId).firstOrNull;

              final progressPercent = (goal.progress * 100).clamp(0, 100);
              final isCompleted = goal.progress >= 1.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: FinanceCard(
                  title: goal.name,
                  icon: Icons.flag,
                  accentColor: isCompleted
                      ? AikoColors.successGreen
                      : AikoColors.primaryBlue,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AikoColors.dangerRed),
                    onPressed: () => _confirmDeleteGoal(context, ref, goal),
                    tooltip: 'Delete Goal',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${progressPercent.toStringAsFixed(0)}% funded',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted
                                      ? AikoColors.successGreen
                                      : AikoColors.primaryBlue,
                                ),
                          ),
                          _PriorityBadge(priority: goal.priority),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: goal.progress.clamp(0.0, 1.0),
                          backgroundColor: AikoColors.borderSubtle,
                          color: isCompleted
                              ? AikoColors.successGreen
                              : AikoColors.primaryBlue,
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Saved: ${goal.currentAmount.format()}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Target: ${goal.targetAmount.format()}',
                            style: const TextStyle(color: AikoColors.mutedText),
                          ),
                        ],
                      ),
                      if (!isCompleted) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Remaining: ${goal.remaining.format()}',
                          style: const TextStyle(
                            color: AikoColors.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AikoColors.borderSubtle),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: AikoColors.mutedText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Target Date: ${DateFormat.yMMMd().format(goal.targetDate)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AikoColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                          if (linkedAccount != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 14,
                                  color: AikoColors.mutedText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  linkedAccount.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AikoColors.mutedText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
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
        onPressed: () => _showAddGoalSheet(context),
        label: const Text('Add SMART Goal'),
        icon: const Icon(Icons.add_task),
        backgroundColor: AikoColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddGoalBottomSheet(),
    );
  }

  Future<void> _confirmDeleteGoal(BuildContext context, WidgetRef ref, Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: Text('Are you sure you want to delete "${goal.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AikoColors.dangerRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(goalsProvider.notifier).deleteGoal(goal.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Goal "${goal.name}" deleted successfully.'),
              backgroundColor: AikoColors.successGreen,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting goal: $e'),
              backgroundColor: AikoColors.dangerRed,
            ),
          );
        }
      }
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
            const Text('Aiko\'s Advice'),
          ],
        ),
        content: const Text(
          'SMART goals are Specific, Measurable, Achievable, Relevant, and Time-bound. '
          'Linking an account allows me to track your savings automatically!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (priority) {
      case 3:
        label = 'High';
        color = AikoColors.dangerRed;
        break;
      case 2:
        label = 'Medium';
        color = AikoColors.warningOrange;
        break;
      default:
        label = 'Low';
        color = AikoColors.mutedText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _AddGoalBottomSheet extends ConsumerStatefulWidget {
  const _AddGoalBottomSheet();

  @override
  ConsumerState<_AddGoalBottomSheet> createState() => _AddGoalBottomSheetState();
}

class _AddGoalBottomSheetState extends ConsumerState<_AddGoalBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController();
  final _dateController = TextEditingController();

  GoalPurpose _selectedPurpose = GoalPurpose.custom;
  String? _selectedAccountId;
  DateTime? _selectedDate;
  int _priority = 2; // Medium by default
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AikoColors.primaryBlue,
              onPrimary: Colors.white,
              onSurface: AikoColors.neutralInk,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat.yMMMd().format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a target date.'),
          backgroundColor: AikoColors.dangerRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final profileAsync = ref.read(profileProvider);
      final baseCurrency = profileAsync.value?.baseCurrency ?? 'USD';

      final targetStr = _targetAmountController.text.trim();
      final currentStr = _currentAmountController.text.trim();

      final goal = Goal(
        id: const Uuid().v4(),
        userId: '', // Populated by repository
        name: _nameController.text.trim(),
        purpose: _selectedPurpose,
        targetAmount: Money.parse(targetStr, baseCurrency),
        currentAmount: Money.parse(currentStr.isEmpty ? '0' : currentStr, baseCurrency),
        targetDate: _selectedDate!,
        linkedAccountId: _selectedAccountId,
        priority: _priority,
      );

      await ref.read(goalsProvider.notifier).addGoal(goal);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SMART Goal "${goal.name}" created successfully!'),
            backgroundColor: AikoColors.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create goal: $e'),
            backgroundColor: AikoColors.dangerRed,
          ),
        );
      }
    }
  }

  String _getPurposeLabel(GoalPurpose purpose) {
    switch (purpose) {
      case GoalPurpose.emergencyFund:
        return 'Emergency Fund';
      case GoalPurpose.debtPayoff:
        return 'Debt Payoff';
      case GoalPurpose.investment:
        return 'Investment';
      case GoalPurpose.vacation:
        return 'Vacation';
      case GoalPurpose.education:
        return 'Education';
      case GoalPurpose.home:
        return 'Home Purchase';
      case GoalPurpose.car:
        return 'Car Purchase';
      case GoalPurpose.wedding:
        return 'Wedding';
      case GoalPurpose.retirement:
        return 'Retirement';
      case GoalPurpose.custom:
        return 'Custom / Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final profileAsync = ref.watch(profileProvider);
    final baseCurrency = profileAsync.value?.baseCurrency ?? 'USD';

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
              // Bottom Sheet Handle Bar
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
                      Icons.flag_rounded,
                      color: AikoColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add SMART Goal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Goal Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Goal Name',
                  hintText: 'e.g., Save for Europe Trip',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a goal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Goal Purpose
              DropdownButtonFormField<GoalPurpose>(
                value: _selectedPurpose,
                decoration: InputDecoration(
                  labelText: 'Goal Category / Purpose',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: GoalPurpose.values.map((purpose) {
                  return DropdownMenuItem(
                    value: purpose,
                    child: Text(_getPurposeLabel(purpose)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPurpose = val);
                },
              ),
              const SizedBox(height: 16),
              // Target Amount & Current Amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _targetAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Target Amount',
                        prefixText: '$baseCurrency ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final dec = Decimal.tryParse(value);
                        if (dec == null || dec <= Decimal.zero) {
                          return 'Must be > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _currentAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Current Savings',
                        hintText: '0',
                        prefixText: '$baseCurrency ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final dec = Decimal.tryParse(value);
                        if (dec == null || dec < Decimal.zero) {
                          return 'Must be >= 0';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Date Picker
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: _selectDate,
                decoration: InputDecoration(
                  labelText: 'Target Date',
                  hintText: 'Select when you need this money',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (_selectedDate == null) {
                    return 'Please select a date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Linked Account (Dynamic Dropdown)
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error loading accounts: $e'),
                data: (accountsList) {
                  final activeAccounts = accountsList.where((a) => a.isActive).toList();
                  return DropdownButtonFormField<String?>(
                    value: _selectedAccountId,
                    decoration: InputDecoration(
                      labelText: 'Linked Funding Account (Optional)',
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Not Linked (General Savings)'),
                      ),
                      ...activeAccounts.map((account) {
                        return DropdownMenuItem<String?>(
                          value: account.id,
                          child: Text('${account.name} (${account.currentBalance.format()})'),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedAccountId = val);
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              // Priority Segmented Button
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Goal Priority',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AikoColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('Low')),
                        ButtonSegment(value: 2, label: Text('Medium')),
                        ButtonSegment(value: 3, label: Text('High')),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (set) {
                        setState(() => _priority = set.first);
                      },
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AikoColors.primaryBlue,
                        selectedForegroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Create Button
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
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSubmitting ? 'Creating Goal...' : 'Create SMART Goal',
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
