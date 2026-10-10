import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money/money.dart';
import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../application/allocation_service.dart';
import '../application/investments_provider.dart';
import '../domain/allocation_target.dart';
import '../domain/investment_holding.dart';

class InvestmentsScreen extends ConsumerStatefulWidget {
  const InvestmentsScreen({super.key});

  static const _allocationService = AllocationService();
  static const _targetAllocation = [
    AllocationTarget(assetClass: 'Stocks', targetPercent: 70),
    AllocationTarget(assetClass: 'Bonds', targetPercent: 30),
  ];

  @override
  ConsumerState<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends ConsumerState<InvestmentsScreen> {
  final _searchController = TextEditingController();
  var _isSearching = false;
  var _searchQuery = '';
  var _assetClassFilter = 'All';
  var _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim());
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  Future<void> _refreshPrices() async {
    if (_isRefreshing) {
      return;
    }
    setState(() => _isRefreshing = true);
    try {
      await ref.read(investmentsProvider.notifier).refreshPrices();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _showAddHoldingBottomSheet() {
    showAikoSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddHoldingBottomSheet(),
    );
  }

  void _confirmDeleteHolding(InvestmentHolding holding) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.holdingRemoveQuestion(holding.symbol)),
          content: Text(context.l10n.holdingRemoveMessage(holding.symbol)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(investmentsProvider.notifier)
                    .deleteHolding(holding.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.holdingRemoved(holding.symbol)),
                    backgroundColor: AikoColors.successGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AikoColors.dangerRed,
              ),
              child: Text(context.l10n.remove),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final holdingsAsync = ref.watch(investmentsProvider);
    final actionColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.holdingSearchHint,
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              )
            : Text(context.l10n.toolInvestments),
        actions: [
          if (_isSearching)
            IconButton(
              tooltip: context.l10n.txCloseSearch,
              onPressed: _stopSearch,
              icon: Icon(Icons.close, color: actionColor),
            )
          else
            IconButton(
              tooltip: context.l10n.holdingSearchTooltip,
              onPressed: _startSearch,
              icon: Icon(Icons.search, color: actionColor),
            ),
          IconButton(
            tooltip: context.l10n.holdingRefreshPrices,
            onPressed: _isRefreshing ? null : _refreshPrices,
            icon: _isRefreshing
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: actionColor,
                    ),
                  )
                : Icon(Icons.refresh, color: actionColor),
          ),
        ],
      ),
      body: holdingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AikoScreenState.error(
          title: context.l10n.portfolioLoadFailed,
          message: error.toString(),
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(investmentsProvider),
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.retry),
          ),
        ),
        data: (holdings) => _buildHoldingsBody(holdings),
      ),
    );
  }

  Widget _buildHoldingsBody(List<InvestmentHolding> holdings) {
    final alerts = InvestmentsScreen._allocationService.rebalanceAlerts(
      portfolio: holdings,
      targets: InvestmentsScreen._targetAllocation,
    );
    final summary = _PortfolioSummary.fromHoldings(
      l10n: context.l10n,
      holdings: holdings,
      alerts: alerts,
    );
    final filteredHoldings = holdings.where(_matchesVisibleFilters).toList();
    final allocationRows = _allocationRowsFor(holdings);

    return RefreshIndicator(
      onRefresh: _refreshPrices,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isRefreshing) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 12),
            ],
            _PortfolioSummaryCard(summary: summary),
            const SizedBox(height: 12),
            _AssetClassFilters(
              selectedAssetClass: _assetClassFilter,
              onSelected: (value) {
                setState(() => _assetClassFilter = value);
              },
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: context.l10n.holdingsTitle,
              trailing: holdings.isEmpty
                  ? null
                  : context.l10n.holdingsFilteredCount(
                      filteredHoldings.length,
                      holdings.length,
                    ),
            ),
            const SizedBox(height: 8),
            _HoldingsList(
              holdings: holdings,
              filteredHoldings: filteredHoldings,
              hasActiveFilters: _hasActiveFilters,
              onClearFilters: _clearFilters,
              onAddHolding: _showAddHoldingBottomSheet,
              onDeleteHolding: _confirmDeleteHolding,
            ),
            const SizedBox(height: 16),
            _AllocationCard(rows: allocationRows),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 12),
              _RebalanceNotice(alerts: alerts),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty || _assetClassFilter != 'All';
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _assetClassFilter = 'All';
    });
  }

  bool _matchesVisibleFilters(InvestmentHolding holding) {
    if (_assetClassFilter != 'All' && holding.assetClass != _assetClassFilter) {
      return false;
    }
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return holding.symbol.toLowerCase().contains(query) ||
        holding.assetClass.toLowerCase().contains(query) ||
        investmentAssetClassLabel(
          holding.assetClass,
          context.l10n,
        ).toLowerCase().contains(query);
  }
}

