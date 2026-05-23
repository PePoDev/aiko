import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/aiko_colors.dart';
import '../../../shared/widgets/finance_card.dart';
import '../application/tax_document_vault_service.dart';

class TaxDeductionItem {
  TaxDeductionItem({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    this.isSelected = true,
  });

  final String id;
  final String name;
  final String category;
  double amount;
  bool isSelected;
}

class TaxCenterScreen extends ConsumerStatefulWidget {
  const TaxCenterScreen({super.key});

  @override
  ConsumerState<TaxCenterScreen> createState() => _TaxCenterScreenState();
}

class _TaxCenterScreenState extends ConsumerState<TaxCenterScreen> {
  double _grossIncome = 75000.0;
  double _taxRatePercent = 22.0;

  final List<TaxDeductionItem> _deductions = [
    TaxDeductionItem(id: 'home_office', name: 'Home Office Deduction', category: 'Schedule C', amount: 1500.0),
    TaxDeductionItem(id: 'software', name: 'Software & Subscriptions (Aiko Pro, etc.)', category: 'Schedule C', amount: 360.0),
    TaxDeductionItem(id: 'vehicle', name: 'Business Mileage (Standard Rate)', category: 'Schedule C', amount: 850.0),
    TaxDeductionItem(id: 'internet', name: 'Internet & Phone (Business portion)', category: 'Schedule C', amount: 480.0),
    TaxDeductionItem(id: 'supplies', name: 'Office Supplies & Hardware', category: 'Schedule C', amount: 250.0),
    TaxDeductionItem(id: 'meals', name: 'Business Meals (50% rule)', category: 'Schedule C', amount: 180.0),
  ];

  final _incomeController = TextEditingController(text: '75000');
  final _taxRateController = TextEditingController(text: '22');
  final _customDeductionNameController = TextEditingController();
  final _customDeductionAmountController = TextEditingController();

