import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/supported_currencies.dart';
import '../../../../l10n/domain_labels.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/aiko_data_widgets.dart';
import '../../../../shared/widgets/discard_changes_guard.dart';
import '../../../../theme/aiko_colors.dart';
import '../../../transactions/domain/transaction.dart';
import '../../domain/account.dart';
import '../../domain/account_details.dart';
import '../../domain/account_validator.dart';
import '../account_validation_l10n.dart';
import 'account_amount_input.dart';
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
  late final String _initialCurrency;
  late bool _includeInNetWorth;
  late bool _isActive;
  var _isSubmitting = false;

  /// Every supported currency, plus the account's own if it is not one of
  /// them, so the picker always has an entry for the current value.
  List<String> get _currencies => [
    ...kAikoSupportedCurrencies,
    if (!kAikoSupportedCurrencies.contains(_initialCurrency)) _initialCurrency,
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
    _initialCurrency = _currency;
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

    for (final controller in _textControllers) {
      controller.addListener(_onTextEdited);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialSnapshot = _snapshot();
    });
  }

  List<TextEditingController> get _textControllers => [
    _nameController,
    _balanceController,
    _institutionController,
    _ccLimit,
    _ccApr,
    _ccAnnualFee,
    _ccMinPayment,
    _loanPrincipal,
    _loanApr,
    _loanTerm,
    _loanPayment,
    _assetPrice,
    _assetNotes,
    _liabType,
    _liabApr,
    _liabNotes,
    _otherNotes,
    _goalTarget,
    _goalCurrent,
  ];

  /// The form as first shown; leaving with anything different asks first.
  String? _initialSnapshot;
  bool _wasDirty = false;

  String _snapshot() => [
    _type.name,
    _currency,
    _includeInNetWorth,
    _isActive,
    _goalDate?.toIso8601String(),
    _goalPriority.name,
    for (final controller in _textControllers) controller.text.trim(),
  ].join('\u0001');

  bool get _hasUnsavedChanges =>
      !_isSubmitting &&
      _initialSnapshot != null &&
      _snapshot() != _initialSnapshot;

  void _onTextEdited() {
    final dirty = _hasUnsavedChanges;
    if (dirty != _wasDirty && mounted) setState(() => _wasDirty = dirty);
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
    final amount = parseAccountAmountInput(c.text);
    return amount == null ? null : Money(amount: amount, currency: currency);
  }

  // --- inline validators for the type-specific fields ---

  /// Optional amount: empty is fine, anything else must be a number >= 0.
  String? _optionalAmount(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    final amount = parseAccountAmountInput(value!);
    if (amount == null) return context.l10n.accountFormEnterValidNumber;
    if (amount < Decimal.zero) return context.l10n.accountFormAmountNonNegative;
    return null;
  }

  /// Optional percentage: empty is fine, anything else must be >= 0.
  String? _optionalRate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final rate = double.tryParse(text);
    if (rate == null) return context.l10n.accountFormAprInvalid;
    if (rate < 0) {
      return localizedAccountValidationMessage(
        AccountValidationMessages.aprNegative,
        context.l10n,
      );
    }
    return null;
  }

  String? _creditLimit(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return localizedAccountValidationMessage(
        AccountValidationMessages.creditLimitRequired,
        context.l10n,
      );
    }
    return _optionalAmount(value);
  }

  String? _loanTermMonths(String? value) {
    final term = int.tryParse((value ?? '').trim()) ?? 0;
    if (term <= 0) {
      return localizedAccountValidationMessage(
        AccountValidationMessages.termMonthsPositive,
        context.l10n,
      );
    }
    return null;
  }

  String? _goalTargetAmount(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = num.tryParse(text);
    if (parsed == null || parsed <= 0) {
      return context.l10n.accountFormTargetPositive;
    }
    return null;
  }

  String? _goalSavedAmount(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = num.tryParse(text);
    if (parsed == null || parsed < 0) {
      return context.l10n.accountFormSavedNonNegative;
    }
    return null;
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
      AccountType.investment => const InvestmentDetails(),
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

  /// Checks that have no form field to show an inline error on. Everything
  /// else is validated inline by the fields' own validators.
  String? _validateTypeFields() {
    if (_type == AccountType.asset &&
        _assetPrice.text.trim().isNotEmpty &&
        _assetDate == null) {
      return localizedAccountValidationMessage(
        AccountValidationMessages.purchaseDateRequired,
        context.l10n,
      );
    }
    return null;
  }

  /// Records a new account's opening balance as a signed `adjustment`, so it
  /// moves the balance without counting as income or spending anywhere.
  Future<void> _createInitialBalanceTransaction(Account account) async {
    if (account.currentBalance.isZero) {
      return;
    }

    await ref
        .read(transactionsProvider.notifier)
        .addTransaction(
          FinanceTransaction(
            id: const Uuid().v4(),
            userId: account.userId,
            accountId: account.id,
            type: TransactionType.adjustment,
            amount: account.currentBalance,
            date: DateTime.now(),
            merchant: context.l10n.accountFormInitialBalance,
            note: context.l10n.accountFormInitialBalanceNote,
          ),
          updateAccountBalance: false,
        );
  }

  /// Balances are recomputed from transactions, so an edited balance must be
  /// backed by an `adjustment` for the difference or it would be overwritten.
  /// [transactions] are the account's existing rows.
  Future<void> _createBalanceAdjustmentTransaction(
    Account account,
    List<FinanceTransaction> transactions,
  ) async {
    final difference =
        account.currentBalance -
        balanceFromTransactions(transactions, account.currency);
    if (difference.isZero) {
      return;
    }

    await ref
        .read(transactionsProvider.notifier)
        .addTransaction(
          FinanceTransaction(
            id: const Uuid().v4(),
            userId: account.userId,
            accountId: account.id,
            type: TransactionType.adjustment,
            amount: difference,
            date: DateTime.now(),
            merchant: context.l10n.accountFormBalanceAdjustment,
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
      final previous = widget.account;
      // A changed balance (or currency) is reconciled against the account's
      // existing transactions; other edits don't need them.
      final balanceChanged =
          previous != null && previous.currentBalance != account.currentBalance;
      final accountTransactions = !balanceChanged
          ? const <FinanceTransaction>[]
          : [
              for (final transaction in await ref.read(
                transactionsProvider.future,
              ))
                if (transaction.accountId == previous.id) transaction,
            ];
      if (!mounted) return;
      // Existing rows are in the old currency; switching would silently drop
      // them from the balance.
      if (previous != null &&
          previous.currency != account.currency &&
          accountTransactions.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.accountFormCurrencyLocked)),
        );
        return;
      }
      await ref.read(accountsProvider.notifier).saveAccount(account);
      if (!mounted) return;
      if (previous == null) {
        await _createInitialBalanceTransaction(account);
      } else if (balanceChanged) {
        await _createBalanceAdjustmentTransaction(account, accountTransactions);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final message = widget.account == null
          ? context.l10n.accountFormCreated(account.name)
          : context.l10n.accountFormUpdated(account.name);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedAccountValidationMessage(e.message, context.l10n),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.accountSaveFailed)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return context.l10n.accountFormTapToChoose;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({
    required DateTime? current,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    // Widen the range to include a stored value outside it (an overdue loan
    // date, a goal date already passed) so the picker can open on it.
    final initial = DateUtils.dateOnly(current ?? firstDate);
    final first = DateUtils.dateOnly(firstDate);
    final last = DateUtils.dateOnly(lastDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: initial.isAfter(last) ? initial : last,
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
          AccountType.investment => const SizedBox.shrink(),
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
            title: context.l10n.accountFormHeadsUp,
            message: localizedAccountValidationMessage(
              _ccValidationError!,
              context.l10n,
            ),
            icon: Icons.warning_amber_outlined,
            accentColor: AikoColors.warningOrange,
          ),
          const SizedBox(height: 12),
        ],
        _DayPickerField(
          label: context.l10n.accountFormStatementDay,
          value: _ccStatementDay,
          onChanged: (v) => setState(() => _ccStatementDay = v),
          rangeError: localizedAccountValidationMessage(
            AccountValidationMessages.statementDayRange,
            context.l10n,
          ),
        ),
        const SizedBox(height: 12),
        _DayPickerField(
          label: context.l10n.accountFormDueDay,
          value: _ccDueDay,
          onChanged: (v) => setState(() => _ccDueDay = v),
          rangeError: localizedAccountValidationMessage(
            AccountValidationMessages.dueDayRange,
            context.l10n,
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.accountFormShareLimit),
          value: _ccSharesLimit,
          onChanged: (v) => setState(() {
            _ccSharesLimit = v;
            if (!v) _ccSharedLimitAccountId = null;
          }),
        ),
        if (_ccSharesLimit) ...[
          DropdownButtonFormField<String>(
            initialValue: _ccSharedLimitAccountId,
            decoration: InputDecoration(
              labelText: context.l10n.accountFormCardToShareWith,
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
            items: available
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (v) => setState(() => _ccSharedLimitAccountId = v),
            validator: (v) => v == null
                ? localizedAccountValidationMessage(
                    AccountValidationMessages.sharedLimitReferenceRequired,
                    context.l10n,
                  )
                : null,
          ),
          const SizedBox(height: 12),
        ] else ...[
          TextFormField(
            controller: _ccLimit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.l10n.accountsDetailCreditLimit,
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            validator: _creditLimit,
          ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: _ccApr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.l10n.accountFormApr,
            prefixIcon: Icon(Icons.percent_outlined),
          ),
          validator: _optionalRate,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<RewardsType?>(
          initialValue: _ccRewardsType,
          decoration: InputDecoration(
            labelText: context.l10n.accountFormRewardsType,
            prefixIcon: Icon(Icons.redeem_outlined),
          ),
          items: [
            DropdownMenuItem<RewardsType?>(
              value: null,
              child: Text(context.l10n.rewardsTypeNone),
            ),
            ...RewardsType.values.map(
              (r) => DropdownMenuItem<RewardsType?>(
                value: r,
                child: Text(r.label(context.l10n)),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _ccRewardsType = v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ccAnnualFee,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.l10n.accountFormAnnualFee,
            prefixIcon: Icon(Icons.payments_outlined),
          ),
          validator: _optionalAmount,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ccMinPayment,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.l10n.accountFormMinPayment,
            prefixIcon: Icon(Icons.payments_outlined),
          ),
          validator: _optionalAmount,
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
          decoration: InputDecoration(
            labelText: context.l10n.accountFormLoanType,
            prefixIcon: Icon(Icons.handshake_outlined),
          ),
          items: LoanType.values
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.label(context.l10n)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _loanType = v);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _loanPrincipal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.l10n.accountsDetailPrincipal,
            prefixIcon: Icon(Icons.payments_outlined),
          ),
          validator: _optionalAmount,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _loanApr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.l10n.accountFormInterestRate,
            prefixIcon: Icon(Icons.percent_outlined),
          ),
          validator: _optionalRate,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _loanTerm,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.l10n.accountFormTermMonths,
            prefixIcon: Icon(Icons.calendar_view_month_outlined),
          ),
          validator: _loanTermMonths,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _loanPayment,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.l10n.accountFormMonthlyPayment,
            prefixIcon: Icon(Icons.payments_outlined),
          ),
          validator: _optionalAmount,
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
            decoration: InputDecoration(
              labelText: context.l10n.accountFormNextDueDate,
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(_dateLabel(_loanDue)),
          ),
        ),
      ],
    );
  }

  Widget _assetFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AssetClass>(
          initialValue: _assetClass,
          decoration: InputDecoration(
            labelText: context.l10n.accountFormAssetClass,
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: AssetClass.values
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c.label(context.l10n)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _assetClass = v);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _assetPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.l10n.accountFormPurchasePrice,
            prefixIcon: Icon(Icons.payments_outlined),
          ),
          validator: _optionalAmount,
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
            decoration: InputDecoration(
              labelText: context.l10n.accountFormPurchaseDate,
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(_dateLabel(_assetDate)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _assetNotes,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.l10n.accountsDetailNotes,
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
          decoration: InputDecoration(
            labelText: context.l10n.accountsDetailType,
            hintText: context.l10n.accountFormLiabilityTypeHint,
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _liabApr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.l10n.accountFormInterestRate,
            prefixIcon: Icon(Icons.percent_outlined),
          ),
          validator: _optionalRate,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _liabNotes,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.l10n.accountsDetailNotes,
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
          decoration: InputDecoration(
            labelText: context.l10n.accountsDetailNotes,
            hintText: context.l10n.accountFormOtherNotesHint,
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 8),
        AikoInlineNotice(
          title: context.l10n.accountFormNoExtraDetails,
          message: context.l10n.accountFormNoExtraDetailsMessage,
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
                  context.l10n.accountFormGoalDetails,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.accountFormGoalDetailsMessage,
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
                      labelText: context.l10n.accountFormTargetAmount,
                      prefixText: '$_currency ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: _goalTargetAmount,
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
                      labelText: context.l10n.accountFormSavedSoFar,
                      prefixText: '$_currency ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: _goalSavedAmount,
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
                labelText: context.l10n.accountFormTargetDate,
                hintText: context.l10n.accountFormTargetDateHint,
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (_) =>
                  _goalTarget.text.trim().isNotEmpty && _goalDate == null
                  ? context.l10n.accountFormTargetDateRequired
                  : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<GoalPriority>(
              segments: [
                for (final priority in [
                  GoalPriority.low,
                  GoalPriority.medium,
                  GoalPriority.high,
                ])
                  ButtonSegment(
                    value: priority,
                    label: Text(priority.label(context.l10n)),
                  ),
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

    return AikoDiscardChangesGuard(
      hasUnsavedChanges: _hasUnsavedChanges,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditing
                ? context.l10n.accountsEditTooltip
                : context.l10n.accountsAddAccount,
          ),
        ),
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
                  currencies: [
                    for (final code in _currencies)
                      (
                        code: code,
                        name: currencyDisplayName(code, context.l10n),
                      ),
                  ],
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
              label: Text(
                isEditing
                    ? context.l10n.txSaveChanges
                    : context.l10n.accountFormCreate,
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
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
    required this.rangeError,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  /// Shown inline when the value is outside 1-31.
  final String rangeError;

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
      validator: (v) => v == null || v < 1 || v > 31 ? rangeError : null,
    );
  }
}
