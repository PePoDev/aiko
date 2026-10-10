import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../../../theme/aiko_status_colors.dart';
import '../application/trip_spending.dart';
import '../domain/trip.dart';
import '../application/travel_mode_provider.dart';

class TravelModeScreen extends ConsumerStatefulWidget {
  const TravelModeScreen({super.key});

  @override
  ConsumerState<TravelModeScreen> createState() => _TravelModeScreenState();
}

class _TravelModeScreenState extends ConsumerState<TravelModeScreen> {
  void _showAddTripBottomSheet() {
    showAikoSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddTripBottomSheet(),
    );
  }

  void _showLogFeeBottomSheet(Trip trip) {
    showAikoSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LogFeeBottomSheet(trip: trip),
    );
  }

  void _confirmResetTrip() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            context.l10n.travelResetQuestion,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: Text(
            context.l10n.travelResetConfirm,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.l10n.cancel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                ref.read(travelModeProvider.notifier).resetTrip();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.flight_land, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(child: Text(context.l10n.travelResetDone)),
                      ],
                    ),
                    backgroundColor: AikoColors.primaryBlue,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AikoColors.dangerRed,
              ),
              child: Text(context.l10n.travelReset),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(travelModeProvider);
    final trip = state.activeTrip;

    if (trip == null) {
      // Welcome Placeholder screen with Aiko Character advice
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.txTravelMode)),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            // Aiko Speech Bubble Advice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AikoColors.primaryBlue.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/aiko/aiko_welcome.png',
                    width: 90,
                    height: 90,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.flight_takeoff,
                      size: 90,
                      color: AikoColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.travelIntro,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Premium features highlight
            AikoFeatureItem(
              icon: Icons.flight_takeoff_outlined,
              title: context.l10n.travelTripBudget,
              subtitle: context.l10n.travelTripBudgetDescription,
              accentColor: AikoColors.analyticsTeal,
            ),
            const SizedBox(height: 16),
            AikoFeatureItem(
              icon: Icons.currency_exchange_outlined,
              title: context.l10n.travelFeeTracking,
              subtitle: context.l10n.travelFeeTrackingDescription,
              accentColor: AikoColors.warningOrange,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _showAddTripBottomSheet,
                icon: const Icon(Icons.add_road),
                label: Text(
                  context.l10n.travelEstablishPlan,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AikoColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Active trip dashboard: local fees converted at the current rate plus
    // fees charged in the home currency.
    final spending = tripSpending(trip, state.exchangeRate);
    final spentPercent = spending.spentRatio;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.travelTripTitle(trip.name)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final l10n = context.l10n;
              final notifier = ref.read(travelModeProvider.notifier);
              final updated = await notifier.refreshRate();
              final rate = formatRate(
                ref.read(travelModeProvider).exchangeRate,
                locale: l10n.localeName,
              );
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    updated
                        ? l10n.travelRatesUpdated(
                            trip.homeCurrency,
                            rate,
                            trip.localCurrency,
                          )
                        : l10n.travelRatesOffline(
                            trip.homeCurrency,
                            rate,
                            trip.localCurrency,
                          ),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: context.l10n.travelVerifyRates,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogFeeBottomSheet(trip),
        backgroundColor: AikoColors.analyticsTeal,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: Text(
          context.l10n.travelLogFee,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // Aiko character encouraging bubble
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: spentPercent > 0.8
                    ? AikoColors.dangerRed.withValues(alpha: 0.5)
                    : AikoColors.successGreen.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Image.asset(
                  spentPercent > 0.8
                      ? 'assets/images/aiko/aiko_warning.png'
                      : 'assets/images/aiko/aiko_happy.png',
                  width: 72,
                  height: 72,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.face,
                    size: 72,
                    color: AikoColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    spentPercent > 0.8
                        ? context.l10n.travelBudgetLowWarning
                        : context.l10n.travelEnjoy,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Trip Progress Card
          FinanceCard(
            title: context.l10n.travelBudgetAllocation,
            icon: Icons.flight_takeoff_outlined,
            accentColor: AikoColors.analyticsTeal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.travelBudgetUsed(
                          (spentPercent * 100).toStringAsFixed(0),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: spentPercent > 0.8
                              ? AikoColors.dangerRed
                              : AikoColors.analyticsTeal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        '${spending.spentHome.format()} / ${trip.budget.format()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: spentPercent.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      spentPercent > 0.8
                          ? AikoColors.dangerRed
                          : AikoColors.analyticsTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.travelRemainingBudget,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            spending.remainingHome.format(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AikoColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            context.l10n.travelLocalEquivalent,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            spending.remainingLocal.format(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Exchange slider controls
          FinanceCard(
            title: context.l10n.travelRateCalculator,
            icon: Icons.currency_exchange_outlined,
            accentColor: AikoColors.warningOrange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RateField(trip: trip, rate: state.exchangeRate),
                const SizedBox(height: 8),
                Text(
                  context.l10n.travelSpreadHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fee entries
          FinanceCard(
            title: context.l10n.travelFeeLogs,
            icon: Icons.receipt_long_outlined,
            accentColor: AikoColors.deepBlue,
            child: Column(
              children: [
                if (trip.foreignFees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      context.l10n.travelNoLogs,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  for (final (index, fee) in trip.foreignFees.indexed) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(
                          Icons.restaurant,
                          color: AikoColors.deepBlue,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        fee.merchant ??
                            (fee.currency == trip.localCurrency
                                ? context.l10n.travelLocalMerchant
                                : context.l10n.travelHomeMerchant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        fee.currency == trip.localCurrency
                            ? context.l10n.travelEstHomeValue(
                                localToHome(
                                  fee.amount,
                                  state.exchangeRate,
                                  trip.homeCurrency,
                                ).format(),
                              )
                            : context.l10n.travelDirectHomeCharge,
                        style: const TextStyle(fontSize: 10),
                      ),
                      trailing: Text(
                        fee.amount.format(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (index < trip.foreignFees.length - 1) const Divider(),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Clear active trip
          TextButton.icon(
            onPressed: _confirmResetTrip,
            icon: const Icon(Icons.flight_land, color: AikoColors.dangerRed),
            label: Text(
              context.l10n.travelWipeTrip,
              style: TextStyle(
                color: AikoStatusColors.of(
                  context,
                ).textFor(AikoColors.dangerRed),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AikoFeatureItem extends StatelessWidget {
  const AikoFeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTripBottomSheet extends ConsumerStatefulWidget {
  const _AddTripBottomSheet();

  @override
  ConsumerState<_AddTripBottomSheet> createState() =>
      _AddTripBottomSheetState();
}

class _AddTripBottomSheetState extends ConsumerState<_AddTripBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  String _selectedHomeCurrency = 'THB';
  String _selectedLocalCurrency = 'JPY';

  final List<String> _currencies = [
    'THB',
    'USD',
    'EUR',
    'JPY',
    'GBP',
    'CAD',
    'AUD',
    'SGD',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final trip = Trip(
      name: _nameController.text.trim(),
      homeCurrency: _selectedHomeCurrency,
      localCurrency: _selectedLocalCurrency,
      budget: Money.parse(_budgetController.text.trim(), _selectedHomeCurrency),
    );

    ref.read(travelModeProvider.notifier).createTrip(trip);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.flight_takeoff, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(context.l10n.travelTripStarted(trip.name))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 30,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  Text(
                    context.l10n.travelEstablishTrip,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AikoColors.primaryBlue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              // Trip Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.travelTripNameLabel,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flight_takeoff_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return context.l10n.travelTripNameError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Home Currency
              DropdownButtonFormField<String>(
                initialValue: _selectedHomeCurrency,
                decoration: InputDecoration(
                  labelText: context.l10n.travelHomeCurrency,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                items: _currencies.map((curr) {
                  return DropdownMenuItem<String>(
                    value: curr,
                    child: Text(curr),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedHomeCurrency = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Local Currency
              DropdownButtonFormField<String>(
                initialValue: _selectedLocalCurrency,
                decoration: InputDecoration(
                  labelText: context.l10n.travelLocalCurrency,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_drop_outlined),
                ),
                // Same currency on both sides would count every fee twice.
                validator: (val) => val == _selectedHomeCurrency
                    ? context.l10n.travelSameCurrencyError
                    : null,
                items: _currencies.map((curr) {
                  return DropdownMenuItem<String>(
                    value: curr,
                    child: Text(curr),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedLocalCurrency = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Trip Budget
              TextFormField(
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.travelTotalBudgetLabel,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money_outlined),
                ),
                validator: (val) {
                  if (val == null ||
                      double.tryParse(val.trim()) == null ||
                      double.parse(val.trim()) <= 0) {
                    return context.l10n.travelBudgetError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  label: Text(
                    context.l10n.travelActivate,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AikoColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogFeeBottomSheet extends StatefulWidget {
  const _LogFeeBottomSheet({required this.trip});

  final Trip trip;

  @override
  State<_LogFeeBottomSheet> createState() => _LogFeeBottomSheetState();
}

class _LogFeeBottomSheetState extends State<_LogFeeBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late String _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.trip.localCurrency;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 30,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      Text(
                        context.l10n.travelLogForeignTransaction,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AikoColors.analyticsTeal,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Currency selector toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.travelCurrencyLabel,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment<String>(
                            value: widget.trip.localCurrency,
                            label: Text(widget.trip.localCurrency),
                          ),
                          ButtonSegment<String>(
                            value: widget.trip.homeCurrency,
                            label: Text(widget.trip.homeCurrency),
                          ),
                        ],
                        selected: {_selectedCurrency},
                        onSelectionChanged: (val) {
                          setState(() {
                            _selectedCurrency = val.first;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Amount
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.l10n.travelAmountCharged(
                        _selectedCurrency,
                      ),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.attach_money_outlined),
                    ),
                    validator: (val) {
                      if (val == null ||
                          double.tryParse(val.trim()) == null ||
                          double.parse(val.trim()) <= 0) {
                        return context.l10n.travelAmountError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: context.l10n.travelMerchantDetails,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        final merchant = _descriptionController.text.trim();
                        final fee = TravelFee(
                          amount: Money.parse(
                            _amountController.text.trim(),
                            _selectedCurrency,
                          ),
                          merchant: merchant.isEmpty ? null : merchant,
                        );
                        ref
                            .read(travelModeProvider.notifier)
                            .addForeignFee(fee);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.l10n.travelFeeLogged(
                                      fee.amount.format(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: Text(
                        context.l10n.travelAddExpense,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AikoColors.analyticsTeal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The trip's `1 home = rate local` exchange rate as a number field. Every
/// valid edit updates the totals right away; the rate is saved (and synced)
/// only when the user submits or leaves the field.
class _RateField extends ConsumerStatefulWidget {
  const _RateField({required this.trip, required this.rate});

  final Trip trip;
  final double rate;

  @override
  ConsumerState<_RateField> createState() => _RateFieldState();
}

class _RateFieldState extends ConsumerState<_RateField> {
  late final _controller = TextEditingController(text: _editable(widget.rate));
  final _focusNode = FocusNode();
  var _invalid = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  @override
  void didUpdateWidget(_RateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refreshed live rate replaces the text unless the user is typing.
    if (!_focusNode.hasFocus && widget.rate != oldWidget.rate) {
      _controller.text = _editable(widget.rate);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Plain digits for editing: 4 significant digits, whole number from 1,000.
  static String _editable(double rate) => rate >= 1000
      ? rate.toStringAsFixed(0)
      : double.parse(rate.toStringAsPrecision(4)).toString();

  double? get _parsed {
    final value = double.tryParse(_controller.text.trim());
    return value != null && value > 0 && value.isFinite ? value : null;
  }

  void _onChanged(String _) {
    final value = _parsed;
    setState(() => _invalid = value == null);
    if (value != null) {
      ref
          .read(travelModeProvider.notifier)
          .updateExchangeRate(value, persist: false);
    }
  }

  void _commit() {
    final value = _parsed;
    if (value == null) {
      _controller.text = _editable(ref.read(travelModeProvider).exchangeRate);
      setState(() => _invalid = false);
      return;
    }
    ref.read(travelModeProvider.notifier).updateExchangeRate(value);
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onChanged: _onChanged,
      onSubmitted: (_) => _commit(),
      onTapOutside: (_) => _focusNode.unfocus(),
      decoration: InputDecoration(
        labelText: context.l10n.travelSpotRate,
        prefixText: '1 ${trip.homeCurrency} = ',
        suffixText: trip.localCurrency,
        errorText: _invalid ? context.l10n.enterPositiveNumber : null,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
