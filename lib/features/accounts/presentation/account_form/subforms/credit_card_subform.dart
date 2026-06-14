import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/money/money.dart';
import '../../../../../shared/widgets/aiko_data_widgets.dart';
import '../../../../../theme/aiko_colors.dart';
import '../../../domain/account.dart';
import '../../../domain/account_details.dart';
import '../../../domain/account_validation_messages.dart';
import 'account_subform.dart';

export '../../../domain/account_details.dart' show RewardsType;

class CreditCardSubform extends AccountSubform {
  const CreditCardSubform({
    super.key,
    required this.initial,
    required this.availableCards,
    required this.onChanged,
  });

  final CreditCardDetails initial;
  final List<Account> availableCards;
  final ValueChanged<CreditCardDetails> onChanged;

  @override
  ConsumerState<CreditCardSubform> createState() => CreditCardSubformState();
}

class CreditCardSubformState extends AccountSubformState<CreditCardSubform> {
  late int _statementDay;
  late int _dueDay;
  late final TextEditingController _limit;
  late final TextEditingController _apr;
  late final TextEditingController _annualFee;
  late final TextEditingController _minPayment;
  RewardsType? _rewardsType;
  late bool _sharesLimit;
  String? _sharedLimitAccountId;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _statementDay = widget.initial.statementDay;
    _dueDay = widget.initial.dueDay;
    _limit = TextEditingController(
      text: widget.initial.creditLimit?.amount.toString() ?? '',
    );
    _apr = TextEditingController(
      text: widget.initial.aprPercent?.toString() ?? '',
    );
    _annualFee = TextEditingController(
      text: widget.initial.annualFee?.amount.toString() ?? '',
    );
    _minPayment = TextEditingController(
      text: widget.initial.minimumPayment?.amount.toString() ?? '',
    );
    _rewardsType = widget.initial.rewardsType;
    _sharesLimit = widget.initial.sharesLimit;
    _sharedLimitAccountId = widget.initial.sharedLimitAccountId;
    for (final c in [_limit, _apr, _annualFee, _minPayment]) {
      c.addListener(_emit);
    }
    if (_sharesLimit && _sharedLimitAccountId != null) {
      final exists = widget.availableCards.any(
        (a) => a.id == _sharedLimitAccountId,
      );
      if (!exists) {
        _sharesLimit = false;
        _sharedLimitAccountId = null;
        _validationError = AccountValidationMessages.sharedLimitCardUnavailable;
      }
    }
  }

  String get _accountCurrency {
    return widget.initial.creditLimit?.currency ??
        widget.initial.annualFee?.currency ??
        widget.initial.minimumPayment?.currency ??
        'USD';
  }

  Money? _parseMoney(String raw, String currency) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    try {
      return Money.parse(t, currency);
    } catch (_) {
      return null;
    }
  }

  void _emit() {
    setState(() => _validationError = null);
    widget.onChanged(
      CreditCardDetails(
        creditLimit: _sharesLimit
            ? null
            : _parseMoney(_limit.text, _accountCurrency),
        statementDay: _statementDay,
        dueDay: _dueDay,
        aprPercent: double.tryParse(_apr.text.trim()),
        rewardsType: _rewardsType,
        annualFee: _parseMoney(_annualFee.text, _accountCurrency),
        minimumPayment: _parseMoney(_minPayment.text, _accountCurrency),
        sharesLimit: _sharesLimit,
        sharedLimitAccountId: _sharesLimit ? _sharedLimitAccountId : null,
      ),
    );
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! CreditCardDetails) return;
    setState(() {
      _statementDay = initial.statementDay;
      _dueDay = initial.dueDay;
      _limit.text = initial.creditLimit?.amount.toString() ?? '';
      _apr.text = initial.aprPercent?.toString() ?? '';
      _annualFee.text = initial.annualFee?.amount.toString() ?? '';
      _minPayment.text = initial.minimumPayment?.amount.toString() ?? '';
      _rewardsType = initial.rewardsType;
      _sharesLimit = initial.sharesLimit;
      _sharedLimitAccountId = initial.sharedLimitAccountId;
      _validationError = null;
    });
  }

  @override
  AccountDetails getDetails() => CreditCardDetails(
    creditLimit: _sharesLimit
        ? null
        : _parseMoney(_limit.text, _accountCurrency),
    statementDay: _statementDay,
    dueDay: _dueDay,
    aprPercent: double.tryParse(_apr.text.trim()),
    rewardsType: _rewardsType,
    annualFee: _parseMoney(_annualFee.text, _accountCurrency),
    minimumPayment: _parseMoney(_minPayment.text, _accountCurrency),
    sharesLimit: _sharesLimit,
    sharedLimitAccountId: _sharesLimit ? _sharedLimitAccountId : null,
  );

  @override
  String? validate() {
    if (_statementDay < 1 || _statementDay > 31) {
      return AccountValidationMessages.statementDayRange;
    }
    if (_dueDay < 1 || _dueDay > 31) {
      return AccountValidationMessages.dueDayRange;
    }
    final apr = double.tryParse(_apr.text.trim());
    if (_apr.text.trim().isNotEmpty && (apr == null || apr < 0)) {
      return AccountValidationMessages.aprNegative;
    }
    if (_sharesLimit) {
      if (_sharedLimitAccountId == null) {
        return AccountValidationMessages.sharedLimitReferenceRequired;
      }
    } else if (_limit.text.trim().isEmpty) {
      return AccountValidationMessages.creditLimitRequired;
    }
    return null;
  }

  @override
  void dispose() {
    _limit.dispose();
    _apr.dispose();
    _annualFee.dispose();
    _minPayment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_validationError != null) ...[
          AikoInlineNotice(
            title: 'Heads up',
            message: _validationError!,
            icon: Icons.warning_amber_outlined,
            accentColor: AikoColors.warningOrange,
          ),
          const SizedBox(height: 12),
        ],
        _DayPickerField(
          label: 'Statement day (1-31)',
          value: _statementDay,
          onChanged: (v) {
            setState(() => _statementDay = v);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        _DayPickerField(
          label: 'Due day (1-31)',
          value: _dueDay,
          onChanged: (v) {
            setState(() => _dueDay = v);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share limit with another card'),
          value: _sharesLimit,
          onChanged: (v) {
            setState(() {
              _sharesLimit = v;
              if (!v) _sharedLimitAccountId = null;
            });
            _emit();
          },
        ),
        if (_sharesLimit) ...[
          DropdownButtonFormField<String>(
            initialValue: _sharedLimitAccountId,
            decoration: const InputDecoration(
              labelText: 'Card to share with',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
            items: widget.availableCards
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (v) {
              setState(() => _sharedLimitAccountId = v);
              _emit();
            },
          ),
          const SizedBox(height: 12),
        ] else ...[
          TextField(
            controller: _limit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Credit limit',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _apr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'APR (%)',
            prefixIcon: Icon(Icons.percent_outlined),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<RewardsType?>(
          initialValue: _rewardsType,
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
          onChanged: (v) {
            setState(() => _rewardsType = v);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _annualFee,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Annual fee (optional)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _minPayment,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Minimum payment (optional)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
      ],
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
