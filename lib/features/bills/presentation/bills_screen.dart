import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../../categories/domain/category.dart';
import '../../../app/providers.dart';
import '../application/subscription_cancellation_service.dart';
import '../application/subscription_suggestion_service.dart';
import '../domain/bill_subscription.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  static const _service = SubscriptionSuggestionService();
  String _selectedCancellationGuideMerchant = 'Streaming Plus';

  void _showCancellationDialog(BuildContext context, String merchantName) {
    final nameController = TextEditingController(text: 'John Doe');
    final emailController = TextEditingController(text: 'johndoe@example.com');
    final idController = TextEditingController(text: 'SUB-123456');
    final reasonController = TextEditingController(text: 'No longer using the service.');

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Cancel $merchantName',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AikoColors.deepBlue),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Aiko will generate a formal, legally structured cancellation letter and trigger the system share sheet to send it to the merchant.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Your Email Address',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: 'Account / Subscription ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Cancelling',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                const cancellationService = SubscriptionCancellationService();
                await cancellationService.shareCancellationLetter(
                  merchantName: merchantName,
                  subscriberName: nameController.text.trim(),
                  subscriberEmail: emailController.text.trim(),
                  accountId: idController.text.trim(),
                  cancellationReason: reasonController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Generate & Share'),
              style: FilledButton.styleFrom(backgroundColor: AikoColors.deepBlue),
            ),
          ],
        );
      },
    );
  }

  void _showAddBillBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddBillBottomSheet(),
    );
  }

  void _confirmDeleteBill(BillSubscription bill) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Remove ${bill.merchant}?',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AikoColors.darkNavy),
          ),
          content: Text(
            'Are you sure you want to stop tracking or delete the subscription for ${bill.merchant}? This does not automatically cancel it with the merchant.',
            style: const TextStyle(color: AikoColors.neutralInk, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AikoColors.mutedText)),
            ),
            FilledButton(
              onPressed: () {
                ref.read(billSubscriptionsProvider.notifier).deleteBillSubscription(bill.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Deleted ${bill.merchant} subscription tracker.'),
                      ],
                    ),
                    backgroundColor: AikoColors.successGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AikoColors.dangerRed),
              child: const Text('Delete Tracker'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billSubscriptionsProvider);

    return Scaffold(
      backgroundColor: AikoColors.appBackgroundLight,
      appBar: AppBar(title: const Text('Bills & Subscriptions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBillBottomSheet,
        backgroundColor: AikoColors.primaryBlue,
        icon: const Icon(Icons.calendar_month, color: Colors.white),
        label: const Text('Add Bill / Subscription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: billsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading subscriptions: $err')),
        data: (bills) {
          double monthlyTotal = 0;
          for (final bill in bills) {
            final double val = bill.amount.amount.toDouble();
            monthlyTotal += switch (bill.billingCycle) {
              BillingCycle.weekly => val * 4.33,
              BillingCycle.monthly => val,
              BillingCycle.yearly => val / 12,
            };
          }

          // Aiko Character dynamic expressions & bubble advisor
          String aikoExpression;
          String aikoSpeech;
          Color aikoBubbleBorder;

          if (monthlyTotal > 100) {
            aikoExpression = 'assets/images/aiko/aiko_warning.png';
            aikoSpeech = "Aiko warning: Your monthly recurring subscriptions total \$${monthlyTotal.toStringAsFixed(0)}! Let's use the cancellation assistant below to clear unutilized services.";
            aikoBubbleBorder = AikoColors.warningOrange;
          } else if (bills.isEmpty) {
            aikoExpression = 'assets/images/aiko/aiko_thinking.png';
            aikoSpeech = "Aiko thoughts: You haven't added any recurring subscriptions yet. Add your Netflix, gym, or software plans to get proactive price alerts!";
            aikoBubbleBorder = AikoColors.primaryBlue;
          } else {
            aikoExpression = 'assets/images/aiko/aiko_happy.png';
            aikoSpeech = "Healthy recurring spending! Your total monthly bills are \$${monthlyTotal.toStringAsFixed(0)}. Keeping sub-items cataloged is a great way to avoid trial traps!";
            aikoBubbleBorder = AikoColors.successGreen;
          }

          // Dynamic calculation of alerts
          final current = bills;
          final previous = bills.map((b) {
            // Mock previous bills to calculate price change alerts
            if (b.merchant == 'Streaming Plus') {
              return BillSubscription(
                merchant: b.merchant,
                amount: Money.parse('14', b.amount.currency),
                billingCycle: b.billingCycle,
                nextBillingDate: b.nextDueDate.subtract(const Duration(days: 30)),
              );
            }
            return b;
          }).toList();

          final alerts = [
            ..._service.priceChangeAlerts(
              currentBills: current,
              previousBills: previous,
            ),
            ..._service.trialEndingAlerts(current, now: DateTime(2026, 5, 22)),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              // Aiko Speech Bubble Advice
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
                          fontSize: 13,
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

              // Upcoming bills list
              FinanceCard(
                title: 'Upcoming bills',
                icon: Icons.event_available_outlined,
                accentColor: AikoColors.warningOrange,
                child: Column(
                  children: [
                    if (bills.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No upcoming bills registered.',
                          style: TextStyle(color: AikoColors.mutedText, fontSize: 13),
                        ),
                      )
                    else
                      for (final bill in bills) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(bill.merchant, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Text(
                                  'Due: ${DateFormat('yyyy-MM-dd').format(bill.nextDueDate)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AikoColors.primaryBlue.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    bill.billingCycle.name.toUpperCase(),
                                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AikoColors.primaryBlue),
                                  ),
                                )
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                bill.amount.format(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AikoColors.darkNavy),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AikoColors.mutedText, size: 18),
                                onPressed: () => _confirmDeleteBill(bill),
                                tooltip: 'Remove subscription',
                              )
                            ],
                          ),
                        ),
                        if (bill != bills.last) const Divider(),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const FinanceCard(
                title: 'Lower your bills',
                icon: Icons.savings_outlined,
                accentColor: AikoColors.successGreen,
                child: Text('Aiko tracks price adjustments and identifies negotiation or lower bill tier opportunities.'),
              ),

              const SizedBox(height: 16),

              // Dynamic Subscription review
              FinanceCard(
                title: 'Subscription review',
                icon: Icons.savings_outlined,
                accentColor: AikoColors.successGreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (alerts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, color: AikoColors.successGreen, size: 18),
                            SizedBox(width: 8),
                            Text('No pricing flags or trial ending alerts.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      for (final alert in alerts) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(alert.merchant, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(alert.message, style: const TextStyle(fontSize: 11)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AikoColors.dangerRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Save \$${alert.estimatedAnnualSavings.round()}/yr',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AikoColors.dangerRed,
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

              // Dynamic Subscription cancellation assistant
              FinanceCard(
                title: 'Subscription cancellation assistant',
                icon: Icons.subscriptions_outlined,
                accentColor: AikoColors.deepBlue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select a merchant to review custom cancel strategies generated by Aiko:',
                      style: TextStyle(fontSize: 12, color: AikoColors.mutedText, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    // Guide selector
                    Row(
                      children: [
                        const Text('Guide for: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                                value: bills.any((b) => b.merchant == _selectedCancellationGuideMerchant)
                                    ? _selectedCancellationGuideMerchant
                                    : (bills.isNotEmpty ? bills.first.merchant : 'Streaming Plus'),
                                items: [
                                  if (!bills.any((b) => b.merchant == 'Streaming Plus'))
                                    const DropdownMenuItem<String>(
                                      value: 'Streaming Plus',
                                      child: Text('Streaming Plus'),
                                    ),
                                  ...bills.map((b) => DropdownMenuItem<String>(
                                    value: b.merchant,
                                    child: Text(b.merchant),
                                  ))
                                ],
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() {
                                    _selectedCancellationGuideMerchant = val;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final step in _service.cancellationGuide(_selectedCancellationGuideMerchant)) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AikoColors.primaryBlue)),
                            Expanded(child: Text(step, style: const TextStyle(height: 1.3, fontSize: 12))),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _showCancellationDialog(context, _selectedCancellationGuideMerchant),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Generate Cancellation Email'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AikoColors.deepBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddBillBottomSheet extends ConsumerStatefulWidget {
  const _AddBillBottomSheet();

  @override
  ConsumerState<_AddBillBottomSheet> createState() => _AddBillBottomSheetState();
}

class _AddBillBottomSheetState extends ConsumerState<_AddBillBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueDateController = TextEditingController();

  BillingCycle _selectedCycle = BillingCycle.monthly;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  String? _selectedCategoryId;
  bool _reminderEnabled = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dueDateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(), // Restrict calendar to future dates only
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AikoColors.primaryBlue,
              onPrimary: Colors.white,
              onSurface: AikoColors.darkNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final merchant = _merchantController.text.trim();
      final amountVal = _amountController.text.trim();

      final bill = BillSubscription(
        id: 'bill-${DateTime.now().millisecondsSinceEpoch}',
        userId: 'session-default',
        merchant: merchant,
        amount: Money.parse(amountVal, 'USD'),
        billingCycle: _selectedCycle,
        nextDueDate: _selectedDate,
        categoryId: _selectedCategoryId,
        reminderEnabled: _reminderEnabled,
      );

      await ref.read(billSubscriptionsProvider.notifier).addBillSubscription(bill);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Successfully scheduled bill for $merchant!'),
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
            content: Text('Failed to schedule bill: ${e.toString()}'),
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
    final categoriesAsync = ref.watch(categoriesProvider);

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
                    'Create Bill or Subscription',
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
              // Merchant Name
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant / Subscription Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a valid merchant name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Due (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money_outlined),
                ),
                validator: (val) {
                  if (val == null || double.tryParse(val.trim()) == null || double.parse(val.trim()) <= 0) {
                    return 'Please enter a valid positive decimal amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Billing Cycle
              DropdownButtonFormField<BillingCycle>(
                value: _selectedCycle,
                decoration: const InputDecoration(
                  labelText: 'Billing Cycle',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat_outlined),
                ),
                items: BillingCycle.values.map((cycle) {
                  return DropdownMenuItem<BillingCycle>(
                    value: cycle,
                    child: Text(cycle.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCycle = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Date picker
              TextFormField(
                controller: _dueDateController,
                readOnly: true,
                onTap: _selectDate,
                decoration: const InputDecoration(
                  labelText: 'Next Due Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: 16),
              // Categories dropdown
              categoriesAsync.when(
                loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
                data: (categories) {
                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category Link',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag_outlined),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat.id,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategoryId = val;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              // Reminders toggle
              SwitchListTile(
                title: const Text('Enable proactive notifications', style: TextStyle(fontSize: 14)),
                value: _reminderEnabled,
                activeColor: AikoColors.primaryBlue,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() {
                    _reminderEnabled = val;
                  });
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
                      : const Icon(Icons.check),
                  label: const Text('Schedule Bill Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
