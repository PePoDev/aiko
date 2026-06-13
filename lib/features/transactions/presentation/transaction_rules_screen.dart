import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/transaction.dart';

class TransactionRulesScreen extends StatefulWidget {
  const TransactionRulesScreen({this.storage, super.key});

  final SecureStorageService? storage;

  @override
  State<TransactionRulesScreen> createState() => _TransactionRulesScreenState();
}

class _TransactionRulesScreenState extends State<TransactionRulesScreen> {
  late final _AutomationRuleStore _store;
  var _rules = <_AutomationRule>[];

  @override
  void initState() {
    super.initState();
    _store = _AutomationRuleStore(
      storage: widget.storage ?? FlutterSecureStorageService(),
    );
    _rules = [..._seedRules];
    _restoreRules();
  }

  Future<void> _restoreRules() async {
    final rules = await _store.load();
    if (!mounted || rules.isEmpty) return;
    setState(() => _rules = rules);
  }

  static final List<_AutomationRule> _seedRules = [
    _AutomationRule(
      id: 'email-statement-rule',
      name: 'Credit card statement imports',
      source: _RuleSource.emailStatement,
      matcher: 'Monthly statement PDF from card issuer',
      action: _RuleAction(
        transactionType: TransactionType.expense,
        merchantHint: 'Parse merchant rows',
        categoryHint: 'Use merchant/category rules',
        accountHint: 'Credit card account',
        tags: ['statement', 'credit-card'],
        reviewBeforeImport: true,
      ),
      priority: 10,
    ),
    _AutomationRule(
      id: 'bank-slip-rule',
      name: 'Mobile banking slip photos',
      source: _RuleSource.bankSlipImage,
      matcher: 'Transfer slip screenshots and saved images',
      action: _RuleAction(
        transactionType: TransactionType.transfer,
        merchantHint: 'Read recipient from image',
        categoryHint: 'Transfer',
        accountHint: 'Selected bank account',
        tags: ['bank-slip'],
        reviewBeforeImport: true,
      ),
      priority: 20,
    ),
    _AutomationRule(
      id: 'sms-rule',
      name: 'Bank SMS alerts',
      source: _RuleSource.sms,
      matcher: 'Debit, credit, paid, transferred',
      action: _RuleAction(
        transactionType: TransactionType.expense,
        merchantHint: 'Extract merchant from SMS',
        categoryHint: 'Auto categorize',
        accountHint: 'Matched bank account',
        tags: ['sms'],
        reviewBeforeImport: false,
      ),
      priority: 30,
    ),
    _AutomationRule(
      id: 'notification-rule',
      name: 'Bank app notifications',
      source: _RuleSource.appNotification,
      matcher: 'Payment, transfer, card charged',
      action: _RuleAction(
        transactionType: TransactionType.expense,
        merchantHint: 'Extract notification title/body',
        categoryHint: 'Auto categorize',
        accountHint: 'Matched account',
        tags: ['notification'],
        reviewBeforeImport: true,
      ),
      priority: 40,
    ),
  ];

  Future<void> _createRule() async {
    final rule = await Navigator.of(context).push<_AutomationRule>(
      MaterialPageRoute(builder: (_) => const _TransactionRuleFormScreen()),
    );
    if (rule == null) return;

    setState(() {
      _rules.add(rule);
      _rules.sort((a, b) => a.priority.compareTo(b.priority));
    });
    await _store.save(_rules);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${rule.name} rule created')));
  }

