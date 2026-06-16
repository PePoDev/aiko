import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../data/line_link_repository.dart';

/// Connect the user's LINE chat to their Aiko account by entering the pairing
/// code the bot sent. See [LineLinkRepository] for the backend flow.
class ConnectLineScreen extends ConsumerStatefulWidget {
  const ConnectLineScreen({super.key, LineLinkRepository? repository})
    : _repository = repository;

  final LineLinkRepository? _repository;

  @override
  ConsumerState<ConnectLineScreen> createState() => _ConnectLineScreenState();
}

class _ConnectLineScreenState extends ConsumerState<ConnectLineScreen> {
  final _codeController = TextEditingController();
  late final LineLinkRepository _repository =
      widget._repository ?? const LineLinkRepository();

  bool _submitting = false;
  bool _connected = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repository.connectWithCode(_codeController.text);
      if (!mounted) return;
      setState(() => _connected = true);
    } on LineLinkException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect LINE')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FinanceCard(
            title: 'Link Aiko to LINE',
            icon: Icons.chat_bubble_outline,
            child: _connected ? _success(context) : _form(context),
          ),
        ],
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Message the Aiko bot on LINE to get a 6-character code, then enter it '
          'below. This lets Aiko answer your LINE messages using your own data.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          enabled: !_submitting,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitting ? null : _connect(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            // Codes are at most 6 chars (see line-webhook newPairingCode).
            LengthLimitingTextInputFormatter(6),
            UpperCaseTextFormatter(),
          ],
          decoration: InputDecoration(
            labelText: 'Pairing code',
            hintText: 'e.g. K7M2QP',
            errorText: _error,
            prefixIcon: const Icon(Icons.vpn_key_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: AikoColors.primaryBlue.withValues(alpha: 0.05),
          ),
          style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submitting ? null : _connect,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Connect'),
        ),
      ],
    );
  }

  Widget _success(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: AikoColors.successGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Connected! Return to LINE and chat with Aiko.',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Keeps the pairing code uppercase as the user types, so it matches the
/// uppercase codes the bot generates.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
