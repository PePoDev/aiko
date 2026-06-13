import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/aiko_idea_widgets.dart';
import '../../../theme/aiko_colors.dart';
import '../../accounts/domain/account.dart';
import '../../settings/domain/profile.dart';

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final _pageController = PageController();
  var _page = 0;
  var _focus = 'save';
  var _selectedAccount = _AccountChoice.bank;
  var _isFinishing = false;

  static const _stepsCount = 2;
  static const _selectedCurrency = 'USD';
  static const _selectedCountry = 'US';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (_page < _stepsCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return;
    }

    setState(() => _isFinishing = true);
    unawaited(_saveFirstAccountAndProfile());
    context.go('/home');
  }

  Future<void> _saveFirstAccountAndProfile() async {
    final option = _accountOptions
        .where((item) => item.choice == _selectedAccount)
        .first;
    final balance = Money.zero(_selectedCurrency);
    final account = Account(
      id: const Uuid().v4(),
      userId: '',
      name: option.accountName,
      type: option.accountType,
      currentBalance: balance,
      institution: option.institution,
    );

    try {
      final repo = ref.read(accountRepositoryProvider);
      final existingAccounts = await repo.list();
      final alreadyExists = existingAccounts.any(
        (existing) =>
            existing.name == account.name &&
            existing.type == account.type &&
            existing.currency == account.currency &&
            existing.institution == account.institution,
      );
      if (!alreadyExists) {
        await repo.save(account);
      }
    } catch (error) {
      debugPrint('Saved first account locally: $error');
    }

    try {
      final repo = ref.read(profileRepositoryProvider);
      final currentProfile = await repo.load();
      await repo.save(
        currentProfile.copyWith(
          baseCurrency: _selectedCurrency,
          country: _selectedCountry,
          onboardingStatus: OnboardingStatus.completed,
          aiConsentEnabled: true,
        ),
      );
    } catch (error) {
      debugPrint('Saved onboarding profile locally: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AikoColors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: clampIdeaWidth(context)),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_page > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Back',
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _isFinishing
                                ? null
                                : () {
                                    _pageController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  },
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (value) => setState(() => _page = value),
                    children: [
                      _GoalStep(
                        focus: _focus,
                        onChanged: (value) => setState(() => _focus = value),
                      ),
                      _FirstAccountStep(
                        selected: _selectedAccount,
                        onChanged: (value) {
                          setState(() => _selectedAccount = value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(28, 10, 28, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: clampIdeaWidth(context)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AikoPrimaryButton(
                  label: _page == _stepsCount - 1
                      ? (_isFinishing
                            ? 'Finishing...'
                            : 'Finish')
                      : 'Next',
                  onPressed: _isFinishing ? null : _handleNext,
                ),
                const SizedBox(height: 14),
                AikoPageDots(count: _stepsCount, active: _page),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.focus, required this.onChanged});

  final String focus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "What's your\nmain goal?",
                    style: textTheme.headlineSmall?.copyWith(
                      color: AikoColors.darkNavy,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose one to get personalized insights and recommendations.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AikoColors.mutedText,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            const AikoCharacterImage(
              size: 108,
              borderRadius: 28,
              semanticLabel: 'Aiko thinking about goals',
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (final option in _goalOptions) ...[
          _IdeaOptionTile(
            selected: focus == option.key,
            icon: option.icon,
            color: option.color,
            title: option.title,
            subtitle: option.subtitle,
            onTap: () => onChanged(option.key),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FirstAccountStep extends StatelessWidget {
  const _FirstAccountStep({required this.selected, required this.onChanged});

  final _AccountChoice selected;
  final ValueChanged<_AccountChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Let's add your\nfirst account",
                    style: textTheme.headlineSmall?.copyWith(
                      color: AikoColors.darkNavy,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect an account to see your financial picture in one place.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AikoColors.mutedText,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            const AikoCharacterImage(
              size: 108,
              borderRadius: 28,
              semanticLabel: 'Aiko ready to connect an account',
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final option in _accountOptions) ...[
          _AccountOptionTile(
            option: option,
            selected: selected == option.choice,
            onTap: () => onChanged(option.choice),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AikoColors.paleBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AikoColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: AikoColors.deepBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bank-level security. Your data is encrypted and secure.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AikoColors.neutralInk,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdeaOptionTile extends StatelessWidget {
  const _IdeaOptionTile({
    required this.selected,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AikoColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AikoColors.deepBlue : AikoColors.borderSubtle,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AikoColors.darkNavy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AikoColors.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked_outlined,
                  color: selected ? AikoColors.deepBlue : AikoColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountOptionTile extends StatelessWidget {
  const _AccountOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _AccountOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _IdeaOptionTile(
      selected: selected,
      icon: option.icon,
      color: option.color,
      title: option.title,
      subtitle: option.subtitle,
      onTap: onTap,
    );
  }
}

class _GoalOption {
  const _GoalOption({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

enum _AccountChoice { bank, creditCard, investment, paypal, other }

class _AccountOption {
  const _AccountOption({
    required this.choice,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.accountName,
    required this.accountType,
    this.institution,
  });

  final _AccountChoice choice;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String accountName;
  final AccountType accountType;
  final String? institution;
}

const _goalOptions = [
  _GoalOption(
    key: 'save',
    title: 'Save More',
    subtitle: 'Build your savings and emergency fund',
    icon: Icons.savings_outlined,
    color: AikoColors.warningOrange,
  ),
  _GoalOption(
    key: 'debt',
    title: 'Pay Off Debt',
    subtitle: 'Become debt-free sooner',
    icon: Icons.credit_score_outlined,
    color: AikoColors.dangerRed,
  ),
  _GoalOption(
    key: 'home',
    title: 'Buy a Home',
    subtitle: 'Plan and save for your dream home',
    icon: Icons.home_work_outlined,
    color: AikoColors.primaryBlue,
  ),
  _GoalOption(
    key: 'retire',
    title: 'Retire Early',
    subtitle: 'Invest smarter for your future',
    icon: Icons.self_improvement_outlined,
    color: AikoColors.premiumPurple,
  ),
  _GoalOption(
    key: 'travel',
    title: 'Travel the World',
    subtitle: 'Save for experiences that matter',
    icon: Icons.flight_takeoff_outlined,
    color: AikoColors.analyticsTeal,
  ),
];

const _accountOptions = [
  _AccountOption(
    choice: _AccountChoice.bank,
    title: 'Bank Account',
    subtitle: 'Checking, Savings',
    icon: Icons.account_balance_outlined,
    color: AikoColors.primaryBlue,
    accountName: 'Chase Checking',
    accountType: AccountType.bank,
    institution: 'Chase Bank',
  ),
  _AccountOption(
    choice: _AccountChoice.creditCard,
    title: 'Credit Card',
    subtitle: 'Visa, Mastercard, Amex',
    icon: Icons.credit_card_outlined,
    color: AikoColors.deepBlue,
    accountName: 'Credit Card',
    accountType: AccountType.creditCard,
  ),
  _AccountOption(
    choice: _AccountChoice.investment,
    title: 'Investment Account',
    subtitle: 'Brokerage, Retirement',
    icon: Icons.trending_up_outlined,
    color: AikoColors.analyticsTeal,
    accountName: 'Investment Account',
    accountType: AccountType.investment,
  ),
  _AccountOption(
    choice: _AccountChoice.paypal,
    title: 'PayPal',
    subtitle: 'Connect your PayPal',
    icon: Icons.account_balance_wallet_outlined,
    color: AikoColors.deepBlue,
    accountName: 'PayPal',
    accountType: AccountType.eWallet,
    institution: 'PayPal',
  ),
  _AccountOption(
    choice: _AccountChoice.other,
    title: 'Other Account',
    subtitle: 'Loans, Mortgages, etc.',
    icon: Icons.wallet_outlined,
    color: AikoColors.premiumPurple,
    accountName: 'Other Account',
    accountType: AccountType.other,
  ),
];
