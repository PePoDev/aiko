import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';
import 'calculator_detail_screen.dart';

class CalculatorLibraryScreen extends StatefulWidget {
  const CalculatorLibraryScreen({super.key});

  static List<String> get calculators =>
      _calculatorItems.map((calculator) => calculator.title).toList();

  @override
  State<CalculatorLibraryScreen> createState() =>
      _CalculatorLibraryScreenState();
}

class _CalculatorLibraryScreenState extends State<CalculatorLibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_CalculatorItem> get _filteredCalculators {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _calculatorItems;
    }

    return _calculatorItems.where((calculator) {
      return calculator.title.toLowerCase().contains(query) ||
          calculator.category.toLowerCase().contains(query) ||
          calculator.description.toLowerCase().contains(query);
    }).toList();
  }

  void _openCalculator(_CalculatorItem calculator) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalculatorDetailScreen(title: calculator.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCalculators = _filteredCalculators;

    return Scaffold(
      appBar: AppBar(title: const Text('Calculators')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search calculator',
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredCalculators.isEmpty
                      ? const Align(
                          alignment: Alignment.topCenter,
                          child: FinanceCard(
                            title: 'No calculators found',
                            icon: Icons.search_off_outlined,
                            child: Text('Try a different search term.'),
                          ),
                        )
                      : _CalculatorGrid(
                          calculators: filteredCalculators,
                          onOpen: _openCalculator,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalculatorGrid extends StatelessWidget {
  const _CalculatorGrid({required this.calculators, required this.onOpen});

  final List<_CalculatorItem> calculators;
  final ValueChanged<_CalculatorItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _crossAxisCountForWidth(constraints.maxWidth);

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 112),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 188,
          ),
          itemCount: calculators.length,
          itemBuilder: (context, index) {
            final calculator = calculators[index];
            return _CalculatorTile(
              calculator: calculator,
              onTap: () => onOpen(calculator),
            );
          },
        );
      },
    );
  }

  int _crossAxisCountForWidth(double width) {
    if (width < 340) {
      return 1;
    }
    if (width < 700) {
      return 2;
    }
    if (width < 980) {
      return 3;
    }
    return 4;
  }
}

class _CalculatorTile extends StatelessWidget {
  const _CalculatorTile({required this.calculator, required this.onTap});

  final _CalculatorItem calculator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(12);

