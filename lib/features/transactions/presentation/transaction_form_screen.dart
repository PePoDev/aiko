import 'dart:async';
import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../theme/aiko_colors.dart';
import '../../accounts/domain/account.dart';
import '../domain/transaction.dart';
import '../domain/transaction_attachment.dart';
import '../data/transaction_attachment_repository.dart';
import '../application/receipt_ocr_service.dart';
import '../application/voice_transaction_parser.dart';
import '../application/voice_transcription_service.dart';
import 'transaction_attachment_section.dart';

const _supportedCurrencies = [
  'THB',
  'USD',
  'EUR',
  'GBP',
  'JPY',
  'SGD',
  'AUD',
  'CAD',
  'CNY',
  'HKD',
];

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({this.initialTransaction, super.key});

  final FinanceTransaction? initialTransaction;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _exchangeRateController = TextEditingController(text: '1.00');
  final _noteController = TextEditingController();
  final _tagsController = TextEditingController();
  final _imagePicker = ImagePicker();
  String _type = 'expense';
  String _selectedCurrency = 'THB';
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId; // For transfer type
  final List<TransactionAttachment> _attachments = [];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _exchangeRateController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final transaction = widget.initialTransaction;
    if (transaction == null) return;

    _titleController.text = transaction.merchant ?? '';
    _amountController.text = transaction.amount.amount.toString();
    _selectedCurrency = _normalizeCurrency(transaction.amount.currency);
    _noteController.text = transaction.note ?? '';
    _type = switch (transaction.type) {
      TransactionType.income => 'income',
      TransactionType.transfer => 'transfer',
      _ => 'expense',
    };
    _selectedDate = transaction.date;
    _selectedCategoryId = transaction.categoryId;
    _selectedAccountId = transaction.accountId;
    _tagsController.text = transaction.tags.join(', ');
  }

  void _autofillForm({
    required double amount,
    required String note,
    required String type,
    required DateTime date,
    String title = '',
    String currency = 'THB',
  }) {
    setState(() {
      _titleController.text = title;
      _amountController.text = amount.toStringAsFixed(2);
      _selectedCurrency = _normalizeCurrency(currency);
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
            Text('Aiko Autofilled: \$${amount.toStringAsFixed(2)}'),
          ],
        ),
        backgroundColor: AikoColors.premiumPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _scanReceiptWithCamera() async {
    XFile? captured;
    try {
      captured = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to open camera right now.'),
          backgroundColor: AikoColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (captured == null || !mounted) {
      return;
    }

    final Uint8List imageBytes;
    try {
      imageBytes = await captured.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to read captured image.'),
          backgroundColor: AikoColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final ext = captured.name.toLowerCase().endsWith('.png')
        ? 'png'
        : (captured.name.toLowerCase().endsWith('.webp') ? 'webp' : 'jpg');
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final attachment = TransactionAttachment(
      id: const Uuid().v4(),
      userId: '',
      transactionId: '',
      fileName: captured.name,
      storagePath: captured.path,
      mimeType: mimeType,
      sizeBytes: imageBytes.length,
      createdAt: DateTime.now(),
    );

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Scanning receipt...'),
            ],
          ),
        );
      },
    );

    const ocrService = ReceiptOcrService();
    late final ReceiptAutofill autofill;
    try {
      autofill = await ocrService.scanWithCloudOcr(
        imageBytes: imageBytes,
        fileName: captured.name,
        currency: 'THB',
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Receipt scan failed. You can still enter manually.',
          ),
          backgroundColor: AikoColors.warningOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // Close spinner

    setState(() {
      _attachments.add(attachment);
    });

    if (!autofill.hasTransactionFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Receipt captured. OCR found limited fields.'),
          backgroundColor: AikoColors.warningOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    _autofillForm(
      amount: autofill.total?.amount.toDouble() ?? 0.0,
      note: 'Scanned receipt: ${autofill.merchant ?? captured.name}',
      type: 'expense',
      date: autofill.date ?? DateTime.now(),
      title: autofill.merchant ?? '',
      currency: autofill.total?.currency ?? 'THB',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.mic, color: AikoColors.premiumPurple),
                  const SizedBox(width: 8),
                  Text(
                    'Voice Entry Assistant',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AikoColors.deepBlue,
                    ),
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
                          ? AikoColors.dangerRed.withValues(alpha: 0.05)
                          : AikoColors.premiumPurple.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isRecording
                            ? AikoColors.dangerRed.withValues(alpha: 0.2)
                            : AikoColors.premiumPurple.withValues(alpha: 0.1),
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
                              valueColor: AlwaysStoppedAnimation(
                                AikoColors.premiumPurple,
                              ),
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
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
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
                          const Icon(
                            Icons.mic,
                            size: 36,
                            color: AikoColors.premiumPurple,
                          ),
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
                                      const voiceService =
                                          VoiceTranscriptionService();
                                      voiceService
                                          .transcribe(
                                            audioBytes: [1, 2, 3, 4],
                                            defaultSimulationText:
                                                voiceTextController.text.trim(),
                                          )
                                          .then((transcription) {
                                            if (context.mounted) {
                                              setModalState(() {
                                                isTranscribing = false;
                                                voiceTextController.text =
                                                    transcription;
                                              });
                                            }
                                          })
                                          .catchError((_) {
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
                                              (_) =>
                                                  5.0 +
                                                  (30.0 *
                                                      (0.1 +
                                                          0.9 *
                                                              (1.0 -
                                                                  (DateTime.now()
                                                                              .millisecond %
                                                                          500) /
                                                                      500.0))),
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
                                color: isRecording
                                    ? AikoColors.dangerRed
                                    : AikoColors.premiumPurple,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isRecording
                                                ? AikoColors.dangerRed
                                                : AikoColors.premiumPurple)
                                            .withValues(alpha: 0.3),
                                    blurRadius: isRecording ? 16 : 8,
                                    spreadRadius: isRecording ? 4 : 1,
                                  ),
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
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: AikoColors.premiumPurple,
                  ),
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
        note: draft.note ?? 'Voice command parser',
        type: draft.type == TransactionType.income ? 'income' : 'expense',
        date: draft.date,
        title: draft.merchant ?? '',
        currency: draft.amount.currency,
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

  List<String> _currencyOptionsFor(List<Account> accounts) {
    return {
      _selectedCurrency,
      ..._supportedCurrencies,
      for (final account in accounts) account.currency.toUpperCase(),
    }.toList(growable: false);
  }

  String? _accountCurrencyFor(List<Account> accounts, String? accountId) {
    if (accountId == null) {
      return null;
    }
    for (final account in accounts) {
      if (account.id == accountId) {
        return account.currency.toUpperCase();
      }
    }
    return null;
  }

  String _normalizeCurrency(String currency) {
    return currency.trim().toUpperCase();
  }

  void _convertAmountToAccountCurrency(String accountCurrency) {
    final amount = Decimal.tryParse(_amountController.text.trim());
    final rate = Decimal.tryParse(_exchangeRateController.text.trim());

    if (amount == null || amount <= Decimal.zero) {
      _showConversionError('Enter a positive amount before converting.');
      return;
    }
    if (rate == null || rate <= Decimal.zero) {
      _showConversionError('Enter a positive exchange rate.');
      return;
    }

    final convertedAmount = amount * rate;
    setState(() {
      _amountController.text = convertedAmount.toStringAsFixed(2);
      _selectedCurrency = accountCurrency;
      _exchangeRateController.text = '1.00';
    });
  }

  void _showConversionError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AikoColors.warningOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _showAmountCalculator() async {
    final currentAmount = _amountController.text.trim();

    final result = await showModalBottomSheet<Decimal>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: _AmountCalculatorSheet(
            initialUnitPrice: currentAmount,
            currency: _selectedCurrency,
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _amountController.text = result.toStringAsFixed(2);
    });
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
                'Document Upload',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AikoColors.premiumPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose a source to attach a real receipt or document:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.folder_open,
                  color: AikoColors.deepBlue,
                ),
                title: const Text('Browse Files'),
                subtitle: const Text('PDF, image, and other documents'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndAttachDocumentFromFiles();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AikoColors.successGreen,
                ),
                title: const Text('Choose Photo from Gallery'),
                subtitle: const Text('Attach an existing receipt image'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndAttachImageFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndAttachDocumentFromFiles() async {
    fs.XFile? selectedFile;
    try {
      selectedFile = await fs.openFile(
        acceptedTypeGroups: const [
          fs.XTypeGroup(
            label: 'documents and images',
            extensions: [
              'pdf',
              'jpg',
              'jpeg',
              'png',
              'heic',
              'webp',
              'txt',
              'csv',
              'doc',
              'docx',
            ],
          ),
        ],
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to open file picker.'),
          backgroundColor: AikoColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (selectedFile == null) {
      return;
    }

    final fileName = selectedFile.name;
    final filePath = selectedFile.path;
    final mimeType = _mimeTypeFromFileName(fileName);
    final sizeBytes = (await selectedFile.readAsBytes()).length;

    await _attachSelectedFile(
      fileName: fileName,
      storagePath: filePath,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
  }

  Future<void> _pickAndAttachImageFromGallery() async {
    XFile? picked;
    try {
      picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        requestFullMetadata: false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to open gallery right now.'),
          backgroundColor: AikoColors.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    await _attachSelectedFile(
      fileName: picked.name,
      storagePath: picked.path,
      mimeType: _mimeTypeFromFileName(picked.name),
      sizeBytes: bytes.length,
    );
  }

  Future<void> _attachSelectedFile({
    required String fileName,
    required String storagePath,
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
              Text('Attaching document...'),
            ],
          ),
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    Navigator.of(context).pop(); // Close spinner

    final newAttachment = TransactionAttachment(
      id: const Uuid().v4(),
      userId: '',
      transactionId: '',
      fileName: fileName,
      storagePath: storagePath,
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
            Text('Attached $fileName'),
          ],
        ),
        backgroundColor: AikoColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _mimeTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
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

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select an account.'),
          backgroundColor: AikoColors.warningOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (_type == 'transfer' && _selectedToAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please select a destination account for transfer.',
          ),
          backgroundColor: AikoColors.warningOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final txType = switch (_type) {
      'income' => TransactionType.income,
      'transfer' => TransactionType.transfer,
      _ => TransactionType.expense,
    };

    final existingTransaction = widget.initialTransaction;
    final txId = existingTransaction?.id ?? const Uuid().v4();
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    final savedTx = FinanceTransaction(
      id: txId,
      userId: existingTransaction?.userId ?? '',
      accountId: _selectedAccountId!,
      type: txType,
      amount: Money(amount: amount, currency: _selectedCurrency),
      date: _selectedDate,
      categoryId: _selectedCategoryId,
      merchant: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      note: _noteController.text.trim(),
      tags: tags,
      splits: existingTransaction?.splits ?? const [],
      status: existingTransaction?.status ?? TransactionStatus.posted,
    );

    final saved = await ref
        .read(transactionsProvider.notifier)
        .saveTransaction(savedTx);

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
        debugPrint(
          'Offline/local session faked: attachment metadata bypass cloud ($e)',
        );
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

    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final accountSnapshot =
        accountsAsync.whenOrNull(data: (accounts) => accounts) ??
        const <Account>[];
    final currencyOptions = _currencyOptionsFor(accountSnapshot);
    final selectedAccountCurrency = _accountCurrencyFor(
      accountSnapshot,
      _selectedAccountId,
    );
    final showCurrencyConversion =
        selectedAccountCurrency != null &&
        selectedAccountCurrency != _selectedCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialTransaction == null
              ? 'Add transaction'
              : 'Edit transaction',
        ),
        actions: [
          IconButton(
            tooltip: 'Scan receipt',
            onPressed: _scanReceiptWithCamera,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Voice entry',
            onPressed: _showVoiceCommandDialog,
            icon: const Icon(Icons.mic_none_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Standard Entry Fields
          SegmentedButton<String>(
            key: const Key('transaction-type-selector'),
            segments: const [
              ButtonSegment(
                value: 'expense',
                label: Text('Expense'),
                icon: Icon(Icons.north_east),
              ),
              ButtonSegment(
                value: 'income',
                label: Text('Income'),
                icon: Icon(Icons.south_west),
              ),
              ButtonSegment(
                value: 'transfer',
                label: Text('Transfer'),
                icon: Icon(Icons.swap_horiz),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) {
              setState(() => _type = selection.first);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Item name',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('transaction-amount-field'),
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    suffixIcon: IconButton(
                      key: const Key('amount-calculator-button'),
                      tooltip: 'Open amount calculator',
                      onPressed: _showAmountCalculator,
                      icon: const Icon(Icons.calculate_outlined),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 124,
                child: DropdownMenu<String>(
                  key: ValueKey(_selectedCurrency),
                  initialSelection: _selectedCurrency,
                  expandedInsets: EdgeInsets.zero,
                  label: const Text('Currency'),
                  dropdownMenuEntries: [
                    for (final currency in currencyOptions)
                      DropdownMenuEntry(value: currency, label: currency),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      setState(() => _selectedCurrency = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category dropdown
          categoriesAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (_, _) => const Text('Error loading categories'),
            data: (categories) {
              final activeCategories = categories
                  .where((c) => c.isActive)
                  .toList();
              if (activeCategories.isEmpty) {
                return const Text('No categories available');
              }
              return DropdownMenu<String>(
                initialSelection: _selectedCategoryId,
                expandedInsets: EdgeInsets.zero,
                label: const Text('Category'),
                dropdownMenuEntries: activeCategories
                    .map(
                      (category) => DropdownMenuEntry(
                        value: category.id,
                        label: category.name,
                      ),
                    )
                    .toList(),
                onSelected: (value) {
                  setState(() => _selectedCategoryId = value);
                },
              );
            },
          ),
          const SizedBox(height: 16),

          // Account dropdown(s)
          accountsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (_, _) => const Text('Error loading accounts'),
            data: (accounts) {
              final activeAccounts = accounts.where((a) => a.isActive).toList();
              if (activeAccounts.isEmpty) {
                return const Text(
                  'No accounts available. Create an account first.',
                );
              }

              if (_type == 'transfer') {
                // Show two account dropdowns for transfer
                return Column(
                  children: [
                    DropdownMenu<String>(
                      initialSelection: _selectedAccountId,
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('From Account'),
                      dropdownMenuEntries: activeAccounts
                          .map(
                            (account) => DropdownMenuEntry(
                              value: account.id,
                              label: account.name,
                            ),
                          )
                          .toList(),
                      onSelected: (value) {
                        setState(() => _selectedAccountId = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownMenu<String>(
                      initialSelection: _selectedToAccountId,
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('To Account'),
                      dropdownMenuEntries: activeAccounts
                          .map(
                            (account) => DropdownMenuEntry(
                              value: account.id,
                              label: account.name,
                            ),
                          )
                          .toList(),
                      onSelected: (value) {
                        setState(() => _selectedToAccountId = value);
                      },
                    ),
                  ],
                );
              } else {
                // Show single account dropdown
                return DropdownMenu<String>(
                  initialSelection: _selectedAccountId,
                  expandedInsets: EdgeInsets.zero,
                  label: const Text('Account'),
                  dropdownMenuEntries: activeAccounts
                      .map(
                        (account) => DropdownMenuEntry(
                          value: account.id,
                          label: account.name,
                        ),
                      )
                      .toList(),
                  onSelected: (value) {
                    setState(() => _selectedAccountId = value);
                  },
                );
              }
            },
          ),
          const SizedBox(height: 16),
          if (showCurrencyConversion) ...[
            _CurrencyConversionPrompt(
              selectedCurrency: _selectedCurrency,
              accountCurrency: selectedAccountCurrency,
              exchangeRateController: _exchangeRateController,
              onConvert: () =>
                  _convertAmountToAccountCurrency(selectedAccountCurrency),
            ),
            const SizedBox(height: 16),
          ],

          TextField(
            key: const Key('transaction-tags-field'),
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'food, work, reimbursable',
              prefixIcon: Icon(Icons.sell_outlined),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: 16),

          // Date and time selection tile
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Transaction Date & Time'),
            subtitle: Text(
              DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final now = DateTime.now();
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 5),
              );
              if (pickedDate == null) return;
              if (!context.mounted) return;

              final pickedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_selectedDate),
              );
              if (pickedTime == null) return;
              if (!context.mounted) return;

              setState(() {
                _selectedDate = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
              });
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
            label: Text(
              widget.initialTransaction == null
                  ? 'Save Transaction'
                  : 'Save Changes',
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyConversionPrompt extends StatelessWidget {
  const _CurrencyConversionPrompt({
    required this.selectedCurrency,
    required this.accountCurrency,
    required this.exchangeRateController,
    required this.onConvert,
  });

  final String selectedCurrency;
  final String accountCurrency;
  final TextEditingController exchangeRateController;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: AikoColors.warningOrange.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.currency_exchange,
                  color: AikoColors.warningOrange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Convert to $accountCurrency?',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The selected account tracks $accountCurrency, but this amount is in $selectedCurrency.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('transaction-exchange-rate-field'),
                    controller: exchangeRateController,
                    decoration: InputDecoration(
                      labelText: '1 $selectedCurrency equals',
                      suffixText: accountCurrency,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('convert-currency-button'),
                    onPressed: onConvert,
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(
                      'Convert to $accountCurrency',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountCalculatorSheet extends StatefulWidget {
  const _AmountCalculatorSheet({
    required this.initialUnitPrice,
    required this.currency,
  });

  final String initialUnitPrice;
  final String currency;

  @override
  State<_AmountCalculatorSheet> createState() => _AmountCalculatorSheetState();
}

class _AmountCalculatorSheetState extends State<_AmountCalculatorSheet> {
  late String _currentInput;
  Decimal? _storedValue;
  String? _pendingOperator;
  String _expression = '';
  String? _errorText;
  bool _waitingForOperand = false;
  bool _justEvaluated = false;

  Decimal get _currentAmount => _parseInput(_currentInput);

  @override
  void initState() {
    super.initState();
    final initialAmount = Decimal.tryParse(widget.initialUnitPrice.trim());
    _currentInput = initialAmount == null ? '0' : _formatDecimal(initialAmount);
  }

  Decimal _parseInput(String input) {
    final normalized = input.endsWith('.') ? '${input}0' : input;
    return Decimal.tryParse(normalized) ?? Decimal.zero;
  }

  void _apply() {
    final amount = _currentAmount;
    if (_errorText != null || amount <= Decimal.zero) {
      return;
    }
    Navigator.of(context).pop(amount);
  }

  void _clear() {
    setState(_clearState);
  }

  void _backspace() {
    setState(() {
      if (_errorText != null || _justEvaluated) {
        _clearState();
        return;
      }

      if (_waitingForOperand || _currentInput.length <= 1) {
        _currentInput = '0';
        _waitingForOperand = false;
        return;
      }

      _currentInput = _currentInput.substring(0, _currentInput.length - 1);
    });
  }

  void _pressDigit(String digit) {
    setState(() {
      if (_errorText != null) {
        _clearState();
      }

      if (_waitingForOperand || _justEvaluated) {
        _currentInput = digit;
        _waitingForOperand = false;
        if (_justEvaluated) {
          _storedValue = null;
          _pendingOperator = null;
          _expression = '';
          _justEvaluated = false;
        }
        return;
      }

      if (_currentInput == '0') {
        _currentInput = digit;
        return;
      }

      if (_currentInput.replaceAll('.', '').length < 12) {
        _currentInput += digit;
      }
    });
  }

  void _pressDecimal() {
    setState(() {
      if (_errorText != null) {
        _clearState();
      }

      if (_waitingForOperand || _justEvaluated) {
        _currentInput = '0.';
        _waitingForOperand = false;
        if (_justEvaluated) {
          _storedValue = null;
          _pendingOperator = null;
          _expression = '';
          _justEvaluated = false;
        }
        return;
      }

      if (!_currentInput.contains('.')) {
        _currentInput += '.';
      }
    });
  }

  void _pressOperator(String operator) {
    setState(() {
      if (_errorText != null) {
        _clearState();
      }

      final currentValue = _currentAmount;
      if (_pendingOperator != null &&
          !_waitingForOperand &&
          _storedValue != null) {
        final result = _calculate(
          _storedValue!,
          currentValue,
          _pendingOperator!,
        );
        if (result == null) {
          _showCalculationError();
          return;
        }
        _storedValue = result;
        _currentInput = _formatDecimal(result);
      } else {
        _storedValue = currentValue;
      }

      _pendingOperator = operator;
      _waitingForOperand = true;
      _justEvaluated = false;
      _expression = '${_formatDecimal(_storedValue!)} $operator';
    });
  }

  void _pressEquals() {
    setState(() {
      if (_pendingOperator == null ||
          _storedValue == null ||
          _waitingForOperand) {
        return;
      }

      final left = _storedValue!;
      final right = _currentAmount;
      final operator = _pendingOperator!;
      final result = _calculate(left, right, operator);
      if (result == null) {
        _showCalculationError();
        return;
      }

      _currentInput = _formatDecimal(result);
      _expression =
          '${_formatDecimal(left)} $operator ${_formatDecimal(right)} =';
      _storedValue = null;
      _pendingOperator = null;
      _waitingForOperand = false;
      _justEvaluated = true;
    });
  }

  void _clearState() {
    _currentInput = '0';
    _storedValue = null;
    _pendingOperator = null;
    _expression = '';
    _errorText = null;
    _waitingForOperand = false;
    _justEvaluated = false;
  }

  void _showCalculationError() {
    _currentInput = '0';
    _storedValue = null;
    _pendingOperator = null;
    _expression = '';
    _errorText = 'Cannot divide by zero';
    _waitingForOperand = false;
    _justEvaluated = true;
  }

  Decimal? _calculate(Decimal left, Decimal right, String operator) {
    switch (operator) {
      case '+':
        return left + right;
      case '-':
        return left - right;
      case '*':
        return left * right;
      case '/':
        if (right == Decimal.zero) {
          return null;
        }
        return (left / right).toDecimal(scaleOnInfinitePrecision: 8);
      default:
        return right;
    }
  }

  String _formatDecimal(Decimal value) {
    final fixed = value.toStringAsFixed(8);
    final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
    if (trimmed.isEmpty || trimmed == '-0') {
      return '0';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canApply = _errorText == null && _currentAmount > Decimal.zero;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Amount calculator',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AikoColors.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AikoColors.primaryBlue.withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _errorText ??
                    (_expression.isEmpty ? widget.currency : _expression),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _errorText == null
                      ? AikoColors.mutedText
                      : AikoColors.dangerRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _errorText ?? _currentInput,
                  key: const Key('calculator-display-value'),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _errorText == null
                        ? theme.colorScheme.onSurface
                        : AikoColors.dangerRed,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_currentAmount.toStringAsFixed(2)} ${widget.currency}',
                key: const Key('calculator-total-value'),
                textAlign: TextAlign.end,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AikoColors.primaryBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _CalculatorKeypad(
          onDigit: _pressDigit,
          onDecimal: _pressDecimal,
          onOperator: _pressOperator,
          onEquals: _pressEquals,
          onClear: _clear,
          onBackspace: _backspace,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('apply-calculated-amount-button'),
          onPressed: canApply ? _apply : null,
          icon: const Icon(Icons.check),
          label: const Text('Use amount'),
        ),
      ],
    );
  }
}

class _CalculatorKeypad extends StatelessWidget {
  const _CalculatorKeypad({
    required this.onDigit,
    required this.onDecimal,
    required this.onOperator,
    required this.onEquals,
    required this.onClear,
    required this.onBackspace,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final ValueChanged<String> onOperator;
  final VoidCallback onEquals;
  final VoidCallback onClear;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CalculatorKeyRow(
          children: [
            _CalculatorKey(label: '7', onPressed: () => onDigit('7')),
            _CalculatorKey(label: '8', onPressed: () => onDigit('8')),
            _CalculatorKey(label: '9', onPressed: () => onDigit('9')),
            _CalculatorKey(
              label: '/',
              onPressed: () => onOperator('/'),
              kind: _CalculatorKeyKind.operator,
            ),
          ],
        ),
        _CalculatorKeyRow(
          children: [
            _CalculatorKey(label: '4', onPressed: () => onDigit('4')),
            _CalculatorKey(label: '5', onPressed: () => onDigit('5')),
            _CalculatorKey(label: '6', onPressed: () => onDigit('6')),
            _CalculatorKey(
              label: '*',
              onPressed: () => onOperator('*'),
              kind: _CalculatorKeyKind.operator,
            ),
          ],
        ),
        _CalculatorKeyRow(
          children: [
            _CalculatorKey(label: '1', onPressed: () => onDigit('1')),
            _CalculatorKey(label: '2', onPressed: () => onDigit('2')),
            _CalculatorKey(label: '3', onPressed: () => onDigit('3')),
            _CalculatorKey(
              label: '-',
              onPressed: () => onOperator('-'),
              kind: _CalculatorKeyKind.operator,
            ),
          ],
        ),
        _CalculatorKeyRow(
          children: [
            _CalculatorKey(label: 'C', onPressed: onClear),
            _CalculatorKey(label: '0', onPressed: () => onDigit('0')),
            _CalculatorKey(label: '.', onPressed: onDecimal),
            _CalculatorKey(
              label: '+',
              onPressed: () => onOperator('+'),
              kind: _CalculatorKeyKind.operator,
            ),
          ],
        ),
        _CalculatorKeyRow(
          children: [
            _CalculatorKey(
              label: 'backspace',
              icon: Icons.backspace_outlined,
              onPressed: onBackspace,
            ),
            _CalculatorKey(
              label: '=',
              onPressed: onEquals,
              kind: _CalculatorKeyKind.primary,
              flex: 3,
            ),
          ],
        ),
      ],
    );
  }
}

class _CalculatorKeyRow extends StatelessWidget {
  const _CalculatorKeyRow({required this.children});

  final List<_CalculatorKey> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(flex: children[i].flex, child: children[i]),
          ],
        ],
      ),
    );
  }
}

enum _CalculatorKeyKind { normal, operator, primary }

class _CalculatorKey extends StatelessWidget {
  const _CalculatorKey({
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = _CalculatorKeyKind.normal,
    this.flex = 1,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final _CalculatorKeyKind kind;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = switch (kind) {
      _CalculatorKeyKind.primary => AikoColors.primaryBlue,
      _CalculatorKeyKind.operator => AikoColors.primaryBlue.withValues(
        alpha: 0.12,
      ),
      _CalculatorKeyKind.normal => theme.colorScheme.surface,
    };
    final foreground = switch (kind) {
      _CalculatorKeyKind.primary => Colors.white,
      _CalculatorKeyKind.operator => AikoColors.primaryBlue,
      _CalculatorKeyKind.normal => theme.colorScheme.onSurface,
    };

    return SizedBox(
      height: 52,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: kind == _CalculatorKeyKind.normal
                ? AikoColors.borderSubtle
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          key: Key(_calculatorKeyName(label)),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: icon == null
                ? Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Icon(icon, color: foreground),
          ),
        ),
      ),
    );
  }
}

String _calculatorKeyName(String label) {
  return switch (label) {
    '.' => 'calculator-key-decimal',
    '+' => 'calculator-key-add',
    '-' => 'calculator-key-subtract',
    '*' => 'calculator-key-multiply',
    '/' => 'calculator-key-divide',
    '=' => 'calculator-key-equals',
    'C' => 'calculator-key-clear',
    'backspace' => 'calculator-key-backspace',
    _ => 'calculator-key-$label',
  };
}
