import '../../../core/storage/synced_preferences.dart';
import 'package:flutter/foundation.dart' hide Category;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../theme/aiko_colors.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_names.dart';
import '../data/transaction_rule_store.dart';
import '../domain/transaction.dart';
import '../domain/transaction_rule.dart';
import 'transaction_rule_labels.dart';

class TransactionRulesScreen extends ConsumerStatefulWidget {
  const TransactionRulesScreen({this.storage, super.key});

  final SecureStorageService? storage;

  @override
  ConsumerState<TransactionRulesScreen> createState() =>
      _TransactionRulesScreenState();
}

class _TransactionRulesScreenState
    extends ConsumerState<TransactionRulesScreen> {
  late final TransactionRuleStore _store;
  var _rules = <TransactionRule>[];

  /// Rules saved (or deleted, null) on this screen, by id, so a load that
  /// finishes after an edit doesn't undo it.
  final _edits = <String, TransactionRule?>{};

  @override
  void initState() {
    super.initState();
    _store = TransactionRuleStore(
      storage: widget.storage ?? SyncedPreferences(),
    );
    _restoreRules();
  }

  Future<void> _restoreRules() async {
    final rules = await _store.load();
    if (!mounted) return;
    setState(() => _rules = TransactionRuleStore.withEdits(rules, _edits));
  }

  /// Stores one rule (or deletes it, with null); only that rule is written,
  /// so rules changed on another device are left alone.
  Future<void> _saveRule(String id, TransactionRule? rule) async {
    _edits[id] = rule;
    setState(() => _rules = TransactionRuleStore.withEdits(_rules, {id: rule}));
    if (rule == null) {
      await _store.deleteRule(id);
    } else {
      await _store.saveRule(rule);
    }
    ref.invalidate(transactionRulesProvider);
  }

  Future<void> _createRule() async {
    final rule = await openAikoPage<TransactionRule>(
      context,
      const _TransactionRuleFormScreen(),
    );
    if (rule == null) return;

    await _saveRule(rule.id, rule);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.rulesCreated(rule.name))),
    );
  }

  Future<void> _editRule(TransactionRule rule) async {
    final updated = await openAikoPage<TransactionRule>(
      context,
      _TransactionRuleFormScreen(initialRule: rule),
    );
    if (updated == null) return;

    await _saveRule(updated.id, updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.rulesUpdated(updated.name))),
    );
  }

  Future<void> _toggleRule(TransactionRule rule, bool value) async {
    await _saveRule(rule.id, rule.copyWith(isActive: value));
  }

  Future<void> _deleteRule(TransactionRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.rulesDeleteQuestion(rule.name)),
        content: Text(context.l10n.rulesDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AikoColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _saveRule(rule.id, null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.rulesDeleted(rule.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountsProvider).whenOrNull(data: (accounts) => accounts) ??
        const <Account>[];
    final categories =
        ref
            .watch(allCategoriesProvider)
            .whenOrNull(data: (categories) => categories) ??
        const <Category>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.rulesTitle),
        actions: [
          if ((!kIsWeb && defaultTargetPlatform == TargetPlatform.android))
            IconButton(
              tooltip: context.l10n.rulesAutoCaptureTooltip,
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
            matchLabel: ruleConditionValueLabel(
              rule,
              accounts: accounts,
              categories: categories,
              l10n: context.l10n,
            ),
            categoryLabel: ruleTargetCategoryLabel(
              rule,
              categories: categories,
              l10n: context.l10n,
            ),
            onTap: () => _editRule(rule),
            onToggle: (value) => _toggleRule(rule, value),
            onDelete: () => _deleteRule(rule),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRule,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.rulesNew),
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
                    context.l10n.rulesAutomaticTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.rulesAutomaticDescription,
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
    required this.matchLabel,
    required this.categoryLabel,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final TransactionRule rule;

  /// What the rule matches, with ids shown as names.
  final String matchLabel;

  /// The category the rule sets, by name.
  final String categoryLabel;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = rule.isActive
        ? AikoColors.primaryBlue
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                    child: Icon(
                      Icons.rule_outlined,
                      color: accentColor,
                      size: 20,
                    ),
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
                          rulePicksConditionValue(rule.conditionType)
                              ? rule.conditionType.label(context.l10n)
                              : '${rule.conditionType.label(context.l10n)} '
                                    '${rule.operator.label(context.l10n)}',
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
                label: context.l10n.rulesMatch,
                value: matchLabel,
              ),
              const SizedBox(height: 8),
              _RuleInfoRow(
                icon: Icons.category_outlined,
                label: context.l10n.txCategory,
                value: categoryLabel,
              ),
              const SizedBox(height: 8),
              _RuleInfoRow(
                icon: Icons.sell_outlined,
                label: context.l10n.txTags,
                value: rule.tagsToApply.isEmpty
                    ? context.l10n.rulesNoTags
                    : rule.tagsToApply.join(', '),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _RuleChip(
                    icon: Icons.priority_high,
                    label: context.l10n.rulesPriorityValue(rule.priority),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: context.l10n.rulesEdit,
                    onPressed: onTap,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: context.l10n.rulesDelete,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
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

class _TransactionRuleFormScreen extends ConsumerStatefulWidget {
  const _TransactionRuleFormScreen({this.initialRule});

  /// The rule being edited; null when creating one.
  final TransactionRule? initialRule;

  @override
  ConsumerState<_TransactionRuleFormScreen> createState() =>
      _TransactionRuleFormScreenState();
}

class _TransactionRuleFormScreenState
    extends ConsumerState<_TransactionRuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _tagsController = TextEditingController();
  final _priorityController = TextEditingController(text: '100');

  RuleConditionType _conditionType = RuleConditionType.merchant;
  RuleConditionOperator _operator = RuleConditionOperator.contains;

  /// The account id, category id or transaction type name picked as the match
  /// value when [rulePicksConditionValue] holds for [_conditionType].
  String? _pickedValue;
  String? _targetCategoryId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final rule = widget.initialRule;
    if (rule == null) return;
    _nameController.text = rule.name;
    _conditionType = rule.conditionType;
    _operator = rule.operator;
    if (rulePicksConditionValue(rule.conditionType)) {
      final value = rule.conditionType == RuleConditionType.transactionType
          ? transactionTypeForRuleValue(rule.conditionValue)?.name ??
                rule.conditionValue
          : rule.conditionValue;
      _pickedValue = value.trim().isEmpty ? null : value;
    } else {
      _valueController.text = rule.conditionValue;
    }
    final target = rule.targetCategoryId?.trim();
    _targetCategoryId = target == null || target.isEmpty ? null : target;
    _tagsController.text = rule.tagsToApply.join(', ');
    _priorityController.text = '${rule.priority}';
    _isActive = rule.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _tagsController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  void _changeConditionType(RuleConditionType type) {
    if (type == _conditionType) return;
    setState(() {
      _conditionType = type;
      // Picked values belong to one list; a typed value stays in its field.
      _pickedValue = null;
      if (rulePicksConditionValue(type)) {
        _operator = RuleConditionOperator.equals;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final initial = widget.initialRule;
    final picks = rulePicksConditionValue(_conditionType);
    final rule = TransactionRule(
      id: initial?.id ?? const Uuid().v4(),
      userId: initial?.userId ?? '',
      name: _nameController.text.trim(),
      conditionType: _conditionType,
      operator: _operator,
      conditionValue: picks ? _pickedValue! : _valueController.text.trim(),
      targetCategoryId: _targetCategoryId,
      tagsToApply: _splitTags(_tagsController.text),
      priority: int.tryParse(_priorityController.text.trim()) ?? 100,
      isActive: _isActive,
    );

    Navigator.of(context).pop(rule);
  }

  /// (value, label) choices for a picked match value. A stored value that is
  /// no longer offered (a deleted account or category) stays selectable under
  /// its last known name, so editing a rule never drops it silently.
  List<(String, String)> _valueChoices({
    required List<Account> accounts,
    required List<Category> categories,
    required List<Category> allCategories,
  }) {
    final l10n = context.l10n;
    final choices = <(String, String)>[
      ...switch (_conditionType) {
        RuleConditionType.account => [
          for (final account in accounts)
            if (account.isActive) (account.id, account.name),
        ],
        RuleConditionType.category => _categoryChoices(categories),
        RuleConditionType.transactionType => [
          for (final type in TransactionType.values)
            (type.name, type.label(l10n)),
        ],
        RuleConditionType.merchant ||
        RuleConditionType.keyword ||
        RuleConditionType.amount => const <(String, String)>[],
      },
    ];
    final picked = _pickedValue;
    if (picked != null && !choices.any((choice) => choice.$1 == picked)) {
      choices.add((
        picked,
        switch (_conditionType) {
          RuleConditionType.account => ruleAccountName(picked, accounts, l10n),
          RuleConditionType.category => categoryNameForId(
            picked,
            allCategories,
            l10n,
          ),
          _ => picked,
        },
      ));
    }
    return choices;
  }

  List<(String, String)> _categoryChoices(List<Category> categories) => [
    for (final category in categories)
      if (category.isActive) (category.id, category.displayName(context.l10n)),
  ];

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountsProvider).whenOrNull(data: (accounts) => accounts) ??
        const <Account>[];
    final categories =
        ref
            .watch(categoriesProvider)
            .whenOrNull(data: (categories) => categories) ??
        const <Category>[];
    final allCategories =
        ref
            .watch(allCategoriesProvider)
            .whenOrNull(data: (categories) => categories) ??
        categories;
    final picksValue = rulePicksConditionValue(_conditionType);
    final targetChoices = _categoryChoices(categories);
    final target = _targetCategoryId;
    if (target != null && !targetChoices.any((choice) => choice.$1 == target)) {
      targetChoices.add((
        target,
        categoryNameForId(target, allCategories, context.l10n),
      ));
    }
    final isEditing = widget.initialRule != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? context.l10n.rulesEditTitle : context.l10n.rulesNewTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.rulesName,
                prefixIcon: Icon(Icons.edit_outlined),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.l10n.rulesNameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RuleConditionType>(
              initialValue: _conditionType,
              decoration: InputDecoration(
                labelText: context.l10n.rulesField,
                prefixIcon: Icon(Icons.source_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final type in RuleConditionType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.label(context.l10n)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) _changeConditionType(value);
              },
            ),
            const SizedBox(height: 16),
            if (picksValue)
              DropdownButtonFormField<String>(
                // Rebuilt per field so the choices always match the list.
                key: ValueKey('rule-value-${_conditionType.name}'),
                initialValue: _pickedValue,
                isExpanded: true,
                menuMaxHeight: 420,
                decoration: InputDecoration(
                  labelText: context.l10n.rulesMatchValue,
                  prefixIcon: Icon(Icons.manage_search_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final (value, label) in _valueChoices(
                    accounts: accounts,
                    categories: categories,
                    allCategories: allCategories,
                  ))
                    DropdownMenuItem(
                      value: value,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _pickedValue = value;
                  _operator = RuleConditionOperator.equals;
                }),
                validator: (value) =>
                    value == null ? context.l10n.rulesMatchValueRequired : null,
              )
            else ...[
              DropdownButtonFormField<RuleConditionOperator>(
                initialValue: _operator,
                decoration: InputDecoration(
                  labelText: context.l10n.rulesCondition,
                  prefixIcon: Icon(Icons.compare_arrows_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final operator in RuleConditionOperator.values)
                    DropdownMenuItem(
                      value: operator,
                      child: Text(operator.label(context.l10n)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _operator = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: context.l10n.rulesMatchValue,
                  hintText: context.l10n.rulesMatchValueHint,
                  prefixIcon: Icon(Icons.manage_search_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.l10n.rulesMatchValueRequired
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _targetCategoryId,
              isExpanded: true,
              menuMaxHeight: 420,
              decoration: InputDecoration(
                labelText: context.l10n.rulesTargetCategory,
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(context.l10n.rulesLeaveUnchanged),
                ),
                for (final (value, label) in targetChoices)
                  DropdownMenuItem<String?>(
                    value: value,
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _targetCategoryId = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: context.l10n.txTags,
                hintText: context.l10n.rulesTagsHint,
                prefixIcon: Icon(Icons.sell_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priorityController,
              decoration: InputDecoration(
                labelText: context.l10n.rulesPriority,
                helperText: context.l10n.rulesPriorityHelper,
                prefixIcon: Icon(Icons.low_priority_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.rulesActive),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: Text(
          isEditing ? context.l10n.txSaveChanges : context.l10n.rulesCreate,
        ),
      ),
    );
  }
}

List<String> _splitTags(String input) {
  return input
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList(growable: false);
}
