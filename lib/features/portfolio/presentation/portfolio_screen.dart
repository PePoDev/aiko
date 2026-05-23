import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/portfolio_allocation_service.dart';
import '../application/portfolio_provider.dart';
import '../domain/allocation_target.dart';
import '../domain/investment_holding.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  static const _service = PortfolioAllocationService();

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  // Interactive Capital Gains tax estimator states
  InvestmentHolding? _selectedTaxHolding;
  double _taxQuantitySold = 1.0;
  double _taxSalePrice = 100.0;
  bool _isTaxEstimatorInitialized = false;

  void _showAddHoldingBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddHoldingBottomSheet(),
    );
  }

  void _confirmDeleteHolding(InvestmentHolding holding) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Sell / Remove ${holding.symbol}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AikoColors.darkNavy),
          ),
          content: Text(
            'Are you sure you want to permanently delete or liquidate your position in ${holding.symbol}? This action cannot be undone.',
            style: const TextStyle(color: AikoColors.neutralInk, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AikoColors.mutedText)),
            ),
            FilledButton(
              onPressed: () {
                ref.read(portfolioProvider.notifier).deleteHolding(holding.symbol);
                if (_selectedTaxHolding?.symbol == holding.symbol) {
                  setState(() {
                    _selectedTaxHolding = null;
                    _isTaxEstimatorInitialized = false;
                  });
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Removed ${holding.symbol} from portfolio.'),
                      ],
                    ),
                    backgroundColor: AikoColors.successGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AikoColors.dangerRed),
              child: const Text('Remove Position'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioProvider);
    final holdings = state.holdings;
    final isRefreshing = state.isRefreshing;

    // Dynamically initialize selection for tax estimator if not yet set
    if (holdings.isNotEmpty && (!_isTaxEstimatorInitialized || _selectedTaxHolding == null)) {
      // Find if previous selected holding still exists, otherwise take first
      final matched = holdings.firstWhere(
        (h) => h.symbol == _selectedTaxHolding?.symbol,
        orElse: () => holdings.first,
      );
      _selectedTaxHolding = matched;
      _taxQuantitySold = matched.quantity.clamp(0.1, matched.quantity);
      _taxSalePrice = matched.currentPrice.amount.toDouble();
      _isTaxEstimatorInitialized = true;
    } else if (holdings.isEmpty) {
      _selectedTaxHolding = null;
      _isTaxEstimatorInitialized = false;
    }

    final alerts = PortfolioScreen._service.rebalanceAlerts(
      portfolio: holdings,
      targets: const [
        AllocationTarget(assetClass: 'Stocks', targetPercent: 70),
        AllocationTarget(assetClass: 'Bonds', targetPercent: 30),
      ],
    );

    // Compute dynamic capital gains estimate based on user sliders
    CapitalGainsEstimate? gains;
    if (_selectedTaxHolding != null && holdings.any((h) => h.symbol == _selectedTaxHolding!.symbol)) {
      // Find latest instance from provider in case values changed
      final latestHolding = holdings.firstWhere((h) => h.symbol == _selectedTaxHolding!.symbol);
      try {
        gains = PortfolioScreen._service.capitalGainsOnSale(
          holding: latestHolding,
          quantitySold: _taxQuantitySold.clamp(0.1, latestHolding.quantity),
          salePrice: Money.parse(_taxSalePrice.toStringAsFixed(2), latestHolding.currentPrice.currency),
        );
      } catch (_) {
        gains = null;
      }
    }

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddHoldingBottomSheet,
        backgroundColor: AikoColors.premiumPurple,
        icon: const Icon(Icons.trending_up, color: Colors.white),
        label: const Text('Add Investment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(portfolioProvider.notifier).refreshPrices(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
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
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AikoColors.mutedText, size: 20),
                                onPressed: () => _confirmDeleteHolding(holding),
                                tooltip: 'Liquidate / Remove position',
                              )
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
                              color: alert.direction.contains('underweight')
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
                    if (gains != null && _selectedTaxHolding != null) ...[
                      const Text(
                        'Simulate a stock liquidation and compute immediate taxable gains using FIFO estimation rules.',
                        style: TextStyle(fontSize: 12, color: AikoColors.mutedText, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      // Dropdown holding selector
                      Row(
                        children: [
                          const Text('Holding: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AikoColors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedTaxHolding!.symbol,
                                  items: holdings.map((h) {
                                    return DropdownMenuItem<String>(
                                      value: h.symbol,
                                      child: Text('${h.symbol} (${h.assetClass})'),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val == null) return;
                                    setState(() {
                                      final matched = holdings.firstWhere((h) => h.symbol == val);
                                      _selectedTaxHolding = matched;
                                      _taxQuantitySold = matched.quantity.clamp(0.1, matched.quantity);
                                      _taxSalePrice = matched.currentPrice.amount.toDouble();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Quantity to sell slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Quantity to Sell:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            _taxQuantitySold.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AikoColors.primaryBlue),
                          ),
                        ],
                      ),
                      Slider(
                        value: _taxQuantitySold.clamp(0.1, _selectedTaxHolding!.quantity),
                        min: 0.1,
                        max: _selectedTaxHolding!.quantity.clamp(0.1, double.infinity),
                        activeColor: AikoColors.analyticsTeal,
                        inactiveColor: AikoColors.borderSubtle,
                        onChanged: (val) {
                          setState(() {
                            _taxQuantitySold = val;
                          });
                        },
                      ),
                      // Sale price slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Simulated Sale Price:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            '\$${_taxSalePrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AikoColors.primaryBlue),
                          ),
                        ],
                      ),
                      Slider(
                        value: _taxSalePrice,
                        min: (_selectedTaxHolding!.averageCost.amount.toDouble() * 0.2).clamp(1.0, double.infinity),
                        max: (_selectedTaxHolding!.currentPrice.amount.toDouble() * 2.0).clamp(10.0, double.infinity),
                        activeColor: AikoColors.successGreen,
                        inactiveColor: AikoColors.borderSubtle,
                        onChanged: (val) {
                          setState(() {
                            _taxSalePrice = val;
                          });
                        },
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
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Sale Proceeds:', style: TextStyle(fontSize: 12)),
                                Text(gains.proceeds.format(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Cost Basis:', style: TextStyle(fontSize: 12)),
                                Text(gains.costBasis.format(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  gains.gainLoss.isNegative ? 'Simulated Capital Loss:' : 'Simulated Capital Gain:',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This estimator utilizes FIFO accounting. Live market pricing updates automatically recompute taxable gains.',
                        style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Add stock or bond holdings above to calculate simulated capital gains.',
                            style: TextStyle(color: AikoColors.mutedText, fontSize: 12),
                          ),
                        ),
                      ),
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

class _AddHoldingBottomSheet extends ConsumerStatefulWidget {
  const _AddHoldingBottomSheet();

  @override
  ConsumerState<_AddHoldingBottomSheet> createState() => _AddHoldingBottomSheetState();
}

class _AddHoldingBottomSheetState extends ConsumerState<_AddHoldingBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController();
  final _quantityController = TextEditingController();
  final _averageCostController = TextEditingController();
  final _currentPriceController = TextEditingController();
  String _selectedAssetClass = 'Stocks';
  bool _isLoading = false;

  final List<String> _assetClasses = ['Stocks', 'Bonds', 'Crypto', 'Cash', 'Custom'];

  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _averageCostController.dispose();
    _currentPriceController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final symbol = _symbolController.text.trim().toUpperCase();
      final quantity = double.parse(_quantityController.text.trim());
      final avgCostVal = _averageCostController.text.trim();
      final currentPriceVal = _currentPriceController.text.trim().isEmpty 
          ? avgCostVal 
          : _currentPriceController.text.trim();

      final holding = InvestmentHolding(
        symbol: symbol,
        assetClass: _selectedAssetClass,
        quantity: quantity,
        averageCost: Money.parse(avgCostVal, 'USD'),
        currentPrice: Money.parse(currentPriceVal, 'USD'),
      );

      ref.read(portfolioProvider.notifier).addHolding(holding);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Holding $symbol successfully added!'),
              ],
            ),
            backgroundColor: AikoColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add investment: ${e.toString()}'),
            backgroundColor: AikoColors.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Investment Asset',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AikoColors.premiumPurple),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              // Asset Class selector
              DropdownButtonFormField<String>(
                value: _selectedAssetClass,
                decoration: const InputDecoration(
                  labelText: 'Asset Class',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _assetClasses.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedAssetClass = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Stock ticker/Symbol
              TextFormField(
                controller: _symbolController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Ticker Symbol (e.g. AAPL, BND, BTC)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a valid stock symbol or ticker';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Quantity
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantity Owned',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                validator: (val) {
                  if (val == null || double.tryParse(val.trim()) == null || double.parse(val.trim()) <= 0) {
                    return 'Please enter a positive numeric quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Average Cost
              TextFormField(
                controller: _averageCostController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Average Cost Basis per Unit (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money_outlined),
                ),
                validator: (val) {
                  if (val == null || double.tryParse(val.trim()) == null || double.parse(val.trim()) <= 0) {
                    return 'Please enter a valid cost basis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Current Live Price
              TextFormField(
                controller: _currentPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Current Market Price (\$) [Optional, defaults to cost]',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.price_change_outlined),
                ),
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty && (double.tryParse(val.trim()) == null || double.parse(val.trim()) <= 0)) {
                    return 'Please enter a positive live price or leave blank';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Active loading button
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Add to Portfolio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: FilledButton.styleFrom(backgroundColor: AikoColors.premiumPurple),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
