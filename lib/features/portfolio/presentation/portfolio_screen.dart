import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/portfolio_allocation_service.dart';
import '../domain/allocation_target.dart';
import '../domain/investment_holding.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  static const _service = PortfolioAllocationService();

  @override
  Widget build(BuildContext context) {
    final holdings = [
      InvestmentHolding(
        symbol: 'VTI',
        assetClass: 'Stocks',
        quantity: 10,
        averageCost: Money.parse('180', 'USD'),
        currentPrice: Money.parse('240', 'USD'),
      ),
      InvestmentHolding(
        symbol: 'BND',
        assetClass: 'Bonds',
        quantity: 5,
        averageCost: Money.parse('75', 'USD'),
        currentPrice: Money.parse('72', 'USD'),
      ),
    ];
    final alerts = _service.rebalanceAlerts(
      portfolio: holdings,
      targets: const [
        AllocationTarget(assetClass: 'Stocks', targetPercent: 70),
        AllocationTarget(assetClass: 'Bonds', targetPercent: 30),
      ],
    );
    final gains = _service.capitalGainsOnSale(
      holding: holdings.first,
      quantitySold: 2,
      salePrice: Money.parse('240', 'USD'),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinanceCard(
              title: 'Holdings',
              icon: Icons.pie_chart_outline,
              accentColor: AikoColors.analyticsTeal,
              child: Column(
                children: [
                  for (final holding in holdings)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(holding.symbol),
                      subtitle: Text(holding.assetClass),
                      trailing: Text(
                        '${_service.allocationPercent(holding, holdings).toStringAsFixed(0)}%',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FinanceCard(
              title: 'Allocation drift',
              icon: Icons.notifications_active_outlined,
              accentColor: AikoColors.warningOrange,
              child: Column(
                children: [
                  for (final alert in alerts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(alert.assetClass),
                      subtitle: Text(alert.direction),
                      trailing: Text(
                        '${alert.actualPercent.toStringAsFixed(0)}% / ${alert.targetPercent.toStringAsFixed(0)}%',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FinanceCard(
              title: 'Capital gains estimate',
              icon: Icons.request_quote_outlined,
              accentColor: AikoColors.successGreen,
              child: Text(
                '${gains.symbol} sale gain/loss: ${gains.gainLoss.format()}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
