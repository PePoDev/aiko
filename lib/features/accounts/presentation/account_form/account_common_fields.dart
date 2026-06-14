import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../domain/account_type.dart';

typedef CommonFieldsCallbacks =
    void Function({
      String? name,
      AccountType? type,
      String? currency,
      String? balance,
      String? institution,
      bool? includeInNetWorth,
      bool? isActive,
    });

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
    required this.currencyController,
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
  final TextEditingController currencyController;
  final CommonFieldsCallbacks onChanged;

  @override
  Widget build(BuildContext context) {
    final institutionDisabled =
        initialType == AccountType.cash || initialType == AccountType.liability;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Account Name',
            hintText: 'e.g. Daily Expenses, Savings Wallet',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          onChanged: (v) => onChanged(name: v),
          validator: (v) => v == null || v.trim().isEmpty
              ? 'Please enter a name for the account.'
              : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AccountType>(
          initialValue: initialType,
          decoration: const InputDecoration(
            labelText: 'Account Type',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
          items: AccountType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(_label(t))))
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
              labelText: 'Institution Name',
              hintText: institutionDisabled
                  ? 'Not used for this account type.'
                  : 'e.g. Chase, PayPal, Coinbase',
              prefixIcon: const Icon(Icons.corporate_fare_outlined),
            ),
            onChanged: (v) => onChanged(institution: v),
          ),
          const SizedBox(height: 12),
        ],
        DropdownMenu<String>(
          controller: currencyController,
          initialSelection: initialCurrency,
          enableFilter: true,
          enableSearch: true,
          requestFocusOnTap: true,
          expandedInsets: EdgeInsets.zero,
          leadingIcon: const Icon(Icons.payments_outlined),
          label: const Text('Currency'),
          dropdownMenuEntries: currencies
              .map(
                (c) => DropdownMenuEntry<String>(
                  value: c.code,
                  label: '${c.code} - ${c.name}',
                ),
              )
              .toList(growable: false),
          onSelected: (value) {
            if (value != null) onChanged(currency: value);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: balanceController,
          decoration: InputDecoration(
            labelText: 'Current Balance',
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => onChanged(balance: v),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'Please enter a balance.';
            if (Decimal.tryParse(t) == null) return 'Enter a valid number.';
            return null;
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include in net worth'),
          value: initialIncludeInNetWorth,
          onChanged: (v) => onChanged(includeInNetWorth: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active account'),
          value: initialIsActive,
          onChanged: (v) => onChanged(isActive: v),
        ),
      ],
    );
  }

  String _label(AccountType t) {
    final n = t.name;
    final buf = StringBuffer();
    for (var i = 0; i < n.length; i++) {
      final c = n[i];
      if (i > 0 && c.toUpperCase() == c) buf.write(' ');
      buf.write(i == 0 ? c.toUpperCase() : c);
    }
    return buf.toString();
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
