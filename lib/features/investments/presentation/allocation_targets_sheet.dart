import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../theme/aiko_colors.dart';
import '../application/allocation_targets.dart';
import '../domain/allocation_target.dart';

/// Edits the target share of each asset class ([AllocationTargetStore]).
Future<void> showAllocationTargetsSheet(
  BuildContext context, {
  required List<AllocationTarget> current,
}) {
  return showAikoSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AllocationTargetsSheet(current: current),
  );
}

class _AllocationTargetsSheet extends ConsumerStatefulWidget {
  const _AllocationTargetsSheet({required this.current});

  final List<AllocationTarget> current;

  @override
  ConsumerState<_AllocationTargetsSheet> createState() =>
      _AllocationTargetsSheetState();
}

class _AllocationTargetsSheetState
    extends ConsumerState<_AllocationTargetsSheet> {
  late final _controllers = {
    for (final assetClass in investmentAssetClasses)
      assetClass: TextEditingController(text: _initialText(assetClass)),
  };
  bool _saving = false;

  String _initialText(String assetClass) {
    for (final target in widget.current) {
      if (target.assetClass == assetClass) {
        final percent = target.targetPercent;
        return percent == percent.roundToDouble()
            ? percent.toStringAsFixed(0)
            : '$percent';
      }
    }
    return '';
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Entered percents; an empty field is 0, unreadable text is null.
  Map<String, double>? get _percents {
    final percents = <String, double>{};
    for (final MapEntry(:key, :value) in _controllers.entries) {
      final text = value.text.trim();
      final percent = text.isEmpty ? 0.0 : double.tryParse(text);
      if (percent == null) return null;
      percents[key] = percent;
    }
    return percents;
  }

  Future<void> _save() async {
    final percents = _percents;
    if (percents == null || !allocationTargetsValid(percents.values)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      await ref.read(allocationTargetsProvider.notifier).save(percents);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.allocationTargetsSaved)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.allocationTargetsSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final percents = _percents;
    final total = percents?.values.fold<double>(0, (sum, p) => sum + p);
    final valid = percents != null && allocationTargetsValid(percents.values);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AikoSheetHandle(),
            Text(
              l10n.allocationTargetsTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.allocationTargetsHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final assetClass in investmentAssetClasses) ...[
              TextField(
                controller: _controllers[assetClass],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: investmentAssetClassLabel(assetClass, l10n),
                  suffixText: '%',
                  hintText: '0',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            Text(
              l10n.allocationTargetsTotal(
                total == null ? '—' : total.toStringAsFixed(1),
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: valid ? null : AikoColors.dangerRed,
              ),
            ),
            if (!valid) ...[
              const SizedBox(height: 4),
              Text(
                l10n.allocationTargetsTotalError,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AikoColors.dangerRed,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving || !valid ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
