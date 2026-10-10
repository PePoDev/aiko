import 'package:flutter/widgets.dart';

import 'aiko_breakpoints.dart';

/// Deals [items] into [columns] lists left to right (0, 2, 4… then 1, 3, 5…
/// for two), so reading order stays row by row across the columns.
List<List<T>> splitIntoColumns<T>(List<T> items, int columns) {
  assert(columns > 0);
  return [
    for (var column = 0; column < columns; column++)
      [for (var i = column; i < items.length; i += columns) items[i]],
  ];
}

/// A vertical stack of cards that becomes two columns once the available width
/// reaches [AikoBreakpoints.twoColumnContent]. Phones always get one column in
/// the given order.
class AikoAdaptiveColumns extends StatelessWidget {
  const AikoAdaptiveColumns({
    required this.children,
    this.spacing = 16,
    super.key,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= AikoBreakpoints.twoColumnContent
            ? 2
            : 1;
        if (columns == 1) return _stack(children);
        final split = splitIntoColumns(children, columns);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < split.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(child: _stack(split[i])),
            ],
          ],
        );
      },
    );
  }

  Widget _stack(List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : spacing),
          child: items[i],
        ),
    ],
  );
}
