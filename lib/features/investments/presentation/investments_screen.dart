import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/money/exchange_rates.dart';
import '../../../core/money/money.dart';
import '../../../core/money/supported_currencies.dart';
import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../shared/widgets/fx_rates_note.dart';
import '../../../shared/widgets/screen_states.dart';
import '../../../theme/aiko_colors.dart';
import '../../../theme/aiko_status_colors.dart';
import '../../dashboard/application/dashboard_summary_builder.dart';
import '../application/allocation_service.dart';
import '../application/investments_provider.dart';
import '../application/portfolio_valuation.dart';
import '../application/price_refresh.dart';
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
    // Exchange rates that failed or come from the saved copy are fetched
    // again when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rates = fxRatesProvider(_baseCurrency);
      if (ref.exists(rates)) ref.read(rates.notifier).retryIfStale();
    });
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
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isRefreshing = true);
    final rates = fxRatesProvider(_baseCurrency);
    if (ref.exists(rates)) unawaited(ref.read(rates.notifier).refresh());
    try {
      final result = await ref
          .read(investmentsProvider.notifier)
          .refreshPrices();
      final message = _refreshMessage(result, l10n);
      if (message != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.holdingPricesSaveFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String? _refreshMessage(PriceRefreshResult result, AppLocalizations l10n) {
    if (result.needsCloud) {
      return l10n.holdingPricesNeedCloud;
    }
    if (result.offline) {
      return [
        if (result.updated > 0) l10n.holdingPricesUpdated(result.updated),
        l10n.netPricesOffline,
      ].join(' ');
    }
    if (result.updated + result.failed + result.deferred == 0) {
      return null;
    }
    return [
      l10n.holdingPricesUpdated(result.updated),
      if (result.failed > 0) l10n.holdingPricesFailed(result.failed),
      if (result.deferred > 0) l10n.holdingPricesDeferred(result.deferred),
    ].join(' ');
  }

  String get _baseCurrency =>
      ref.read(profileProvider).value?.baseCurrency ?? kDefaultBaseCurrency;

  void _showHoldingSheet({InvestmentHolding? initial}) {
    showAikoSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _HoldingFormSheet(initial: initial, defaultCurrency: _baseCurrency),
    );
  }

  void _openHolding(InvestmentHolding holding) {
    final id = Uri.encodeQueryComponent(holding.id);
    context.push('/portfolio/holding?id=$id', extra: holding);
  }

  void _confirmDeleteHolding(InvestmentHolding holding) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.holdingRemoveQuestion(holding.symbol)),
          content: Text(context.l10n.holdingRemoveMessage(holding.symbol)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteHolding(holding);
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

  Future<void> _deleteHolding(InvestmentHolding holding) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(investmentsProvider.notifier).deleteHolding(holding.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.holdingRemoved(holding.symbol)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.holdingRemoveFailed(holding.symbol)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final holdingsAsync = ref.watch(investmentsProvider);
    // Loaded here so the add sheet can default to the base currency.
    ref.watch(profileProvider);
    final actionColor = Theme.of(context).colorScheme.primary;
    final hasHoldings = holdingsAsync.value?.isNotEmpty ?? false;

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
      // The empty state carries its own add button.
      floatingActionButton: hasHoldings
          ? FloatingActionButton.extended(
              tooltip: context.l10n.holdingAdd,
              onPressed: _showHoldingSheet,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.holdingAdd),
            )
          : null,
      body: holdingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => AikoScreenState.error(
          title: context.l10n.portfolioLoadFailed,
          message: context.l10n.holdingsUnavailableMessage,
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
    final valuation = _valuationFor(holdings);
    final alerts = InvestmentsScreen._allocationService.rebalanceAlerts(
      portfolio: valuation.holdings,
      targets: InvestmentsScreen._targetAllocation,
    );
    final summary = _PortfolioSummary.fromHoldings(
      l10n: context.l10n,
      valuation: valuation,
      holdingCount: holdings.length,
      alerts: alerts,
      pricesUpdatedAt: ref.watch(pricesUpdatedAtProvider).value,
    );
    final filteredHoldings = holdings.where(_matchesVisibleFilters).toList();
    final allocationRows = _allocationRowsFor(valuation.holdings);

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
              onAddHolding: _showHoldingSheet,
              onOpenHolding: _openHolding,
              onEditHolding: (holding) => _showHoldingSheet(initial: holding),
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

  /// Totals and allocation add holdings up in the profile's base currency.
  PortfolioValuation _valuationFor(List<InvestmentHolding> holdings) {
    final baseCurrency =
        ref.watch(profileProvider).value?.baseCurrency ?? kDefaultBaseCurrency;
    final needsRates = holdings.any(
      (holding) => holding.currency.toUpperCase() != baseCurrency,
    );
    final rates = needsRates
        ? ref.watch(fxRatesProvider(baseCurrency)).value
        : null;
    return valueHoldingsIn(
      holdings,
      CurrencyConverter.from(rates ?? ExchangeRates.none(baseCurrency)),
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
          if (FxRatesNote.applies(
            excludedCurrencies: summary.excludedCurrencies,
            ratesAsOf: summary.ratesAsOf,
          )) ...[
            const SizedBox(height: 8),
            FxRatesNote(
              excludedCurrencies: summary.excludedCurrencies,
              ratesAsOf: summary.ratesAsOf,
            ),
          ],
          if (summary.pricesUpdatedAt case final updatedAt?) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.netPricesUpdatedAt(ratesAsOfLabel(updatedAt)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
              color: valueColor == null
                  ? null
                  : AikoStatusColors.of(context).textFor(valueColor!),
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
    required this.onOpenHolding,
    required this.onEditHolding,
    required this.onDeleteHolding,
  });

  final List<InvestmentHolding> holdings;
  final List<InvestmentHolding> filteredHoldings;
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onAddHolding;
  final ValueChanged<InvestmentHolding> onOpenHolding;
  final ValueChanged<InvestmentHolding> onEditHolding;
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
              onOpen: () => onOpenHolding(holding),
              onEdit: () => onEditHolding(holding),
              onDelete: () => onDeleteHolding(holding),
            ),
          ),
      ],
    );
  }
}

