import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/money/money.dart';
import '../../../theme/aiko_colors.dart';
import '../../../shared/widgets/finance_card.dart';
import '../domain/credit_card_detail.dart';
import '../application/credit_card_metrics_service.dart';

class CreditCardsNotifier extends Notifier<List<CreditCardDetail>> {
  @override
  List<CreditCardDetail> build() {
    return [
      CreditCardDetail(
        id: 'card-1',
        userId: 'user-default',
        accountId: 'account-1',
        statementBalance: Money.parse('2450.00', 'USD'),
        paymentDueDate: DateTime.now().add(const Duration(days: 15)),
        creditLimit: Money.parse('10000.00', 'USD'),
        aprPercent: 18.99,
        rewardsSummary: '2% Cashback on Dining & Travel',
        minimumPayment: Money.parse('50.00', 'USD'),
      ),
      CreditCardDetail(
        id: 'card-2',
        userId: 'user-default',
        accountId: 'account-2',
        statementBalance: Money.parse('850.00', 'USD'),
        paymentDueDate: DateTime.now().add(const Duration(days: 22)),
        creditLimit: Money.parse('4000.00', 'USD'),
        aprPercent: 24.99,
        rewardsSummary: '1.5% Unlimited Cashback',
        minimumPayment: Money.parse('25.00', 'USD'),
      ),
    ];
  }

  void addCard(CreditCardDetail card) {
    state = [...state, card];
  }

  void deleteCard(String id) {
    state = state.where((c) => c.id != id).toList();
  }
}

// State provider to manage the list of credit cards locally for interactive tracking
final creditCardsProvider = NotifierProvider<CreditCardsNotifier, List<CreditCardDetail>>(() {
  return CreditCardsNotifier();
});

class CreditCardOverviewScreen extends ConsumerStatefulWidget {
  const CreditCardOverviewScreen({super.key});

  @override
  ConsumerState<CreditCardOverviewScreen> createState() => _CreditCardOverviewScreenState();
}

class _CreditCardOverviewScreenState extends ConsumerState<CreditCardOverviewScreen> {
  CreditCardDetail? _selectedCard;
  final _metricsService = const CreditCardMetricsService();

  // Payoff estimator inputs
  double _customMonthlyPayment = 100;
  bool _isEstimatingPayoff = false;

