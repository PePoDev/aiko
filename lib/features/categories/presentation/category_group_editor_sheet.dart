import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/category.dart';
import 'category_names.dart';
import 'category_visual.dart';

/// Shows the bottom sheet for creating or editing a [CategoryGroup].
///
/// Pass [initial] to edit an existing group. Returns `true` when the user
/// saved, `false` when they cancelled, or `null` when the sheet was dismissed
/// (tap outside / back gesture).
Future<bool?> showCategoryGroupEditorSheet(
  BuildContext context, {
  CategoryGroup? initial,
}) {
  return showAikoSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CategoryGroupEditorSheet(initial: initial),
  );
}

class _CategoryGroupEditorSheet extends ConsumerStatefulWidget {
  const _CategoryGroupEditorSheet({this.initial});

  final CategoryGroup? initial;

  @override
  ConsumerState<_CategoryGroupEditorSheet> createState() =>
      _CategoryGroupEditorSheetState();
}

class _CategoryGroupEditorSheetState
    extends ConsumerState<_CategoryGroupEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late String _selectedColorHex;
  late String _selectedIconKey;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isEditing => widget.initial != null;

  /// The name shown when editing started; null for a new group.
  String? _shownName;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _shownName = initial.displayName(currentL10n());
      _nameController.text = _shownName!;
      _selectedColorHex = initial.color;
      _selectedIconKey = initial.icon;
    } else {
      _selectedColorHex = aikoCategoryColorPresets.first['hex']!;
      _selectedIconKey = aikoCategoryIconPresets.first.key;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _parseHex(String hex) {
    return aikoHexColor(hex);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final groups = ref.read(categoryGroupsProvider).value ?? const [];
      final duplicate = groups.any(
        (g) =>
            g.id != widget.initial?.id &&
            (g.name.toLowerCase() ==
                    _nameController.text.trim().toLowerCase() ||
                g.displayName(context.l10n).toLowerCase() ==
                    _nameController.text.trim().toLowerCase()),
      );
      if (duplicate) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.groupNameExists)));
        }
        return;
      }

      final group = widget.initial == null
          ? CategoryGroup(
              id: const Uuid().v4(),
              userId: '',
              name: _nameController.text.trim(),
              color: _selectedColorHex,
              icon: _selectedIconKey,
              sortOrder: groups.where((g) => !g.isSystem).length,
            )
          : widget.initial!.copyWith(
              name: storedCategoryName(
                original: widget.initial!.name,
                shown: _shownName ?? widget.initial!.name,
                edited: _nameController.text,
              ),
              color: _selectedColorHex,
              icon: _selectedIconKey,
            );

      await ref.read(categoryGroupsProvider.notifier).saveGroup(group);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? context.l10n.groupUpdated(group.displayName(context.l10n))
                  : context.l10n.groupCreated(group.displayName(context.l10n)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.groupSaveFailed)));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final group = widget.initial;
    if (group == null) return;

    final categories = ref.read(categoriesProvider).value ?? const [];
    final assigned = categories
        .where((c) => c.groupId == group.id && c.isActive)
        .length;

    final message = assigned == 0
        ? context.l10n.groupDeleteMessageEmpty
        : context.l10n.groupDeleteMessageAssigned(assigned);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.l10n.categoryDeleteQuestion(group.displayName(context.l10n)),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AikoColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await ref.read(categoryGroupsProvider.notifier).deleteGroup(group.id);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.groupDeleted(group.displayName(context.l10n)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.groupDeleteFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = _parseHex(_selectedColorHex);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AikoSheetHandle(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      aikoCategoryIcon(_selectedIconKey),
                      color: activeColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing
                          ? context.l10n.groupEditTitle
                          : context.l10n.groupNewTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_isEditing)
                    IconButton(
                      tooltip: context.l10n.groupDeleteTooltip,
                      color: AikoColors.dangerRed,
                      onPressed: _isSubmitting || _isDeleting
                          ? null
                          : _confirmDelete,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AikoColors.dangerRed,
                              ),
                            )
                          : const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.groupExplanation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('group-name-field'),
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: context.l10n.groupNameLabel,
                  hintText: context.l10n.groupNameHint,
                  prefixIcon: const Icon(Icons.folder_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.groupNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.colorLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.builder(
                  key: const Key('group-color-list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: aikoCategoryColorPresets.length,
                  itemBuilder: (context, idx) {
                    final item = aikoCategoryColorPresets[idx];
                    final colorHex = item['hex']!;
                    final colorVal = _parseHex(colorHex);
                    final isSelected = _selectedColorHex == colorHex;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorHex = colorHex),
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: colorVal,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.iconLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  return LayoutBuilder(
                    key: const Key('group-icon-grid'),
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 420
                          ? 7
                          : constraints.maxWidth >= 340
                          ? 6
                          : 5;
                      const spacing = 8.0;
                      const tileSize = 48.0;
                      final gridWidth =
                          tileSize * crossAxisCount +
                          spacing * (crossAxisCount - 1);
                      final rowCount =
                          (aikoCategoryIconPresets.length / crossAxisCount)
                              .ceil();

                      return Center(
                        child: SizedBox(
                          width: gridWidth,
                          height:
                              tileSize * rowCount + spacing * (rowCount - 1),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                  mainAxisSpacing: spacing,
                                  crossAxisSpacing: spacing,
                                ),
                            itemCount: aikoCategoryIconPresets.length,
                            itemBuilder: (context, idx) {
                              final entry = aikoCategoryIconPresets[idx];
                              final key = entry.key;
                              final iconData = entry.value;
                              final isSelected = _selectedIconKey == key;

                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    setState(() => _selectedIconKey = key),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? activeColor.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? activeColor
                                          : Theme.of(
                                              context,
                                            ).colorScheme.outlineVariant,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: isSelected
                                        ? activeColor
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    size: 23,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('group-save-button'),
                onPressed: _isSubmitting || _isDeleting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AikoColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _isSubmitting
                      ? context.l10n.savingEllipsis
                      : (_isEditing
                            ? context.l10n.groupSave
                            : context.l10n.groupCreate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
