import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../theme/aiko_colors.dart';
import '../data/transaction_rule_store.dart';
import '../domain/transaction_rule.dart';

class TransactionRulesScreen extends ConsumerStatefulWidget {
  const TransactionRulesScreen({this.storage, super.key});

  final SecureStorageService? storage;

  @override
  ConsumerState<TransactionRulesScreen> createState() =>
      _TransactionRulesScreenState();
}

class _TransactionRulesScreenState extends ConsumerState<TransactionRulesScreen> {
  late final TransactionRuleStore _store;
  var _rules = <TransactionRule>[];

  @override
  void initState() {
    super.initState();
    _store = TransactionRuleStore(
      storage: widget.storage ?? FlutterSecureStorageService(),
    );
    _restoreRules();
  }

  Future<void> _restoreRules() async {
    final rules = await _store.load();
    if (!mounted) return;
    setState(() => _rules = _sortRules(rules));
  }

  Future<void> _saveRules(List<TransactionRule> rules) async {
    final sorted = _sortRules(rules);
    setState(() => _rules = sorted);
    await _store.save(sorted);
    ref.invalidate(transactionRulesProvider);
  }

  Future<void> _createRule() async {
    final rule = await Navigator.of(context).push<TransactionRule>(
      MaterialPageRoute(builder: (_) => const _TransactionRuleFormScreen()),
    );
    if (rule == null) return;

    await _saveRules([..._rules, rule]);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${rule.name} rule created')));
  }

  Future<void> _toggleRule(TransactionRule rule, bool value) async {
    await _saveRules([
      for (final item in _rules)
        if (item.id == rule.id) item.copyWith(isActive: value) else item,
    ]);
  }

  Future<void> _deleteRule(TransactionRule rule) async {
    await _saveRules([
      for (final item in _rules)
        if (item.id != rule.id) item,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction rules'),
        actions: [
          if (Platform.isAndroid)
            IconButton(
              tooltip: 'Auto-capture (SMS & notifications)',
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: () => context.push('/transaction-capture'),
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        itemCount: _rules.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _RulesHeader();
          }

          final rule = _rules[index - 1];
          return _RuleCard(
            rule: rule,
            onToggle: (value) => _toggleRule(rule, value),
            onDelete: () => _deleteRule(rule),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRule,
        icon: const Icon(Icons.add),
        label: const Text('New rule'),
      ),
    );
  }
}

class _RulesHeader extends StatelessWidget {
  const _RulesHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AikoColors.primaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.rule_folder_outlined,
                color: AikoColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automatic transaction rules',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rules run after SMS and notification capture. A matching rule can assign a category and add tags before the transaction is saved.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onDelete,
  });

  final TransactionRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = rule.isActive
        ? AikoColors.primaryBlue
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.rule_outlined, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rule.conditionType.label} ${rule.operator.label}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(value: rule.isActive, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: 12),
            _RuleInfoRow(
              icon: Icons.manage_search_outlined,
              label: 'Match',
              value: rule.conditionValue,
            ),
            const SizedBox(height: 8),
            _RuleInfoRow(
              icon: Icons.category_outlined,
              label: 'Category',
              value: rule.targetCategoryId?.trim().isNotEmpty == true
                  ? rule.targetCategoryId!
                  : 'Leave unchanged',
            ),
            const SizedBox(height: 8),
            _RuleInfoRow(
              icon: Icons.sell_outlined,
              label: 'Tags',
              value: rule.tagsToApply.isEmpty
                  ? 'No tags'
                  : rule.tagsToApply.join(', '),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _RuleChip(
                  icon: Icons.priority_high,
                  label: 'Priority ${rule.priority}',
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete rule',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleInfoRow extends StatelessWidget {
  const _RuleInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TransactionRuleFormScreen extends StatefulWidget {
  const _TransactionRuleFormScreen();

  @override
  State<_TransactionRuleFormScreen> createState() =>
      _TransactionRuleFormScreenState();
}

class _TransactionRuleFormScreenState
    extends State<_TransactionRuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _priorityController = TextEditingController(text: '100');

  RuleConditionType _conditionType = RuleConditionType.merchant;
  RuleConditionOperator _operator = RuleConditionOperator.contains;
  bool _isActive = true;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final categoryId = _categoryController.text.trim();
    final rule = TransactionRule(
      id: const Uuid().v4(),
      userId: '',
      name: _nameController.text.trim(),
      conditionType: _conditionType,
      operator: _operator,
      conditionValue: _valueController.text.trim(),
      targetCategoryId: categoryId.isEmpty ? null : categoryId,
      tagsToApply: _splitTags(_tagsController.text),
      priority: int.tryParse(_priorityController.text.trim()) ?? 100,
      isActive: _isActive,
    );

    Navigator.of(context).pop(rule);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New transaction rule')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Rule name',
                prefixIcon: Icon(Icons.edit_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Rule name is required'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RuleConditionType>(
              initialValue: _conditionType,
              decoration: const InputDecoration(
                labelText: 'Field to match',
                prefixIcon: Icon(Icons.source_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final type in RuleConditionType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _conditionType = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RuleConditionOperator>(
              initialValue: _operator,
              decoration: const InputDecoration(
                labelText: 'Condition',
                prefixIcon: Icon(Icons.compare_arrows_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final operator in RuleConditionOperator.values)
                  DropdownMenuItem(value: operator, child: Text(operator.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _operator = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Match value',
                hintText: 'Example: grocery, debit, 7-eleven',
                prefixIcon: Icon(Icons.manage_search_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Match value is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Target category id',
                hintText: 'Optional',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'sms, bank, recurring',
                prefixIcon: Icon(Icons.sell_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priorityController,
              decoration: const InputDecoration(
                labelText: 'Priority',
                helperText: 'Lower priority runs first',
                prefixIcon: Icon(Icons.low_priority_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rule active'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('Create rule'),
      ),
    );
  }
}

List<TransactionRule> _sortRules(List<TransactionRule> rules) {
  return [...rules]..sort((a, b) => a.priority.compareTo(b.priority));
}

List<String> _splitTags(String input) {
  return input
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList(growable: false);
}

extension on RuleConditionType {
  String get label {
    return switch (this) {
      RuleConditionType.merchant => 'Merchant',
      RuleConditionType.keyword => 'Merchant or note',
      RuleConditionType.amount => 'Amount',
      RuleConditionType.account => 'Account id',
      RuleConditionType.category => 'Category id',
      RuleConditionType.transactionType => 'Transaction type',
    };
  }
}

extension on RuleConditionOperator {
  String get label {
    return switch (this) {
      RuleConditionOperator.contains => 'contains',
      RuleConditionOperator.equals => 'equals',
      RuleConditionOperator.startsWith => 'starts with',
      RuleConditionOperator.endsWith => 'ends with',
    };
  }
}
