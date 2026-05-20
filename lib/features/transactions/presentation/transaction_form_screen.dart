import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/transaction.dart';
import 'transaction_attachment_section.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key});

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'expense';

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submitForm() {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Please enter an amount.'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Please enter a valid positive amount.'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final accountsAsync = ref.read(accountsProvider);
    String? accountId;
    if (accountsAsync.hasValue && accountsAsync.value!.isNotEmpty) {
      final active = accountsAsync.value!.where((a) => a.isActive).toList();
      accountId = active.isNotEmpty
          ? active.first.id
          : accountsAsync.value!.first.id;
    }
    accountId ??= (AikoSupabase.tryClient()?.auth.currentUser != null
        ? '10000000-0000-0000-0000-000000000001'
        : 'cash');

    final categoriesAsync = ref.read(categoriesProvider);
    String? categoryId;
    if (categoriesAsync.hasValue && categoriesAsync.value!.isNotEmpty) {
      final active = categoriesAsync.value!.where((c) => c.isActive).toList();
      categoryId = active.isNotEmpty
          ? active.first.id
          : categoriesAsync.value!.first.id;
    }
    categoryId ??= (AikoSupabase.tryClient()?.auth.currentUser != null
        ? '20000000-0000-0000-0000-000000000001'
        : 'food');

    final txType = switch (_type) {
      'income' => TransactionType.income,
      'transfer' => TransactionType.transfer,
      _ => TransactionType.expense,
    };

    final newTx = FinanceTransaction(
      id: const Uuid().v4(),
      userId: AikoSupabase.tryClient()?.auth.currentUser?.id ?? 'demo-user',
      accountId: accountId,
      type: txType,
      amount: Money.parse(amount.toString(), 'USD'),
      date: DateTime.now(),
      categoryId: categoryId,
      merchant: _merchantController.text.trim(),
      note: _noteController.text.trim(),
    );

    ref.read(transactionsProvider.notifier).addTransaction(newTx);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Transaction saved successfully!'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add transaction'),
        actions: [
          TextButton(
            onPressed: _submitForm,
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          DropdownMenu<String>(
            initialSelection: _type,
            expandedInsets: EdgeInsets.zero,
            label: const Text('Type'),
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'expense', label: 'Expense'),
              DropdownMenuEntry(value: 'income', label: 'Income'),
              DropdownMenuEntry(value: 'transfer', label: 'Transfer'),
            ],
            onSelected: (value) {
              if (value != null) {
                setState(() => _type = value);
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _merchantController,
            decoration: const InputDecoration(labelText: 'Merchant'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: 16),
          const TransactionAttachmentSection(attachments: []),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submitForm,
            icon: const Icon(Icons.check),
            label: const Text('Save Transaction'),
          ),
        ],
      ),
    );
  }
}
