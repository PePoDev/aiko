import 'package:flutter/material.dart';

import '../../domain/category.dart';
import '../category_visual.dart';

/// Group selector embedded in the category editor sheet. Lets the
/// user pick an existing [CategoryGroup], ungroup the category, or open
/// the group editor for a fresh group.
class CategoryGroupPicker extends StatelessWidget {
  const CategoryGroupPicker({
    super.key,
    required this.groups,
    required this.selectedGroupId,
    required this.onChanged,
    required this.onCreateNew,
    required this.accentColor,
  });

  static const String createNewSentinel = '__create__';

  final List<CategoryGroup> groups;
  final String? selectedGroupId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCreateNew;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Group',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: selectedGroupId,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.folder_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          hint: const Text('Ungrouped'),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Ungrouped'),
            ),
            for (final group in groups)
              DropdownMenuItem<String?>(
                value: group.id,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: aikoHexColor(group.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            DropdownMenuItem<String?>(
              value: createNewSentinel,
              child: Row(
                children: [
                  Icon(Icons.add, color: accentColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Create new group...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value == createNewSentinel) {
              onCreateNew();
              return;
            }
            onChanged(value);
          },
        ),
      ],
    );
  }
}
