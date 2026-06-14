import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../../../core/money/money.dart';
import '../../../../../features/assets/domain/asset.dart';
import '../../../domain/account_details.dart';
import '../../../domain/account_validation_messages.dart';
import 'account_subform.dart';

class AssetSubform extends AccountSubform {
  const AssetSubform({
    super.key,
    required this.initial,
    required this.currency,
    required this.onChanged,
  });
  final AssetDetails initial;
  final String currency;
  final ValueChanged<AssetDetails> onChanged;

  @override
  ConsumerState<AssetSubform> createState() => _AssetSubformState();
}

class _AssetSubformState extends AccountSubformState<AssetSubform> {
  late AssetClass _class;
  late final TextEditingController _price;
  DateTime? _date;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _class = widget.initial.assetClass;
    _price = TextEditingController(
      text: widget.initial.purchasePrice?.amount.toString() ?? '',
    );
    _date = widget.initial.purchaseDate;
    _notes = TextEditingController(text: widget.initial.notes ?? '');
    _price.addListener(_emit);
    _notes.addListener(_emit);
  }

  void _emit() {
    widget.onChanged(
      AssetDetails(
        assetClass: _class,
        purchasePrice: _price.text.trim().isEmpty
            ? null
            : Money.parse(_price.text.trim(), widget.currency),
        purchaseDate: _date,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! AssetDetails) return;
    setState(() {
      _class = initial.assetClass;
      _price.text = initial.purchasePrice?.amount.toString() ?? '';
      _date = initial.purchaseDate;
      _notes.text = initial.notes ?? '';
    });
  }

  @override
  AccountDetails getDetails() => AssetDetails(
    assetClass: _class,
    purchasePrice: _price.text.trim().isEmpty
        ? null
        : Money.parse(_price.text.trim(), widget.currency),
    purchaseDate: _date,
    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
  );

  @override
  String? validate() {
    if (_price.text.trim().isNotEmpty && _date == null) {
      return AccountValidationMessages.purchaseDateRequired;
    }
    return null;
  }

  @override
  void dispose() {
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _dateLabel() {
    final d = _date;
    if (d == null) return 'Tap to choose';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AssetClass>(
          initialValue: _class,
          decoration: const InputDecoration(
            labelText: 'Asset class',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: AssetClass.values
              .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _class = v);
              _emit();
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Purchase price (optional)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              initialDate: _date ?? DateTime.now(),
            );
            if (picked != null) {
              setState(() => _date = picked);
              _emit();
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Purchase date',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(_dateLabel()),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
      ],
    );
  }
}
