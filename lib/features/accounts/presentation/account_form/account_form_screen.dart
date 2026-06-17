import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/money/money.dart';
import '../../../transactions/domain/transaction.dart';
import '../../domain/account.dart';
import '../../domain/account_details.dart';
import '../../domain/account_validation_exception.dart';
import '../../domain/account_validator.dart';
import 'account_common_fields.dart';
import 'subforms/account_subform.dart';
import 'subforms/asset_subform.dart';
import 'subforms/bank_subform.dart';
import 'subforms/cash_subform.dart';
import 'subforms/credit_card_subform.dart';
import 'subforms/ewallet_subform.dart';
import 'subforms/goal_subform.dart';
import 'subforms/investment_subform.dart';
import 'subforms/liability_subform.dart';
import 'subforms/loan_subform.dart';
import 'subforms/other_subform.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.account, this.initialType});

  final Account? account;

  /// Pre-selects the account type when creating a new account (ignored when
  /// [account] is provided, since an existing account carries its own type).
  final AccountType? initialType;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _institutionController = TextEditingController();

  late AccountType _type;
  late String _currency;
  late bool _includeInNetWorth;
  late bool _isActive;
  late AccountDetails _details;
  GlobalKey<AccountSubformState>? _subformKey;
  GlobalKey<GoalSubformState>? _goalSubformKey;
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
    _type = a?.type ?? widget.initialType ?? AccountType.cash;
    _currency = a?.currency ?? 'THB';
    _details = a?.details ?? AccountDetails.defaultFor(_type);
    _nameController.text = a?.name ?? '';
    _balanceController.text = a?.currentBalance.amount.toString() ?? '';
    _institutionController.text = a?.institution ?? '';
    _includeInNetWorth = a?.includeInNetWorth ?? true;
    _isActive = a?.isActive ?? true;
    _subformKey = GlobalKey<AccountSubformState>();
    _goalSubformKey = GlobalKey<GoalSubformState>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  void _changeType(AccountType next) {
    if (next == _type) return;
    setState(() {
      _type = next;
      _details = AccountDetails.defaultFor(next);
      _subformKey = GlobalKey<AccountSubformState>();
      _goalSubformKey = GlobalKey<GoalSubformState>();
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
      child: KeyedSubtree(
        key: ValueKey(_type),
        child: switch (_type) {
          AccountType.cash => const CashSubform(),
          AccountType.bank => const BankSubform(),
          AccountType.eWallet => const EWalletSubform(),
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
          AccountType.goal => _accountSeedForGoal().maybeWhen(
            data: (initial) => GoalSubform(
              key: _goalSubformKey,
              initial: initial,
              currency: _currency,
              onChanged: (a) {
                // The shared form reads the account from the form state
                // directly; we only need to ensure the typed values land
                // in the goal fields when the form is saved.
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          AccountType.other => OtherSubform(
            key: const ValueKey('other'),
            initial: _details as OtherDetails,
            onChanged: (d) => setState(() => _details = d),
          ),
        },
      ),
    );
  }

  /// Returns the [Account] used to seed the goal subform. When the form
  /// is editing an existing goal account we pass it through; otherwise we
  /// build a placeholder with the user's current draft values.
  AsyncValue<Account> _accountSeedForGoal() {
    final async = ref.watch(accountsProvider);
    return async.whenData((_) => _draftGoalAccount());
  }

  Account _draftGoalAccount() {
    final existing = widget.account;
    if (existing != null && existing.type == AccountType.goal) {
      return existing;
    }
    return Account(
      id: widget.account?.id ?? const Uuid().v4(),
      userId: widget.account?.userId ?? '',
      name: _nameController.text.trim(),
      type: AccountType.goal,
      currentBalance: Money(
        amount:
            Decimal.tryParse(_balanceController.text.trim()) ?? Decimal.zero,
        currency: _currency,
      ),
      targetAmount: null,
      targetDate: null,
      priority: GoalPriority.medium,
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
    final goalError = _goalSubformKey?.currentState?.validate();
    if (goalError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(goalError)));
      return;
    }
    final latest = _subformKey?.currentState?.getDetails() ?? _details;
    final goalSubform = _goalSubformKey?.currentState;
    final goalTargetAmount = goalSubform != null && _type == AccountType.goal
        ? _parseGoalMoney(goalSubform, _currency, kind: 'target')
        : null;
    final goalCurrentAmount = goalSubform != null && _type == AccountType.goal
        ? _parseGoalMoney(goalSubform, _currency, kind: 'current')
        : null;

    setState(() => _isSubmitting = true);
    try {
      final balance = _type == AccountType.goal && goalCurrentAmount != null
          ? goalCurrentAmount
          : Money(
              amount: Decimal.parse(_balanceController.text.trim()),
              currency: _currency,
            );
      final account = Account(
        id: widget.account?.id ?? const Uuid().v4(),
        userId: widget.account?.userId ?? '',
        name: _nameController.text.trim(),
        type: _type,
        currentBalance: balance,
        institution: _institutionController.text.trim().isEmpty
            ? null
            : _institutionController.text.trim(),
        includeInNetWorth: _includeInNetWorth,
        isActive: _isActive,
        details: latest,
        targetAmount: goalTargetAmount,
        targetDate: _type == AccountType.goal ? goalSubform?.targetDate : null,
        priority: _type == AccountType.goal
            ? goalSubform?.priority ?? GoalPriority.medium
            : GoalPriority.medium,
      );
      final all = ref.read(accountsProvider).value ?? const <Account>[];
      AccountValidator.validate(account, allAccounts: all);
      await ref.read(accountsProvider.notifier).saveAccount(account);
      if (!mounted) return;
      if (widget.account == null) {
        await _createInitialBalanceTransaction(account);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final message = widget.account == null
          ? 'Account "${account.name}" created.'
          : 'Account "${account.name}" updated.';
      Navigator.of(context).pop(account);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        ),
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

  Money? _parseGoalMoney(
    GoalSubformState subform,
    String currency, {
    required String kind,
  }) {
    final controller = kind == 'target'
        ? subform.targetController
        : subform.currentController;
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return Money.parse(value, currency);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final isEditing = widget.account != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit account' : 'Add account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
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
            label: Text(isEditing ? 'Save Changes' : 'Create Account'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }
}