    return Semantics(
      button: true,
      label: '${calculator.title} calculator',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        calculator.icon,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  calculator.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  calculator.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    calculator.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalculatorItem {
  const _CalculatorItem({
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
  });

  final String title;
  final String category;
  final String description;
  final IconData icon;
}

const _calculatorItems = [
  _CalculatorItem(
    title: 'Compound interest',
    category: 'Saving and investing',
    description: 'Project future value with contributions and annual growth.',
    icon: Icons.trending_up,
  ),
  _CalculatorItem(
    title: 'Loan',
    category: 'Debt and loans',
    description: 'Estimate monthly payment from balance, APR, and term.',
    icon: Icons.payments_outlined,
  ),
  _CalculatorItem(
    title: 'Credit card payoff',
    category: 'Debt and loans',
    description: 'Estimate payoff time from APR and monthly payment.',
    icon: Icons.credit_card,
  ),
  _CalculatorItem(
    title: 'Savings goal',
    category: 'Goals',
    description: 'Calculate the pace needed to reach a target amount.',
    icon: Icons.flag_outlined,
  ),
  _CalculatorItem(
    title: 'ROI',
    category: 'Investing',
    description: 'Compare gain, cost, and holding period return.',
    icon: Icons.query_stats,
  ),
  _CalculatorItem(
    title: 'Currency converter',
    category: 'Travel and currency',
    description: 'Convert an amount with a known exchange rate.',
    icon: Icons.currency_exchange,
  ),
  _CalculatorItem(
    title: 'Time value of money',
    category: 'Saving and investing',
    description: 'Estimate present and future value scenarios.',
    icon: Icons.schedule,
  ),
  _CalculatorItem(
    title: 'IRR / NPV',
    category: 'Investing',
    description: 'Evaluate cash flows with discount-rate analysis.',
    icon: Icons.stacked_line_chart,
  ),
  _CalculatorItem(
    title: 'Certificate of deposit',
    category: 'Saving and investing',
    description: 'Estimate CD earnings over a fixed term.',
    icon: Icons.savings_outlined,
  ),
  _CalculatorItem(
    title: 'Bond yield',
    category: 'Investing',
    description: 'Review coupon, price, and yield relationships.',
    icon: Icons.account_balance_outlined,
  ),
  _CalculatorItem(
    title: 'Tax equivalent yield',
    category: 'Tax',
    description: 'Compare tax-free and taxable investment yields.',
    icon: Icons.percent,
  ),
  _CalculatorItem(
    title: 'Rule of 72',
    category: 'Saving and investing',
    description: 'Estimate how long an investment takes to double.',
    icon: Icons.av_timer,
  ),
  _CalculatorItem(
    title: 'Bi-weekly mortgage payment',
    category: 'Home',
    description: 'Estimate savings from extra mortgage payment cadence.',
    icon: Icons.home_outlined,
  ),
  _CalculatorItem(
    title: 'Refinance savings',
    category: 'Home',
    description: 'Compare loan costs before and after refinancing.',
    icon: Icons.compare_arrows,
  ),
  _CalculatorItem(
    title: 'Rent vs. buy',
    category: 'Home',
    description: 'Compare housing costs across renting and owning.',
    icon: Icons.real_estate_agent_outlined,
  ),
  _CalculatorItem(
    title: 'Home affordability',
    category: 'Home',
    description: 'Estimate purchase budget from income and payments.',
    icon: Icons.house_outlined,
  ),
  _CalculatorItem(
    title: 'Rental property cash flow',
    category: 'Real estate',
    description: 'Estimate operating income and monthly cash flow.',
    icon: Icons.apartment,
  ),
  _CalculatorItem(
    title: 'Traditional vs. Roth IRA',
    category: 'Retirement',
    description: 'Compare contribution tax treatment over time.',
    icon: Icons.elderly_outlined,
  ),
  _CalculatorItem(
    title: 'Required minimum distributions',
    category: 'Retirement',
    description: 'Estimate annual retirement account withdrawals.',
    icon: Icons.event_repeat_outlined,
  ),
  _CalculatorItem(
    title: 'Social Security estimate',
    category: 'Retirement',
    description: 'Estimate benefit timing and income assumptions.',
    icon: Icons.account_balance_wallet_outlined,
  ),
  _CalculatorItem(
    title: 'Annuity payout',
    category: 'Retirement',
    description: 'Estimate periodic payouts from a lump sum.',
    icon: Icons.payments,
  ),
  _CalculatorItem(
    title: 'Auto loan vs. lease',
    category: 'Auto',
    description: 'Compare ownership and lease payment tradeoffs.',
    icon: Icons.directions_car_outlined,
  ),
  _CalculatorItem(
    title: 'WACC',
    category: 'Business',
    description: 'Estimate weighted average cost of capital.',
    icon: Icons.business_center_outlined,
  ),
  _CalculatorItem(
    title: 'Black-Scholes options',
    category: 'Investing',
    description: 'Estimate theoretical option value inputs.',
    icon: Icons.candlestick_chart,
  ),
  _CalculatorItem(
    title: 'CAPM',
    category: 'Investing',
    description: 'Estimate expected return from market risk.',
    icon: Icons.timeline,
  ),
  _CalculatorItem(
    title: 'Capital gains',
    category: 'Tax',
    description: 'Estimate taxable gain from sale proceeds and basis.',
    icon: Icons.receipt_long_outlined,
  ),
  _CalculatorItem(
    title: 'Salary to hourly',
    category: 'Income',
    description: 'Convert annual salary to equivalent hourly pay.',
    icon: Icons.badge_outlined,
  ),
  _CalculatorItem(
    title: 'Paycheck tax',
    category: 'Income',
    description: 'Estimate take-home pay after common deductions.',
    icon: Icons.request_quote_outlined,
  ),
  _CalculatorItem(
    title: 'Inflation',
    category: 'Everyday',
    description: 'Estimate purchasing power after inflation.',
    icon: Icons.price_change_outlined,
  ),
  _CalculatorItem(
    title: 'Tip and percentage',
    category: 'Everyday',
    description: 'Calculate tip, split bills, and percentage changes.',
    icon: Icons.restaurant_outlined,
  ),
];
