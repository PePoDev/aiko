import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import 'onboarding_account_form.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: const [
          FinanceCard(
            title: 'Account workspace',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: AikoColors.analyticsTeal,
            child: Text(
              'Add cash, bank, e-wallet, credit, loan, investment, and asset accounts.',
            ),
          ),
          SizedBox(height: 16),
          FinanceCard(
            title: 'Add account',
            icon: Icons.add_card_outlined,
            child: OnboardingAccountForm(),
          ),
        ],
      ),
    );
  }
}
