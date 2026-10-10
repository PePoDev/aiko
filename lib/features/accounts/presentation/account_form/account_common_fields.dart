import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/domain_labels.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/account_type.dart';

class AccountCommonFields extends StatelessWidget {
  const AccountCommonFields({
    super.key,
    required this.initialType,
    required this.initialCurrency,
    required this.initialIncludeInNetWorth,
    required this.initialIsActive,
    required this.currencies,
    required this.nameController,
    required this.balanceController,
    required this.institutionController,
    required this.onChanged,
  });

  final AccountType initialType;
  final String initialCurrency;
  final bool initialIncludeInNetWorth;
  final bool initialIsActive;
  final List<({String code, String name})> currencies;
  final TextEditingController nameController;
  final TextEditingController balanceController;
  final TextEditingController institutionController;
  final void Function({
    String? name,
    AccountType? type,
    String? currency,
    String? balance,
    String? institution,
    bool? includeInNetWorth,
    bool? isActive,
  })
  onChanged;

  @override
  Widget build(BuildContext context) {
    final institutionDisabled =
        initialType == AccountType.cash || initialType == AccountType.liability;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.l10n.accountFormName,
            hintText: context.l10n.accountFormNameHint,
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          onChanged: (v) => onChanged(name: v),
          validator: (v) => v == null || v.trim().isEmpty
              ? context.l10n.accountFormNameRequired
              : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AccountType>(
          initialValue: initialType,
          decoration: InputDecoration(
            labelText: context.l10n.accountFormType,
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
          items: AccountType.values
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.label(context.l10n)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(type: v);
          },
        ),
        const SizedBox(height: 12),
        if (initialType != AccountType.cash) ...[
          TextFormField(
            controller: institutionController,
            enabled: !institutionDisabled,
            decoration: InputDecoration(
              labelText: context.l10n.accountFormInstitution,
              hintText: institutionDisabled
                  ? context.l10n.accountFormInstitutionNotUsed
                  : context.l10n.accountFormInstitutionHint,
              prefixIcon: const Icon(Icons.corporate_fare_outlined),
            ),
            onChanged: (v) => onChanged(institution: v),
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          initialValue: initialCurrency,
          decoration: InputDecoration(
            labelText: context.l10n.txCurrency,
            prefixIcon: Icon(Icons.payments_outlined),
          ),
          items: currencies
              .map(
                (c) => DropdownMenuItem(
                  value: c.code,
                  child: Text('${c.code} - ${c.name}'),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(currency: v);
          },
        ),
        // Goals record their balance as "Saved so far" in the goal details.
        if (initialType != AccountType.goal) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: balanceController,
            decoration: InputDecoration(
              labelText: context.l10n.accountFormCurrentBalance,
              hintText: '0.00',
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    _currencySymbol(initialCurrency),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
            ),
            // Signed so iOS offers a minus key for overdrawn balances.
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            onChanged: (v) => onChanged(balance: v),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return context.l10n.accountFormBalanceRequired;
              if (Decimal.tryParse(t) == null) {
                return context.l10n.accountFormEnterValidNumber;
              }
              return null;
            },
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.accountFormIncludeInNetWorth),
          value: initialIncludeInNetWorth,
          onChanged: (v) => onChanged(includeInNetWorth: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.accountFormActive),
          value: initialIsActive,
          onChanged: (v) => onChanged(isActive: v),
        ),
      ],
    );
  }

  String _currencySymbol(String currency) {
    return switch (currency.toUpperCase()) {
      'THB' => '฿',
      'USD' => r'$',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' || 'CNY' => '¥',
      'KRW' => '₩',
      'INR' => '₹',
      _ => currency.toUpperCase(),
    };
  }
}
