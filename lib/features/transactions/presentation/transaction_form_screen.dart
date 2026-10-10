import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/storage/local_file_cache.dart';
import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/widgets/discard_changes_guard.dart';
import '../../categories/presentation/category_names.dart';
import 'package:decimal/decimal.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/money/money.dart';
import '../../../core/notifications/transaction_reminder_service.dart';
import '../../../core/money/supported_currencies.dart';
import '../../../theme/aiko_colors.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../../categories/domain/category_defaults.dart';
import '../../categories/presentation/category_visual.dart';
import '../domain/transaction.dart';
import '../domain/transaction_attachment.dart';
import '../data/transaction_attachment_repository.dart';
import '../application/amount_input.dart';
import '../application/receipt_ocr_service.dart';
import '../application/voice_transaction_parser.dart';
import 'transaction_attachment_section.dart';

const _supportedCurrencies = kAikoSupportedCurrencies;

/// Reminder lead-time presets offered in the reminder dropdown. `custom`
/// surfaces the full date+time picker.
///
/// The persisted source of truth is still [FinanceTransaction.reminderAt];
/// this enum is a UI-only convenience that derives `reminderAt` from the
/// transaction's date minus the lead.
enum ReminderLead {
  oneHour._(minutes: 60),
  twoHours._(minutes: 120),
  oneDay._(minutes: 24 * 60),
  twoDays._(minutes: 2 * 24 * 60),
  oneWeek._(minutes: 7 * 24 * 60),
  none._(minutes: 0),
  custom._(minutes: null);

  const ReminderLead._({required this.minutes});

  final int? minutes;

