import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final _pageController = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      const _OnboardingStep(
        title: 'Meet Aiko',
        message: 'Aiko helps you track spending, build wealth, and stay calm.',
        icon: Icons.auto_awesome,
      ),
      const _OnboardingStep(
        title: 'Choose your focus',
        message: 'Track spending, save money, pay debt, or build wealth.',
        icon: Icons.flag_outlined,
      ),
      const _OnboardingStep(
        title: 'Set money basics',
        message: 'Base currency: USD. Country: United States.',
        icon: Icons.public,
      ),
      const _OnboardingStep(
        title: 'Add first account',
        message: 'Start with Cash Wallet and add more accounts later.',
        icon: Icons.account_balance_wallet_outlined,
      ),
      const _OnboardingStep(
        title: 'Protect Aiko',
        message: 'Enable PIN or biometrics before viewing financial data.',
        icon: Icons.lock_outline,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Aiko')),
      body: PageView(
        controller: _pageController,
        onPageChanged: (value) => setState(() => _page = value),
        children: steps,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_page + 1) / steps.length,
                color: AikoColors.premiumPurple,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                if (_page == steps.length - 1) {
                  context.push('/auth');
                } else {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              },
              child: Text(
                _page == steps.length - 1 ? 'Continue to sign in' : 'Continue',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: FinanceCard(
          title: title,
          icon: icon,
          accentColor: AikoColors.premiumPurple,
          prominent: true,
          child: Text(message),
        ),
      ),
    );
  }
}
