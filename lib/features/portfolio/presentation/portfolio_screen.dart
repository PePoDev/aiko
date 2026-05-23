import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/portfolio_allocation_service.dart';
import '../application/portfolio_provider.dart';
import '../domain/allocation_target.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  static const _service = PortfolioAllocationService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioProvider);
    final holdings = state.holdings;
    final isRefreshing = state.isRefreshing;

    final alerts = _service.rebalanceAlerts(
      portfolio: holdings,
      targets: const [
        AllocationTarget(assetClass: 'Stocks', targetPercent: 70),
        AllocationTarget(assetClass: 'Bonds', targetPercent: 30),
      ],
    );

    final gains = holdings.isNotEmpty
        ? _service.capitalGainsOnSale(
            holding: holdings.first,
            quantitySold: 2,
            salePrice: holdings.first.currentPrice,
          )
        : null;

    return Scaffold(
      backgroundColor: AikoColors.appBackgroundLight,
      appBar: AppBar(
        title: const Text('Investment Portfolio'),
        actions: [
          IconButton(
            icon: isRefreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: isRefreshing
                ? null
                : () => ref.read(portfolioProvider.notifier).refreshPrices(),
            tooltip: 'Refresh Prices',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Premium Live Ticker Indicator
              if (isRefreshing) ...[
                Card(
                  color: AikoColors.premiumPurple.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AikoColors.premiumPurple),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AikoColors.premiumPurple,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Updating stock market prices in real-time...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AikoColors.premiumPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Active Holdings Card
              FinanceCard(
                title: 'Holdings',
                icon: Icons.pie_chart_outline,
                accentColor: AikoColors.analyticsTeal,
                child: Column(
                  children: [
                    if (holdings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No holdings found. Add investments to get started.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    else
                      for (final holding in holdings) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Text(
                                holding.symbol,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AikoColors.analyticsTeal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  holding.assetClass,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AikoColors.analyticsTeal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Qty: ${holding.quantity} | Cost basis: ${holding.averageCost.format()} | Live: ${holding.currentPrice.format()}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                holding.marketValue.format(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    holding.unrealizedGainLoss.isNegative
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    size: 10,
                                    color: holding.unrealizedGainLoss.isNegative
                                        ? AikoColors.dangerRed
                                        : AikoColors.successGreen,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    holding.unrealizedGainLoss.format(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: holding.unrealizedGainLoss.isNegative
                                          ? AikoColors.dangerRed
                                          : AikoColors.successGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (holding != holdings.last) const Divider(),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Allocation Drift & Smart Rebalancing Recommendation
              FinanceCard(
                title: 'Target Asset Allocation Drift',
                icon: Icons.notifications_active_outlined,
                accentColor: AikoColors.warningOrange,
                child: Column(
                  children: [
                    if (alerts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, color: AikoColors.successGreen, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Portfolio is perfectly balanced!',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final alert in alerts) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            alert.assetClass,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            'Drift direction: ${alert.direction}',
                            style: TextStyle(
                              fontSize: 11,
                              color: alert.direction.contains('Under')
                                  ? AikoColors.dangerRed
                                  : AikoColors.warningOrange,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AikoColors.warningOrange.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Actual: ${alert.actualPercent.toStringAsFixed(0)}% / Target: ${alert.targetPercent.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AikoColors.warningOrange,
                              ),
                            ),
                          ),
                        ),
                        if (alert != alerts.last) const Divider(),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Smart Capital Gains Calculator Panel
              FinanceCard(
                title: 'Capital Gains Tax Estimator',
                icon: Icons.request_quote_outlined,
                accentColor: AikoColors.successGreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (gains != null) ...[
                      Text(
                        'Simulating sale of 2 units of ${gains.symbol}:',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: gains.gainLoss.isNegative
                              ? AikoColors.dangerRed.withOpacity(0.05)
                              : AikoColors.successGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: gains.gainLoss.isNegative
                                ? AikoColors.dangerRed.withOpacity(0.15)
                                : AikoColors.successGreen.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Estimated Unrealized Gain:',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                            ),
                            Text(
                              gains.gainLoss.format(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: gains.gainLoss.isNegative
                                    ? AikoColors.dangerRed
                                    : AikoColors.successGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This estimator utilizes FIFO accounting. Live market pricing updates automatically recompute taxable gains.',
                        style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                      ),
                    ] else
                      const Text('Add holdings to estimate gains.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
