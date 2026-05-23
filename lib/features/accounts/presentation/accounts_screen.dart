import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/account.dart';
import '../application/bank_feed_service.dart';
import 'onboarding_account_form.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final _bankFeedService = const BankFeedService();
  var _isLinking = false;

  void _showPlaidLinkDialog() {
    final institutionController = TextEditingController(text: 'Chase Bank');
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Link Bank via Plaid',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AikoColors.premiumPurple,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Securely link Chase, BofA, or other institutions in under 30 seconds.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (_isLinking) ...[
                    const SizedBox(height: 40),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 20),
                    const Text(
                      'Connecting to institution APIs and running multi-device sync handshake...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 40),
                  ] else ...[
                    TextField(
                      controller: institutionController,
                      decoration: const InputDecoration(
                        labelText: 'Institution Name',
                        hintText: 'e.g. Chase Bank, Bank of America',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Online ID / Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      onSubmitted: (_) {
                        // Submit link
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () async {
                        final inst = institutionController.text.trim();
                        final user = usernameController.text.trim();
                        final pass = passwordController.text;

                        if (inst.isEmpty || user.isEmpty || pass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill out all credentials.'),
                              backgroundColor: AikoColors.dangerRed,
                            ),
                          );
                          return;
                        }

                        setModalState(() => _isLinking = true);
                        try {
                          final accounts = await _bankFeedService.linkBankFeed(
                            institution: inst,
                            username: user,
                            password: pass,
                          );

                          for (final acc in accounts) {
                            await ref.read(accountsProvider.notifier).addAccount(acc);
                          }

                          if (!mounted) return;
                          Navigator.pop(context); // Close sheet

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text('Successfully linked ${accounts.length} bank feed accounts!'),
                                ],
                              ),
                              backgroundColor: AikoColors.successGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('API Integration Error: $e'),
                              backgroundColor: AikoColors.dangerRed,
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setModalState(() => _isLinking = false);
                          }
                        }
                      },
                      icon: const Icon(Icons.link),
                      label: const Text('Authorize Secure Link'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AikoColors.premiumPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _iconForAccount(AccountType type) {
    return switch (type) {
      AccountType.cash => Icons.wallet_outlined,
      AccountType.bank => Icons.account_balance_outlined,
      AccountType.creditCard => Icons.credit_card_outlined,
      AccountType.investment => Icons.trending_up_outlined,
      AccountType.loan => Icons.handshake_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };
  }

  Color _colorForAccount(AccountType type) {
    return switch (type) {
      AccountType.cash => AikoColors.successGreen,
      AccountType.bank => AikoColors.deepBlue,
      AccountType.creditCard => AikoColors.warningOrange,
      AccountType.investment => AikoColors.analyticsTeal,
      _ => AikoColors.primaryBlue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: AikoColors.appBackgroundLight,
      appBar: AppBar(title: const Text('Accounts & Bank Feeds')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          // Premium bank link prompt card
          FinanceCard(
            title: 'Live Bank Connection',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: AikoColors.premiumPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Automate your money tracking by connecting to Chase, Bank of America, or credit cards in real-time.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _showPlaidLinkDialog,
                    icon: const Icon(Icons.link),
                    label: const Text('Link Bank via Plaid Feed'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AikoColors.premiumPurple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dynamic accounts list
          FinanceCard(
            title: 'Active Accounts Workspace',
            icon: Icons.account_balance_outlined,
            accentColor: AikoColors.analyticsTeal,
            child: accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No accounts configured. Use the link or form below to get started!',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final acc in accounts) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _colorForAccount(acc.type).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForAccount(acc.type),
                            color: _colorForAccount(acc.type),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          acc.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          acc.institution ?? (acc.type == AccountType.cash ? 'Cash wallet' : 'Manual Entry'),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          acc.currentBalance.format(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (acc != accounts.last) const Divider(),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Error loading accounts: $err', style: const TextStyle(color: AikoColors.dangerRed)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Manual Add Account
          const FinanceCard(
            title: 'Add Account Manually',
            icon: Icons.add_card_outlined,
            child: OnboardingAccountForm(),
          ),
        ],
      ),
    );
  }
}
