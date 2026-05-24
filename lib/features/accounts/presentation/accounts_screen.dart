import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/account.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: AikoColors.appBackgroundLight,
      appBar: AppBar(title: const Text('Accounts')),
      body: accountsAsync.when(
        loading: () => const AikoScreenState.loading(),
        error: (err, _) => AikoScreenState.error(
          title: 'Accounts are unavailable',
          message: 'Aiko could not load your accounts right now. $err',
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return AikoScreenState.empty(
              title: 'No accounts yet',
              message: 'Add your cash, bank, card, or investment accounts.',
              action: PrimaryActionButton(
                label: 'Add account',
                icon: Icons.add_card_outlined,
                onPressed: () => _showAccountForm(context),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return _AccountListItem(
                account: account,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountDetailScreen(account: account),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}

void _showAccountForm(BuildContext context, {Account? account}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AccountFormSheet(account: account),
  );
}

void _showAccountSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ),
  );
}

class _AccountListItem extends StatelessWidget {
  const _AccountListItem({required this.account, required this.onTap});

  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _colorForAccount(account.type);

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_iconForAccount(account.type), color: accent, size: 22),
        ),
        title: Text(
          account.name,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(_accountSubtitle(account)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              account.currentBalance.format(),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({required this.account, super.key});

  final Account account;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  late Account _account;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
  }

  Future<void> _editAccount() async {
    final updated = await showModalBottomSheet<Account>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AccountFormSheet(account: _account),
    );

    if (updated == null || !mounted) {
      return;
    }
    setState(() => _account = updated);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
          'Are you sure you want to delete "${_account.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref.read(accountsProvider.notifier).deleteAccount(_account.id);
      if (!mounted) {
        return;
      }
      _showAccountSnackBar(context, 'Account "${_account.name}" deleted.');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showAccountSnackBar(context, 'Unable to delete account right now.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _colorForAccount(_account.type);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account details'),
        actions: [
          IconButton(
            tooltip: 'Delete account',
            onPressed: _deleteAccount,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Edit account',
            onPressed: _editAccount,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _iconForAccount(_account.type),
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _account.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(_accountSubtitle(_account)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _account.currentBalance.format(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AccountDetailRow(
                    label: 'Type',
                    value: _accountTypeLabel(_account.type),
                  ),
                  const Divider(),
                  _AccountDetailRow(
                    label: 'Net worth',
                    value: _account.includeInNetWorth ? 'Included' : 'Hidden',
                  ),
                  const Divider(),
                  _AccountDetailRow(
                    label: 'Status',
                    value: _account.isActive ? 'Active' : 'Inactive',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountFormSheet extends ConsumerStatefulWidget {
  const _AccountFormSheet({this.account});

  final Account? account;

  @override
  ConsumerState<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<_AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _currentBalanceController;
  late final TextEditingController _currencyController;
  late final TextEditingController _institutionController;
  late AccountType _selectedType;
  late bool _includeInNetWorth;
  late bool _isActive;
  var _isSubmitting = false;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _currentBalanceController = TextEditingController(
      text: account?.currentBalance.amount.toString() ?? '',
    );
    _currencyController = TextEditingController(
      text: account?.currentBalance.currency ?? 'THB',
    );
    _institutionController = TextEditingController(
      text: account?.institution ?? '',
    );
    _selectedType = account?.type ?? AccountType.cash;
    _includeInNetWorth = account?.includeInNetWorth ?? true;
    _isActive = account?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentBalanceController.dispose();
    _currencyController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final existing = widget.account;
      final currency = _currencyController.text.trim().toUpperCase();
      final currentBalanceText = _currentBalanceController.text.trim();
      final currentBalance = Money(
        amount: Decimal.parse(currentBalanceText),
        currency: currency,
      );
      final institution = _institutionController.text.trim();
      final account = Account(
        id: existing?.id ?? const Uuid().v4(),
        userId: existing?.userId ?? '',
        name: _nameController.text.trim(),
        type: _selectedType,
        openingBalance: currentBalance,
        currentBalance: currentBalance,
        institution: institution.isEmpty ? null : institution,
        includeInNetWorth: _includeInNetWorth,
        isActive: _isActive,
      );

      await ref.read(accountsProvider.notifier).saveAccount(account);
      if (!_isEditing) {
        await _createInitialBalanceTransaction(account);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(account);
      _showAccountSnackBar(
        context,
        _isEditing
            ? 'Account "${account.name}" updated.'
            : 'Account "${account.name}" created.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showAccountSnackBar(context, 'Unable to save account: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _createInitialBalanceTransaction(Account account) async {
    final amount = account.currentBalance.amount;
    if (amount == Decimal.zero) {
      return;
    }

    final isNegative = amount < Decimal.zero;
    final transactionAmount = Money(
      amount: isNegative ? Decimal.zero - amount : amount,
      currency: account.currentBalance.currency,
    );

    await ref
        .read(transactionsProvider.notifier)
        .addTransaction(
          FinanceTransaction(
            id: const Uuid().v4(),
            userId: account.userId,
            accountId: account.id,
            type: isNegative ? TransactionType.expense : TransactionType.income,
            amount: transactionAmount,
            date: DateTime.now(),
            merchant: 'Initial balance',
            note: 'Created from account starting balance',
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit account' : 'Add account',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g. Daily Expenses, Savings Wallet',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter a name for the account.'
                    : null,
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: AccountType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_accountTypeLabel(type)),
                  );
                }).toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedType = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _institutionController,
                decoration: const InputDecoration(
                  labelText: 'Institution Name',
                  hintText: 'e.g. Chase, PayPal, Coinbase',
                  prefixIcon: Icon(Icons.corporate_fare_outlined),
                ),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _currencyController,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  hintText: 'USD',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  final currency = value?.trim() ?? '';
                  if (currency.length != 3) {
                    return 'Please enter a 3-letter currency code.';
                  }
                  return null;
                },
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentBalanceController,
                decoration: const InputDecoration(
                  labelText: 'Current Balance',
                  prefixText: r'$ ',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Please enter a balance.';
                  }
                  if (Decimal.tryParse(text) == null) {
                    return 'Please enter a valid decimal number.';
                  }
                  return null;
                },
                enabled: !_isSubmitting,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include in net worth'),
                value: _includeInNetWorth,
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _includeInNetWorth = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active account'),
                value: _isActive,
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_isEditing ? 'Save Changes' : 'Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDetailRow extends StatelessWidget {
  const _AccountDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AikoColors.mutedText),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForAccount(AccountType type) {
  return switch (type) {
    AccountType.cash => Icons.wallet_outlined,
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.creditCard => Icons.credit_card_outlined,
    AccountType.investment => Icons.trending_up_outlined,
    AccountType.loan => Icons.handshake_outlined,
    _ => Icons.account_balance_wallet_outlined,
  };
}

Color _colorForAccount(AccountType type) {
  return switch (type) {
    AccountType.cash => AikoColors.successGreen,
    AccountType.bank => AikoColors.deepBlue,
    AccountType.creditCard => AikoColors.warningOrange,
    AccountType.investment => AikoColors.analyticsTeal,
    _ => AikoColors.primaryBlue,
  };
}

String _accountSubtitle(Account account) {
  return account.institution ??
      (account.type == AccountType.cash ? 'Cash wallet' : 'Manual entry');
}

String _accountTypeLabel(AccountType type) {
  final name = type.name;
  final buffer = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final char = name[i];
    if (i > 0 && char.toUpperCase() == char) {
      buffer.write(' ');
    }
    buffer.write(i == 0 ? char.toUpperCase() : char);
  }
  return buffer.toString();
}