  // Controllers for Add Card Form
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _limitController = TextEditingController();
  final _aprController = TextEditingController();
  final _rewardsController = TextEditingController();
  final _minPaymentController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _limitController.dispose();
    _aprController.dispose();
    _rewardsController.dispose();
    _minPaymentController.dispose();
    super.dispose();
  }

  void _showAddCardDialog() {
    _nameController.clear();
    _balanceController.clear();
    _limitController.clear();
    _aprController.clear();
    _rewardsController.clear();
    _minPaymentController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AikoColors.white,
        title: const Text(
          'Add Credit Card',
          style: TextStyle(color: AikoColors.darkNavy, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Card Name (e.g. Aiko Premium)'),
              ),
              TextField(
                controller: _balanceController,
                decoration: const InputDecoration(labelText: 'Statement Balance (\$)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _limitController,
                decoration: const InputDecoration(labelText: 'Credit Limit (\$)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _aprController,
                decoration: const InputDecoration(labelText: 'APR % (e.g. 18.99)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _minPaymentController,
                decoration: const InputDecoration(labelText: 'Minimum Payment (\$)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _rewardsController,
                decoration: const InputDecoration(labelText: 'Rewards (e.g. 2% Cash Back)'),
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
              final limit = double.tryParse(_limitController.text) ?? 5000.0;
              final apr = double.tryParse(_aprController.text) ?? 18.0;
              final minPay = double.tryParse(_minPaymentController.text) ?? (balance * 0.02);

              final newCard = CreditCardDetail(
                id: 'card-${DateTime.now().millisecondsSinceEpoch}',
                userId: 'user-default',
                accountId: _nameController.text,
                statementBalance: Money.parse(balance.toStringAsFixed(2), 'USD'),
                paymentDueDate: DateTime.now().add(const Duration(days: 30)),
                creditLimit: Money.parse(limit.toStringAsFixed(2), 'USD'),
                aprPercent: apr,
                rewardsSummary: _rewardsController.text.isEmpty ? 'Standard Rewards' : _rewardsController.text,
                minimumPayment: Money.parse(minPay.toStringAsFixed(2), 'USD'),
              );

              ref.read(creditCardsProvider.notifier).addCard(newCard);
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Payoff calculation loop
  Map<String, dynamic> _calculatePayoffMonths(CreditCardDetail card, double payment) {
    double bal = card.statementBalance.amount.toDouble();
    double apr = card.aprPercent ?? 0.0;
    double rate = apr / 100 / 12;

    if (bal <= 0) {
      return {'months': 0, 'interest': 0.0, 'never': false};
    }
    if (payment <= bal * rate) {
      return {'months': 999, 'interest': 0.0, 'never': true};
    }

    int months = 0;
    double totalInterest = 0;
    double currentBal = bal;

    while (currentBal > 0 && months < 360) {
      double interest = currentBal * rate;
      totalInterest += interest;
      currentBal = currentBal + interest - payment;
      months++;
    }

    return {
      'months': months,
      'interest': totalInterest,
      'never': false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(creditCardsProvider);

    // Sum overall credit metrics
    double totalLimit = 0;
    double totalBalance = 0;
    double totalMinPayment = 0;
    double totalInterestEst = 0;

    for (final card in cards) {
      totalLimit += card.creditLimit?.amount.toDouble() ?? 0;
      totalBalance += card.statementBalance.amount.toDouble();
      totalMinPayment += _metricsService.suggestedMinimumPayment(card).amount.toDouble();
      totalInterestEst += _metricsService.estimateMonthlyInterest(card).amount.toDouble();
    }

    final overallUtil = totalLimit > 0 ? (totalBalance / totalLimit * 100) : 0.0;

    // Determine Aiko's expression and guidance text
    String aikoExpression;
    String aikoSpeech;
    Color aikoBubbleBorder;

    if (overallUtil > 30) {
      aikoExpression = 'assets/images/aiko/aiko_warning.png';
      aikoSpeech = "Aiko warning: Your credit utilization is at ${overallUtil.toStringAsFixed(1)}%. Keeping utilization under 30% helps protect your credit score! Let's build a payoff plan.";
      aikoBubbleBorder = AikoColors.dangerRed;
    } else if (cards.isEmpty) {
      aikoExpression = 'assets/images/aiko/aiko_thinking.png';
      aikoSpeech = "Hi! You haven't added any credit cards yet. Tap the button below to add your cards and estimate your monthly interest.";
      aikoBubbleBorder = AikoColors.primaryBlue;
    } else {
      aikoExpression = 'assets/images/aiko/aiko_happy.png';
      aikoSpeech = "Fantastic job! Your overall credit utilization is ${overallUtil.toStringAsFixed(1)}%, which is well within the healthy range. Let's keep it up!";
      aikoBubbleBorder = AikoColors.successGreen;
    }

    return Scaffold(
      backgroundColor: AikoColors.appBackgroundLight,
      appBar: AppBar(
        title: const Text('Credit Cards & Utilization'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            onPressed: _showAddCardDialog,
            tooltip: 'Add Credit Card',
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          // Aiko Advice Banner
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
              ]
            ),
            child: Row(
              children: [
                Image.asset(
                  aikoExpression,
                  width: 72,
                  height: 72,
                  errorBuilder: (_, __, ___) => const Icon(Icons.face_3, size: 72, color: AikoColors.primaryBlue),
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

          // Total Utilization Metric Panel
          FinanceCard(
            title: 'Utilization',
            icon: Icons.pie_chart_outline_outlined,
            accentColor: overallUtil > 30 ? AikoColors.warningOrange : AikoColors.deepBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${overallUtil.toStringAsFixed(1)}% Used',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: overallUtil > 30 ? AikoColors.warningOrange : AikoColors.deepBlue,
                      ),
                    ),
                    Text(
                      '\$${totalBalance.toStringAsFixed(0)} / \$${totalLimit.toStringAsFixed(0)}',
                      style: const TextStyle(color: AikoColors.mutedText, fontWeight: FontWeight.w600),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: totalLimit > 0 ? (totalBalance / totalLimit).clamp(0.0, 1.0) : 0,
                    minHeight: 10,
                    backgroundColor: AikoColors.surfacePanel,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      overallUtil > 30 ? AikoColors.warningOrange : AikoColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your credit utilization is calculated as (Total Balance / Total Limit). Keep individual and total card utilization below 30% to maximize credit score health.',
                  style: TextStyle(fontSize: 11, color: AikoColors.mutedText, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payment Planning Panel
          FinanceCard(
            title: 'Payment planning',
            icon: Icons.payment_outlined,
            accentColor: AikoColors.successGreen,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Est. Monthly Interest', style: TextStyle(fontSize: 12, color: AikoColors.mutedText)),
                      const SizedBox(height: 4),
                      Text(
                        '\$${totalInterestEst.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AikoColors.dangerRed),
                      )
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: AikoColors.borderSubtle),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Suggested Min', style: TextStyle(fontSize: 12, color: AikoColors.mutedText)),
                      const SizedBox(height: 4),
                      Text(
                        '\$${totalMinPayment.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AikoColors.darkNavy),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Card List Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: const Text(
              'Your Credit Cards',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AikoColors.darkNavy),
            ),
          ),
          const SizedBox(height: 10),

          if (cards.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: AikoColors.surfacePanel,
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text('No credit cards found. Tap the top-right button to add one.', style: TextStyle(color: AikoColors.mutedText)),
                ),
              ),
            )
          else
            ...cards.map((card) {
              final isSelected = _selectedCard?.id == card.id;
              final cardUtil = card.utilizationPercent;
              final minPay = _metricsService.suggestedMinimumPayment(card);

              return Card(
                elevation: isSelected ? 4 : 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isSelected
                      ? const BorderSide(color: AikoColors.primaryBlue, width: 2)
                      : BorderSide.none,
                ),
                color: AikoColors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      _selectedCard = card;
                      _customMonthlyPayment = (minPay.amount.toDouble() * 2).clamp(25.0, card.statementBalance.amount.toDouble()).toDouble();
                      _isEstimatingPayoff = true;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.credit_card, color: cardUtil > 30 ? AikoColors.warningOrange : AikoColors.primaryBlue),
                                const SizedBox(width: 8),
                                Text(
                                  card.accountId,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AikoColors.darkNavy),
                                ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20, color: AikoColors.mutedText),
                              onSelected: (value) {
                                if (value == 'delete') {
                                  ref.read(creditCardsProvider.notifier).deleteCard(card.id);
                                  if (_selectedCard?.id == card.id) {
                                    setState(() {
                                      _selectedCard = null;
                                      _isEstimatingPayoff = false;
                                    });
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete Card', style: TextStyle(color: AikoColors.dangerRed)),
                                )
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Statement Balance', style: TextStyle(fontSize: 12, color: AikoColors.mutedText)),
                                  const SizedBox(height: 4),
                                  Text(
                                    card.statementBalance.toString(),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AikoColors.darkNavy),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('APR & Limit', style: TextStyle(fontSize: 12, color: AikoColors.mutedText)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${card.aprPercent}% | ${card.creditLimit?.toString() ?? 'N/A'}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AikoColors.neutralInk),
                                    textAlign: TextAlign.end,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Mini Utilization Progress
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (cardUtil / 100).clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: AikoColors.surfacePanel,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    cardUtil > 30 ? AikoColors.warningOrange : AikoColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${cardUtil.toStringAsFixed(0)}% Utilized',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: cardUtil > 30 ? AikoColors.warningOrange : AikoColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                        if (card.rewardsSummary != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: AikoColors.warningOrange),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  card.rewardsSummary!,
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AikoColors.mutedText),
                                ),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              );
            }),

          // Selected Card Interactive Payoff Estimator panel
          if (_isEstimatingPayoff && _selectedCard != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AikoColors.surfacePanel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AikoColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimate Payoff for ${_selectedCard!.accountId}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AikoColors.darkNavy),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _isEstimatingPayoff = false),
                      )
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Est. Monthly Interest: \$${_metricsService.estimateMonthlyInterest(_selectedCard!).amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AikoColors.dangerRed),
                      ),
                      Text(
                        'Min Payment: \$${_metricsService.suggestedMinimumPayment(_selectedCard!).amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AikoColors.darkNavy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Custom Monthly Payment',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AikoColors.darkNavy),
                      ),
                      Text(
                        '\$${_customMonthlyPayment.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AikoColors.primaryBlue),
                      )
                    ],
                  ),
                  Slider(
                    value: _customMonthlyPayment,
                    min: 10,
                    max: (_selectedCard!.statementBalance.amount.toDouble() * 1.2).clamp(50.0, 5000.0),
                    activeColor: AikoColors.primaryBlue,
                    inactiveColor: AikoColors.borderSubtle,
                    onChanged: (val) {
                      setState(() {
                        _customMonthlyPayment = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final result = _calculatePayoffMonths(_selectedCard!, _customMonthlyPayment);
                      final int months = result['months'];
                      final double interest = result['interest'];
                      final bool never = result['never'];

                      if (never) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AikoColors.dangerRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning, color: AikoColors.dangerRed),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Aiko warning: This monthly payment is less than or equal to the interest. Your balance will grow indefinitely!',
                                  style: TextStyle(color: AikoColors.dangerRed, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              )
                            ],
                          ),
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AikoColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AikoColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Months to Payoff', style: TextStyle(fontSize: 11, color: AikoColors.mutedText)),
                                const SizedBox(height: 4),
                                Text(
                                  '$months months',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AikoColors.primaryBlue),
                                )
                              ],
                            ),
                            Container(width: 1, height: 30, color: AikoColors.borderSubtle),
                            Column(
                              children: [
                                const Text('Total Interest Paid', style: TextStyle(fontSize: 11, color: AikoColors.mutedText)),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${interest.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AikoColors.dangerRed),
                                )
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  )
                ],
              ),
            )
          ]
        ],
      ),
    );
  }
}
