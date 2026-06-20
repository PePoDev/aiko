import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/money/money.dart';
import '../../../../features/assets/domain/asset.dart';
import '../../../../shared/widgets/aiko_data_widgets.dart';
import '../../../../theme/aiko_colors.dart';
import '../../../transactions/domain/transaction.dart';
import '../../domain/account.dart';
import '../../domain/account_details.dart';
import '../../domain/account_validator.dart';
import 'account_common_fields.dart';

export '../../domain/account_details.dart' show RewardsType;

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

  // Credit card
  late final TextEditingController _ccLimit;
  late final TextEditingController _ccApr;
  late final TextEditingController _ccAnnualFee;
  late final TextEditingController _ccMinPayment;
  late int _ccStatementDay;
  late int _ccDueDay;
  RewardsType? _ccRewardsType;
  late bool _ccSharesLimit;
  String? _ccSharedLimitAccountId;
  String? _ccValidationError;

  // Loan
  late LoanType _loanType;
  late final TextEditingController _loanPrincipal;
  late final TextEditingController _loanApr;
  late final TextEditingController _loanTerm;
  late final TextEditingController _loanPayment;
  late DateTime _loanDue;

  // Investment
  late final TextEditingController _invLast4;

  // Asset
  late AssetClass _assetClass;
  late final TextEditingController _assetPrice;
  DateTime? _assetDate;
  late final TextEditingController _assetNotes;

  // Liability
  late final TextEditingController _liabType;
  late final TextEditingController _liabApr;
  late final TextEditingController _liabNotes;

  // Other
  late final TextEditingController _otherNotes;

  // Goal
  late final TextEditingController _goalTarget;
  late final TextEditingController _goalCurrent;
  late DateTime? _goalDate;
  late GoalPriority _goalPriority;

  late AccountType _type;
  late String _currency;
  late bool _includeInNetWorth;
  late bool _isActive;
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
    _currency =
        a?.currency ??
        ref.read(profileProvider).value?.baseCurrency ??
        kDefaultBaseCurrency;
    _nameController.text = a?.name ?? '';
    _balanceController.text = a?.currentBalance.amount.toString() ?? '';
    _institutionController.text = a?.institution ?? '';
    _includeInNetWorth = a?.includeInNetWorth ?? true;
    _isActive = a?.isActive ?? true;

    final cc = a?.details is CreditCardDetails
        ? a!.details as CreditCardDetails
        : AccountDetails.defaultFor(AccountType.creditCard)
              as CreditCardDetails;
    _ccLimit = TextEditingController(
      text: cc.creditLimit?.amount.toString() ?? '',
    );
    _ccApr = TextEditingController(text: cc.aprPercent?.toString() ?? '');
    _ccAnnualFee = TextEditingController(
      text: cc.annualFee?.amount.toString() ?? '',
    );
    _ccMinPayment = TextEditingController(
      text: cc.minimumPayment?.amount.toString() ?? '',
    );
    _ccStatementDay = cc.statementDay;
    _ccDueDay = cc.dueDay;
    _ccRewardsType = cc.rewardsType;
    _ccSharesLimit = cc.sharesLimit;
    _ccSharedLimitAccountId = cc.sharedLimitAccountId;

    final loan = a?.details is LoanDetails
        ? a!.details as LoanDetails
        : AccountDetails.defaultFor(AccountType.loan) as LoanDetails;
    _loanType = loan.loanType;
    _loanPrincipal = TextEditingController(
      text: loan.principal.amount.toString(),
    );
    _loanApr = TextEditingController(text: loan.interestRatePercent.toString());
    _loanTerm = TextEditingController(text: loan.termMonths.toString());
    _loanPayment = TextEditingController(
      text: loan.monthlyPayment.amount.toString(),
    );
    _loanDue = loan.nextDueDate;

    final inv = a?.details is InvestmentDetails
        ? a!.details as InvestmentDetails
        : AccountDetails.defaultFor(AccountType.investment)
              as InvestmentDetails;
    _invLast4 = TextEditingController(text: inv.accountNumberLast4 ?? '');

    final asset = a?.details is AssetDetails
        ? a!.details as AssetDetails
        : AccountDetails.defaultFor(AccountType.asset) as AssetDetails;
    _assetClass = asset.assetClass;
    _assetPrice = TextEditingController(
      text: asset.purchasePrice?.amount.toString() ?? '',
    );
    _assetDate = asset.purchaseDate;
    _assetNotes = TextEditingController(text: asset.notes ?? '');

    final liab = a?.details is LiabilityDetails
        ? a!.details as LiabilityDetails
        : AccountDetails.defaultFor(AccountType.liability) as LiabilityDetails;
    _liabType = TextEditingController(text: liab.liabilityType ?? '');
    _liabApr = TextEditingController(
      text: liab.interestRatePercent?.toString() ?? '',
    );
    _liabNotes = TextEditingController(text: liab.notes ?? '');

    final other = a?.details is OtherDetails
        ? a!.details as OtherDetails
        : AccountDetails.defaultFor(AccountType.other) as OtherDetails;
    _otherNotes = TextEditingController(text: other.notes ?? '');

    _goalTarget = TextEditingController(
      text: a?.targetAmount?.amount.toString() ?? '',
    );
    _goalCurrent = TextEditingController(
      text: a?.currentBalance.amount.toString(),
    );
    _goalDate = a?.targetDate;
    _goalPriority = a?.priority ?? GoalPriority.medium;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _institutionController.dispose();
    _ccLimit.dispose();
    _ccApr.dispose();
    _ccAnnualFee.dispose();
    _ccMinPayment.dispose();
    _loanPrincipal.dispose();
    _loanApr.dispose();
    _loanTerm.dispose();
    _loanPayment.dispose();
    _invLast4.dispose();
    _assetPrice.dispose();
    _assetNotes.dispose();
    _liabType.dispose();
    _liabApr.dispose();
    _liabNotes.dispose();
    _otherNotes.dispose();
    _goalTarget.dispose();
    _goalCurrent.dispose();
    super.dispose();
  }

  void _changeType(AccountType next) {
    if (next == _type) return;
    setState(() => _type = next);
  }

  // --- type-specific details assembly ---

  Money? _moneyOrNone(TextEditingController c, String currency) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    try {
      return Money.parse(t, currency);
    } catch (_) {
      return null;
    }
  }

  Money _moneyOrZero(TextEditingController c, String currency) {
    return _moneyOrNone(c, currency) ?? Money.zero(currency);
  }

  AccountDetails _detailsForType() {
    return switch (_type) {
      AccountType.cash => const CashDetails(),
      AccountType.bank => const BankDetails(),
      AccountType.eWallet => const EWalletDetails(),
      AccountType.creditCard => CreditCardDetails(
        creditLimit: _ccSharesLimit ? null : _moneyOrNone(_ccLimit, _currency),
        statementDay: _ccStatementDay,
        dueDay: _ccDueDay,
        aprPercent: double.tryParse(_ccApr.text.trim()),
        rewardsType: _ccRewardsType,
        annualFee: _moneyOrNone(_ccAnnualFee, _currency),
        minimumPayment: _moneyOrNone(_ccMinPayment, _currency),
        sharesLimit: _ccSharesLimit,
        sharedLimitAccountId: _ccSharesLimit ? _ccSharedLimitAccountId : null,
      ),
      AccountType.loan => LoanDetails(
        loanType: _loanType,
        principal: _moneyOrZero(_loanPrincipal, _currency),
        interestRatePercent: double.tryParse(_loanApr.text.trim()) ?? 0,
        termMonths: int.tryParse(_loanTerm.text.trim()) ?? 0,
        monthlyPayment: _moneyOrZero(_loanPayment, _currency),
        nextDueDate: _loanDue,
      ),
      AccountType.investment => InvestmentDetails(
        accountNumberLast4: _invLast4.text.trim().isEmpty
            ? null
            : _invLast4.text.trim(),
      ),
      AccountType.asset => AssetDetails(
        assetClass: _assetClass,
        purchasePrice: _moneyOrNone(_assetPrice, _currency),
        purchaseDate: _assetDate,
        notes: _assetNotes.text.trim().isEmpty ? null : _assetNotes.text.trim(),
      ),
      AccountType.liability => LiabilityDetails(
        liabilityType: _liabType.text.trim().isEmpty
            ? null
            : _liabType.text.trim(),
        interestRatePercent: double.tryParse(_liabApr.text.trim()),
        notes: _liabNotes.text.trim().isEmpty ? null : _liabNotes.text.trim(),
      ),
      AccountType.other => OtherDetails(
        notes: _otherNotes.text.trim().isEmpty ? null : _otherNotes.text.trim(),
      ),
      AccountType.goal => const OtherDetails(),
    };
  }

  String? _validateTypeFields() {
    switch (_type) {
      case AccountType.creditCard:
        if (_ccStatementDay < 1 || _ccStatementDay > 31) {
          return AccountValidationMessages.statementDayRange;
        }
        if (_ccDueDay < 1 || _ccDueDay > 31) {
          return AccountValidationMessages.dueDayRange;
        }
        final apr = double.tryParse(_ccApr.text.trim());
        if (_ccApr.text.trim().isNotEmpty && (apr == null || apr < 0)) {
          return AccountValidationMessages.aprNegative;
        }
        if (_ccSharesLimit) {
          if (_ccSharedLimitAccountId == null) {
            return AccountValidationMessages.sharedLimitReferenceRequired;
          }
        } else if (_ccLimit.text.trim().isEmpty) {
          return AccountValidationMessages.creditLimitRequired;
        }
        return null;
      case AccountType.loan:
        final term = int.tryParse(_loanTerm.text.trim()) ?? 0;
        if (term <= 0) return AccountValidationMessages.termMonthsPositive;
        return null;
      case AccountType.asset:
        if (_assetPrice.text.trim().isNotEmpty && _assetDate == null) {
          return AccountValidationMessages.purchaseDateRequired;
        }
        return null;
      case AccountType.liability:
        final apr = double.tryParse(_liabApr.text.trim());
        if (_liabApr.text.trim().isNotEmpty && apr == null) {
          return 'Enter a valid APR.';
        }
        return null;
      case AccountType.goal:
        final target = _goalTarget.text.trim();
        final current = _goalCurrent.text.trim();
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
        if (target.isNotEmpty && _goalDate == null) {
          return 'Pick a target date when a target amount is set';
        }
        return null;
      default:
        return null;
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
          updateAccountBalance: false,
        );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final typeError = _validateTypeFields();
    if (typeError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(typeError)));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      Money balance;
      if (_type == AccountType.goal) {
        final currentText = _goalCurrent.text.trim();
        balance = currentText.isEmpty
            ? Money(amount: Decimal.zero, currency: _currency)
            : Money.parse(currentText, _currency);
      } else {
        balance = Money(
          amount: Decimal.parse(_balanceController.text.trim()),
          currency: _currency,
        );
      }
      Money? goalTargetAmount;
      if (_type == AccountType.goal) {
        final targetText = _goalTarget.text.trim();
        goalTargetAmount = targetText.isEmpty
            ? null
            : Money.parse(targetText, _currency);
      }
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
        details: _detailsForType(),
        targetAmount: goalTargetAmount,
        targetDate: _type == AccountType.goal ? _goalDate : null,
        priority: _type == AccountType.goal
            ? _goalPriority
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

  String _dateLabel(DateTime? d) {
    if (d == null) return 'Tap to choose';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({
    required DateTime? current,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Widget _typeFields(List<Account> allCards) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: KeyedSubtree(
        key: ValueKey(_type),
        child: switch (_type) {
          AccountType.cash ||
          AccountType.bank ||
          AccountType.eWallet => const SizedBox.shrink(),
          AccountType.creditCard => _creditCardFields(allCards),
          AccountType.loan => _loanFields(),
          AccountType.investment => _investmentFields(),
          AccountType.asset => _assetFields(),
          AccountType.liability => _liabilityFields(),
          AccountType.other => _otherFields(),
          AccountType.goal => _goalFields(),
        },
      ),
    );
  }

  Widget _creditCardFields(List<Account> allCards) {
    final available = allCards
        .where((a) => a.id != widget.account?.id)
        .toList();
    if (_ccSharesLimit &&
        _ccSharedLimitAccountId != null &&
        !available.any((a) => a.id == _ccSharedLimitAccountId)) {
      // Carry the validation message set in initState if the referenced card
      // is gone; surface it on the next rebuild.
      _ccValidationError ??=
          AccountValidationMessages.sharedLimitCardUnavailable;
      _ccSharesLimit = false;
      _ccSharedLimitAccountId = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_ccValidationError != null) ...[
          AikoInlineNotice(
            title: 'Heads up',
            message: _ccValidationError!,
            icon: Icons.warning_amber_outlined,
            accentColor: AikoColors.warningOrange,
          ),
          const SizedBox(height: 12),
        ],
        _DayPickerField(
          label: 'Statement day (1-31)',
          value: _ccStatementDay,
          onChanged: (v) => setState(() => _ccStatementDay = v),
        ),
        const SizedBox(height: 12),
        _DayPickerField(
          label: 'Due day (1-31)',
          value: _ccDueDay,
          onChanged: (v) => setState(() => _ccDueDay = v),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share limit with another card'),
          value: _ccSharesLimit,
          onChanged: (v) => setState(() {
            _ccSharesLimit = v;
            if (!v) _ccSharedLimitAccountId = null;
          }),
        ),
        if (_ccSharesLimit) ...[
          DropdownButtonFormField<String>(
            initialValue: _ccSharedLimitAccountId,
            decoration: const InputDecoration(
              labelText: 'Card to share with',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
            items: available
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (v) => setState(() => _ccSharedLimitAccountId = v),
          ),
          const SizedBox(height: 12),
        ] else ...[
          TextField(
            controller: _ccLimit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Credit limit',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _ccApr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'APR (%)',
            prefixIcon: Icon(Icons.percent_outlined),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<RewardsType?>(
          initialValue: _ccRewardsType,
          decoration: const InputDecoration(
            labelText: 'Rewards type',
            prefixIcon: Icon(Icons.redeem_outlined),
          ),
          items: [
            const DropdownMenuItem<RewardsType?>(
              value: null,
              child: Text('None'),
            ),
            ...RewardsType.values.map(
              (r) =>
                  DropdownMenuItem<RewardsType?>(value: r, child: Text(r.name)),
            ),
          ],
          onChanged: (v) => setState(() => _ccRewardsType = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ccAnnualFee,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Annual fee (optional)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ccMinPayment,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Minimum payment (optional)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
      ],
    );
  }

  Widget _loanFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<LoanType>(
          initialValue: _loanType,
          decoration: const InputDecoration(
            labelText: 'Loan type',
            prefixIcon: Icon(Icons.handshake_outlined),
          ),
          items: LoanType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _loanType = v);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loanPrincipal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Principal',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loanApr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Interest rate (%)',
            prefixIcon: Icon(Icons.percent_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loanTerm,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Term (months)',
            prefixIcon: Icon(Icons.calendar_view_month_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loanPayment,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly payment',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _pickDate(
            current: _loanDue,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
            onPicked: (d) => _loanDue = d,
          ),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Next due date',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(_dateLabel(_loanDue)),
          ),
        ),
      ],
    );
  }

  Widget _investmentFields() {
    return TextField(
      controller: _invLast4,
      maxLength: 4,
      decoration: const InputDecoration(
        labelText: 'Account number (last 4)',
        prefixIcon: Icon(Icons.numbers_outlined),
      ),
    );
  }

  Widget _assetFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AssetClass>(
          initialValue: _assetClass,
          decoration: const InputDecoration(
            labelText: 'Asset class',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: AssetClass.values
              .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _assetClass = v);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _assetPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Purchase price (optional)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _pickDate(
            current: _assetDate,
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
            onPicked: (d) => _assetDate = d,
          ),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Purchase date',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(_dateLabel(_assetDate)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _assetNotes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
      ],
    );
  }

  Widget _liabilityFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _liabType,
          decoration: const InputDecoration(
            labelText: 'Type',
            hintText: 'e.g. Overdraft, Personal loan',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _liabApr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Interest rate (%)',
            prefixIcon: Icon(Icons.percent_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _liabNotes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
      ],
    );
  }

  Widget _otherFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _otherNotes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'What kind of account is this?',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 8),
        const AikoInlineNotice(
          title: 'No extra details',
          message: 'Other accounts are flexible. Add notes to help future-you.',
          icon: Icons.lightbulb_outline,
          accentColor: AikoColors.deepBlue,
        ),
      ],
    );
  }

  Widget _goalFields() {
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
                const Icon(
                  Icons.flag_outlined,
                  color: AikoColors.premiumPurple,
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
                    controller: _goalTarget,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Target amount',
                      prefixText: '$_currency ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _goalCurrent,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Saved so far',
                      prefixText: '$_currency ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              readOnly: true,
              controller: TextEditingController(text: _dateLabel(_goalDate)),
              onTap: () => _pickDate(
                current: _goalDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
                onPicked: (d) => _goalDate = d,
              ),
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
              selected: {_goalPriority},
              onSelectionChanged: (set) =>
                  setState(() => _goalPriority = set.first),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCards = ref
        .watch(accountsProvider)
        .maybeWhen(
          data: (list) =>
              list.where((a) => a.type == AccountType.creditCard).toList(),
          orElse: () => const <Account>[],
        );
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
              _typeFields(allCards),
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

class _DayPickerField extends StatelessWidget {
  const _DayPickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      items: [
        for (var d = 1; d <= 31; d++)
          DropdownMenuItem(value: d, child: Text('$d')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
