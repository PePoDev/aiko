import 'package:flutter/material.dart';

import 'transaction_attachment_section.dart';

class TransactionFormScreen extends StatelessWidget {
  const TransactionFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          TextField(
            decoration: InputDecoration(labelText: 'Amount'),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          SizedBox(height: 12),
          DropdownMenu<String>(
            label: Text('Type'),
            dropdownMenuEntries: [
              DropdownMenuEntry(value: 'expense', label: 'Expense'),
              DropdownMenuEntry(value: 'income', label: 'Income'),
              DropdownMenuEntry(value: 'transfer', label: 'Transfer'),
            ],
          ),
          SizedBox(height: 12),
          TextField(decoration: InputDecoration(labelText: 'Merchant')),
          SizedBox(height: 12),
          TextField(decoration: InputDecoration(labelText: 'Note')),
          SizedBox(height: 12),
          TransactionAttachmentSection(attachments: []),
        ],
      ),
    );
  }
}
