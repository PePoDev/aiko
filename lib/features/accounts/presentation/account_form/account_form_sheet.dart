import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/money/money.dart';
import '../../../transactions/domain/transaction.dart';
import '../../domain/account.dart';
import '../../domain/account_details.dart';
import '../../domain/account_type.dart';
import '../../domain/account_validation_exception.dart';
import '../../domain/account_validator.dart';
import 'account_common_fields.dart';
import 'subforms/account_subform.dart';
import 'subforms/asset_subform.dart';
import 'subforms/bank_subform.dart';
import 'subforms/cash_subform.dart';
import 'subforms/credit_card_subform.dart';
import 'subforms/ewallet_subform.dart';
import 'subforms/investment_subform.dart';
import 'subforms/liability_subform.dart';
import 'subforms/loan_subform.dart';
import 'subforms/other_subform.dart';

class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({super.key, this.account});
  final Account? account;

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _institutionController = TextEditingController();
  final _currencyController = TextEditingController();

  late AccountType _type;
  late String _currency;
  late bool _includeInNetWorth;
  late bool _isActive;
  late AccountDetails _details;
  GlobalKey<AccountSubformState>? _subformKey;
  var _isSubmitting = false;
  static const _currencies = [
    ('THB', 'Thai Baht'),
    ('USD', 'US Dollar'),
    ('EUR', 'Euro'),
    ('GBP', 'British Pound'),
    ('JPY', 'Japanese Yen'),
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _type = a?.type ?? AccountType.cash;
    _currency = a?.currency ?? 'THB';
    _details = a?.details ?? AccountDetails.defaultFor(_type);
    _nameController.text = a?.name ?? '';
    _balanceController.text = a?.currentBalance.amount.toString() ?? '';
    _institutionController.text = a?.institution ?? '';
    _includeInNetWorth = a?.includeInNetWorth ?? true;
    _isActive = a?.isActive ?? true;
    _subformKey = GlobalKey<AccountSubformState>();
    _currencyController.text = _currency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _institutionController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _changeType(AccountType next) async {
    if (next == _type) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Switch account type?'),
        content: const Text(
          'Switching type resets the details you entered for this account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _type = next;
      _details = AccountDetails.defaultFor(next);
      _subformKey = GlobalKey<AccountSubformState>();
    });
  }

  Widget _buildSubform(AsyncValue<List<Account>> accounts) {
    final allCards = accounts.maybeWhen(
      data: (list) =>
          list.where((a) => a.type == AccountType.creditCard).toList(),
      orElse: () => const <Account>[],
    );
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: switch (_type) {
        AccountType.cash => const CashSubform(),
        AccountType.bank => BankSubform(
          key: const ValueKey('bank'),
          initial: _details as BankDetails,
          onChanged: (d) => setState(() => _details = d),
        ),
        AccountType.eWallet => EWalletSubform(
          key: const ValueKey('ew'),
          initial: _details as EWalletDetails,
          onChanged: (d) => setState(() => _details = d),
        ),
        AccountType.creditCard => CreditCardSubform(
          key: _subformKey,
          initial: _details as CreditCardDetails,
          availableCards: allCards
              .where((a) => a.id != widget.account?.id)
              .toList(),
          onChanged: (d) => setState(() => _details = d),
        ),
        AccountType.loan => LoanSubform(
          key: _subformKey,
          initial: _details as LoanDetails,
          currency: _currency,
          onChanged: (d) => setState(() => _details = d),
        ),
        AccountType.investment => InvestmentSubform(
          key: const ValueKey('inv'),
          initial: _details as InvestmentDetails,
          onChanged: (d) => setState(() => _details = d),
        ),
        AccountType.asset => AssetSubform(
          key: _subformKey,
          initial: _details as AssetDetails,
          currency: _currency,
          onChanged: (d) => setState(() => _details = d),
        ),
        AccountType.liability => LiabilitySubform(
          key: const ValueKey('liab'),
          initial: _details as LiabilityDetails,
          onChanged: (d) => setState(() => _details = d),
        ),
        AccountType.other => OtherSubform(
          key: const ValueKey('other'),
          initial: _details as OtherDetails,
          onChanged: (d) => setState(() => _details = d),
        ),
      },
    );
  }

  void _showSnack(BuildContext context, String message) {
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
          updateAccountBalance: false,
        );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final subError = _subformKey?.currentState?.validate();
    if (subError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(subError)));
      return;
    }
    final latest = _subformKey?.currentState?.getDetails() ?? _details;

    setState(() => _isSubmitting = true);
    try {
      final account = Account(
        id: widget.account?.id ?? const Uuid().v4(),
        userId: widget.account?.userId ?? '',
        name: _nameController.text.trim(),
        type: _type,
        currentBalance: Money(
          amount: Decimal.parse(_balanceController.text.trim()),
          currency: _currency,
        ),
        institution: _institutionController.text.trim().isEmpty
            ? null
            : _institutionController.text.trim(),
        includeInNetWorth: _includeInNetWorth,
        isActive: _isActive,
        details: latest,
      );
      final all = ref.read(accountsProvider).value ?? const <Account>[];
      AccountValidator.validate(account, allAccounts: all);
      await ref.read(accountsProvider.notifier).saveAccount(account);
      if (!mounted) return;
      if (widget.account == null) {
        await _createInitialBalanceTransaction(account);
      }
      if (!mounted) return;
      Navigator.of(context).pop(account);
      _showSnack(
        context,
        widget.account == null
            ? 'Account "${account.name}" created.'
            : 'Account "${account.name}" updated.',
      );
    } on AccountValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
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
                widget.account == null ? 'Add account' : 'Edit account',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AccountCommonFields(
                initialType: _type,
                initialCurrency: _currency,
                initialIncludeInNetWorth: _includeInNetWorth,
                initialIsActive: _isActive,
                currencies: _currencies
                    .map((c) => (code: c.$1, name: c.$2))
                    .toList(),
                nameController: _nameController,
                balanceController: _balanceController,
                institutionController: _institutionController,
                currencyController: _currencyController,
                onChanged:
                    ({
                      String? name,
                      AccountType? type,
                      String? currency,
                      String? balance,
                      String? institution,
                      bool? includeInNetWorth,
                      bool? isActive,
                    }) {
                      if (type != null) _changeType(type);
                      setState(() {
                        if (currency != null) _currency = currency;
                        if (includeInNetWorth != null) {
                          _includeInNetWorth = includeInNetWorth;
                        }
                        if (isActive != null) _isActive = isActive;
                      });
                    },
              ),
              const SizedBox(height: 16),
              _buildSubform(accountsAsync),
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
                label: Text(
                  widget.account == null ? 'Create Account' : 'Save Changes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
