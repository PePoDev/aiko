import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/trip.dart';
import '../application/travel_mode_provider.dart';
import '../application/travel_mode_service.dart';

class TravelModeScreen extends ConsumerStatefulWidget {
  const TravelModeScreen({super.key});

  @override
  ConsumerState<TravelModeScreen> createState() => _TravelModeScreenState();
}

class _TravelModeScreenState extends ConsumerState<TravelModeScreen> {
  static const _service = TravelModeService();

  void _showAddTripBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddTripBottomSheet(),
    );
  }

  void _showLogFeeBottomSheet(Trip trip) {
    showModalBottomSheet<void>(
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Reset Trip Plan?',
            style: TextStyle(fontWeight: FontWeight.bold, color: AikoColors.darkNavy),
          ),
          content: const Text(
            'Are you sure you want to end your trip tracking and wipe out all recorded travel fees? This action is permanent.',
            style: TextStyle(color: AikoColors.neutralInk, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AikoColors.mutedText)),
            ),
            FilledButton(
              onPressed: () {
                ref.read(travelModeProvider.notifier).resetTrip();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.flight_land, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Trip logs reset. Welcome back home!'),
                      ],
                    ),
                    backgroundColor: AikoColors.primaryBlue,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AikoColors.dangerRed),
              child: const Text('Reset Travel Mode'),
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
        backgroundColor: AikoColors.appBackgroundLight,
        appBar: AppBar(title: const Text('Travel Mode')),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            // Aiko Speech Bubble Advice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AikoColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AikoColors.primaryBlue.withOpacity(0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AikoColors.border.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/aiko/aiko_welcome.png',
                    width: 90,
                    height: 90,
                    errorBuilder: (_, __, ___) => const Icon(Icons.flight_takeoff, size: 90, color: AikoColors.primaryBlue),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Aiko welcomes you! Planning a trip abroad? We can establish a dedicated travel budget, log currency-aware foreign transaction fees, and keep spending drift under check! Let's get started!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AikoColors.darkNavy,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Premium features highlight
            const AikoFeatureItem(
              icon: Icons.flight_takeoff_outlined,
              title: 'Trip budget',
              subtitle: 'Plan in home currency and track expenses in local trip currency.',
              accentColor: AikoColors.analyticsTeal,
            ),
            const SizedBox(height: 16),
            const AikoFeatureItem(
              icon: Icons.currency_exchange_outlined,
              title: 'Foreign Fee & Drift Tracking',
              subtitle: 'Monitor bad exchange rates, bank surcharges, and credit card fee drag.',
              accentColor: AikoColors.warningOrange,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _showAddTripBottomSheet,
                icon: const Icon(Icons.add_road),
                label: const Text('Establish Trip Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: FilledButton.styleFrom(backgroundColor: AikoColors.primaryBlue),
              ),
            ),
          ],
        ),
      );
    }

    // Active trip dashboard
    final totalFees = _service.totalForeignFees(trip);
    
    // Converted math using live slider exchange rate
    // Spent total = Sum of all logged foreign fees
    final double totalSpentLocal = trip.foreignFees
        .where((f) => f.currency == trip.localCurrency)
        .fold(0.0, (sum, f) => sum + f.amount.toDouble());
        
    final double totalSpentHome = trip.foreignFees
        .where((f) => f.currency == trip.homeCurrency)
        .fold(0.0, (sum, f) => sum + f.amount.toDouble());

    // Converted Spent = local fees converted to Home + home fees directly
    final double convertedSpentHome = (totalSpentLocal / state.exchangeRate) + totalSpentHome;
    final double budgetHomeVal = trip.budget.amount.toDouble();
    final double remainingHomeVal = (budgetHomeVal - convertedSpentHome).clamp(0.0, budgetHomeVal);
    final double spentPercent = budgetHomeVal > 0 ? (convertedSpentHome / budgetHomeVal) : 0.0;

    return Scaffold(
      backgroundColor: AikoColors.appBackgroundLight,
      appBar: AppBar(
        title: Text('${trip.name} Trip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Updated spot rates: 1 ${trip.homeCurrency} = ${state.exchangeRate.toStringAsFixed(2)} ${trip.localCurrency}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Verify exchange rates',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogFeeBottomSheet(trip),
        backgroundColor: AikoColors.analyticsTeal,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text('Log Foreign Fee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // Aiko character encouraging bubble
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: spentPercent > 0.8 ? AikoColors.dangerRed.withOpacity(0.5) : AikoColors.successGreen.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Image.asset(
                  spentPercent > 0.8 ? 'assets/images/aiko/aiko_warning.png' : 'assets/images/aiko/aiko_happy.png',
                  width: 72,
                  height: 72,
                  errorBuilder: (_, __, ___) => const Icon(Icons.face, size: 72, color: AikoColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    spentPercent > 0.8
                        ? "Aiko Warning: Trip budget is almost depleted! Let's watch out for those high airport currency exchanges!"
                        : "Enjoy your travels! Aiko is tracking exchange surcharges automatically. Keep a look out for fees!",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AikoColors.darkNavy, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Trip Progress Card
          FinanceCard(
            title: 'Trip Budget Allocation',
            icon: Icons.flight_takeoff_outlined,
            accentColor: AikoColors.analyticsTeal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(spentPercent * 100).toStringAsFixed(0)}% Budget Used',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: spentPercent > 0.8 ? AikoColors.dangerRed : AikoColors.analyticsTeal,
                      ),
                    ),
                    Text(
                      '\$${convertedSpentHome.toStringAsFixed(0)} / \$${budgetHomeVal.toStringAsFixed(0)} ${trip.homeCurrency}',
                      style: const TextStyle(color: AikoColors.mutedText, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: spentPercent.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AikoColors.surfacePanel,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      spentPercent > 0.8 ? AikoColors.dangerRed : AikoColors.analyticsTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Remaining Budget', style: TextStyle(fontSize: 11, color: AikoColors.mutedText)),
                        const SizedBox(height: 2),
                        Text(
                          '\$${remainingHomeVal.toStringAsFixed(2)} ${trip.homeCurrency}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AikoColors.successGreen),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Local Est. Equivalent', style: TextStyle(fontSize: 11, color: AikoColors.mutedText)),
                        const SizedBox(height: 2),
                        Text(
                          '${(remainingHomeVal * state.exchangeRate).toStringAsFixed(0)} ${trip.localCurrency}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AikoColors.neutralInk),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Exchange slider controls
          FinanceCard(
            title: 'Interactive Exchange Rate Calculator',
            icon: Icons.currency_exchange_outlined,
            accentColor: AikoColors.warningOrange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Spot Exchange Rate:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      '1 ${trip.homeCurrency} = ${state.exchangeRate.toStringAsFixed(2)} ${trip.localCurrency}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AikoColors.warningOrange, fontSize: 15),
                    ),
                  ],
                ),
                Slider(
                  value: state.exchangeRate.clamp(0.1, 300.0),
                  min: 0.1,
                  max: 300.0,
                  activeColor: AikoColors.warningOrange,
                  inactiveColor: AikoColors.borderSubtle,
                  onChanged: (val) {
                    ref.read(travelModeProvider.notifier).updateExchangeRate(val);
                  },
                ),
                const Text(
                  'Adjust the slider to simulate custom bank spread markup. Fluctuations recalculate spent conversions dynamically.',
                  style: TextStyle(fontSize: 11, color: AikoColors.mutedText, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fee entries
          FinanceCard(
            title: 'Travel Fee Logs',
            icon: Icons.receipt_long_outlined,
            accentColor: AikoColors.deepBlue,
            child: Column(
              children: [
                if (trip.foreignFees.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No transaction logs found for this trip.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                else
                  for (final fee in trip.foreignFees) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AikoColors.appBackgroundLight,
                        child: Icon(Icons.restaurant, color: AikoColors.deepBlue, size: 20),
                      ),
                      title: Text(
                        fee.currency == trip.localCurrency
                            ? 'Local Merchant'
                            : 'Home Currency Merchant',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        fee.currency == trip.localCurrency
                            ? 'Est. Home value: \$${(fee.amount.toDouble() / state.exchangeRate).toStringAsFixed(2)} ${trip.homeCurrency}'
                            : 'Direct Home Charge',
                        style: const TextStyle(fontSize: 10),
                      ),
                      trailing: Text(
                        fee.format(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AikoColors.darkNavy),
                      ),
                    ),
                    if (fee != trip.foreignFees.last) const Divider(),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Clear active trip
          TextButton.icon(
            onPressed: _confirmResetTrip,
            icon: const Icon(Icons.flight_land, color: AikoColors.dangerRed),
            label: const Text('Wipe / Complete Trip', style: TextStyle(color: AikoColors.dangerRed, fontWeight: FontWeight.bold)),
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
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AikoColors.border.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AikoColors.darkNavy)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AikoColors.mutedText, height: 1.3)),
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
  ConsumerState<_AddTripBottomSheet> createState() => _AddTripBottomSheetState();
}

class _AddTripBottomSheetState extends ConsumerState<_AddTripBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  String _selectedHomeCurrency = 'USD';
  String _selectedLocalCurrency = 'JPY';

  final List<String> _currencies = ['USD', 'EUR', 'JPY', 'GBP', 'CAD', 'AUD', 'SGD'];

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
            Text('Bon voyage! Active trip established for ${trip.name}.'),
          ],
        ),
        backgroundColor: AikoColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                    'Establish Travel Trip',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AikoColors.primaryBlue),
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
                decoration: const InputDecoration(
                  labelText: 'Trip Name (e.g. Tokyo Spring 2026)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flight_takeoff_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a valid trip name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Home Currency
              DropdownButtonFormField<String>(
                value: _selectedHomeCurrency,
                decoration: const InputDecoration(
                  labelText: 'Home Currency',
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
                value: _selectedLocalCurrency,
                decoration: const InputDecoration(
                  labelText: 'Local Travel Currency',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_drop_outlined),
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
                      _selectedLocalCurrency = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Trip Budget
              TextFormField(
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total Trip Budget (in home currency)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money_outlined),
                ),
                validator: (val) {
                  if (val == null || double.tryParse(val.trim()) == null || double.parse(val.trim()) <= 0) {
                    return 'Please enter a positive numeric trip budget';
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
                  label: const Text('Activate Trip Tracking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: FilledButton.styleFrom(backgroundColor: AikoColors.primaryBlue),
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
                        'Log Foreign Transaction',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AikoColors.analyticsTeal),
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
                      const Text('Currency:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount Charged ($_selectedCurrency)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.attach_money_outlined),
                    ),
                    validator: (val) {
                      if (val == null || double.tryParse(val.trim()) == null || double.parse(val.trim()) <= 0) {
                        return 'Please enter a valid positive decimal amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Merchant / Surcharge Details',
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
                        final fee = Money.parse(_amountController.text.trim(), _selectedCurrency);
                        ref.read(travelModeProvider.notifier).addForeignFee(fee);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 8),
                                Text('Logged travel fee of ${fee.format()}!'),
                              ],
                            ),
                            backgroundColor: AikoColors.successGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Travel Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: FilledButton.styleFrom(backgroundColor: AikoColors.analyticsTeal),
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
