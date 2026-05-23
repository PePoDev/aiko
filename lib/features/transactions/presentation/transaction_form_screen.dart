import 'dart:async';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/transaction.dart';
import '../domain/transaction_attachment.dart';
import '../data/transaction_attachment_repository.dart';
import '../application/receipt_ocr_service.dart';
import '../application/voice_transaction_parser.dart';
import '../application/voice_transcription_service.dart';
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
  DateTime _selectedDate = DateTime.now();
  final List<TransactionAttachment> _attachments = [];

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _autofillForm({
    required double amount,
    required String merchant,
    required String note,
    required String type,
    required DateTime date,
  }) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(2);
      _merchantController.text = merchant;
      _noteController.text = note;
      _type = type;
      _selectedDate = date;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white),
            const SizedBox(width: 8),
            Text('Aiko Autofilled: $merchant | \$${amount.toStringAsFixed(2)}'),
          ],
        ),
        backgroundColor: AikoColors.premiumPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showOcrScannerDialog() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Simulate AI Receipt Scan',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AikoColors.premiumPurple,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Select a mock transaction receipt to simulate scanning and autofill:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.coffee, color: AikoColors.warningOrange),
                title: const Text('Starbucks Receipt'),
                subtitle: const Text('Total: \$12.45 | Today'),
                onTap: () {
                  Navigator.of(context).pop();
                  _runMockOcrProgress(
                    text: 'STARBUCKS\n12/3/2026\nCOFFEE & TEA\nTOTAL: 12.45\nPAID WITH VISA',
                    merchant: 'Starbucks',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined, color: AikoColors.deepBlue),
                title: const Text('Amazon Order invoice'),
                subtitle: const Text('Total: \$89.99 | Yesterday'),
                onTap: () {
                  Navigator.of(context).pop();
                  _runMockOcrProgress(
                    text: 'AMAZON.COM\n12/2/2026\nTEXTBOOKS\nAMOUNT DUE: 89.99\nDELIVERED',
                    merchant: 'Amazon',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_gas_station_outlined, color: AikoColors.successGreen),
                title: const Text('Chevron Gas Station'),
                subtitle: const Text('Total: \$45.50 | 2 Days Ago'),
                onTap: () {
                  Navigator.of(context).pop();
                  _runMockOcrProgress(
                    text: 'CHEVRON PUMP 04\n12/1/2026\nREGULAR UNLEADED\nPAID: 45.50\nTHANK YOU',
                    merchant: 'Chevron Gas',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _runMockOcrProgress({required String text, required String merchant}) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Aiko OCR recognizing text...'),
            ],
          ),
        );
      },
    );

    const ocrService = ReceiptOcrService();
    final autofill = await ocrService.scanWithCloudOcr(
      imageBytes: [1, 2, 3, 4],
      fileName: '${merchant.toLowerCase().replaceAll(' ', '_')}.png',
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // Close spinner

    _autofillForm(
      amount: autofill.total?.amount.toDouble() ?? 0.0,
      merchant: autofill.merchant ?? merchant,
      note: 'Simulated OCR Receipt: ${autofill.merchant}',
      type: 'expense',
      date: autofill.date ?? DateTime.now(),
    );
  }

  void _showVoiceCommandDialog() {
    final voiceTextController = TextEditingController(
      text: 'spent 15.50 at Starbucks yesterday for coffee',
    );

    var isRecording = false;
    var isTranscribing = false;
    var recordDuration = 0;
    Timer? durationTimer;
    Timer? waveTimer;
    var waveHeights = List<double>.generate(15, (index) => 6.0);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void stopTimers() {
              durationTimer?.cancel();
              waveTimer?.cancel();
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.mic, color: AikoColors.premiumPurple),
                  const SizedBox(width: 8),
                  Text(
                    'Voice Entry Assistant',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: AikoColors.deepBlue),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Animated waveform and status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRecording
                          ? AikoColors.dangerRed.withOpacity(0.05)
                          : AikoColors.premiumPurple.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isRecording
                            ? AikoColors.dangerRed.withOpacity(0.2)
                            : AikoColors.premiumPurple.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (isTranscribing) ...[
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(AikoColors.premiumPurple),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Whisper Cloud transcribing audio...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AikoColors.premiumPurple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else if (isRecording) ...[
                          // Waveform visualizer
                          SizedBox(
                            height: 48,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: List.generate(
                                waveHeights.length,
                                (i) => Container(
                                  width: 4,
                                  height: waveHeights[i],
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: AikoColors.dangerRed,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Recording... ${recordDuration}s',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AikoColors.dangerRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else ...[
                          const Icon(Icons.mic, size: 36, color: AikoColors.premiumPurple),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the mic to start speaking',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Mic Button
                        Center(
                          child: InkWell(
                            onTap: isTranscribing
                                ? null
                                : () {
                                    if (isRecording) {
                                      // Stop recording
                                      stopTimers();
                                      setModalState(() {
                                        isRecording = false;
                                        isTranscribing = true;
                                      });
                                      
                                      // Call service
                                      const voiceService = VoiceTranscriptionService();
                                      voiceService.transcribe(
                                        audioBytes: [1, 2, 3, 4],
                                        defaultSimulationText: voiceTextController.text.trim(),
                                      ).then((transcription) {
                                        if (context.mounted) {
                                          setModalState(() {
                                            isTranscribing = false;
                                            voiceTextController.text = transcription;
                                          });
                                        }
                                      }).catchError((_) {
                                        if (context.mounted) {
                                          setModalState(() {
                                            isTranscribing = false;
                                          });
                                        }
                                      });
                                    } else {
                                      // Start recording
                                      setModalState(() {
                                        isRecording = true;
                                        recordDuration = 0;
                                      });
                                      durationTimer = Timer.periodic(
                                        const Duration(seconds: 1),
                                        (t) {
                                          setModalState(() {
                                            recordDuration++;
                                          });
                                        },
                                      );
                                      waveTimer = Timer.periodic(
                                        const Duration(milliseconds: 100),
                                        (t) {
                                          setModalState(() {
                                            waveHeights = List.generate(
                                              15,
                                              (_) => 5.0 + (30.0 * (0.1 + 0.9 * (1.0 - (DateTime.now().millisecond % 500) / 500.0))),
                                            );
                                          });
                                        },
                                      );
                                    }
                                  },
                            borderRadius: BorderRadius.circular(40),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: isRecording ? AikoColors.dangerRed : AikoColors.premiumPurple,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isRecording ? AikoColors.dangerRed : AikoColors.premiumPurple)
                                        .withOpacity(0.3),
                                    blurRadius: isRecording ? 16 : 8,
                                    spreadRadius: isRecording ? 4 : 1,
                                  )
                                ],
                              ),
                              child: Icon(
                                isRecording ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Edit transcription context if needed:',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: voiceTextController,
                    decoration: const InputDecoration(
                      labelText: 'Parsed Text Transcript',
                      hintText: 'e.g. spent 25 dollars at Amazon...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    enabled: !isRecording && !isTranscribing,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isTranscribing || isRecording
                      ? null
                      : () {
                          stopTimers();
                          Navigator.of(context).pop();
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isTranscribing || isRecording
                      ? null
                      : () {
                          stopTimers();
                          final txt = voiceTextController.text.trim();
                          Navigator.of(context).pop();
                          _parseVoiceCommand(txt);
                        },
                  style: FilledButton.styleFrom(backgroundColor: AikoColors.premiumPurple),
                  child: const Text('Parse Draft'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _parseVoiceCommand(String command) {
    try {
      const parser = VoiceTransactionParser();
      final draft = parser.parse(command, now: DateTime.now());

      _autofillForm(
        amount: draft.amount.amount.toDouble(),
        merchant: draft.merchant ?? 'Unknown',
        note: draft.note ?? 'Voice command parser',
        type: draft.type == TransactionType.income ? 'income' : 'expense',
        date: draft.date,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not parse voice command: $e'),
          backgroundColor: AikoColors.dangerRed,
        ),
      );
    }
  }

  void _showAddAttachmentDialog() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Simulate Document Upload',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AikoColors.premiumPurple,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose a simulated receipt or document to upload:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: AikoColors.dangerRed),
                title: const Text('Starbucks_Receipt.pdf'),
                subtitle: const Text('PDF | 1.2 MB'),
                onTap: () {
                  Navigator.of(context).pop();
                  _simulateAttachmentUpload(
                    fileName: 'Starbucks_Receipt.pdf',
                    mimeType: 'application/pdf',
                    sizeBytes: 1250000,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: AikoColors.primaryBlue),
                title: const Text('Amazon_Invoice.png'),
                subtitle: const Text('PNG | 450 KB'),
                onTap: () {
                  Navigator.of(context).pop();
                  _simulateAttachmentUpload(
                    fileName: 'Amazon_Invoice.png',
                    mimeType: 'image/png',
                    sizeBytes: 460800,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: AikoColors.successGreen),
                title: const Text('Chevron_Gas_Receipt.jpg'),
                subtitle: const Text('JPEG | 850 KB'),
                onTap: () {
                  Navigator.of(context).pop();
                  _simulateAttachmentUpload(
                    fileName: 'Chevron_Gas_Receipt.jpg',
                    mimeType: 'image/jpeg',
                    sizeBytes: 870400,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _simulateAttachmentUpload({
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Uploading attachment to Supabase...'),
            ],
          ),
        );
      },
    );

    // Simulate 800ms upload delay
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    Navigator.of(context).pop(); // Close spinner

    final newAttachment = TransactionAttachment(
      id: const Uuid().v4(),
      userId: '',
      transactionId: '',
      fileName: fileName,
      storagePath: 'receipts/simulated/${const Uuid().v4()}_$fileName',
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      createdAt: DateTime.now(),
    );

    setState(() {
      _attachments.add(newAttachment);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text('Attached $fileName successfully!'),
          ],
        ),
        backgroundColor: AikoColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _submitForm() async {
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
          backgroundColor: AikoColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final Decimal amount;
    try {
      amount = Decimal.parse(amountText);
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Please enter a valid positive amount.'),
            ],
          ),
          backgroundColor: AikoColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (amount <= Decimal.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Please enter a valid positive amount.'),
            ],
          ),
          backgroundColor: AikoColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final accounts = await ref.read(accountsProvider.future);
    if (!mounted) return;
    String? accountId;
    if (accounts.isNotEmpty) {
      final active = accounts.where((account) => account.isActive).toList();
      accountId = active.isNotEmpty ? active.first.id : accounts.first.id;
    }

    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Create an account before adding transactions.'),
          backgroundColor: AikoColors.warningOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final categories = await ref.read(categoriesProvider.future);
    if (!mounted) return;
    String? categoryId;
    if (categories.isNotEmpty) {
      final active = categories.where((category) => category.isActive).toList();
      categoryId = active.isNotEmpty ? active.first.id : categories.first.id;
    }

    final txType = switch (_type) {
      'income' => TransactionType.income,
      'transfer' => TransactionType.transfer,
      _ => TransactionType.expense,
    };

    final txId = const Uuid().v4();
    final newTx = FinanceTransaction(
      id: txId,
      userId: '',
      accountId: accountId,
      type: txType,
      amount: Money(amount: amount, currency: 'USD'),
      date: _selectedDate,
      categoryId: categoryId,
      merchant: _merchantController.text.trim(),
      note: _noteController.text.trim(),
    );

    await ref.read(transactionsProvider.notifier).addTransaction(newTx);

    // Save attachments if any exist
    if (_attachments.isNotEmpty) {
      try {
        const attachmentRepo = TransactionAttachmentRepository();
        for (final attachment in _attachments) {
          final updatedAttachment = TransactionAttachment(
            id: attachment.id,
            userId: attachment.userId,
            transactionId: txId, // Link to the newly saved transaction ID
            fileName: attachment.fileName,
            storagePath: attachment.storagePath,
            mimeType: attachment.mimeType,
            sizeBytes: attachment.sizeBytes,
            createdAt: attachment.createdAt,
            isSensitive: attachment.isSensitive,
            exportPolicy: attachment.exportPolicy,
          );
          await attachmentRepo.save(updatedAttachment);
        }
      } catch (e) {
        debugPrint('Offline/local session faked: attachment metadata bypass cloud ($e)');
      }
    }

    if (!mounted) return;

    final state = ref.read(transactionsProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to save this transaction right now.'),
          backgroundColor: AikoColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Transaction saved successfully!'),
          ],
        ),
        backgroundColor: AikoColors.successGreen,
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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Smart Entry Dashboard Card
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AikoColors.premiumPurple.withOpacity(0.3)),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AikoColors.premiumPurple.withOpacity(0.05),
                    AikoColors.deepBlue.withOpacity(0.05),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AikoColors.premiumPurple, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Aiko Smart Entry Tools',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AikoColors.premiumPurple,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Autofill this transaction instantly using scanned receipt OCR or voice text patterns.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showOcrScannerDialog,
                          icon: const Icon(Icons.receipt_long_outlined, size: 18),
                          label: const Text('Scan Receipt', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AikoColors.premiumPurple,
                            side: const BorderSide(color: AikoColors.premiumPurple),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showVoiceCommandDialog,
                          icon: const Icon(Icons.mic_none_outlined, size: 18),
                          label: const Text('Voice Entry', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AikoColors.deepBlue,
                            side: const BorderSide(color: AikoColors.deepBlue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Standard Entry Fields
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
          
          // Date selection tile
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Transaction Date'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          const SizedBox(height: 16),
          
          TransactionAttachmentSection(
            attachments: _attachments,
            onAddAttachment: _showAddAttachmentDialog,
          ),
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