class _PortfolioSummaryCard extends StatelessWidget {
  const _PortfolioSummaryCard({required this.summary});

  final _PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FinanceCard(
      title: context.l10n.investmentsValue,
      icon: Icons.account_balance_wallet_outlined,
      accentColor: AikoColors.primaryBlue,
      prominent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.totalValue,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryLine(
            label: context.l10n.investmentsTotalGainLoss,
            value: summary.totalGain,
            valueColor: summary.gainColor,
          ),
          const SizedBox(height: 8),
          _SummaryLine(
            label: context.l10n.investmentsHoldingCount,
            value: summary.holdingsLabel,
          ),
          const SizedBox(height: 8),
          _SummaryLine(
            label: context.l10n.investmentsAllocationStatus,
            value: summary.allocationStatus,
            valueColor: summary.allocationColor,
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _AssetClassFilters extends StatelessWidget {
  const _AssetClassFilters({
    required this.selectedAssetClass,
    required this.onSelected,
  });

  static const _assetClasses = [
    'All',
    'Stocks',
    'Bonds',
    'Funds',
    'Crypto',
    'Cash',
  ];

  final String selectedAssetClass;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final assetClass in _assetClasses) ...[
            ChoiceChip(
              label: Text(
                assetClass == 'All'
                    ? context.l10n.txFilterAll
                    : investmentAssetClassLabel(assetClass, context.l10n),
              ),
              selected: selectedAssetClass == assetClass,
              onSelected: (_) => onSelected(assetClass),
            ),
            if (assetClass != _assetClasses.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _HoldingsList extends StatelessWidget {
  const _HoldingsList({
    required this.holdings,
    required this.filteredHoldings,
    required this.hasActiveFilters,
    required this.onClearFilters,
    required this.onAddHolding,
    required this.onDeleteHolding,
  });

  final List<InvestmentHolding> holdings;
  final List<InvestmentHolding> filteredHoldings;
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onAddHolding;
  final ValueChanged<InvestmentHolding> onDeleteHolding;

  @override
  Widget build(BuildContext context) {
    if (holdings.isEmpty) {
      return SizedBox(
        height: 360,
        child: AikoScreenState.empty(
          title: context.l10n.investmentsEmptyTitle,
          message: context.l10n.investmentsEmptyMessage,
          action: FilledButton.icon(
            onPressed: onAddHolding,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.holdingAdd),
          ),
        ),
      );
    }

    if (filteredHoldings.isEmpty) {
      return SizedBox(
        height: 240,
        child: AikoScreenState.empty(
          title: context.l10n.holdingsNoMatches,
          message: context.l10n.holdingsNoMatchesMessage,
          action: hasActiveFilters
              ? TextButton(
                  onPressed: onClearFilters,
                  child: Text(context.l10n.clearFilters),
                )
              : null,
        ),
      );
    }

    return Column(
      children: [
        for (final holding in filteredHoldings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _HoldingCard(
              holding: holding,
              onDelete: () => onDeleteHolding(holding),
            ),
          ),
      ],
    );
  }
}

class _HoldingCard extends StatelessWidget {
  const _HoldingCard({required this.holding, required this.onDelete});

  final InvestmentHolding holding;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _assetClassColor(context, holding.assetClass);
    final gain = holding.unrealizedGainLoss;
    final radius = BorderRadius.circular(8);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _assetClassIcon(holding.assetClass),
                color: accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          holding.symbol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AssetClassBadge(
                        label: investmentAssetClassLabel(
                          holding.assetClass,
                          context.l10n,
                        ),
                        color: accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.holdingSharesAtPrice(
                      _formatQuantity(holding.quantity),
                      holding.currentPrice.format(),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    holding.marketValue.format(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatSignedMoney(gain),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: gain.isNegative
                          ? AikoColors.dangerRed
                          : AikoColors.successGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: context.l10n.holdingRemoveTooltip(holding.symbol),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetClassBadge extends StatelessWidget {
  const _AssetClassBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({required this.rows});

  final List<_AllocationRowData> rows;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      title: context.l10n.allocationTitle,
      icon: Icons.donut_large_outlined,
      accentColor: AikoColors.analyticsTeal,
      child: rows.isEmpty
          ? Text(
              context.l10n.allocationAddHoldings,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                for (final row in rows) ...[
                  _AllocationRow(row: row),
                  if (row != rows.last) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({required this.row});

  final _AllocationRowData row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                investmentAssetClassLabel(row.assetClass, context.l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${row.percent.toStringAsFixed(0)}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: row.percent / 100,
            minHeight: 8,
            color: _assetClassColor(context, row.assetClass),
            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }
}

class _RebalanceNotice extends StatelessWidget {
  const _RebalanceNotice({required this.alerts});

  final List<RebalanceAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final alert = alerts.first;
    final extraCount = alerts.length - 1;
    final l10n = context.l10n;
    final assetClass = investmentAssetClassLabel(alert.assetClass, l10n);
    final percent = alert.driftPercent.abs().toStringAsFixed(0);
    final message = alert.driftPercent > 0
        ? l10n.rebalanceOverweight(assetClass, percent)
        : l10n.rebalanceUnderweight(assetClass, percent);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AikoColors.warningOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AikoColors.warningOrange.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              color: AikoColors.warningOrange,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                extraCount > 0
                    ? l10n.rebalancePlusMore(message, extraCount)
                    : message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioSummary {
  const _PortfolioSummary({
    required this.totalValue,
    required this.totalGain,
    required this.gainColor,
    required this.holdingsLabel,
    required this.allocationStatus,
    required this.allocationColor,
  });

  final String totalValue;
  final String totalGain;
  final Color gainColor;
  final String holdingsLabel;
  final String allocationStatus;
  final Color allocationColor;

  factory _PortfolioSummary.fromHoldings({
    required List<InvestmentHolding> holdings,
    required List<RebalanceAlert> alerts,
    required AppLocalizations l10n,
  }) {
    final currency = _portfolioCurrency(holdings);
    final totalValue = _sumMoney(
      currency: currency,
      amounts: holdings.map((holding) => holding.marketValue),
    );
    final totalGain = _sumMoney(
      currency: currency,
      amounts: holdings.map((holding) => holding.unrealizedGainLoss),
    );
    final isBalanced = alerts.isEmpty;

    return _PortfolioSummary(
      totalValue: totalValue.format(),
      totalGain: _formatSignedMoney(totalGain),
      gainColor: totalGain.isNegative
          ? AikoColors.dangerRed
          : AikoColors.successGreen,
      holdingsLabel: l10n.holdingsCount(holdings.length),
      allocationStatus: isBalanced
          ? l10n.allocationOnTrack
          : l10n.allocationNeedsRebalance,
      allocationColor: isBalanced
          ? AikoColors.successGreen
          : AikoColors.warningOrange,
    );
  }
}

class _AllocationRowData {
  const _AllocationRowData({
    required this.assetClass,
    required this.percent,
    required this.value,
  });

  final String assetClass;
  final double percent;
  final double value;
}

List<_AllocationRowData> _allocationRowsFor(List<InvestmentHolding> holdings) {
  final total = holdings.fold<double>(
    0,
    (sum, holding) => sum + holding.marketValue.amount.toDouble(),
  );
  if (total <= 0) {
    return const [];
  }

  final totalsByClass = <String, double>{};
  for (final holding in holdings) {
    totalsByClass.update(
      holding.assetClass,
      (value) => value + holding.marketValue.amount.toDouble(),
      ifAbsent: () => holding.marketValue.amount.toDouble(),
    );
  }

  final rows = [
    for (final entry in totalsByClass.entries)
      _AllocationRowData(
        assetClass: entry.key,
        value: entry.value,
        percent: entry.value / total * 100,
      ),
  ]..sort((a, b) => b.value.compareTo(a.value));

  return rows;
}

Money _sumMoney({required String currency, required Iterable<Money> amounts}) {
  var total = Money.zero(currency);
  for (final amount in amounts) {
    if (amount.currency == currency) {
      total = total + amount;
    }
  }
  return total;
}

String _portfolioCurrency(List<InvestmentHolding> holdings) {
  if (holdings.isEmpty) {
    return 'USD';
  }
  return holdings.first.currentPrice.currency;
}

String _formatSignedMoney(Money money) {
  if (money.isPositive) {
    return '+${money.format()}';
  }
  return money.format();
}

String _formatQuantity(Decimal quantity) {
  if (quantity == quantity.round()) {
    return quantity.toStringAsFixed(0);
  }
  return quantity.toStringAsFixed(2);
}

IconData _assetClassIcon(String assetClass) {
  return switch (assetClass) {
    'Stocks' => Icons.show_chart,
    'Bonds' => Icons.account_balance_outlined,
    'Funds' => Icons.pie_chart_outline,
    'Crypto' => Icons.currency_bitcoin,
    'Cash' => Icons.account_balance_wallet_outlined,
    _ => Icons.category_outlined,
  };
}

Color _assetClassColor(BuildContext context, String assetClass) {
  return switch (assetClass) {
    'Stocks' => AikoColors.primaryBlue,
    'Bonds' => AikoColors.analyticsTeal,
    'Funds' => AikoColors.premiumPurple,
    'Crypto' => AikoColors.warningOrange,
    'Cash' => AikoColors.successGreen,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

class _AddHoldingBottomSheet extends ConsumerStatefulWidget {
  const _AddHoldingBottomSheet();

  @override
  ConsumerState<_AddHoldingBottomSheet> createState() =>
      _AddHoldingBottomSheetState();
}

class _AddHoldingBottomSheetState
    extends ConsumerState<_AddHoldingBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController();
  final _quantityController = TextEditingController();
  final _averageCostController = TextEditingController();
  final _currentPriceController = TextEditingController();
  var _selectedAssetClass = 'Stocks';
  var _isLoading = false;

  static const _assetClasses = [
    'Stocks',
    'Bonds',
    'Funds',
    'Crypto',
    'Cash',
    'Custom',
  ];

  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _averageCostController.dispose();
    _currentPriceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final symbol = _symbolController.text.trim().toUpperCase();
      final quantity = Decimal.parse(_quantityController.text.trim());
      final averageCost = _averageCostController.text.trim();
      final currentPrice = _currentPriceController.text.trim().isEmpty
          ? averageCost
          : _currentPriceController.text.trim();

      ref
          .read(investmentsProvider.notifier)
          .addHolding(
            InvestmentHolding(
              id: const Uuid().v4(),
              symbol: symbol,
              assetClass: _selectedAssetClass,
              quantity: quantity,
              averageCost: Money.parse(averageCost, 'USD'),
              currentPrice: Money.parse(currentPrice, 'USD'),
            ),
          );

      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.holdingAdded(symbol)),
          backgroundColor: AikoColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.holdingAddFailed),
            backgroundColor: AikoColors.dangerRed,
            behavior: SnackBarBehavior.floating,
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
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.holdingAdd,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.close,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedAssetClass,
                  decoration: InputDecoration(
                    labelText: context.l10n.holdingAssetClass,
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final assetClass in _assetClasses)
                      DropdownMenuItem(
                        value: assetClass,
                        child: Text(
                          investmentAssetClassLabel(assetClass, context.l10n),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedAssetClass = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _symbolController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                  decoration: InputDecoration(
                    labelText: context.l10n.holdingSymbol,
                    hintText: context.l10n.holdingSymbolHint,
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.holdingSymbolRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.holdingQuantity,
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                  validator: _positiveNumberValidator(context.l10n),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _averageCostController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.holdingAverageCost,
                    prefixIcon: Icon(Icons.attach_money_outlined),
                  ),
                  validator: _positiveNumberValidator(context.l10n),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _currentPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.holdingCurrentPrice,
                    hintText: context.l10n.optional,
                    prefixIcon: Icon(Icons.price_change_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    return _positiveNumberValidator(context.l10n)(value);
                  },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(context.l10n.holdingSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

FormFieldValidator<String> _positiveNumberValidator(AppLocalizations l10n) {
  return (value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) {
      return l10n.enterPositiveNumber;
    }
    return null;
  };
}