  final _vaultService = const TaxDocumentVaultService();
  List<String> _documents = [];
  bool _isLoadingDocs = true;
  bool _isUploading = false;
  String? _uploadStatusMessage;

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoadingDocs = true;
    });
    try {
      final docs = await _vaultService.listDocuments(userId: 'user_123');
      setState(() {
        _documents = docs;
        _isLoadingDocs = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDocs = false;
      });
    }
  }

  Future<void> _uploadDocument(String fileName) async {
    setState(() {
      _isUploading = true;
      _uploadStatusMessage = 'Uploading $fileName...';
    });
    
    try {
      final bytes = [0, 1, 2, 3];
      await _vaultService.uploadDocument(
        fileName: fileName,
        fileBytes: bytes,
        userId: 'user_123',
      );
      
      final updatedDocs = await _vaultService.listDocuments(userId: 'user_123');
      
      setState(() {
        _documents = updatedDocs;
        if (!_documents.contains(fileName)) {
          _documents.add(fileName);
        }
        _isUploading = false;
        _uploadStatusMessage = null;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fileName uploaded successfully to encrypted cloud vault!'),
          backgroundColor: AikoColors.successGreen,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatusMessage = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to upload document.'),
          backgroundColor: AikoColors.dangerRed,
        ),
      );
    }
  }

  void _showUploadPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Upload Tax Document',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AikoColors.primaryBlue,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Select a document template to simulate a secure PDF upload to your encrypted cloud vault.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: AikoColors.analyticsTeal),
                title: const Text('Form 1099-DIV (Dividend Income)'),
                subtitle: const Text('1099_DIV_Brokerage.pdf'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadDocument('1099_DIV_Brokerage.pdf');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.badge_outlined, color: AikoColors.primaryBlue),
                title: const Text('Form W-2 (Wage & Tax Statement)'),
                subtitle: const Text('W2_Form_2026.pdf'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadDocument('W2_Form_2026.pdf');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.savings_outlined, color: AikoColors.successGreen),
                title: const Text('Form 1099-INT (Interest Income)'),
                subtitle: const Text('1099_INT_Savings.pdf'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadDocument('1099_INT_Savings.pdf');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined, color: AikoColors.premiumPurple),
                title: const Text('Custom Expense PDF Receipt'),
                subtitle: const Text('Custom_Receipt.pdf'),
                onTap: () {
                  Navigator.pop(context);
                  final ts = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
                  _uploadDocument('Custom_Tax_Receipt_$ts.pdf');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _incomeController.addListener(() {
      setState(() {
        _grossIncome = double.tryParse(_incomeController.text) ?? 0.0;
      });
    });
    _taxRateController.addListener(() {
      setState(() {
        _taxRatePercent = double.tryParse(_taxRateController.text) ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _taxRateController.dispose();
    _customDeductionNameController.dispose();
    _customDeductionAmountController.dispose();
    super.dispose();
  }

  void _showAddDeductionDialog() {
    _customDeductionNameController.clear();
    _customDeductionAmountController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AikoColors.white,
        title: const Text(
          'Add Custom Deduction',
          style: TextStyle(color: AikoColors.darkNavy, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customDeductionNameController,
              decoration: const InputDecoration(labelText: 'Deduction Name (e.g. Marketing)'),
            ),
            TextField(
              controller: _customDeductionAmountController,
              decoration: const InputDecoration(labelText: 'Amount (\$)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AikoColors.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AikoColors.primaryBlue),
            onPressed: () {
              final name = _customDeductionNameController.text;
              final amount = double.tryParse(_customDeductionAmountController.text) ?? 0.0;
              if (name.isNotEmpty && amount > 0) {
                setState(() {
                  _deductions.add(
                    TaxDeductionItem(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      category: 'Custom Schedule C',
                      amount: amount,
                    ),
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalDeductions = 0.0;
    for (final item in _deductions) {
      if (item.isSelected) {
        totalDeductions += item.amount;
      }
    }

    final taxableIncome = max(0.0, _grossIncome - totalDeductions);
    final estimatedTax = taxableIncome * (_taxRatePercent / 100);
    final taxSavings = totalDeductions * (_taxRatePercent / 100);

    return Scaffold(
      backgroundColor: AikoColors.appBackgroundLight,
      appBar: AppBar(
        title: const Text('Tax Center & Estimates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart),
            onPressed: _showAddDeductionDialog,
            tooltip: 'Add Custom Deduction',
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          // Aiko Advice Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AikoColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AikoColors.analyticsTeal.withOpacity(0.5), width: 1.5),
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
                  'assets/images/aiko/aiko_thinking.png',
                  width: 72,
                  height: 72,
                  errorBuilder: (_, __, ___) => const Icon(Icons.face_5, size: 72, color: AikoColors.analyticsTeal),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Hi! Welcome to your Aiko Tax Center. Every eligible business deduction reduces your taxable income, putting money back in your pocket! Let's estimate your quarterly liability.",
                    style: TextStyle(
                      fontSize: 14,
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

          // Interactive Income & Bracket inputs
          FinanceCard(
            title: 'Income & Tax Details',
            icon: Icons.account_balance_outlined,
            accentColor: AikoColors.primaryBlue,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _incomeController,
                        decoration: const InputDecoration(
                          labelText: 'Estimated Gross Income (\$)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _taxRateController,
                        decoration: const InputDecoration(
                          labelText: 'Effective Tax Rate (%)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tax Estimates Calculator Card
          FinanceCard(
            title: 'Tax estimates',
            icon: Icons.request_quote_outlined,
            accentColor: AikoColors.analyticsTeal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Est. Tax Liability', style: TextStyle(fontSize: 11, color: AikoColors.mutedText)),
                        const SizedBox(height: 4),
                        Text(
                          '\$${estimatedTax.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AikoColors.dangerRed),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 40, color: AikoColors.borderSubtle),
                    Column(
                      children: [
                        const Text('Total Deductions', style: TextStyle(fontSize: 11, color: AikoColors.mutedText)),
                        const SizedBox(height: 4),
                        Text(
                          '\$${totalDeductions.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AikoColors.primaryBlue),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 40, color: AikoColors.borderSubtle),
                    Column(
                      children: [
                        const Text('Tax Savings', style: TextStyle(fontSize: 11, color: AikoColors.mutedText)),
                        const SizedBox(height: 4),
                        Text(
                          '\$${taxSavings.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AikoColors.successGreen),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Net Taxable Income:',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AikoColors.darkNavy, fontSize: 13),
                    ),
                    Text(
                      '\$${taxableIncome.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AikoColors.neutralInk, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Deduction Checklist Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tax Deduction Log',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AikoColors.darkNavy),
                ),
                TextButton.icon(
                  onPressed: _showAddDeductionDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                )
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Deduction items list
          ..._deductions.map((item) {

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: AikoColors.white,
              child: CheckboxListTile(
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AikoColors.darkNavy),
                ),
                subtitle: Text(
                  '${item.category} | Amount: \$${item.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: AikoColors.mutedText),
                ),
                value: item.isSelected,
                activeColor: AikoColors.analyticsTeal,
                onChanged: (val) {
                  setState(() {
                    item.isSelected = val ?? false;
                  });
                },
                secondary: const Icon(Icons.receipt_long, color: AikoColors.analyticsTeal),
              ),
            );
          }),
          const SizedBox(height: 16),

          // Secure Document Vault Card
          FinanceCard(
            title: 'Secure Document Vault',
            icon: Icons.lock_outline,
            accentColor: AikoColors.premiumPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Encrypted Cloud Vault (Supabase Storage)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AikoColors.premiumPurple,
                  ),
                ),
                const SizedBox(height: 10),
                if (_isLoadingDocs)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AikoColors.premiumPurple,
                      ),
                    ),
                  )
                else if (_documents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No documents stored. Upload your tax statements securely.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ..._documents.map((doc) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.picture_as_pdf,
                        color: AikoColors.dangerRed,
                      ),
                      title: Text(
                        doc,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AikoColors.darkNavy,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.file_download_outlined,
                              color: AikoColors.primaryBlue,
                              size: 20,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Downloading $doc securely...'),
                                  backgroundColor: AikoColors.primaryBlue,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AikoColors.dangerRed,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _documents.remove(doc);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$doc deleted from local vault.'),
                                  backgroundColor: AikoColors.warningOrange,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                if (_isUploading) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AikoColors.premiumPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _uploadStatusMessage ?? 'Uploading...',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AikoColors.premiumPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AikoColors.premiumPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isUploading ? null : _showUploadPicker,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Upload PDF Statement'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tax Disclaimer Card
          FinanceCard(
            title: 'Tax disclaimer',
            icon: Icons.privacy_tip_outlined,
            accentColor: AikoColors.warningOrange,
            child: const Text(
              'Aiko calculations and deductions are estimates for educational and forecasting purposes only. Tax laws are complex and change frequently. Please consult a licensed CPA or certified tax professional for official tax filing guidance.',
              style: TextStyle(fontSize: 12, color: AikoColors.mutedText, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
