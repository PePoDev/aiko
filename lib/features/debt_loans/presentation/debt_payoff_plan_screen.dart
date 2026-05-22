import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/money/money.dart';
import '../../../theme/aiko_colors.dart';
import '../../../shared/widgets/finance_card.dart';
import '../domain/debt_loan_plan.dart';
import '../application/debt_payoff_service.dart';

// Notifier to manage active list of debts locally
class DebtsNotifier extends Notifier<List<DebtLoanPlan>> {
  @override
  List<DebtLoanPlan> build() {
    return [
      DebtLoanPlan(
        name: 'Student Loan',
        balance: Money.parse('18500.00', 'USD'),
        interestRatePercent: 4.5,
        monthlyPayment: Money.parse('220.00', 'USD'),
      ),
      DebtLoanPlan(
        name: 'Auto Loan',
        balance: Money.parse('9200.00', 'USD'),
        interestRatePercent: 6.8,
        monthlyPayment: Money.parse('185.00', 'USD'),
      ),
      DebtLoanPlan(
        name: 'Credit Card Debt',
        balance: Money.parse('4200.00', 'USD'),
        interestRatePercent: 18.9,
        monthlyPayment: Money.parse('130.00', 'USD'),
      ),
    ];
  }

  void addDebt(DebtLoanPlan debt) {
    state = [...state, debt];
  }

  void deleteDebt(String name) {
    state = state.where((d) => d.name != name).toList();
  }
}

final debtsProvider = NotifierProvider<DebtsNotifier, List<DebtLoanPlan>>(() {
  return DebtsNotifier();
});

// Manage selected payoff strategy
class DebtStrategyNotifier extends Notifier<DebtPayoffStrategy> {
  @override
  DebtPayoffStrategy build() {
    return DebtPayoffStrategy.avalanche;
  }

  void setStrategy(DebtPayoffStrategy strategy) {
    state = strategy;
  }
}

final debtStrategyProvider = NotifierProvider<DebtStrategyNotifier, DebtPayoffStrategy>(() {
  return DebtStrategyNotifier();
});

class DebtPayoffPlanScreen extends ConsumerStatefulWidget {
  const DebtPayoffPlanScreen({super.key});

  @override
  ConsumerState<DebtPayoffPlanScreen> createState() => _DebtPayoffPlanScreenState();
}

class _DebtPayoffPlanScreenState extends ConsumerState<DebtPayoffPlanScreen> {
  final _service = const DebtPayoffService();
  double _extraMonthlyPayment = 100.0;

