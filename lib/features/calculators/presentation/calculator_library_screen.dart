import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/widgets/finance_card.dart';
import 'calculator_detail_screen.dart';

class CalculatorLibraryScreen extends StatefulWidget {
  const CalculatorLibraryScreen({super.key});

  /// Stable ids of every listed calculator.
  static List<String> get calculators =>
      _calculatorItems.map((calculator) => calculator.id).toList();

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

    final l10n = context.l10n;
    return _calculatorItems.where((calculator) {
      final text = calculator.text(l10n);
      return calculator.id.toLowerCase().contains(query) ||
          text.title.toLowerCase().contains(query) ||
          text.category.toLowerCase().contains(query) ||
          text.description.toLowerCase().contains(query);
    }).toList();
  }

  void _openCalculator(_CalculatorItem calculator) {
    openAikoPage<void>(
      context,
      CalculatorDetailScreen(
        calculatorId: calculator.id,
        title: calculator.text(context.l10n).title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCalculators = _filteredCalculators;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.toolCalculators)),
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
                    labelText: context.l10n.calcSearch,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.l10n.txClearSearch,
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
                      ? Align(
                          alignment: Alignment.topCenter,
                          child: FinanceCard(
                            title: context.l10n.calcNoneFound,
                            icon: Icons.search_off_outlined,
                            child: Text(context.l10n.calcTryDifferentSearch),
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
    final text = calculator.text(context.l10n);

    return Semantics(
      button: true,
      label: context.l10n.calcTileSemantics(text.title),
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
                  text.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  text.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    text.description,
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
  const _CalculatorItem({required this.id, required this.icon});

  /// Stable English id; also picks the form in `CalculatorDetailScreen`.
  final String id;
  final IconData icon;

  ({String title, String category, String description}) text(
    AppLocalizations l10n,
  ) {
    final (title, category, description) = _calculatorText(id, l10n);
    return (title: title, category: category, description: description);
  }
}

(String, String, String) _calculatorText(String id, AppLocalizations l10n) =>
    switch (id) {
      'Compound interest' => (
        l10n.calcTitleCompoundInterest,
        l10n.calcCategorySavingInvesting,
        l10n.calcDescriptionCompoundInterest,
      ),
      'Loan' => (
        l10n.calcTitleLoan,
        l10n.calcCategoryDebtLoans,
        l10n.calcDescriptionLoan,
      ),
      'Credit card payoff' => (
        l10n.calcTitleCreditCardPayoff,
        l10n.calcCategoryDebtLoans,
        l10n.calcDescriptionCreditCardPayoff,
      ),
      'Savings goal' => (
        l10n.calcTitleSavingsGoal,
        l10n.calcCategoryGoals,
        l10n.calcDescriptionSavingsGoal,
      ),
      'ROI' => (
        l10n.calcTitleRoi,
        l10n.calcCategoryInvesting,
        l10n.calcDescriptionRoi,
      ),
      'Currency converter' => (
        l10n.calcTitleCurrencyConverter,
        l10n.calcCategoryTravelCurrency,
        l10n.calcDescriptionCurrencyConverter,
      ),
      'Time value of money' => (
        l10n.calcTitleTimeValueOfMoney,
        l10n.calcCategorySavingInvesting,
        l10n.calcDescriptionTimeValueOfMoney,
      ),
      'IRR / NPV' => (
        l10n.calcTitleIrrNpv,
        l10n.calcCategoryInvesting,
        l10n.calcDescriptionIrrNpv,
      ),
      'Certificate of deposit' => (
        l10n.calcTitleCertificateOfDeposit,
        l10n.calcCategorySavingInvesting,
        l10n.calcDescriptionCertificateOfDeposit,
      ),
      'Bond yield' => (
        l10n.calcTitleBondYield,
        l10n.calcCategoryInvesting,
        l10n.calcDescriptionBondYield,
      ),
      'Tax equivalent yield' => (
        l10n.calcTitleTaxEquivalentYield,
        l10n.calcCategoryTax,
        l10n.calcDescriptionTaxEquivalentYield,
      ),
      'Rule of 72' => (
        l10n.calcTitleRuleOf72,
        l10n.calcCategorySavingInvesting,
        l10n.calcDescriptionRuleOf72,
      ),
      'Bi-weekly mortgage payment' => (
        l10n.calcTitleBiweeklyMortgage,
        l10n.calcCategoryHome,
        l10n.calcDescriptionBiweeklyMortgage,
      ),
      'Refinance savings' => (
        l10n.calcTitleRefinanceSavings,
        l10n.calcCategoryHome,
        l10n.calcDescriptionRefinanceSavings,
      ),
      'Rent vs. buy' => (
        l10n.calcTitleRentVsBuy,
        l10n.calcCategoryHome,
        l10n.calcDescriptionRentVsBuy,
      ),
      'Home affordability' => (
        l10n.calcTitleHomeAffordability,
        l10n.calcCategoryHome,
        l10n.calcDescriptionHomeAffordability,
      ),
      'Rental property cash flow' => (
        l10n.calcTitleRentalCashFlow,
        l10n.calcCategoryRealEstate,
        l10n.calcDescriptionRentalCashFlow,
      ),
      'Traditional vs. Roth IRA' => (
        l10n.calcTitleTraditionalVsRoth,
        l10n.calcCategoryRetirement,
        l10n.calcDescriptionTraditionalVsRoth,
      ),
      'Required minimum distributions' => (
        l10n.calcTitleRequiredMinimumDistributions,
        l10n.calcCategoryRetirement,
        l10n.calcDescriptionRequiredMinimumDistributions,
      ),
      'Social Security estimate' => (
        l10n.calcTitleSocialSecurity,
        l10n.calcCategoryRetirement,
        l10n.calcDescriptionSocialSecurity,
      ),
      'Annuity payout' => (
        l10n.calcTitleAnnuityPayout,
        l10n.calcCategoryRetirement,
        l10n.calcDescriptionAnnuityPayout,
      ),
      'Auto loan vs. lease' => (
        l10n.calcTitleAutoLoanVsLease,
        l10n.calcCategoryAuto,
        l10n.calcDescriptionAutoLoanVsLease,
      ),
      'WACC' => (
        l10n.calcTitleWacc,
        l10n.calcCategoryBusiness,
        l10n.calcDescriptionWacc,
      ),
      'Black-Scholes options' => (
        l10n.calcTitleBlackScholes,
        l10n.calcCategoryInvesting,
        l10n.calcDescriptionBlackScholes,
      ),
      'CAPM' => (
        l10n.calcTitleCapm,
        l10n.calcCategoryInvesting,
        l10n.calcDescriptionCapm,
      ),
      'Capital gains' => (
        l10n.calcTitleCapitalGains,
        l10n.calcCategoryTax,
        l10n.calcDescriptionCapitalGains,
      ),
      'Salary to hourly' => (
        l10n.calcTitleSalaryToHourly,
        l10n.calcCategoryIncome,
        l10n.calcDescriptionSalaryToHourly,
      ),
      'Paycheck tax' => (
        l10n.calcTitlePaycheckTax,
        l10n.calcCategoryIncome,
        l10n.calcDescriptionPaycheckTax,
      ),
      'Inflation' => (
        l10n.calcTitleInflation,
        l10n.calcCategoryEveryday,
        l10n.calcDescriptionInflation,
      ),
      'Tip and percentage' => (
        l10n.calcTitleTipPercentage,
        l10n.calcCategoryEveryday,
        l10n.calcDescriptionTipPercentage,
      ),
      _ => (id, '', ''),
    };

const _calculatorItems = [
  _CalculatorItem(id: 'Compound interest', icon: Icons.trending_up),
  _CalculatorItem(id: 'Loan', icon: Icons.payments_outlined),
  _CalculatorItem(id: 'Credit card payoff', icon: Icons.credit_card),
  _CalculatorItem(id: 'Savings goal', icon: Icons.flag_outlined),
  _CalculatorItem(id: 'ROI', icon: Icons.query_stats),
  _CalculatorItem(id: 'Currency converter', icon: Icons.currency_exchange),
  _CalculatorItem(id: 'Time value of money', icon: Icons.schedule),
  _CalculatorItem(id: 'IRR / NPV', icon: Icons.stacked_line_chart),
  _CalculatorItem(id: 'Certificate of deposit', icon: Icons.savings_outlined),
  _CalculatorItem(id: 'Bond yield', icon: Icons.account_balance_outlined),
  _CalculatorItem(id: 'Tax equivalent yield', icon: Icons.percent),
  _CalculatorItem(id: 'Rule of 72', icon: Icons.av_timer),
  _CalculatorItem(id: 'Bi-weekly mortgage payment', icon: Icons.home_outlined),
  _CalculatorItem(id: 'Refinance savings', icon: Icons.compare_arrows),
  _CalculatorItem(id: 'Rent vs. buy', icon: Icons.real_estate_agent_outlined),
  _CalculatorItem(id: 'Home affordability', icon: Icons.house_outlined),
  _CalculatorItem(id: 'Rental property cash flow', icon: Icons.apartment),
  _CalculatorItem(id: 'Traditional vs. Roth IRA', icon: Icons.elderly_outlined),
  _CalculatorItem(
    id: 'Required minimum distributions',
    icon: Icons.event_repeat_outlined,
  ),
  _CalculatorItem(
    id: 'Social Security estimate',
    icon: Icons.account_balance_wallet_outlined,
  ),
  _CalculatorItem(id: 'Annuity payout', icon: Icons.payments),
  _CalculatorItem(
    id: 'Auto loan vs. lease',
    icon: Icons.directions_car_outlined,
  ),
  _CalculatorItem(id: 'WACC', icon: Icons.business_center_outlined),
  _CalculatorItem(id: 'Black-Scholes options', icon: Icons.candlestick_chart),
  _CalculatorItem(id: 'CAPM', icon: Icons.timeline),
  _CalculatorItem(id: 'Capital gains', icon: Icons.receipt_long_outlined),
  _CalculatorItem(id: 'Salary to hourly', icon: Icons.badge_outlined),
  _CalculatorItem(id: 'Paycheck tax', icon: Icons.request_quote_outlined),
  _CalculatorItem(id: 'Inflation', icon: Icons.price_change_outlined),
  _CalculatorItem(id: 'Tip and percentage', icon: Icons.restaurant_outlined),
];