  void _toggleRule(_AutomationRule rule, bool value) {
    setState(() {
      final index = _rules.indexWhere((item) => item.id == rule.id);
      if (index == -1) return;
      _rules[index] = rule.copyWith(isActive: value);
    });
    _store.save(_rules);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction rules')),
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
                Icons.auto_awesome_motion_outlined,
                color: AikoColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automatic transaction capture',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create rules for external data sources so Aiko can read the content, extract transaction details, and import them for review or automatic logging.',
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
  const _RuleCard({required this.rule, required this.onToggle});

  final _AutomationRule rule;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final source = rule.source;

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
                    color: source.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(source.icon, color: source.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        source.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AikoColors.mutedText,
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
              value: rule.matcher,
            ),
            const SizedBox(height: 8),
            _RuleInfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'Log',
              value:
                  '${rule.action.transactionType.name} • ${rule.action.accountHint}',
            ),
            const SizedBox(height: 8),
            _RuleInfoRow(
              icon: Icons.sell_outlined,
              label: 'Apply',
              value:
                  '${rule.action.categoryHint} • ${rule.action.tags.join(', ')}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RuleChip(
                  icon: rule.action.reviewBeforeImport
                      ? Icons.fact_check_outlined
                      : Icons.flash_on_outlined,
                  label: rule.action.reviewBeforeImport
                      ? 'Review before import'
                      : 'Auto log',
                ),
                _RuleChip(
                  icon: Icons.priority_high,
                  label: 'Priority ${rule.priority}',
                ),
                _RuleChip(
                  icon: Icons.security_outlined,
                  label: source.permissionLabel,
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
        Icon(icon, size: 18, color: AikoColors.mutedText),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AikoColors.mutedText),
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
  final _matcherController = TextEditingController();
  final _merchantController = TextEditingController();
  final _accountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _priorityController = TextEditingController(text: '100');

  _RuleSource _source = _RuleSource.emailStatement;
  TransactionType _transactionType = TransactionType.expense;
  bool _reviewBeforeImport = true;
  bool _isActive = true;