enum _HoldingAction { edit, remove }

class _HoldingCard extends StatelessWidget {
  const _HoldingCard({
    required this.holding,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final InvestmentHolding holding;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
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
      child: InkWell(
        onTap: onOpen,
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
              PopupMenuButton<_HoldingAction>(
                tooltip: context.l10n.holdingActionsTooltip(holding.symbol),
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onSelected: (action) => switch (action) {
                  _HoldingAction.edit => onEdit(),
                  _HoldingAction.remove => onDelete(),
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _HoldingAction.edit,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(context.l10n.holdingEdit),
                    ),
                  ),
                  PopupMenuItem(
                    value: _HoldingAction.remove,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline),
                      title: Text(context.l10n.remove),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
            color: AikoStatusColors.of(context).textFor(color),
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
    required this.excludedCurrencies,
    this.ratesAsOf,
    this.pricesUpdatedAt,
  });

  final String totalValue;
  final String totalGain;
  final Color gainColor;
  final String holdingsLabel;
  final String allocationStatus;
  final Color allocationColor;
  final Set<String> excludedCurrencies;
  final DateTime? ratesAsOf;
  final DateTime? pricesUpdatedAt;

  factory _PortfolioSummary.fromHoldings({
    required PortfolioValuation valuation,
    required int holdingCount,
    required List<RebalanceAlert> alerts,
    required AppLocalizations l10n,
    DateTime? pricesUpdatedAt,
  }) {
    final currency = valuation.currency;
    final totalValue = _sumMoney(
      currency: currency,
      amounts: valuation.holdings.map((holding) => holding.marketValue),
    );
    final totalGain = _sumMoney(
      currency: currency,
      amounts: valuation.holdings.map((holding) => holding.unrealizedGainLoss),
    );
    final isBalanced = alerts.isEmpty;

    return _PortfolioSummary(
      totalValue: totalValue.format(),
      totalGain: _formatSignedMoney(totalGain),
      gainColor: totalGain.isNegative
          ? AikoColors.dangerRed
          : AikoColors.successGreen,
      holdingsLabel: l10n.holdingsCount(holdingCount),
      allocationStatus: isBalanced
          ? l10n.allocationOnTrack
          : l10n.allocationNeedsRebalance,
      allocationColor: isBalanced
          ? AikoColors.successGreen
          : AikoColors.warningOrange,
      excludedCurrencies: valuation.excludedCurrencies,
      ratesAsOf: valuation.ratesAsOf,
      pricesUpdatedAt: pricesUpdatedAt,
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

/// Adds a holding, or edits [initial] in place (same id).
class _HoldingFormSheet extends ConsumerStatefulWidget {
  const _HoldingFormSheet({this.initial, required this.defaultCurrency});

  final InvestmentHolding? initial;

  /// Currency for a new holding: the profile's base currency.
  final String defaultCurrency;

  @override
  ConsumerState<_HoldingFormSheet> createState() => _HoldingFormSheetState();
}

class _HoldingFormSheetState extends ConsumerState<_HoldingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _symbolController = TextEditingController(
    text: widget.initial?.symbol,
  );
  late final _quantityController = TextEditingController(
    text: widget.initial?.quantity.toString(),
  );
  late final _averageCostController = TextEditingController(
    text: widget.initial?.averageCost.amount.toString(),
  );
  late final _currentPriceController = TextEditingController(
    text: widget.initial?.currentPrice.amount.toString(),
  );
  late var _selectedAssetClass = widget.initial?.assetClass ?? 'Stocks';
  late var _currency = (widget.initial?.currency ?? widget.defaultCurrency)
      .toUpperCase();
  var _isLoading = false;

  static const _assetClasses = [
    'Stocks',
    'Bonds',
    'Funds',
    'Crypto',
    'Cash',
    'Custom',
  ];

  bool get _isEditing => widget.initial != null;

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

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isLoading = true);

    try {
      final symbol = _symbolController.text.trim().toUpperCase();
      final quantity = Decimal.parse(_quantityController.text.trim());
      final averageCost = Money.parse(
        _averageCostController.text.trim(),
        _currency,
      );
      final currentPrice = _currentPriceController.text.trim().isEmpty
          ? averageCost
          : Money.parse(_currentPriceController.text.trim(), _currency);
      final holding =
          widget.initial?.copyWith(
            symbol: symbol,
            assetClass: _selectedAssetClass,
            quantity: quantity,
            averageCost: averageCost,
            currentPrice: currentPrice,
          ) ??
          InvestmentHolding(
            id: const Uuid().v4(),
            symbol: symbol,
            assetClass: _selectedAssetClass,
            quantity: quantity,
            averageCost: averageCost,
            currentPrice: currentPrice,
          );

      await ref.read(investmentsProvider.notifier).saveHolding(holding);

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? l10n.holdingUpdated(symbol)
                : l10n.holdingAdded(symbol),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.holdingSaveFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                        _isEditing
                            ? context.l10n.holdingEdit
                            : context.l10n.holdingAdd,
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
                    for (final assetClass in {
                      ..._assetClasses,
                      _selectedAssetClass,
                    })
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
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.txCurrency,
                    prefixIcon: const Icon(Icons.currency_exchange_outlined),
                  ),
                  items: [
                    for (final code in {_currency, ...kAikoSupportedCurrencies})
                      DropdownMenuItem(
                        value: code,
                        child: Text(
                          '$code · ${currencyDisplayName(code, context.l10n)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _currency = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _averageCostController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.holdingAverageCost,
                    prefixIcon: Icon(Icons.payments_outlined),
                    suffixText: _currency,
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
                    suffixText: _currency,
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
                      : Icon(_isEditing ? Icons.check : Icons.add),
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