  // Input controllers for Add Debt
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _aprController = TextEditingController();
  final _minPayController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _aprController.dispose();
    _minPayController.dispose();
    super.dispose();
  }

  void _showAddDebtDialog() {
    _nameController.clear();
    _balanceController.clear();
    _aprController.clear();
    _minPayController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AikoColors.white,
        title: const Text(
          'Add Debt or Loan',
          style: TextStyle(color: AikoColors.darkNavy, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Debt Name (e.g. Student Loan)'),
              ),
              TextField(
                controller: _balanceController,
                decoration: const InputDecoration(labelText: 'Current Balance (\$)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _aprController,
                decoration: const InputDecoration(labelText: 'Interest Rate % (APR)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _minPayController,
                decoration: const InputDecoration(labelText: 'Minimum Monthly Payment (\$)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AikoColors.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AikoColors.primaryBlue),
            onPressed: () {
              if (_nameController.text.isEmpty) return;
              final balance = double.tryParse(_balanceController.text) ?? 0.0;
              final apr = double.tryParse(_aprController.text) ?? 5.0;
              final minPay = double.tryParse(_minPayController.text) ?? 50.0;

              final newDebt = DebtLoanPlan(
                name: _nameController.text,
                balance: Money.parse(balance.toStringAsFixed(2), 'USD'),
                interestRatePercent: apr,
                monthlyPayment: Money.parse(minPay.toStringAsFixed(2), 'USD'),
              );

              ref.read(debtsProvider.notifier).addDebt(newDebt);
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    final strategy = ref.watch(debtStrategyProvider);

    // Baseline calculation (minimum payments, no extra contribution)
    final baseline = _service.simulatePayoff(
      debts: debts,
      strategy: strategy,
      extraPayment: 0.0,
    );

    // Accelerated calculation
    final accelerated = _service.simulatePayoff(
      debts: debts,
      strategy: strategy,
      extraPayment: _extraMonthlyPayment,
    );

    final int baseMonths = baseline['months'];
    final double baseInterest = baseline['interest'];
    
    final int accMonths = accelerated['months'];
    final double accInterest = accelerated['interest'];
    
    final double savedInterest = max(0.0, baseInterest - accInterest);
    final int savedMonths = max(0, baseMonths - accMonths);

    // Sort active debts using the selected strategy
    final rankedDebts = _service.rank(debts, strategy);

    double totalBalance = 0.0;
    double totalMins = 0.0;
    double highestApr = 0.0;

    for (final d in debts) {
      totalBalance += d.balance.amount.toDouble();
      totalMins += d.monthlyPayment.amount.toDouble();
      if (d.interestRatePercent > highestApr) {
        highestApr = d.interestRatePercent;
      }
    }

    // Aiko custom character expressions and tips
    String aikoExpression;
    String aikoSpeech;
    Color aikoBubbleBorder;

    if (debts.isEmpty) {
      aikoExpression = 'assets/images/aiko/aiko_happy.png';
      aikoSpeech = "Aiko says: Amazing! You have no recorded debts. You are completely free to invest and grow your assets! Keep it up!";
      aikoBubbleBorder = AikoColors.successGreen;
    } else if (highestApr > 15.0) {
      aikoExpression = 'assets/images/aiko/aiko_warning.png';
      aikoSpeech = "Aiko warning: You have high-interest debt at ${highestApr.toStringAsFixed(1)}% APR! I strongly recommend the Avalanche strategy to wipe out high APRs first.";
      aikoBubbleBorder = AikoColors.dangerRed;
    } else {
      aikoExpression = 'assets/images/aiko/aiko_thinking.png';
      aikoSpeech = "Aiko guide: Snowball builds psychological momentum by clearing small debts first. Avalanche saves you the most money. Let's run the numbers!";
      aikoBubbleBorder = AikoColors.primaryBlue;
    }

    return Scaffold(
      backgroundColor: AikoColors.appBackgroundLight,
      appBar: AppBar(
        title: const Text('Debt Snowball & Avalanche'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddDebtDialog,
            tooltip: 'Add Debt or Loan',
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          // Aiko advice banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AikoColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: aikoBubbleBorder.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AikoColors.border.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Image.asset(
                  aikoExpression,
                  width: 72,
                  height: 72,
                  errorBuilder: (_, __, ___) => const Icon(Icons.face, size: 72, color: AikoColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    aikoSpeech,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AikoColors.darkNavy,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Total Debt Panel
          FinanceCard(
            title: 'Total Debt Balance',
            icon: Icons.money_off_csred_outlined,
            accentColor: AikoColors.dangerRed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${totalBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AikoColors.dangerRed,
                      ),
                    ),
                    Text(
                      'Mins: \$${totalMins.toStringAsFixed(0)}/mo',
                      style: const TextStyle(color: AikoColors.mutedText, fontWeight: FontWeight.w600),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'This includes student loans, auto loans, personal loans, and credit card balances. Leverage strategy-based payoffs to wipe this out faster.',
                  style: TextStyle(fontSize: 11, color: AikoColors.mutedText, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payoff Strategies Config Panel
          FinanceCard(
            title: 'Payoff strategies',
            icon: Icons.compare_arrows_outlined,
            accentColor: AikoColors.deepBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Strategy:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AikoColors.darkNavy),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Snowball')),
                        selected: strategy == DebtPayoffStrategy.snowball,
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(debtStrategyProvider.notifier).setStrategy(DebtPayoffStrategy.snowball);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Avalanche')),
                        selected: strategy == DebtPayoffStrategy.avalanche,
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(debtStrategyProvider.notifier).setStrategy(DebtPayoffStrategy.avalanche);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Accelerated Monthly Payment',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AikoColors.darkNavy),
                    ),
                    Text(
                      '+\$${_extraMonthlyPayment.toStringAsFixed(0)}/mo',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AikoColors.primaryBlue),
                    )
                  ],
                ),
                Slider(
                  value: _extraMonthlyPayment,
                  min: 0.0,
                  max: 2000.0,
                  divisions: 40,
                  activeColor: AikoColors.primaryBlue,
                  inactiveColor: AikoColors.borderSubtle,
                  onChanged: (val) {
                    setState(() {
                      _extraMonthlyPayment = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interest Savings and Payoff Forecast Panel
          FinanceCard(
            title: 'Interest savings',
            icon: Icons.savings_outlined,
            accentColor: AikoColors.successGreen,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Accelerated Payoff', style: TextStyle(fontSize: 11, color: AikoColors.mutedText)),
                        const SizedBox(height: 4),
                        Text(
                          accelerated['never'] ? 'Never' : '$accMonths months',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: accelerated['never'] ? AikoColors.dangerRed : AikoColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 40, color: AikoColors.borderSubtle),
                    Column(
                      children: [
                        const Text('Total Interest Saved', style: TextStyle(fontSize: 11, color: AikoColors.mutedText)),
                        const SizedBox(height: 4),
                        Text(
                          '\$${savedInterest.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AikoColors.successGreen),
                        ),
                      ],
                    ),
                  ],
                ),
                if (savedMonths > 0) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flash_on, size: 16, color: AikoColors.warningOrange),
                      const SizedBox(width: 4),
                      Text(
                        'You will be debt-free $savedMonths months earlier!',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AikoColors.neutralInk, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Prioritized Debt Payoff List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Debt Prioritization List',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AikoColors.darkNavy),
                ),
                Text(
                  strategy == DebtPayoffStrategy.snowball ? 'By Balance' : 'By Interest Rate',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AikoColors.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (debts.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: AikoColors.surfacePanel,
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text('No debts found! Tap the top-right button to add one.', style: TextStyle(color: AikoColors.mutedText)),
                ),
              ),
            )
          else
            ...rankedDebts.asMap().entries.map((entry) {
              final idx = entry.key;
              final d = entry.value;

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: AikoColors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: idx == 0 ? AikoColors.warningOrange : AikoColors.surfacePanel,
                        child: Text(
                          '#${idx + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: idx == 0 ? AikoColors.white : AikoColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AikoColors.darkNavy),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${d.interestRatePercent}% APR | min \$${d.monthlyPayment.amount.toStringAsFixed(0)}/mo',
                              style: const TextStyle(fontSize: 12, color: AikoColors.mutedText),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            d.balance.toString(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AikoColors.dangerRed),
                          ),
                          const SizedBox(height: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AikoColors.mutedText, size: 18),
                            onPressed: () {
                              ref.read(debtsProvider.notifier).deleteDebt(d.name);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
