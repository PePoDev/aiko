import 'package:flutter/material.dart';

import '../../../theme/aiko_colors.dart';

class InlineGlossaryText extends StatelessWidget {
  const InlineGlossaryText({
    required this.text,
    required this.glossary,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  final String text;
  final Map<String, String> glossary;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final terms =
        glossary.keys
            .where((term) => term.trim().isNotEmpty)
            .toList(growable: false)
          ..sort((a, b) => b.length.compareTo(a.length));

    if (text.isEmpty || terms.isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final definitions = <String, String>{
      for (final entry in glossary.entries)
        entry.key.toLowerCase(): entry.value,
    };
    final matcher = RegExp(
      terms.map(RegExp.escape).join('|'),
      caseSensitive: false,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in matcher.allMatches(text)) {
      if (!_hasTermBoundaries(text, match.start, match.end)) {
        continue;
      }
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final matchedTerm = text.substring(match.start, match.end);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _GlossaryTerm(
            term: matchedTerm,
            definition: definitions[matchedTerm.toLowerCase()]!,
            style: style,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor == 0) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

bool _hasTermBoundaries(String text, int start, int end) {
  final beforeIsWord = start > 0 && _isWordCharacter(text[start - 1]);
  final afterIsWord = end < text.length && _isWordCharacter(text[end]);
  return !beforeIsWord && !afterIsWord;
}

bool _isWordCharacter(String character) {
  return RegExp(r'[A-Za-z0-9]').hasMatch(character);
}

class _GlossaryTerm extends StatefulWidget {
  const _GlossaryTerm({
    required this.term,
    required this.definition,
    required this.style,
  });

  final String term;
  final String definition;
  final TextStyle? style;

  @override
  State<_GlossaryTerm> createState() => _GlossaryTermState();
}

class _GlossaryTermState extends State<_GlossaryTerm> {
  final _tooltipKey = GlobalKey<TooltipState>();

  void _showTooltip() {
    _tooltipKey.currentState?.ensureTooltipVisible();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: '${widget.term}: ${widget.definition}',
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) _showTooltip();
        },
        child: GestureDetector(
          onLongPress: _showTooltip,
          child: Tooltip(
            key: _tooltipKey,
            message: widget.definition,
            triggerMode: TooltipTriggerMode.tap,
            enableTapToDismiss: true,
            excludeFromSemantics: true,
            child: Text(
              widget.term,
              style:
                  widget.style?.copyWith(
                    color: AikoColors.analyticsTeal,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: AikoColors.analyticsTeal,
                  ) ??
                  const TextStyle(
                    color: AikoColors.analyticsTeal,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: AikoColors.analyticsTeal,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