  String label(AppLocalizations l10n) => switch (this) {
    oneHour => l10n.reminderLeadOneHour,
    twoHours => l10n.reminderLeadTwoHours,
    oneDay => l10n.reminderLeadOneDay,
    twoDays => l10n.reminderLeadTwoDays,
    oneWeek => l10n.reminderLeadOneWeek,
    none => l10n.reminderLeadNone,
    custom => l10n.reminderLeadCustom,
  };
}

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

  /// Rate from the entered currency to a transfer's destination account,
  /// when that account tracks another currency.
  final _toExchangeRateController = TextEditingController(text: '1.00');
  final _noteController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _tagFocusNode = FocusNode();
  final _imagePicker = ImagePicker();
  final List<String> _tags = [];
  TransactionType _type = TransactionType.expense;
  String _selectedCurrency = kDefaultBaseCurrency;

  /// The user's preferred currency; used as the default for new entries and
  /// when OCR/voice/autofill can't infer one. Falls back to the app default
  /// until the profile loads.
  String get _baseCurrency =>
      ref.read(profileProvider).value?.baseCurrency ?? kDefaultBaseCurrency;

  // Live FX auto-fill state. Tracks the last "from>to" pair we fetched so we
  // don't refetch on every rebuild, and a flag for the in-flight spinner.
  String? _fetchedRatePair;
  bool _isFetchingRate = false;
  String? _fetchedToRatePair;
  bool _isFetchingToRate = false;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId; // For transfer type
  final List<TransactionAttachment> _attachments = [];

  // Recurring transaction state. Defaults mirror a one-off transaction so the
  // form keeps its current behaviour until the user opts in.
  bool _isRecurring = false;
  RecurringFrequency _recurringFrequency = RecurringFrequency.monthly;
  DateTime? _recurringEndDate;
  int? _recurringMaxOccurrences;
  int? _recurringDayOfWeek;
  int? _recurringDayOfMonth;
  int? _recurringMonthOfYear;

  // Reminder notification. null = no reminder.
  DateTime? _reminderAt;

  // UI-only reminder lead selection. Drives [_reminderAt] whenever the
  // transaction date changes. `custom` hands control to the full picker.
  ReminderLead _reminderLead = ReminderLead.oneHour;

  // True while a save is in flight: disables Save so a double tap can't
  // create duplicates.
  bool _isSaving = false;

  // Both legs of the linked transfer being edited (null for new entries,
  // non-transfers and legacy unlinked legs). The form edits the pair as one.
  FinanceTransaction? _pairOut;
  FinanceTransaction? _pairIn;

  // The destination rate pre-filled from a cross-currency pair, to tell
  // whether the user changed it.
  String? _pairToRateText;

  bool get _isEditing => widget.initialTransaction != null;

  /// Editing a transfer leg saved before legs were linked: only its own
  /// account is known, so it's edited as a single row.
  bool get _isUnlinkedTransferLeg =>
      (widget.initialTransaction?.type.isTransfer ?? false) && _pairOut == null;

  /// An existing entry keeps its transfer/non-transfer kind: a transfer leg
  /// can't become income or an expense (its partner would be orphaned), and
  /// an expense or income can't become a transfer (there's no second leg).
  bool _canSwitchTo(TransactionType next) {
    final initial = widget.initialTransaction;
    if (initial == null) return true;
    return initial.type.isTransfer == (next == TransactionType.transfer);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _exchangeRateController.dispose();
    _toExchangeRateController.dispose();
    _noteController.dispose();
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  /// The form as first shown; leaving with anything different asks first.
  String? _initialSnapshot;
  bool _wasDirty = false;

  String _snapshot() => [
    _type.name,
    _amountController.text.trim(),
    _titleController.text.trim(),
    _noteController.text.trim(),
    _selectedCategoryId,
    _selectedAccountId,
    _selectedToAccountId,
    _selectedCurrency,
    _tags.join('|'),
    _attachments.length,
    _isRecurring,
    _reminderAt?.toIso8601String(),
    _selectedDate.toIso8601String(),
  ].join('\u0001');

  bool get _hasUnsavedChanges =>
      !_isSaving && _initialSnapshot != null && _snapshot() != _initialSnapshot;

  /// Typing doesn't rebuild the form; rebuild when the dirty state flips so
  /// the discard guard knows.
  void _onTextEdited() {
    final dirty = _hasUnsavedChanges;
    if (dirty != _wasDirty && mounted) setState(() => _wasDirty = dirty);
  }

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _amountController,
      _titleController,
      _noteController,
    ]) {
      controller.addListener(_onTextEdited);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialSnapshot = _snapshot();
    });
    final transaction = widget.initialTransaction;
    if (transaction == null) {
      _selectedCurrency = _baseCurrency;
      return;
    }

    _type = _formTypeFor(transaction.type);

    // A linked transfer leg loads the whole pair: From is the outflow's
    // account, To the inflow's, and the amount is what left the source.
    if (transaction.type.isTransfer) {
      final partners = transferPartnersOf(
        transaction,
        ref.read(transactionsProvider).value ?? const [],
      );
      if (partners.isNotEmpty) {
        final partner = partners.first;
        final isIn = transaction.type == TransactionType.transferIn;
        _pairOut = isIn ? partner : transaction;
        _pairIn = isIn ? transaction : partner;
      }
    }
    final primary = _pairOut ?? transaction;

    _titleController.text = primary.merchant ?? '';
    _amountController.text = primary.amount.amount.toString();
    _selectedCurrency = _normalizeCurrency(primary.amount.currency);
    _noteController.text = primary.note ?? '';
    _selectedDate = primary.date;
    _selectedCategoryId = transaction.categoryId;
    _selectedAccountId = primary.accountId;
    _selectedToAccountId = _pairIn?.accountId;
    final pairOut = _pairOut;
    final pairIn = _pairIn;
    if (pairOut != null &&
        pairIn != null &&
        pairIn.amount.currency != pairOut.amount.currency &&
        !pairOut.amount.isZero) {
      // Show the pair's own conversion and keep a live quote from replacing it.
      final rate = (pairIn.amount.amount / pairOut.amount.amount).toDecimal(
        scaleOnInfinitePrecision: 10,
      );
      _pairToRateText = rate.toString();
      _toExchangeRateController.text = _pairToRateText!;
      _fetchedToRatePair =
          '$_selectedCurrency>${_normalizeCurrency(pairIn.amount.currency)}';
    }
    _tags.addAll(primary.tags);
    _isRecurring = transaction.isRecurring;
    final frequency = transaction.recurringFrequency;
    if (frequency != null) {
      _recurringFrequency = frequency;
    }
    final settings = transaction.recurringSettings;
    if (settings != null) {
      _recurringEndDate = settings.endDate;
      _recurringMaxOccurrences = settings.maxOccurrences;
      _recurringDayOfWeek = settings.dayOfWeek;
      _recurringDayOfMonth = settings.dayOfMonth;
      _recurringMonthOfYear = settings.monthOfYear;
    }
    _reminderAt = primary.reminderAt;
    _reminderLead = _inferReminderLead(primary.date, _reminderAt);
  }

  /// The form's Expense/Income/Transfer choice for a stored type.
  static TransactionType _formTypeFor(TransactionType type) {
    if (type == TransactionType.income) return TransactionType.income;
    if (type.isTransfer) return TransactionType.transfer;
    return TransactionType.expense;
  }

  /// Picks the [ReminderLead] that matches an existing [reminderAt] relative
  /// to [transactionDate]. Falls back to [ReminderLead.custom] when the gap
  /// isn't one of the presets, and to [ReminderLead.oneHour] when there is
  /// no reminder yet.
  ReminderLead _inferReminderLead(
    DateTime transactionDate,
    DateTime? reminderAt,
  ) {
    if (reminderAt == null) return ReminderLead.oneHour;
    final diffMinutes = transactionDate.difference(reminderAt).inMinutes;
    for (final lead in ReminderLead.values) {
      if (lead.minutes != null && lead.minutes == diffMinutes) {
        return lead;
      }
    }
    return ReminderLead.custom;
  }

  void _addTag(String value) {
    final tag = value.trim();
    if (tag.isEmpty || _tags.contains(tag)) {
      _tagInputController.clear();
      return;
    }
    setState(() {
      _tags.add(tag);
      _tagInputController.clear();
    });
  }

  void _addTagsFromInput(String value) {
    final tags = value
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty);
    for (final tag in tags) {
      if (!_tags.contains(tag)) {
        _tags.add(tag);
      }
    }
    setState(_tagInputController.clear);
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  /// Handles the user picking a different transaction type (Expense / Income /
  /// Transfer) on the segmented selector. In add mode this resets the typed
  /// fields so a half-entered expense can't accidentally be saved as an
  /// income (or vice versa). In edit mode we only clear the category since
  /// expense/income categories live in disjoint sets; the rest of the
  /// transaction is preserved so the user can flip the type without losing
  /// their work.
  ///
  /// Date, recurring-series settings, and attachments are preserved in add
  /// mode too — they describe the transaction context, not its direction.
  void _onTransactionTypeChanged(TransactionType newType) {
    if (!_canSwitchTo(newType)) return;
    if (widget.initialTransaction != null) {
      setState(() {
        _type = newType;
        _selectedCategoryId = null;
      });
      return;
    }

    setState(() {
      _type = newType;
      _titleController.clear();
      _amountController.clear();
      _selectedCurrency = _baseCurrency;
      _exchangeRateController.text = '1.00';
      _toExchangeRateController.text = '1.00';
      _fetchedToRatePair = null;
      _noteController.clear();
      _selectedCategoryId = null;
      _selectedAccountId = null;
      _selectedToAccountId = null;
      _tags.clear();
      _tagInputController.clear();
    });
  }

  void _applyItemSuggestion(FinanceTransaction suggestion) {
    final amountText = suggestion.amount.amount.toStringAsFixed(2);
    final currency = _normalizeCurrency(suggestion.amount.currency);

    final validCategoryId = _validateSuggestionCategory(suggestion.categoryId);
    final validAccountId = _validateSuggestionAccount(suggestion.accountId);

    setState(() {
      _amountController.text = amountText;
      _selectedCurrency = currency;
      _exchangeRateController.text = '1.00';
      if (validCategoryId != null) {
        _selectedCategoryId = validCategoryId;
      }
      if (validAccountId != null) {
        _selectedAccountId = validAccountId;
      }
      _tags
        ..clear()
        ..addAll(suggestion.tags);
    });
  }

  String? _validateSuggestionCategory(String? categoryId) {
    if (categoryId == null || _type == TransactionType.transfer) {
      return null;
    }
    final categories =
        ref.read(categoriesProvider).whenOrNull(data: (value) => value) ??
        const <Category>[];
    final expectedType = _categoryTypeFor(_type);
    for (final category in categories) {
      if (category.id == categoryId &&
          category.isActive &&
          category.type == expectedType) {
        return category.id;
      }
    }
    return null;
  }

  String? _validateSuggestionAccount(String? accountId) {
    if (accountId == null) {
      return null;
    }
    final accounts =
        ref.read(accountsProvider).whenOrNull(data: (value) => value) ??
        const <Account>[];
    for (final account in accounts) {
      if (account.id == accountId && account.isActive) {
        return account.id;
      }
    }
    return null;
  }

  void _onTransferFromAccountSelected(String selectedAccountId) {
    setState(() {
      if (_selectedToAccountId == selectedAccountId) {
        _selectedToAccountId = _selectedAccountId;
      }
      _selectedAccountId = selectedAccountId;
    });
    _autofillTransferRates();
  }

  void _onTransferToAccountSelected(String selectedAccountId) {
    setState(() {
      if (_selectedAccountId == selectedAccountId) {
        _selectedAccountId = _selectedToAccountId;
      }
      _selectedToAccountId = selectedAccountId;
    });
    _autofillTransferRates();
  }

  /// Both legs of a transfer convert from the entered currency: the source
  /// leg into the source account's currency, the destination leg into the
  /// destination's.
  void _autofillTransferRates() {
    final accounts =
        ref.read(accountsProvider).whenOrNull(data: (value) => value) ??
        const <Account>[];
    _maybeAutofillRate(_accountCurrencyFor(accounts, _selectedAccountId));
    _maybeAutofillToRate(_accountCurrencyFor(accounts, _selectedToAccountId));
  }

  void _autofillForm({
    required double amount,
    required String note,
    required TransactionType type,
    required DateTime date,
    String title = '',
    String currency = 'THB',
  }) {
    setState(() {
      _titleController.text = title;
      _amountController.text = amount.toStringAsFixed(2);
      _selectedCurrency = _normalizeCurrency(currency);
      _noteController.text = note;
      if (_canSwitchTo(type)) _type = type;
      _selectedDate = date;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.txAikoAutofilled(amount.toStringAsFixed(2)),
              ),
            ),
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
          content: Text(context.l10n.txCameraUnavailable),
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
          content: Text(context.l10n.txCapturedImageUnreadable),
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
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Flexible(child: Text(context.l10n.txScanningReceipt)),
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
        currency: _baseCurrency,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.txReceiptScanFailed),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Close spinner

    setState(() {
      _attachments.add(attachment);
    });

    if (!autofill.hasTransactionFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.txReceiptLimitedFields),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    _autofillForm(
      amount: autofill.total?.amount.toDouble() ?? 0.0,
      note: context.l10n.txScannedReceiptNote(
        autofill.merchant ?? captured.name,
      ),
      type: TransactionType.expense,
      date: autofill.date ?? DateTime.now(),
      title: autofill.merchant ?? '',
      currency: autofill.total?.currency ?? _baseCurrency,
    );
  }

  void _showVoiceCommandDialog() {
    final voiceTextController = TextEditingController(
      text: context.l10n.txVoiceExample,
    );

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.mic, color: AikoColors.premiumPurple),
              const SizedBox(width: 8),
              Text(
                context.l10n.txVoiceAssistantTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AikoColors.deepBlue,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: voiceTextController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.txVoiceDescriptionLabel,
              hintText: context.l10n.txVoiceDescriptionHint,
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final text = voiceTextController.text.trim();
                Navigator.of(context).pop();
                _parseVoiceCommand(text);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AikoColors.premiumPurple,
              ),
              child: Text(context.l10n.txParseDraft),
            ),
          ],
        );
      },
    );
  }

  void _parseVoiceCommand(String command) {
    try {
      const parser = VoiceTransactionParser();
      final draft = parser.parse(
        command,
        now: DateTime.now(),
        currency: _baseCurrency,
      );

      _autofillForm(
        amount: draft.amount.amount.toDouble(),
        note: draft.note ?? context.l10n.txVoiceNoteFallback,
        type: draft.type == TransactionType.income
            ? TransactionType.income
            : TransactionType.expense,
        date: draft.date,
        title: draft.merchant ?? '',
        currency: draft.amount.currency,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.txVoiceParseFailed)));
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

  /// Auto-fills the exchange rate with a live quote when the selected account
  /// tracks a currency different from the amount's. Skips a pair already fetched
  /// (or being fetched) so it's safe to call from every relevant change/build.
  /// On failure the rate stays at its current value for the user to enter.
  Future<void> _maybeAutofillRate(String? accountCurrency) async {
    if (accountCurrency == null || accountCurrency == _selectedCurrency) {
      return;
    }
    final pair = '$_selectedCurrency>$accountCurrency';
    if (_isFetchingRate || _fetchedRatePair == pair) {
      return;
    }

    setState(() {
      _isFetchingRate = true;
      _fetchedRatePair = pair;
    });
    final rate = await ref
        .read(exchangeRateServiceProvider)
        .fetchRate(_selectedCurrency, accountCurrency);
    if (!mounted) {
      return;
    }
    setState(() {
      _isFetchingRate = false;
      if (rate != null) {
        _exchangeRateController.text = rate.toStringAsFixed(4);
      }
      // On failure we keep the pair marked as attempted so `build` doesn't
      // auto-retry in a loop. The refresh button / manual edit let the user
      // retry or enter a rate by hand.
    });
  }

  /// Like [_maybeAutofillRate], for a transfer's destination account.
  Future<void> _maybeAutofillToRate(String? accountCurrency) async {
    if (accountCurrency == null || accountCurrency == _selectedCurrency) {
      return;
    }
    final pair = '$_selectedCurrency>$accountCurrency';
    if (_isFetchingToRate || _fetchedToRatePair == pair) {
      return;
    }
    setState(() {
      _isFetchingToRate = true;
      _fetchedToRatePair = pair;
    });
    final rate = await ref
        .read(exchangeRateServiceProvider)
        .fetchRate(_selectedCurrency, accountCurrency);
    if (!mounted) {
      return;
    }
    setState(() {
      _isFetchingToRate = false;
      if (rate != null) {
        _toExchangeRateController.text = rate.toStringAsFixed(4);
      }
    });
  }

  /// Lets the user override the auto-filled rate. The amount itself is left in
  /// its entered currency — the conversion happens at save time.
  /// [destination] edits the rate for a transfer's destination account.
  Future<void> _editRateManually(
    String selectedCurrency,
    String accountCurrency, {
    bool destination = false,
  }) async {
    final rateController = destination
        ? _toExchangeRateController
        : _exchangeRateController;
    final controller = TextEditingController(text: rateController.text.trim());
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.txRateEquals(selectedCurrency)),
        content: TextField(
          key: const Key('transaction-exchange-rate-field'),
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: accountCurrency),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.l10n.txUseThisRate),
          ),
        ],
      ),
    );
    controller.dispose();

    final rate = result == null ? null : Decimal.tryParse(result);
    if (rate == null || rate <= Decimal.zero) {
      return;
    }
    setState(() {
      rateController.text = rate.toStringAsFixed(4);
      // A manual rate sticks — don't let an auto-fetch overwrite it.
      if (destination) {
        _fetchedToRatePair = '$_selectedCurrency>$accountCurrency';
      } else {
        _fetchedRatePair = '$_selectedCurrency>$accountCurrency';
      }
    });
  }

  Future<void> _showAmountCalculator() async {
    final currentAmount = _amountController.text.trim();

    final result = await showAikoSheet<Decimal>(
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
    showAikoSheet<void>(
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
                context.l10n.txDocumentUpload,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AikoColors.premiumPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.txChooseAttachmentSource,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.folder_open,
                  color: AikoColors.deepBlue,
                ),
                title: Text(context.l10n.txFilesAndDocuments),
                subtitle: Text(context.l10n.txFilesAndDocumentsSubtitle),
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
                title: Text(context.l10n.txPhotoGallery),
                subtitle: Text(context.l10n.txPhotoGallerySubtitle),
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
        acceptedTypeGroups: [
          fs.XTypeGroup(
            label: context.l10n.txFilePickerTypeLabel,
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
          content: Text(context.l10n.txFilePickerUnavailable),
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
          content: Text(context.l10n.txGalleryUnavailable),
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
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Flexible(child: Text(context.l10n.txAttachingDocument)),
            ],
          ),
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Close spinner

    final newAttachment = TransactionAttachment(
      id: const Uuid().v4(),
      userId: '',
      transactionId: '',
      fileName: fileName,
      storagePath: await LocalFileCache.write(
        'attachments/${const Uuid().v4()}',
        await LocalFileCache.read(storagePath),
      ),
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      createdAt: DateTime.now(),
    );

    if (!mounted) return;
    setState(() {
      _attachments.add(newAttachment);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(context.l10n.txAttachedFile(fileName))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Removes an attachment from the local list before the transaction is saved.
  ///
  /// This only touches the in-memory [_attachments] list — it does not delete
  /// the underlying file or any persisted row, since an unsaved attachment has
  /// neither a cloud row nor a committed local file. Saved attachments are
  /// managed elsewhere.
  void _removeAttachment(TransactionAttachment attachment) {
    setState(() {
      _attachments.removeWhere((item) => item.id == attachment.id);
    });
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
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
      return 'text/markdown';
    }
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument'
          '.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }

  void _showFormError(String message, {Color color = AikoColors.dangerRed}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Out-of-range recurring numbers are shown on their fields; this stops the
  /// save until they're fixed. Returns the message to show, or null.
  String? _recurringSettingsError() {
    if (!_isRecurring || _type == TransactionType.transfer) return null;
    final usesDayOfMonth =
        _recurringFrequency == RecurringFrequency.monthly ||
        _recurringFrequency == RecurringFrequency.annually;
    final day = _recurringDayOfMonth;
    if (usesDayOfMonth && day != null && (day < 1 || day > 31)) {
      return context.l10n.txNumberRange(1, 31);
    }
    final max = _recurringMaxOccurrences;
    if (_recurringFrequency != RecurringFrequency.once &&
        max != null &&
        (max < 1 || max > _maxOccurrencesLimit)) {
      return context.l10n.txNumberRange(1, _maxOccurrencesLimit);
    }
    return null;
  }

  Future<void> _submitForm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _validateAndSave();
    } catch (_) {
      // A failed save keeps the form open with what the user entered.
      if (mounted) _showSaveError();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _validateAndSave() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showFormError(context.l10n.txEnterAmount);
      return;
    }

    final amount = parseAmountInput(amountText);
    if (amount == null || amount <= Decimal.zero) {
      _showFormError(context.l10n.txEnterValidAmount);
      return;
    }

    if (_selectedAccountId == null) {
      _showFormError(
        context.l10n.txSelectAccountError,
        color: AikoColors.warningOrange,
      );
      return;
    }

    final existingTransaction = widget.initialTransaction;
    // New transfers and linked pairs need both ends; a legacy unlinked leg
    // only knows its own account.
    final savesTransferPair =
        _type == TransactionType.transfer &&
        (existingTransaction == null || _pairOut != null);
    if (savesTransferPair && _selectedToAccountId == null) {
      _showFormError(
        context.l10n.txSelectDestinationError,
        color: AikoColors.warningOrange,
      );
      return;
    }

    final recurringError = _recurringSettingsError();
    if (recurringError != null) {
      _showFormError(recurringError, color: AikoColors.warningOrange);
      return;
    }

    // Convert into the account's currency at save time. The amount is entered
    // in `_selectedCurrency`; if the account tracks a different currency we
    // multiply by the (auto-filled or manually edited) rate and store the
    // result in the account's currency. See docs/currency-conversion.md.
    final accounts =
        ref.read(accountsProvider).whenOrNull(data: (value) => value) ??
        const <Account>[];
    final accountCurrency = _accountCurrencyFor(accounts, _selectedAccountId);
    var effectiveAmount = amount;
    var effectiveCurrency = _selectedCurrency;
    if (accountCurrency != null && accountCurrency != _selectedCurrency) {
      final rate = Decimal.tryParse(_exchangeRateController.text.trim());
      if (rate == null || rate <= Decimal.zero) {
        _showFormError(
          context.l10n.txEnterPositiveRate,
          color: AikoColors.warningOrange,
        );
        return;
      }
      effectiveAmount = amount * rate;
      effectiveCurrency = accountCurrency;
    }

    // An edited row keeps its stored type (a refund stays a refund, a
    // transfer leg keeps its direction) unless the user picked another one.
    final txType =
        existingTransaction != null &&
            _type == _formTypeFor(existingTransaction.type)
        ? existingTransaction.type
        : switch (_type) {
            TransactionType.income => TransactionType.income,
            TransactionType.transfer => TransactionType.transfer,
            _ => TransactionType.expense,
          };

    final txId = existingTransaction?.id ?? const Uuid().v4();
    final pendingTagText = _tagInputController.text.trim();
    final tags = {
      ..._tags,
      if (pendingTagText.isNotEmpty) pendingTagText,
    }.toList(growable: false);
    final itemName = _titleController.text.trim();
    final categoryName = _categoryNameFor(
      ref
              .read(categoriesProvider)
              .whenOrNull(data: (categories) => categories) ??
          const [],
      _selectedCategoryId,
    );

    // A transfer is recorded as a linked outflow/inflow pair: one leg leaves
    // the source account, the other arrives in the destination. Editing a
    // linked leg re-saves both; a legacy unlinked leg falls through to the
    // single-row path below.
    if (savesTransferPair) {
      // The destination leg converts from the entered amount into the
      // destination account's currency, so its balance changes too.
      final toCurrency = _accountCurrencyFor(accounts, _selectedToAccountId);
      var inAmount = amount;
      var inCurrency = _selectedCurrency;
      if (toCurrency != null && toCurrency != _selectedCurrency) {
        final rate = Decimal.tryParse(_toExchangeRateController.text.trim());
        if (rate == null || rate <= Decimal.zero) {
          _showFormError(
            context.l10n.txEnterPositiveRate,
            color: AikoColors.warningOrange,
          );
          return;
        }
        inAmount = amount * rate;
        inCurrency = toCurrency;
      }
      await _submitTransferPair(
        amount: effectiveAmount,
        currency: effectiveCurrency,
        enteredAmount: amount,
        inAmount: inAmount,
        inCurrency: inCurrency,
        tags: tags,
        note: _noteController.text.trim(),
        itemName: itemName,
      );
      return;
    }

    final savedTx = FinanceTransaction(
      id: txId,
      userId: existingTransaction?.userId ?? '',
      accountId: _selectedAccountId!,
      type: txType,
      amount: Money(amount: effectiveAmount, currency: effectiveCurrency),
      date: _selectedDate,
      categoryId: _selectedCategoryId,
      merchant: itemName.isEmpty ? categoryName : itemName,
      note: _noteController.text.trim(),
      tags: tags,
      splits: existingTransaction?.splits ?? const [],
      status: existingTransaction?.status ?? TransactionStatus.posted,
      isRecurring: _isRecurring,
      recurringFrequency: _isRecurring ? _recurringFrequency : null,
      recurringSettings: _isRecurring ? _buildRecurringSettings() : null,
      reminderAt: _reminderAt,
      transferGroupId: existingTransaction?.transferGroupId,
    );

    final saved = await ref
        .read(transactionsProvider.notifier)
        .saveTransaction(savedTx);

    await _syncReminder(savedTx);
    await _saveAttachmentsFor(txId);

    if (!mounted) return;
    _showSaveSuccess(context.l10n.txSaved);
    Navigator.of(context).pop(saved);
  }

  /// Saves a transfer as two linked rows: an outflow leaving the source
  /// account and an inflow arriving in the destination, sharing one
  /// `transferGroupId`. When editing a linked pair both rows are updated in
  /// place. When the user leaves the item name blank we default to a sensible
  /// `Transfer to/from <account>` label so each leg reads clearly in the list.
  Future<void> _submitTransferPair({
    required Decimal amount,
    required String currency,
    required Decimal enteredAmount,
    required Decimal inAmount,
    required String inCurrency,
    required List<String> tags,
    required String note,
    required String itemName,
  }) async {
    final l10n = context.l10n;
    final accounts =
        ref.read(accountsProvider).whenOrNull(data: (value) => value) ??
        const <Account>[];
    String nameFor(String? id) {
      for (final account in accounts) {
        if (account.id == id) return account.name;
      }
      return l10n.txUnknownAccount;
    }

    final pairOut = _pairOut;
    final pairIn = _pairIn;
    var outMoney = Money(amount: amount, currency: currency);
    var inMoney = Money(amount: inAmount, currency: inCurrency);
    if (pairOut != null &&
        pairIn != null &&
        pairOut.amount.currency != pairIn.amount.currency) {
      // A cross-currency pair keeps its stored amounts: re-converting would
      // drift through rounding, so amount/currency/account edits are blocked.
      final unchanged =
          enteredAmount == pairOut.amount.amount &&
          _selectedCurrency == _normalizeCurrency(pairOut.amount.currency) &&
          _selectedAccountId == pairOut.accountId &&
          _selectedToAccountId == pairIn.accountId &&
          _toExchangeRateController.text.trim() == _pairToRateText;
      if (!unchanged) {
        _showFormError(
          l10n.txTransferCrossCurrencyLocked,
          color: AikoColors.warningOrange,
        );
        return;
      }
      outMoney = pairOut.amount;
      inMoney = pairIn.amount;
    }

    final toName = nameFor(_selectedToAccountId);
    final fromName = nameFor(_selectedAccountId);
    // An untouched title on an edited pair leaves each leg's own label.
    final titleUnchanged =
        pairOut != null && itemName == (pairOut.merchant ?? '').trim();
    String merchantFor(FinanceTransaction? existing, String defaultLabel) {
      if (itemName.isEmpty) return defaultLabel;
      if (titleUnchanged && existing != null) {
        return existing.merchant ?? defaultLabel;
      }
      return itemName;
    }

    final groupId =
        pairOut?.transferGroupId ??
        pairIn?.transferGroupId ??
        const Uuid().v4();
    final outLeg =
        (pairOut ??
                FinanceTransaction(
                  id: const Uuid().v4(),
                  userId: '',
                  accountId: _selectedAccountId!,
                  type: TransactionType.transferOut,
                  amount: outMoney,
                  date: _selectedDate,
                ))
            .copyWith(
              accountId: _selectedAccountId!,
              amount: outMoney,
              date: _selectedDate,
              merchant: merchantFor(pairOut, l10n.txTransferToName(toName)),
              note: note,
              tags: tags,
              reminderAt: _reminderAt,
              clearReminderAt: _reminderAt == null,
              transferGroupId: groupId,
            );
    final inLeg =
        (pairIn ??
                FinanceTransaction(
                  id: const Uuid().v4(),
                  userId: '',
                  accountId: _selectedToAccountId!,
                  type: TransactionType.transferIn,
                  amount: inMoney,
                  date: _selectedDate,
                ))
            .copyWith(
              accountId: _selectedToAccountId!,
              amount: inMoney,
              date: _selectedDate,
              merchant: merchantFor(pairIn, l10n.txTransferFromName(fromName)),
              note: note,
              tags: tags,
              transferGroupId: groupId,
            );

    final saved = await ref
        .read(transactionsProvider.notifier)
        .saveTransactions([outLeg, inLeg]);

    // Reminder + receipts/docs attach to the outflow leg.
    await _syncReminder(outLeg);
    await _saveAttachmentsFor(outLeg.id);
    if (!mounted) return;

    _showSaveSuccess(l10n.txTransferSaved);
    // Hand back the leg that was opened (the inflow for a new transfer).
    final openedId = widget.initialTransaction?.id ?? inLeg.id;
    Navigator.of(context).pop(saved.firstWhere((leg) => leg.id == openedId));
  }

  Future<void> _saveAttachmentsFor(String txId) async {
    if (_attachments.isEmpty) return;
    try {
      const attachmentRepo = TransactionAttachmentRepository();
      for (final attachment in _attachments) {
        await attachmentRepo.save(
          TransactionAttachment(
            id: attachment.id,
            userId: attachment.userId,
            transactionId: txId,
            fileName: attachment.fileName,
            storagePath: attachment.storagePath,
            mimeType: attachment.mimeType,
            sizeBytes: attachment.sizeBytes,
            createdAt: attachment.createdAt,
            isSensitive: attachment.isSensitive,
            exportPolicy: attachment.exportPolicy,
          ),
        );
      }
    } catch (e) {
      debugPrint(
        'Offline/local session faked: attachment metadata bypass cloud ($e)',
      );
    }
  }

  void _showSaveError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.txSaveFailed),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSaveSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Populates the per-cadence knobs with sensible defaults for the
  /// currently selected frequency. Called when the user opts in to
  /// recurring or switches the cadence.
  void _applyFrequencyDefaults(RecurringFrequency frequency) {
    final anchor = _selectedDate;
    switch (frequency) {
      case RecurringFrequency.once:
        _recurringEndDate ??= anchor.add(const Duration(days: 1));
        _recurringMaxOccurrences = null;
        _recurringDayOfWeek = null;
        _recurringDayOfMonth = null;
        _recurringMonthOfYear = null;
      case RecurringFrequency.daily:
        _recurringEndDate ??= anchor.add(const Duration(days: 30));
        _recurringMaxOccurrences ??= 30;
        _recurringDayOfWeek = null;
        _recurringDayOfMonth = null;
        _recurringMonthOfYear = null;
      case RecurringFrequency.weekly:
        _recurringEndDate ??= anchor.add(const Duration(days: 84));
        _recurringMaxOccurrences ??= 12;
        _recurringDayOfWeek ??= anchor.weekday;
        _recurringDayOfMonth = null;
        _recurringMonthOfYear = null;
      case RecurringFrequency.monthly:
        _recurringEndDate ??= DateTime(
          anchor.year + 1,
          anchor.month,
          anchor.day,
        );
        _recurringMaxOccurrences ??= 12;
        _recurringDayOfMonth ??= anchor.day;
        _recurringDayOfWeek = null;
        _recurringMonthOfYear = null;
      case RecurringFrequency.annually:
        _recurringEndDate ??= DateTime(
          anchor.year + 5,
          anchor.month,
          anchor.day,
        );
        _recurringMaxOccurrences ??= 5;
        _recurringMonthOfYear ??= anchor.month;
        _recurringDayOfMonth ??= anchor.day;
        _recurringDayOfWeek = null;
    }
  }

  RecurringSettings _buildRecurringSettings() {
    return RecurringSettings(
      endDate: _recurringEndDate,
      maxOccurrences: _recurringMaxOccurrences,
      dayOfWeek: _recurringDayOfWeek,
      dayOfMonth: _recurringDayOfMonth,
      monthOfYear: _recurringMonthOfYear,
    );
  }

  /// Default reminder: 9am on the transaction's date, or an hour from now if
  /// that's already past.
  DateTime _defaultReminderTime() {
    final candidate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      9,
    );
    final now = DateTime.now();
    return candidate.isAfter(now)
        ? candidate
        : now.add(const Duration(hours: 1));
  }

  /// Recomputes an existing [_reminderAt] from [_selectedDate] and
  /// [_reminderLead].
  ///
  /// Called whenever the transaction date or lead changes. Does nothing when
  /// no reminder is set (picking a date must not turn one on). The `custom`
  /// lead leaves [_reminderAt] untouched; otherwise the reminder is pinned to
  /// `transactionDate - lead`.
  void _recomputeReminderForLead() {
    if (_reminderAt == null || _reminderLead == ReminderLead.custom) return;
    _reminderAt = _leadReminderTime();
  }

  /// `transactionDate - lead` for the current preset lead.
  DateTime _leadReminderTime() =>
      _selectedDate.subtract(Duration(minutes: _reminderLead.minutes ?? 0));

  /// Sets the reminder lead and recomputes [_reminderAt] accordingly.
  void _setReminderLead(ReminderLead lead) {
    setState(() {
      _reminderLead = lead;
      if (lead == ReminderLead.custom) {
        _reminderAt ??= _defaultReminderTime();
      } else {
        _recomputeReminderForLead();
      }
    });
  }

  /// Schedules (or clears) the OS reminder for [transaction]. Best-effort —
  /// failures are swallowed inside the service so a save never fails here.
  Future<void> _syncReminder(FinanceTransaction transaction) =>
      TransactionReminderService.instance.scheduleFor(
        transaction,
        context.l10n,
      );

  Future<void> _pickReminderTime() async {
    final initial = _reminderAt ?? _defaultReminderTime();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 366 * 5)),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;
    setState(() {
      _reminderAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final categoryGroupsAsync = ref.watch(categoryGroupsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
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
    final toAccountCurrency = _type == TransactionType.transfer
        ? _accountCurrencyFor(accountSnapshot, _selectedToAccountId)
        : null;
    final showToCurrencyConversion =
        toAccountCurrency != null && toAccountCurrency != _selectedCurrency;
    final selectedTypeColor = _transactionTypeColor(_type);

    return AikoDiscardChangesGuard(
      hasUnsavedChanges: _hasUnsavedChanges,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialTransaction == null
                ? context.l10n.txAddTitle
                : context.l10n.txEditTitle,
          ),
          actions: [
            IconButton(
              tooltip: context.l10n.txScanReceipt,
              onPressed: _scanReceiptWithCamera,
              icon: const Icon(Icons.receipt_long_outlined),
            ),
            IconButton(
              tooltip: context.l10n.txVoiceEntry,
              onPressed: _showVoiceCommandDialog,
              icon: const Icon(Icons.mic_none_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Standard Entry Fields
            SegmentedButton<TransactionType>(
              key: const Key('transaction-type-selector'),
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return selectedTypeColor;
                  }
                  return null;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Theme.of(context).colorScheme.onPrimary;
                  }
                  return null;
                }),
                iconColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Theme.of(context).colorScheme.onPrimary;
                  }
                  return null;
                }),
              ),
              segments: [
                ButtonSegment<TransactionType>(
                  value: TransactionType.expense,
                  label: Text(context.l10n.transactionTypeExpense),
                  icon: Icon(Icons.north_east),
                  enabled: _canSwitchTo(TransactionType.expense),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.income,
                  label: Text(context.l10n.transactionTypeIncome),
                  icon: Icon(Icons.south_west),
                  enabled: _canSwitchTo(TransactionType.income),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.transfer,
                  label: Text(context.l10n.transactionTypeTransfer),
                  icon: Icon(Icons.swap_horiz),
                  enabled: _canSwitchTo(TransactionType.transfer),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  _onTransactionTypeChanged(selection.first),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 6),
              Text(
                _type == TransactionType.transfer
                    ? context.l10n.txTypeLockedTransfer
                    : context.l10n.txTypeLockedNonTransfer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _ItemNameInput(
              controller: _titleController,
              suggestions: _itemNameSuggestionsFrom(
                transactionsAsync,
                selectedType: _transactionTypeFromFormType(_type),
              ),
              onSelected: _applyItemSuggestion,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('transaction-amount-field'),
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: context.l10n.txAmount,
                      suffixIcon: IconButton(
                        key: const Key('amount-calculator-button'),
                        tooltip: context.l10n.txOpenCalculator,
                        onPressed: _showAmountCalculator,
                        icon: const Icon(Icons.calculate_outlined),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    // Digits, one decimal point and thousands commas.
                    inputFormatters: [AmountInputFormatter()],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 124,
                  child: DropdownMenu<String>(
                    key: ValueKey(_selectedCurrency),
                    initialSelection: _selectedCurrency,
                    expandedInsets: EdgeInsets.zero,
                    label: Text(context.l10n.txCurrency),
                    dropdownMenuEntries: [
                      for (final currency in currencyOptions)
                        DropdownMenuEntry(value: currency, label: currency),
                    ],
                    onSelected: (value) {
                      if (value != null) {
                        setState(() => _selectedCurrency = value);
                        _maybeAutofillRate(
                          _accountCurrencyFor(
                            accountSnapshot,
                            _selectedAccountId,
                          ),
                        );
                        if (_type == TransactionType.transfer) {
                          _maybeAutofillToRate(
                            _accountCurrencyFor(
                              accountSnapshot,
                              _selectedToAccountId,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category dropdown
            if (_type != TransactionType.transfer) ...[
              categoriesAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, _) => Text(context.l10n.txCategoriesLoadError),
                data: (categories) {
                  final selectedCategoryType = _categoryTypeFor(_type);
                  final activeCategories = categories
                      .where(
                        (category) =>
                            category.isActive &&
                            category.type == selectedCategoryType,
                      )
                      .toList();
                  if (activeCategories.isEmpty) {
                    return Text(context.l10n.txNoCategories);
                  }
                  final loadedGroups = categoryGroupsAsync.value;
                  final fallbackGroups =
                      activeCategories.any(
                        (category) => category.templateId != null,
                      )
                      ? CategoryGroupDefaults.forUser(
                          activeCategories.first.userId,
                        )
                      : CategoryGroupDefaults.all;
                  final groups = loadedGroups ?? fallbackGroups;
                  final orderedGroups = <CategoryGroup>[
                    for (final group in groups)
                      if (group.effectiveTemplateId !=
                          CategoryGroupDefaults.unfiledGroupId)
                        group,
                    for (final group in groups)
                      if (group.effectiveTemplateId ==
                          CategoryGroupDefaults.unfiledGroupId)
                        group,
                  ];
                  return _CategoryPicker(
                    categories: activeCategories,
                    groups: orderedGroups,
                    selectedCategoryId: _selectedCategoryId,
                    transactionType: _type,
                    onSelected: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            // Account dropdown(s)
            accountsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => Text(context.l10n.txAccountsLoadError),
              data: (accounts) {
                final activeAccounts = accounts
                    .where((a) => a.isActive)
                    .toList();
                if (activeAccounts.isEmpty) {
                  return Text(context.l10n.txNoAccounts);
                }

                if (_isUnlinkedTransferLeg) {
                  // A legacy leg only knows its own account: label it by side.
                  final isInflow =
                      widget.initialTransaction!.type ==
                      TransactionType.transferIn;
                  return _AccountPicker(
                    label: isInflow
                        ? context.l10n.txToAccount
                        : context.l10n.txFromAccount,
                    fieldKey: isInflow ? 'to-account' : 'from-account',
                    accounts: activeAccounts,
                    selectedAccountId: _selectedAccountId,
                    onSelected: (value) {
                      setState(() => _selectedAccountId = value);
                      _maybeAutofillRate(
                        _accountCurrencyFor(accountSnapshot, value),
                      );
                    },
                  );
                }
                if (_type == TransactionType.transfer) {
                  // Show the source and destination side by side with an arrow
                  // between them, so the money visibly moves left → right.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _AccountPicker(
                          label: context.l10n.txFromAccount,
                          fieldKey: 'from-account',
                          accounts: activeAccounts,
                          selectedAccountId: _selectedAccountId,
                          onSelected: _onTransferFromAccountSelected,
                          compact: true,
                        ),
                      ),
                      const _TransferFlowArrow(),
                      Expanded(
                        child: _AccountPicker(
                          label: context.l10n.txToAccount,
                          fieldKey: 'to-account',
                          accounts: activeAccounts,
                          selectedAccountId: _selectedToAccountId,
                          onSelected: _onTransferToAccountSelected,
                          compact: true,
                        ),
                      ),
                    ],
                  );
                } else {
                  return _AccountPicker(
                    label: context.l10n.txAccount,
                    fieldKey: 'account',
                    accounts: activeAccounts,
                    selectedAccountId: _selectedAccountId,
                    onSelected: (value) {
                      setState(() => _selectedAccountId = value);
                      _maybeAutofillRate(
                        _accountCurrencyFor(accountSnapshot, value),
                      );
                    },
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            if (showCurrencyConversion) ...[
              _CurrencyConversionPrompt(
                selectedCurrency: _selectedCurrency,
                accountCurrency: selectedAccountCurrency,
                exchangeRateController: _exchangeRateController,
                amountController: _amountController,
                isFetchingRate: _isFetchingRate,
                onRefreshRate: () {
                  _fetchedRatePair = null;
                  _maybeAutofillRate(selectedAccountCurrency);
                },
                onEditRate: () => _editRateManually(
                  _selectedCurrency,
                  selectedAccountCurrency,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (showToCurrencyConversion) ...[
              _CurrencyConversionPrompt(
                selectedCurrency: _selectedCurrency,
                accountCurrency: toAccountCurrency,
                exchangeRateController: _toExchangeRateController,
                amountController: _amountController,
                isFetchingRate: _isFetchingToRate,
                onRefreshRate: () {
                  _fetchedToRatePair = null;
                  _maybeAutofillToRate(toAccountCurrency);
                },
                onEditRate: () => _editRateManually(
                  _selectedCurrency,
                  toAccountCurrency,
                  destination: true,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Date and time selection tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(context.l10n.txDateTime),
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
                  _recomputeReminderForLead();
                });
              },
            ),
            const SizedBox(height: 12),

            _TagInput(
              tags: _tags,
              suggestions: _tagSuggestionsFrom(
                transactionsAsync,
                selectedType: _transactionTypeFromFormType(_type),
              ),
              inputController: _tagInputController,
              focusNode: _tagFocusNode,
              onAddTag: _addTag,
              onAddTagsFromInput: _addTagsFromInput,
              onRemoveTag: _removeTag,
            ),
            const SizedBox(height: 12),

            TextField(
              key: const Key('transaction-note-field'),
              controller: _noteController,
              minLines: 3,
              maxLines: 4,
              decoration: InputDecoration(labelText: context.l10n.txNote),
            ),
            const SizedBox(height: 12),

            TransactionAttachmentSection(
              attachments: _attachments,
              onAddAttachment: _showAddAttachmentDialog,
              onRemoveAttachment: _removeAttachment,
            ),
            const SizedBox(height: 12),

            // Transfers don't repeat: the pair is saved once.
            if (_type != TransactionType.transfer) ...[
              _RecurringSection(
                isRecurring: _isRecurring,
                frequency: _recurringFrequency,
                endDate: _recurringEndDate,
                maxOccurrences: _recurringMaxOccurrences,
                dayOfWeek: _recurringDayOfWeek,
                dayOfMonth: _recurringDayOfMonth,
                monthOfYear: _recurringMonthOfYear,
                occurrenceTime: TimeOfDay.fromDateTime(_selectedDate),
                onToggle: (value) {
                  setState(() {
                    _isRecurring = value;
                    if (value) {
                      // Re-derive the cadence-specific knobs for the active
                      // frequency so the per-cadence panel is always populated.
                      _applyFrequencyDefaults(_recurringFrequency);
                    }
                  });
                },
                onFrequencyChanged: (frequency) {
                  setState(() {
                    _recurringFrequency = frequency;
                    _applyFrequencyDefaults(frequency);
                  });
                },
                onEndDateChanged: (value) =>
                    setState(() => _recurringEndDate = value),
                onMaxOccurrencesChanged: (value) =>
                    setState(() => _recurringMaxOccurrences = value),
                onDayOfWeekChanged: (value) =>
                    setState(() => _recurringDayOfWeek = value),
                onDayOfMonthChanged: (value) =>
                    setState(() => _recurringDayOfMonth = value),
                onMonthOfYearChanged: (value) =>
                    setState(() => _recurringMonthOfYear = value),
                onOccurrenceTimeChanged: (value) {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      value.hour,
                      value.minute,
                    );
                    _recomputeReminderForLead();
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

            _ReminderSection(
              reminderAt: _reminderAt,
              lead: _reminderLead,
              transactionDate: _selectedDate,
              onToggle: (value) {
                setState(() {
                  if (!value) {
                    _reminderAt = null;
                  } else if (_reminderLead == ReminderLead.custom) {
                    _reminderAt ??= _defaultReminderTime();
                  } else {
                    _reminderAt = _leadReminderTime();
                  }
                });
              },
              onLeadChanged: _setReminderLead,
              onPick: _pickReminderTime,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSaving ? null : _submitForm,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                widget.initialTransaction == null
                    ? context.l10n.txSaveTransaction
                    : context.l10n.txSaveChanges,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagInput extends StatelessWidget {
  const _TagInput({
    required this.tags,
    required this.suggestions,
    required this.inputController,
    required this.focusNode,
    required this.onAddTag,
    required this.onAddTagsFromInput,
    required this.onRemoveTag,
  });

  final List<String> tags;
  final List<String> suggestions;
  final TextEditingController inputController;
  final FocusNode focusNode;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onAddTagsFromInput;
  final ValueChanged<String> onRemoveTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RawAutocomplete<String>(
          textEditingController: inputController,
          focusNode: focusNode,
          displayStringForOption: (option) => option,
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) {
              return const Iterable<String>.empty();
            }
            return suggestions.where(
              (tag) => !tags.contains(tag) && tag.toLowerCase().contains(query),
            );
          },
          onSelected: onAddTag,
          fieldViewBuilder:
              (context, textController, textFocusNode, onFieldSubmitted) {
                return TextField(
                  key: const Key('transaction-tags-field'),
                  controller: textController,
                  focusNode: textFocusNode,
                  decoration: InputDecoration(
                    labelText: context.l10n.txTags,
                    hintText: context.l10n.txTagsHint,
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (value) {
                    if (value.endsWith(',')) {
                      onAddTagsFromInput(value);
                    }
                  },
                  onSubmitted: onAddTagsFromInput,
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final option in options)
                        ListTile(
                          dense: true,
                          title: Text(option),
                          onTap: () => onSelected(option),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                InputChip(
                  key: Key('transaction-tag-chip-$tag'),
                  label: Text(tag),
                  labelStyle: theme.textTheme.labelMedium,
                  onDeleted: () => onRemoveTag(tag),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ItemNameInput extends StatefulWidget {
  const _ItemNameInput({
    required this.controller,
    required this.suggestions,
    required this.onSelected,
  });

  final TextEditingController controller;
  final List<FinanceTransaction> suggestions;
  final ValueChanged<FinanceTransaction> onSelected;

  @override
  State<_ItemNameInput> createState() => _ItemNameInputState();
}

class _ItemNameInputState extends State<_ItemNameInput> {
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _showSuggestions) {
      setState(() => _showSuggestions = false);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _filteredItemNameSuggestions(
      widget.suggestions,
      widget.controller.text,
    );

    return Column(
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(labelText: context.l10n.txItemName),
          onTap: () => setState(() => _showSuggestions = true),
          onChanged: (_) => setState(() => _showSuggestions = true),
        ),
        if (_showSuggestions && options.isNotEmpty)
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      key: Key(
                        'transaction-item-name-option-${option.merchant ?? ''}',
                      ),
                      dense: true,
                      title: Text(option.merchant ?? ''),
                      onTap: () {
                        widget.controller.text = option.merchant ?? '';
                        setState(() => _showSuggestions = false);
                        widget.onSelected(option);
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact notice shown when the chosen account's currency differs from the
/// amount's. It states the account currency, shows the live rate as a tappable
/// (editable) number, and previews the converted amount. No convert button —
/// the conversion runs at save time. See docs/currency-conversion.md.
class _CurrencyConversionPrompt extends StatelessWidget {
  const _CurrencyConversionPrompt({
    required this.selectedCurrency,
    required this.accountCurrency,
    required this.exchangeRateController,
    required this.amountController,
    required this.isFetchingRate,
    required this.onRefreshRate,
    required this.onEditRate,
  });

  final String selectedCurrency;
  final String accountCurrency;
  final TextEditingController exchangeRateController;
  final TextEditingController amountController;
  final bool isFetchingRate;
  final VoidCallback onRefreshRate;
  final VoidCallback onEditRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Card(
      color: AikoColors.warningOrange.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: ListenableBuilder(
          listenable: Listenable.merge([
            exchangeRateController,
            amountController,
          ]),
          builder: (context, _) {
            final rate = Decimal.tryParse(exchangeRateController.text.trim());
            final amount = parseAmountInput(amountController.text);
            final preview = (rate != null && amount != null)
                ? '≈ ${(amount * rate).toStringAsFixed(2)} $accountCurrency'
                : null;

            return Row(
              children: [
                const Icon(
                  Icons.currency_exchange,
                  size: 20,
                  color: AikoColors.warningOrange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Account currency + editable rate on one line.
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            context.l10n.txAccountCurrencyRate(
                              accountCurrency,
                              selectedCurrency,
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                          InkWell(
                            key: const Key('edit-exchange-rate'),
                            onTap: onEditRate,
                            child: Text(
                              // l10n-ignore: a number and a currency code.
                              '${rate?.toStringAsFixed(4) ?? '—'} $accountCurrency',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (preview != null)
                        Text(
                          context.l10n.txSavesAs(preview),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isFetchingRate)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    key: const Key('refresh-exchange-rate-button'),
                    tooltip: context.l10n.txRefreshRate,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: onRefreshRate,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The little arrow badge shown between the From and To pickers on a transfer,
/// signalling that money flows from the left account into the right one.
class _TransferFlowArrow extends StatelessWidget {
  const _TransferFlowArrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: AikoColors.primaryBlue,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_forward,
          size: 18,
          color: AikoColors.white,
        ),
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.label,
    required this.fieldKey,
    required this.accounts,
    required this.selectedAccountId,
    required this.onSelected,
    this.compact = false,
  });

  final String label;
  final String fieldKey;
  final List<Account> accounts;
  final String? selectedAccountId;
  final ValueChanged<String> onSelected;

  /// Tighter layout for the side-by-side transfer row: stacks the account mark
  /// above the name and drops the balance/subtitle line so two pickers fit.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedAccount = _selectedAccountFrom(accounts, selectedAccountId);
    final accent = selectedAccount == null
        ? AikoColors.primaryBlue
        : _accountColorFor(selectedAccount.type);

    final nameText = Text(
      key: Key('transaction-$fieldKey-selected-account-name'),
      selectedAccount?.name ?? context.l10n.txSelectAccount,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
    final labelText = Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        key: Key('transaction-$fieldKey-picker'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showAccountPickerSheet(context),
        child: Padding(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    labelText,
                    const SizedBox(height: 6),
                    _AccountMark(
                      account: selectedAccount,
                      fallbackColor: accent,
                    ),
                    const SizedBox(height: 6),
                    nameText,
                  ],
                )
              : Row(
                  children: [
                    _AccountMark(
                      account: selectedAccount,
                      fallbackColor: accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          labelText,
                          const SizedBox(height: 2),
                          nameText,
                          if (selectedAccount != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _accountSubtitle(
                                      selectedAccount,
                                      context.l10n,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  selectedAccount.currentBalance.format(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_down, color: accent),
                  ],
                ),
        ),
      ),
    );
  }

  void _showAccountPickerSheet(BuildContext context) {
    showAikoSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.txChooseAccount,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final selected = account.id == selectedAccountId;
                      return _AccountOptionTile(
                        fieldKey: fieldKey,
                        account: account,
                        selected: selected,
                        onTap: () {
                          onSelected(account.id);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccountOptionTile extends StatelessWidget {
  const _AccountOptionTile({
    required this.fieldKey,
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final String fieldKey;
  final Account account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _accountColorFor(account.type);
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? color.withValues(alpha: 0.10)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? color.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: ListTile(
        key: Key('transaction-$fieldKey-option-${account.id}'),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: _AccountMark(account: account, fallbackColor: color),
        title: Text(
          account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                _accountSubtitle(account, context.l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(account.currentBalance.format()),
          ],
        ),
        trailing: selected
            ? Icon(Icons.check_circle, color: color)
            : const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }
}

class _AccountMark extends StatelessWidget {
  const _AccountMark({required this.account, required this.fallbackColor});

  final Account? account;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final color = account == null
        ? fallbackColor
        : _accountColorFor(account!.type);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        account == null
            ? Icons.wallet_outlined
            : _accountIconFor(account!.type),
        color: color,
        size: 20,
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.groups,
    required this.selectedCategoryId,
    required this.transactionType,
    required this.onSelected,
  });

  final List<Category> categories;
  final List<CategoryGroup> groups;
  final String? selectedCategoryId;
  final TransactionType transactionType;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCategory = _selectedCategoryFrom(
      categories,
      selectedCategoryId,
    );
    final accent = selectedCategory == null
        ? _transactionTypeColor(transactionType)
        : _categoryColorFrom(selectedCategory);

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        key: const Key('transaction-category-picker'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showCategoryPickerSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _CategoryMark(category: selectedCategory, fallbackColor: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.txCategory,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedCategory?.displayName(context.l10n) ??
                          context.l10n.txSelectCategory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (selectedCategory != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        selectedCategory.group.label(context.l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_down, color: accent),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryPickerSheet(BuildContext context) {
    showAikoSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _CategoryPickerSheet(
          categories: categories,
          groups: groups,
          selectedCategoryId: selectedCategoryId,
          onSelected: (value) {
            onSelected(value);
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }
}

/// Modal bottom sheet for choosing a category. Sections the categories by
/// group, supports full-text search, and renders each group as a compact
/// grid so the user can browse 60+ entries with minimal scrolling.
///
/// Layout (top to bottom):
///   1. Title
///   2. Sticky search field (auto-focus on open)
///   3. Sticky horizontal group chip bar (hidden while searching)
///   4. Scrollable body: one section per group, each with a compact header
///      and a 2- or 3-column grid of compact category cards.
class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.groups,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<Category> categories;
  final List<CategoryGroup> groups;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelected;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _chipScrollController = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};
  String _query = '';
  int _activeGroupIndex = 0;

  @override
  void initState() {
    super.initState();
    // Auto-focus so users can start typing immediately; the keyboard is
    // expected to push the sheet to its `isScrollControlled: true` ceiling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_sectionKeys.isEmpty) return;
    final scrollOffset =
        _scrollController.offset +
        _CategoryPickerSheetLayout.searchHeaderExtent;
    String? currentKey;
    for (final entry in _sectionKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final position =
          box.localToGlobal(Offset.zero).dy -
          _CategoryPickerSheetLayout.bodyTopInset;
      if (position <= 16) {
        currentKey = entry.key;
      } else {
        break;
      }
    }
    if (currentKey == null) return;
    final index = widget.groups.indexWhere((group) => group.id == currentKey);
    if (index >= 0 && index != _activeGroupIndex) {
      setState(() => _activeGroupIndex = index);
    }
    // Best-effort: keep scrollOffset referenced to silence unused warnings if
    // the heuristic is replaced with an IntersectionObserver later.
    assert(scrollOffset >= 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.86;

    // Build section map: ordered groups (already sorted by caller) → only the
    // groups that actually have at least one matching category.
    final normalizedQuery = _query.trim().toLowerCase();
    final sections = <_CategorySectionData>[];
    for (final group in widget.groups) {
      final members = widget.categories
          .where((c) => _belongsToGroup(c, group))
          .where(
            (c) =>
                normalizedQuery.isEmpty ||
                c.name.toLowerCase().contains(normalizedQuery) ||
                c
                    .displayName(context.l10n)
                    .toLowerCase()
                    .contains(normalizedQuery),
          )
          .toList(growable: false);
      if (members.isEmpty) continue;
      sections.add(_CategorySectionData(group: group, categories: members));
    }

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(
                context.l10n.txChooseCategory,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _CategorySearchField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                    // Re-collect section keys because the visible groups can
                    // change as the query narrows the list.
                    _sectionKeys.clear();
                    _activeGroupIndex = 0;
                  });
                },
                onClear: () {
                  _searchController.clear();
                  setState(() {
                    _query = '';
                    _sectionKeys.clear();
                    _activeGroupIndex = 0;
                  });
                },
              ),
              if (normalizedQuery.isEmpty && sections.length > 1) ...[
                const SizedBox(height: 12),
                _CategoryGroupChipBar(
                  controller: _chipScrollController,
                  sections: sections,
                  activeIndex: _activeGroupIndex,
                  onTap: (index) => _scrollToSection(sections, index),
                ),
              ],
              const SizedBox(height: 8),
              Flexible(
                child: sections.isEmpty
                    ? _CategoryEmptyResults(query: _query)
                    : _CategorySectionList(
                        scrollController: _scrollController,
                        sections: sections,
                        selectedCategoryId: widget.selectedCategoryId,
                        onCategoryTap: widget.onSelected,
                        registerSectionKey: (groupId, key) {
                          _sectionKeys[groupId] = key;
                        },
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToSection(List<_CategorySectionData> sections, int index) {
    if (index < 0 || index >= sections.length) return;
    final key = _sectionKeys[sections[index].group.id];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    setState(() => _activeGroupIndex = index);
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.02,
    );
  }
}

/// Mirrors [CategoryManagementScreen._belongsToGroup] so a custom category
/// with a null/empty `groupId` is filed under the "Other" catch-all group.
bool _belongsToGroup(Category category, CategoryGroup group) {
  if (group.effectiveTemplateId == CategoryGroupDefaults.unfiledGroupId) {
    return category.groupId == group.id ||
        category.groupId == null ||
        category.groupId!.isEmpty;
  }
  return category.groupId == group.id;
}

/// Layout constants shared by the search/chip/scroll sync logic. Kept here so
/// the scroll handler can re-create the same Y offset the layout produces.
class _CategoryPickerSheetLayout {
  static const double searchHeaderExtent = 168;
  static const double bodyTopInset = 8;
}

class _CategorySectionData {
  const _CategorySectionData({required this.group, required this.categories});

  final CategoryGroup group;
  final List<Category> categories;
}

class _CategorySearchField extends StatelessWidget {
  const _CategorySearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        key: const Key('transaction-category-search-field'),
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: context.l10n.txSearchCategories,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.4,
            ),
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('transaction-category-search-clear'),
                  tooltip: context.l10n.txClearSearch,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                ),
        ),
      ),
    );
  }
}

class _CategoryGroupChipBar extends StatelessWidget {
  const _CategoryGroupChipBar({
    required this.controller,
    required this.sections,
    required this.activeIndex,
    required this.onTap,
  });

  final ScrollController controller;
  final List<_CategorySectionData> sections;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        key: const Key('transaction-category-group-chips'),
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = sections[index];
          final color = aikoHexColor(section.group.color);
          final selected = index == activeIndex;
          return _CategoryGroupChip(
            label: section.group.displayName(context.l10n),
            count: section.categories.length,
            color: color,
            selected: selected,
            onTap: () => onTap(index),
            groupId: section.group.id,
          );
        },
      ),
    );
  }
}

class _CategoryGroupChip extends StatelessWidget {
  const _CategoryGroupChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.groupId,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? color.withValues(alpha: 0.14)
          : theme.colorScheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? color.withValues(alpha: 0.55)
              : theme.colorScheme.outlineVariant,
          width: selected ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        key: Key('transaction-category-group-chip-$groupId'),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? color : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.22)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? color
                        : theme.colorScheme.onSurfaceVariant,
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

class _CategorySectionList extends StatelessWidget {
  const _CategorySectionList({
    required this.scrollController,
    required this.sections,
    required this.selectedCategoryId,
    required this.onCategoryTap,
    required this.registerSectionKey,
  });

  final ScrollController scrollController;
  final List<_CategorySectionData> sections;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategoryTap;
  final void Function(String groupId, GlobalKey key) registerSectionKey;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('transaction-category-section-list'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final key = GlobalKey(
          debugLabel: 'category-section-${section.group.id}',
        );
        // Register on this build so the parent can resolve the section
        // position for the chip-tap jump scroll.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          registerSectionKey(section.group.id, key);
        });
        return Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 16),
          child: _CategoryGroupSection(
            section: section,
            selectedCategoryId: selectedCategoryId,
            onCategoryTap: onCategoryTap,
          ),
        );
      },
    );
  }
}

class _CategoryGroupSection extends StatelessWidget {
  const _CategoryGroupSection({
    required this.section,
    required this.selectedCategoryId,
    required this.onCategoryTap,
  });

  final _CategorySectionData section;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = aikoHexColor(section.group.color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                aikoCategoryIcon(section.group.icon),
                color: color,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                section.group.displayName(context.l10n),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${section.categories.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _CategoryCardGrid(
          categories: section.categories,
          selectedCategoryId: selectedCategoryId,
          onTap: onCategoryTap,
        ),
      ],
    );
  }
}

class _CategoryCardGrid extends StatelessWidget {
  const _CategoryCardGrid({
    required this.categories,
    required this.selectedCategoryId,
    required this.onTap,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onTap;

  static const double _spacing = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns on most phones; 3 columns on wider surfaces.
        final crossAxisCount = constraints.maxWidth >= 360 ? 2 : 1;
        final usableWidth =
            constraints.maxWidth - _spacing * (crossAxisCount - 1);
        final cardWidth = usableWidth / crossAxisCount;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final category in categories)
              SizedBox(
                width: cardWidth,
                child: _CategoryGridCard(
                  category: category,
                  selected: category.id == selectedCategoryId,
                  onTap: () => onTap(category.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryGridCard extends StatelessWidget {
  const _CategoryGridCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _categoryColorFrom(category);
    final surface = theme.colorScheme.surface;
    final fillColor = selected ? color.withValues(alpha: 0.12) : surface;
    final borderColor = selected
        ? color.withValues(alpha: 0.6)
        : theme.colorScheme.outlineVariant;

    return Material(
      color: fillColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: selected ? 1.2 : 1),
      ),
      child: InkWell(
        key: Key('transaction-category-option-${category.id}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _categoryIconFor(category.icon),
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.displayName(context.l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.check_circle, color: color, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryEmptyResults extends StatelessWidget {
  const _CategoryEmptyResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 36,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            query.isEmpty
                ? context.l10n.txNoCategoriesShort
                : context.l10n.txNoMatchesFor(query),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (query.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.txTryDifferentKeyword,
              textAlign: TextAlign.center,
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

class _CategoryMark extends StatelessWidget {
  const _CategoryMark({required this.category, required this.fallbackColor});

  final Category? category;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final color = category == null
        ? fallbackColor
        : _categoryColorFrom(category!);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        category == null
            ? Icons.category_outlined
            : _categoryIconFor(category!.icon),
        color: color,
        size: 20,
      ),
    );
  }
}

/// Toggle + dropdown of lead presets for a reminder notification.
///
/// The persisted source of truth is [FinanceTransaction.reminderAt]; the
/// dropdown is a UI convenience that derives `reminderAt` from the
/// transaction's date minus the selected lead. `custom` exposes the full
/// date+time picker.
class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.reminderAt,
    required this.lead,
    required this.transactionDate,
    required this.onToggle,
    required this.onLeadChanged,
    required this.onPick,
  });

  final DateTime? reminderAt;
  final ReminderLead lead;
  final DateTime transactionDate;
  final ValueChanged<bool> onToggle;
  final ValueChanged<ReminderLead> onLeadChanged;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = reminderAt != null;
    final formatted = enabled && reminderAt != null
        ? DateFormat('EEE, MMM d, yyyy · HH:mm').format(reminderAt!)
        : null;
    return Card(
      key: const Key('transaction-reminder-section'),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.txReminder,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        kIsWeb
                            ? context.l10n.txReminderWebNote
                            : enabled
                            ? context.l10n.txReminderEnabledNote
                            : context.l10n.txReminderDisabledNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const Key('transaction-reminder-toggle'),
                  value: enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<ReminderLead>(
                key: const Key('transaction-reminder-lead'),
                initialValue: lead,
                decoration: InputDecoration(
                  labelText: context.l10n.txNotifyMe,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final option in ReminderLead.values)
                    DropdownMenuItem(
                      value: option,
                      child: Text(option.label(context.l10n)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onLeadChanged(value);
                },
              ),
              if (lead == ReminderLead.custom && formatted != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(context.l10n.txRemindAt(formatted)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RecurringSection extends StatelessWidget {
  const _RecurringSection({
    required this.isRecurring,
    required this.frequency,
    required this.endDate,
    required this.maxOccurrences,
    required this.dayOfWeek,
    required this.dayOfMonth,
    required this.monthOfYear,
    required this.occurrenceTime,
    required this.onToggle,
    required this.onFrequencyChanged,
    required this.onEndDateChanged,
    required this.onMaxOccurrencesChanged,
    required this.onDayOfWeekChanged,
    required this.onDayOfMonthChanged,
    required this.onMonthOfYearChanged,
    required this.onOccurrenceTimeChanged,
  });

  final bool isRecurring;
  final RecurringFrequency frequency;
  final DateTime? endDate;
  final int? maxOccurrences;
  final int? dayOfWeek;
  final int? dayOfMonth;
  final int? monthOfYear;

  /// Time of day the recurring occurrence fires. Derived from the parent
  /// transaction's date so the two stay in sync.
  final TimeOfDay occurrenceTime;
  final ValueChanged<bool> onToggle;
  final ValueChanged<RecurringFrequency> onFrequencyChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<int?> onMaxOccurrencesChanged;
  final ValueChanged<int?> onDayOfWeekChanged;
  final ValueChanged<int?> onDayOfMonthChanged;
  final ValueChanged<int?> onMonthOfYearChanged;
  final ValueChanged<TimeOfDay> onOccurrenceTimeChanged;

  static const _frequencies = <RecurringFrequency, _FrequencyChoiceMeta>{
    RecurringFrequency.daily: _FrequencyChoiceMeta(
      icon: Icons.today_outlined,
      hint: _dailyHint,
    ),
    RecurringFrequency.weekly: _FrequencyChoiceMeta(
      icon: Icons.view_week_outlined,
      hint: _weeklyHint,
    ),
    RecurringFrequency.monthly: _FrequencyChoiceMeta(
      icon: Icons.calendar_view_month_outlined,
      hint: _monthlyHint,
    ),
    RecurringFrequency.annually: _FrequencyChoiceMeta(
      icon: Icons.calendar_today_outlined,
      hint: _annuallyHint,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('transaction-recurring-section'),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.event_repeat_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.txRecurring,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRecurring
                            ? context.l10n.txRecurringOnNote
                            : context.l10n.txRecurringOffNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const Key('transaction-recurring-toggle'),
                  value: isRecurring,
                  onChanged: onToggle,
                ),
              ],
            ),
            if (isRecurring) ...[
              const SizedBox(height: 12),
              _FrequencyPicker(
                frequency: frequency,
                frequencies: _frequencies,
                onChanged: onFrequencyChanged,
              ),
              const SizedBox(height: 12),
              _OccurrenceTimeTile(
                occurrenceTime: occurrenceTime,
                onChanged: onOccurrenceTimeChanged,
              ),
              const SizedBox(height: 12),
              _FrequencySettingsPanel(
                frequency: frequency,
                endDate: endDate,
                maxOccurrences: maxOccurrences,
                dayOfWeek: dayOfWeek,
                dayOfMonth: dayOfMonth,
                monthOfYear: monthOfYear,
                onEndDateChanged: onEndDateChanged,
                onMaxOccurrencesChanged: onMaxOccurrencesChanged,
                onDayOfWeekChanged: onDayOfWeekChanged,
                onDayOfMonthChanged: onDayOfMonthChanged,
                onMonthOfYearChanged: onMonthOfYearChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _dailyHint(AppLocalizations l10n) => l10n.frequencyDailyHint;
String _weeklyHint(AppLocalizations l10n) => l10n.frequencyWeeklyHint;
String _monthlyHint(AppLocalizations l10n) => l10n.frequencyMonthlyHint;
String _annuallyHint(AppLocalizations l10n) => l10n.frequencyAnnuallyHint;

class _FrequencyChoiceMeta {
  const _FrequencyChoiceMeta({required this.icon, required this.hint});

  final IconData icon;
  final String Function(AppLocalizations l10n) hint;
}

/// Time-of-day picker for the recurring occurrence. Mirrors the parent
/// transaction's time component so the cadence fires at the right moment.
class _OccurrenceTimeTile extends StatelessWidget {
  const _OccurrenceTimeTile({
    required this.occurrenceTime,
    required this.onChanged,
  });

  final TimeOfDay occurrenceTime;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted =
        '${occurrenceTime.hour.toString().padLeft(2, '0')}'
        ':${occurrenceTime.minute.toString().padLeft(2, '0')}';
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: occurrenceTime,
          );
          if (picked != null) onChanged(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.txOccurrenceTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatted,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrequencyPicker extends StatelessWidget {
  const _FrequencyPicker({
    required this.frequency,
    required this.frequencies,
    required this.onChanged,
  });

  final RecurringFrequency frequency;
  final Map<RecurringFrequency, _FrequencyChoiceMeta> frequencies;
  final ValueChanged<RecurringFrequency> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = frequencies.entries.toList(growable: false);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          ChoiceChip(
            key: Key('recurring-frequency-${entry.key.name}'),
            selected: entry.key == frequency,
            label: Text(entry.key.label(context.l10n)),
            avatar: Icon(entry.value.icon, size: 18),
            onSelected: (selected) {
              if (selected) {
                onChanged(entry.key);
              }
            },
          ),
      ],
    );
  }
}

class _FrequencySettingsPanel extends StatelessWidget {
  const _FrequencySettingsPanel({
    required this.frequency,
    required this.endDate,
    required this.maxOccurrences,
    required this.dayOfWeek,
    required this.dayOfMonth,
    required this.monthOfYear,
    required this.onEndDateChanged,
    required this.onMaxOccurrencesChanged,
    required this.onDayOfWeekChanged,
    required this.onDayOfMonthChanged,
    required this.onMonthOfYearChanged,
  });

  final RecurringFrequency frequency;
  final DateTime? endDate;
  final int? maxOccurrences;
  final int? dayOfWeek;
  final int? dayOfMonth;
  final int? monthOfYear;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<int?> onMaxOccurrencesChanged;
  final ValueChanged<int?> onDayOfWeekChanged;
  final ValueChanged<int?> onDayOfMonthChanged;
  final ValueChanged<int?> onMonthOfYearChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = _RecurringSection._frequencies[frequency]!.hint(context.l10n);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AikoColors.warningOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AikoColors.warningOrange.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          switch (frequency) {
            RecurringFrequency.once => _OnceSettings(
              endDate: endDate,
              onEndDateChanged: onEndDateChanged,
            ),
            RecurringFrequency.daily => _DailySettings(
              endDate: endDate,
              maxOccurrences: maxOccurrences,
              onEndDateChanged: onEndDateChanged,
              onMaxOccurrencesChanged: onMaxOccurrencesChanged,
            ),
            RecurringFrequency.weekly => _WeeklySettings(
              endDate: endDate,
              maxOccurrences: maxOccurrences,
              dayOfWeek: dayOfWeek,
              onEndDateChanged: onEndDateChanged,
              onMaxOccurrencesChanged: onMaxOccurrencesChanged,
              onDayOfWeekChanged: onDayOfWeekChanged,
            ),
            RecurringFrequency.monthly => _MonthlySettings(
              endDate: endDate,
              maxOccurrences: maxOccurrences,
              dayOfMonth: dayOfMonth,
              onEndDateChanged: onEndDateChanged,
              onMaxOccurrencesChanged: onMaxOccurrencesChanged,
              onDayOfMonthChanged: onDayOfMonthChanged,
            ),
            RecurringFrequency.annually => _AnnualSettings(
              endDate: endDate,
              maxOccurrences: maxOccurrences,
              monthOfYear: monthOfYear,
              dayOfMonth: dayOfMonth,
              onEndDateChanged: onEndDateChanged,
              onMaxOccurrencesChanged: onMaxOccurrencesChanged,
              onMonthOfYearChanged: onMonthOfYearChanged,
              onDayOfMonthChanged: onDayOfMonthChanged,
            ),
          },
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = value == null
        ? context.l10n.txNoEndDate
        : DateFormat('yyyy-MM-dd').format(value!);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final initial = value ?? now;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial.isBefore(now) ? now : initial,
            firstDate: now,
            lastDate: DateTime(now.year + 10),
            builder: (context, child) {
              return Theme(
                data: Theme.of(
                  context,
                ).copyWith(colorScheme: Theme.of(context).colorScheme),
                child: child!,
              );
            },
          );
          if (picked != null) {
            onChanged(picked);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.event_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      formatted,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (value != null)
                IconButton(
                  tooltip: context.l10n.txClearEndDate,
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Upper bound for "or after N occurrences".
const _maxOccurrencesLimit = 999;

/// Whole-number field for recurring settings. Keeps one controller (so the
/// cursor doesn't jump on each keystroke) and reports what was typed; an
/// out-of-range number shows an error instead of being silently changed, and
/// the form refuses to save until it's fixed.
class _IntField extends StatefulWidget {
  const _IntField({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 31,
  });

  final String label;
  final String hint;
  final int? value;
  final ValueChanged<int?> onChanged;
  final int min;
  final int max;

  @override
  State<_IntField> createState() => _IntFieldState();
}

class _IntFieldState extends State<_IntField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value == null ? '' : '${widget.value}',
  );

  @override
  void didUpdateWidget(covariant _IntField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow outside changes (e.g. frequency defaults) without fighting typing.
    final typed = int.tryParse(_controller.text.trim());
    if (widget.value != typed) {
      _controller.text = widget.value == null ? '' : '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final outOfRange =
        value != null && (value < widget.min || value > widget.max);
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        border: const OutlineInputBorder(),
        errorText: outOfRange
            ? context.l10n.txNumberRange(widget.min, widget.max)
            : null,
      ),
      keyboardType: const TextInputType.numberWithOptions(),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (raw) {
        final trimmed = raw.trim();
        widget.onChanged(trimmed.isEmpty ? null : int.tryParse(trimmed));
      },
    );
  }
}

class _OnceSettings extends StatelessWidget {
  const _OnceSettings({required this.endDate, required this.onEndDateChanged});

  final DateTime? endDate;
  final ValueChanged<DateTime?> onEndDateChanged;

  @override
  Widget build(BuildContext context) {
    return _DateField(
      label: context.l10n.txScheduleFor,
      value: endDate,
      onChanged: onEndDateChanged,
    );
  }
}

class _DailySettings extends StatelessWidget {
  const _DailySettings({
    required this.endDate,
    required this.maxOccurrences,
    required this.onEndDateChanged,
    required this.onMaxOccurrencesChanged,
  });

  final DateTime? endDate;
  final int? maxOccurrences;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<int?> onMaxOccurrencesChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DateField(
          label: context.l10n.txStopsOn,
          value: endDate,
          onChanged: onEndDateChanged,
        ),
        const SizedBox(height: 12),
        _IntField(
          label: context.l10n.txOrAfterOccurrences,
          hint: context.l10n.exampleValue(30),
          value: maxOccurrences,
          onChanged: onMaxOccurrencesChanged,
          max: _maxOccurrencesLimit,
        ),
      ],
    );
  }
}

class _WeeklySettings extends StatelessWidget {
  const _WeeklySettings({
    required this.endDate,
    required this.maxOccurrences,
    required this.dayOfWeek,
    required this.onEndDateChanged,
    required this.onMaxOccurrencesChanged,
    required this.onDayOfWeekChanged,
  });

  final DateTime? endDate;
  final int? maxOccurrences;
  final int? dayOfWeek;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<int?> onMaxOccurrencesChanged;
  final ValueChanged<int?> onDayOfWeekChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<int>(
          key: const Key('recurring-weekly-day'),
          initialValue: dayOfWeek,
          decoration: InputDecoration(
            labelText: context.l10n.txOnDay,
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_view_week_outlined),
          ),
          items: [
            // 2024-01-01 was a Monday; day 1..7 = Monday..Sunday.
            for (var day = 1; day <= 7; day++)
              DropdownMenuItem(
                value: day,
                child: Text(DateFormat.EEEE().format(DateTime(2024, 1, day))),
              ),
          ],
          onChanged: onDayOfWeekChanged,
        ),
        const SizedBox(height: 12),
        _DateField(
          label: context.l10n.txStopsOn,
          value: endDate,
          onChanged: onEndDateChanged,
        ),
        const SizedBox(height: 12),
        _IntField(
          label: context.l10n.txOrAfterOccurrences,
          hint: context.l10n.exampleValue(12),
          value: maxOccurrences,
          onChanged: onMaxOccurrencesChanged,
          max: _maxOccurrencesLimit,
        ),
      ],
    );
  }
}

class _MonthlySettings extends StatelessWidget {
  const _MonthlySettings({
    required this.endDate,
    required this.maxOccurrences,
    required this.dayOfMonth,
    required this.onEndDateChanged,
    required this.onMaxOccurrencesChanged,
    required this.onDayOfMonthChanged,
  });

  final DateTime? endDate;
  final int? maxOccurrences;
  final int? dayOfMonth;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<int?> onMaxOccurrencesChanged;
  final ValueChanged<int?> onDayOfMonthChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _IntField(
          label: context.l10n.txDayOfMonth,
          hint: '1–31',
          value: dayOfMonth,
          onChanged: onDayOfMonthChanged,
          min: 1,
          max: 31,
        ),
        const SizedBox(height: 12),
        _DateField(
          label: context.l10n.txStopsOn,
          value: endDate,
          onChanged: onEndDateChanged,
        ),
        const SizedBox(height: 12),
        _IntField(
          label: context.l10n.txOrAfterOccurrences,
          hint: context.l10n.exampleValue(12),
          value: maxOccurrences,
          onChanged: onMaxOccurrencesChanged,
          max: _maxOccurrencesLimit,
        ),
      ],
    );
  }
}

class _AnnualSettings extends StatelessWidget {
  const _AnnualSettings({
    required this.endDate,
    required this.maxOccurrences,
    required this.monthOfYear,
    required this.dayOfMonth,
    required this.onEndDateChanged,
    required this.onMaxOccurrencesChanged,
    required this.onMonthOfYearChanged,
    required this.onDayOfMonthChanged,
  });

  final DateTime? endDate;
  final int? maxOccurrences;
  final int? monthOfYear;
  final int? dayOfMonth;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<int?> onMaxOccurrencesChanged;
  final ValueChanged<int?> onMonthOfYearChanged;
  final ValueChanged<int?> onDayOfMonthChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const Key('recurring-annual-month'),
                initialValue: monthOfYear,
                decoration: InputDecoration(
                  labelText: context.l10n.txMonth,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (var month = 1; month <= 12; month++)
                    DropdownMenuItem(
                      value: month,
                      child: Text(
                        DateFormat.MMMM().format(DateTime(2024, month)),
                      ),
                    ),
                ],
                onChanged: onMonthOfYearChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _IntField(
                label: context.l10n.txDay,
                hint: '1–31',
                value: dayOfMonth,
                onChanged: onDayOfMonthChanged,
                min: 1,
                max: 31,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DateField(
          label: context.l10n.txStopsOn,
          value: endDate,
          onChanged: onEndDateChanged,
        ),
        const SizedBox(height: 12),
        _IntField(
          label: context.l10n.txOrAfterOccurrences,
          hint: context.l10n.exampleValue(5),
          value: maxOccurrences,
          onChanged: onMaxOccurrencesChanged,
          max: _maxOccurrencesLimit,
        ),
      ],
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
    final initialAmount = parseAmountInput(widget.initialUnitPrice);
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
    _errorText = context.l10n.txCannotDivideByZero;
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
          context.l10n.txAmountCalculator,
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
                      ? theme.colorScheme.onSurfaceVariant
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
          label: Text(context.l10n.txUseAmount),
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
            _CalculatorKey(label: 'C', onPressed: onClear), // l10n-ignore
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
              label: 'backspace', // l10n-ignore: key id, not shown
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
                ? theme.colorScheme.outlineVariant
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

Color _transactionTypeColor(TransactionType type) {
  return switch (type) {
    TransactionType.income => AikoColors.successGreen,
    TransactionType.transfer ||
    TransactionType.transferIn ||
    TransactionType.transferOut => AikoColors.primaryBlue,
    _ => AikoColors.dangerRed,
  };
}

CategoryType _categoryTypeFor(TransactionType type) {
  return switch (type) {
    TransactionType.income => CategoryType.income,
    TransactionType.transfer ||
    TransactionType.transferIn ||
    TransactionType.transferOut => CategoryType.transfer,
    _ => CategoryType.expense,
  };
}

String? _categoryNameFor(List<Category> categories, String? categoryId) {
  if (categoryId == null) {
    return null;
  }
  for (final category in categories) {
    if (category.id == categoryId) {
      final name = category.name.trim();
      return name.isEmpty ? null : name;
    }
  }
  return null;
}

Category? _selectedCategoryFrom(
  List<Category> categories,
  String? selectedCategoryId,
) {
  if (selectedCategoryId == null) {
    return null;
  }
  for (final category in categories) {
    if (category.id == selectedCategoryId) {
      return category;
    }
  }
  return null;
}

Account? _selectedAccountFrom(
  List<Account> accounts,
  String? selectedAccountId,
) {
  if (selectedAccountId == null) {
    return null;
  }
  for (final account in accounts) {
    if (account.id == selectedAccountId) {
      return account;
    }
  }
  return null;
}

Color _categoryColorFrom(Category category) {
  try {
    final hexColor = category.color.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  } catch (_) {
    return _transactionTypeColor(switch (category.type) {
      CategoryType.income => TransactionType.income,
      CategoryType.transfer => TransactionType.transfer,
      _ => TransactionType.expense,
    });
  }
}

IconData _categoryIconFor(String iconName) {
  return switch (iconName) {
    'food' || 'groceries' || 'dining' => Icons.restaurant_outlined,
    'housing' || 'home' => Icons.home_outlined,
    'travel' => Icons.flight_outlined,
    'coffee' => Icons.coffee_outlined,
    'shopping' => Icons.shopping_bag_outlined,
    'savings' => Icons.savings_outlined,
    'investing' || 'investment' => Icons.trending_up_outlined,
    'gym' => Icons.fitness_center_outlined,
    'salary' => Icons.attach_money_outlined,
    'entertainment' => Icons.movie_outlined,
    'transport' => Icons.directions_bus_outlined,
    'utilities' => Icons.bolt_outlined,
    'health' => Icons.health_and_safety_outlined,
    'tax' => Icons.request_quote_outlined,
    _ => Icons.category_outlined,
  };
}

IconData _accountIconFor(AccountType type) {
  return switch (type) {
    AccountType.cash => Icons.wallet_outlined,
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.eWallet => Icons.account_balance_wallet_outlined,
    AccountType.creditCard => Icons.credit_card_outlined,
    AccountType.loan => Icons.handshake_outlined,
    AccountType.investment => Icons.trending_up_outlined,
    AccountType.asset => Icons.home_work_outlined,
    AccountType.liability => Icons.request_quote_outlined,
    AccountType.goal => Icons.flag_outlined,
    AccountType.other => Icons.account_balance_wallet_outlined,
  };
}

Color _accountColorFor(AccountType type) {
  return switch (type) {
    AccountType.cash => AikoColors.successGreen,
    AccountType.bank => AikoColors.deepBlue,
    AccountType.eWallet => AikoColors.primaryBlue,
    AccountType.creditCard => AikoColors.warningOrange,
    AccountType.loan => AikoColors.warningOrange,
    AccountType.investment => AikoColors.analyticsTeal,
    AccountType.asset => AikoColors.analyticsTeal,
    AccountType.liability => AikoColors.dangerRed,
    AccountType.goal => AikoColors.premiumPurple,
    AccountType.other => AikoColors.primaryBlue,
  };
}

String _accountSubtitle(Account account, AppLocalizations l10n) {
  final typeLabel = account.type == AccountType.cash
      ? l10n.accountCashWallet
      : account.type.label(l10n);
  final institution = account.institution?.trim();
  if (institution == null || institution.isEmpty) {
    return typeLabel;
  }
  return '$institution - $typeLabel';
}

List<String> _tagSuggestionsFrom(
  AsyncValue<List<FinanceTransaction>> transactionsAsync, {
  required TransactionType selectedType,
}) {
  final tags =
      transactionsAsync
          .whenOrNull(data: (transactions) => transactions)
          ?.where((transaction) => transaction.type == selectedType)
          .expand((transaction) => transaction.tags)
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList() ??
      <String>[];
  tags.sort();
  return tags;
}

List<FinanceTransaction> _itemNameSuggestionsFrom(
  AsyncValue<List<FinanceTransaction>> transactionsAsync, {
  required TransactionType selectedType,
}) {
  final transactions =
      transactionsAsync.whenOrNull(data: (transactions) => transactions) ??
      const <FinanceTransaction>[];
  final filteredTransactions =
      transactions
          .where((transaction) => transaction.type == selectedType)
          .toList(growable: false)
        ..sort((a, b) => b.date.compareTo(a.date));

  final seen = <String>{};
  final suggestions = <FinanceTransaction>[];
  for (final transaction in filteredTransactions) {
    final name = transaction.merchant?.trim() ?? '';
    if (name.isEmpty) {
      continue;
    }
    if (seen.add(name.toLowerCase())) {
      suggestions.add(transaction);
    }
  }
  return suggestions;
}

TransactionType _transactionTypeFromFormType(TransactionType formType) {
  return formType;
}

List<FinanceTransaction> _filteredItemNameSuggestions(
  List<FinanceTransaction> suggestions,
  String input,
) {
  final query = input.trim().toLowerCase();
  if (query.isEmpty) {
    return suggestions.take(5).toList(growable: false);
  }
  return suggestions
      .where((transaction) {
        final name = (transaction.merchant ?? '').trim().toLowerCase();
        if (name.isEmpty) {
          return false;
        }
        return name.contains(query) && name != query;
      })
      .toList(growable: false);
}
