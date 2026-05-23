import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/account.dart';

class OnboardingAccountForm extends ConsumerStatefulWidget {
  const OnboardingAccountForm({super.key});

  @override
  ConsumerState<OnboardingAccountForm> createState() => _OnboardingAccountFormState();
}

class _OnboardingAccountFormState extends ConsumerState<OnboardingAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _institutionController = TextEditingController();

  AccountType _selectedType = AccountType.cash;
  var _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final name = _nameController.text.trim();
      final balanceVal = Decimal.parse(_balanceController.text.trim());
      final institution = _institutionController.text.trim();

      final money = Money(amount: balanceVal, currency: 'USD');

      final account = Account(
        id: const Uuid().v4(),
        userId: '', // Populated by repository
        name: name,
        type: _selectedType,
        openingBalance: money,
        currentBalance: money,
        institution: institution.isEmpty ? null : institution,
      );

      await ref.read(accountsProvider.notifier).addAccount(account);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Account "$name" successfully created manually!'),
            ],
          ),
          backgroundColor: AikoColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reset form
      _nameController.clear();
      _balanceController.clear();
      _institutionController.clear();
      setState(() {
        _selectedType = AccountType.cash;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding account: $e'),
          backgroundColor: AikoColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showInstitution = _selectedType == AccountType.bank ||
        _selectedType == AccountType.creditCard ||
        _selectedType == AccountType.investment ||
        _selectedType == AccountType.eWallet;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Account Name',
              hintText: 'e.g. Daily Expenses, Savings Wallet',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name for the account.';
              }
              return null;
            },
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AccountType>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Account Type',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            items: AccountType.values.map((type) {
              final label = type.name[0].toUpperCase() + type.name.substring(1);
              return DropdownMenuItem(
                value: type,
                child: Text(label),
              );
            }).toList(),
            onChanged: _isSubmitting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                      });
                    }
                  },
          ),
          if (showInstitution) ...[
            const SizedBox(height: 16),
            AnimatedOpacity(
              opacity: showInstitution ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: TextFormField(
                controller: _institutionController,
                decoration: const InputDecoration(
                  labelText: 'Institution Name',
                  hintText: 'e.g. Chase, PayPal, Coinbase',
                  prefixIcon: Icon(Icons.corporate_fare_outlined),
                ),
                enabled: !_isSubmitting,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _balanceController,
            decoration: const InputDecoration(
              labelText: 'Opening Balance',
              prefixText: r'$ ',
              hintText: '0.00',
              prefixIcon: Icon(Icons.attach_money_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter an opening balance.';
              }
              if (Decimal.tryParse(value.trim()) == null) {
                return 'Please enter a valid decimal number.';
              }
              return null;
            },
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 24),
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
                : const Icon(Icons.add_task),
            label: Text(_isSubmitting ? 'Creating Account...' : 'Create Account'),
            style: FilledButton.styleFrom(
              backgroundColor: AikoColors.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