  @override
  void dispose() {
    _nameController.dispose();
    _matcherController.dispose();
    _merchantController.dispose();
    _accountController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final rule = _AutomationRule(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      source: _source,
      matcher: _matcherController.text.trim(),
      action: _RuleAction(
        transactionType: _transactionType,
        merchantHint: _merchantController.text.trim().isEmpty
            ? 'Extract from source content'
            : _merchantController.text.trim(),
        accountHint: _accountController.text.trim().isEmpty
            ? 'Ask before import'
            : _accountController.text.trim(),
        categoryHint: _categoryController.text.trim().isEmpty
            ? 'Auto categorize'
            : _categoryController.text.trim(),
        tags: _tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(growable: false),
        reviewBeforeImport: _reviewBeforeImport,
      ),
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
            DropdownButtonFormField<_RuleSource>(
              initialValue: _source,
              decoration: const InputDecoration(
                labelText: 'External source',
                prefixIcon: Icon(Icons.source_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final source in _RuleSource.values)
                  DropdownMenuItem(value: source, child: Text(source.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _source = value);
              },
            ),
            const SizedBox(height: 16),
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
            TextFormField(
              controller: _matcherController,
              decoration: InputDecoration(
                labelText: 'Match text or pattern',
                helperText: _source.helperText,
                prefixIcon: const Icon(Icons.manage_search_outlined),
                border: const OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 3,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Match text or pattern is required'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TransactionType>(
              initialValue: _transactionType,
              decoration: const InputDecoration(
                labelText: 'Transaction type to create',
                prefixIcon: Icon(Icons.receipt_long_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final type in TransactionType.values)
                  DropdownMenuItem(value: type, child: Text(type.name)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _transactionType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _merchantController,
              decoration: const InputDecoration(
                labelText: 'Merchant or payee mapping',
                hintText: 'Extract from source content',
                prefixIcon: Icon(Icons.storefront_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountController,
              decoration: const InputDecoration(
                labelText: 'Account mapping',
                hintText: 'Ask before import',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category mapping',
                hintText: 'Auto categorize',
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
              title: const Text('Review before import'),
              subtitle: const Text('Show extracted transactions before saving'),
              value: _reviewBeforeImport,
              onChanged: (value) => setState(() => _reviewBeforeImport = value),
            ),
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

enum _RuleSource { emailStatement, bankSlipImage, sms, appNotification }

extension _RuleSourceDetails on _RuleSource {
  String get label {
    return switch (this) {
      _RuleSource.emailStatement => 'Email statement file',
      _RuleSource.bankSlipImage => 'Bank slip image',
      _RuleSource.sms => 'SMS message',
      _RuleSource.appNotification => 'App notification',
    };
  }

  String get helperText {
    return switch (this) {
      _RuleSource.emailStatement =>
        'Example: card issuer sender, PDF file name, or statement keywords',
      _RuleSource.bankSlipImage =>
        'Example: transfer complete, recipient name, or bank slip text',
      _RuleSource.sms => 'Example: debit, credited, payment, available balance',
      _RuleSource.appNotification =>
        'Example: notification title/body from banking or wallet apps',
    };
  }

  String get permissionLabel {
    return switch (this) {
      _RuleSource.emailStatement => 'Email access required',
      _RuleSource.bankSlipImage => 'Photo access required',
      _RuleSource.sms => 'SMS access required',
      _RuleSource.appNotification => 'Notification access required',
    };
  }

  IconData get icon {
    return switch (this) {
      _RuleSource.emailStatement => Icons.mark_email_read_outlined,
      _RuleSource.bankSlipImage => Icons.image_search_outlined,
      _RuleSource.sms => Icons.sms_outlined,
      _RuleSource.appNotification => Icons.notifications_active_outlined,
    };
  }

  Color get color {
    return switch (this) {
      _RuleSource.emailStatement => AikoColors.deepBlue,
      _RuleSource.bankSlipImage => AikoColors.analyticsTeal,
      _RuleSource.sms => AikoColors.successGreen,
      _RuleSource.appNotification => AikoColors.warningOrange,
    };
  }
}

class _AutomationRule {
  const _AutomationRule({
    required this.id,
    required this.name,
    required this.source,
    required this.matcher,
    required this.action,
    required this.priority,
    this.isActive = true,
  });

  final String id;
  final String name;
  final _RuleSource source;
  final String matcher;
  final _RuleAction action;
  final int priority;
  final bool isActive;

  factory _AutomationRule.fromJson(Map<String, dynamic> json) {
    return _AutomationRule(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Untitled rule',
      source: _RuleSource.values.byName(
        json['source'] as String? ?? _RuleSource.emailStatement.name,
      ),
      matcher: json['matcher'] as String? ?? '',
      action: _RuleAction.fromJson(
        Map<String, dynamic>.from(json['action'] as Map? ?? {}),
      ),
      priority: json['priority'] as int? ?? 100,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  _AutomationRule copyWith({bool? isActive}) {
    return _AutomationRule(
      id: id,
      name: name,
      source: source,
      matcher: matcher,
      action: action,
      priority: priority,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'source': source.name,
      'matcher': matcher,
      'action': action.toJson(),
      'priority': priority,
      'is_active': isActive,
    };
  }
}

class _RuleAction {
  const _RuleAction({
    required this.transactionType,
    required this.merchantHint,
    required this.categoryHint,
    required this.accountHint,
    required this.tags,
    required this.reviewBeforeImport,
  });

  final TransactionType transactionType;
  final String merchantHint;
  final String categoryHint;
  final String accountHint;
  final List<String> tags;
  final bool reviewBeforeImport;

  factory _RuleAction.fromJson(Map<String, dynamic> json) {
    return _RuleAction(
      transactionType: TransactionType.values.byName(
        json['transaction_type'] as String? ?? TransactionType.expense.name,
      ),
      merchantHint:
          json['merchant_hint'] as String? ?? 'Extract from source content',
      categoryHint: json['category_hint'] as String? ?? 'Auto categorize',
      accountHint: json['account_hint'] as String? ?? 'Ask before import',
      tags: List<String>.from(json['tags'] as List? ?? []),
      reviewBeforeImport: json['review_before_import'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_type': transactionType.name,
      'merchant_hint': merchantHint,
      'category_hint': categoryHint,
      'account_hint': accountHint,
      'tags': tags,
      'review_before_import': reviewBeforeImport,
    };
  }
}

class _AutomationRuleStore {
  const _AutomationRuleStore({required SecureStorageService storage})
    : _storage = storage;

  static const _key = 'transaction_automation_rules';

  final SecureStorageService _storage;

  Future<List<_AutomationRule>> load() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map(
            (item) => _AutomationRule.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => a.priority.compareTo(b.priority));
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<_AutomationRule> rules) async {
    try {
      await _storage.write(
        _key,
        jsonEncode([for (final rule in rules) rule.toJson()]),
      );
    } catch (_) {
      // Rule creation should keep working for the current session even if
      // secure storage is temporarily unavailable.
    }
  }
}
