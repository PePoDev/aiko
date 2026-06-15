import 'package:flutter/material.dart';

import '../../../theme/aiko_colors.dart';

class AikoMarkdownText extends StatelessWidget {
  const AikoMarkdownText({
    super.key,
    required this.content,
    this.streaming = false,
    this.baseStyle,
  });

  final String content;
  final bool streaming;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();
    final style =
        baseStyle ??
        TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          height: 1.4,
        );
    final blocks = parseAikoMarkdownBlocks(content, style);
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final isLast = i == blocks.length - 1;
      final block = blocks[i];
      children.add(
        Text.rich(
          TextSpan(
            style: block.style ?? style,
            children: [
              ...block.spans,
              if (isLast && streaming)
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _AikoCaret(),
                ),
            ],
          ),
        ),
      );
      if (!isLast) children.add(const SizedBox(height: 6));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

enum _BlockKind { paragraph, heading, bullet }

class AikoMarkdownBlock {
  const AikoMarkdownBlock({required this.spans, this.style});
  final List<InlineSpan> spans;
  final TextStyle? style;
}

List<AikoMarkdownBlock> parseAikoMarkdownBlocks(String text, TextStyle base) {
  if (text.isEmpty) return const [];
  final lines = text.split('\n');
  final blocks = <AikoMarkdownBlock>[];
  final buffer = StringBuffer();
  _BlockKind? current;

  void flush() {
    if (buffer.isEmpty || current == null) return;
    final raw = buffer.toString();
    final kind = current!;
    buffer.clear();
    current = null;
    switch (kind) {
      case _BlockKind.paragraph:
        blocks.add(AikoMarkdownBlock(spans: _parseInline(raw, base)));
      case _BlockKind.heading:
        final stripped = raw.replaceFirst(RegExp(r'^\s*#{1,3}\s+'), '');
        blocks.add(
          AikoMarkdownBlock(
            spans: _parseInline(stripped, base),
            style: base.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: (base.fontSize ?? 15) + 2,
            ),
          ),
        );
      case _BlockKind.bullet:
        blocks.add(AikoMarkdownBlock(spans: _parseBullets(raw, base)));
    }
  }

  for (final line in lines) {
    if (line.trim().isEmpty) {
      flush();
      continue;
    }
    final kind = _classifyLine(line);
    if (kind != current) {
      flush();
      current = kind;
    }
    if (buffer.isNotEmpty) buffer.write('\n');
    buffer.write(line);
  }
  flush();
  return blocks;
}

_BlockKind _classifyLine(String line) {
  final trimmed = line.trimLeft();
  if (RegExp(r'^#{1,3}\s+').hasMatch(trimmed)) return _BlockKind.heading;
  if (trimmed.startsWith('- ') ||
      trimmed.startsWith('* ') ||
      trimmed.startsWith('• ')) {
    return _BlockKind.bullet;
  }
  return _BlockKind.paragraph;
}

List<InlineSpan> _parseBullets(String raw, TextStyle base) {
  final out = <InlineSpan>[];
  final lines = raw.split('\n');
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    if (out.isNotEmpty) out.add(const TextSpan(text: '\n'));
    final leading = line.length - line.trimLeft().length;
    final trimmed = line.trimLeft();
    final marker = trimmed[0];
    final body = trimmed.substring(2).trimLeft();
    out.add(TextSpan(text: '${' ' * leading}$marker '));
    out.addAll(_parseInline(body, base));
  }
  return out;
}

List<InlineSpan> _parseInline(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  int i = 0;

  void flush() {
    if (buffer.isEmpty) return;
    spans.add(TextSpan(text: buffer.toString()));
    buffer.clear();
  }

  while (i < text.length) {
    final ch = text[i];

    if (ch == '*' && i + 1 < text.length && text[i + 1] == '*') {
      final end = text.indexOf('**', i + 2);
      if (end > i + 2) {
        flush();
        spans.add(
          TextSpan(
            text: text.substring(i + 2, end),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
        i = end + 2;
        continue;
      }
    }

    if (ch == '_' && i + 1 < text.length && text[i + 1] == '_') {
      final end = text.indexOf('__', i + 2);
      if (end > i + 2) {
        flush();
        spans.add(
          TextSpan(
            text: text.substring(i + 2, end),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
        i = end + 2;
        continue;
      }
    }

    if (ch == '`') {
      final end = text.indexOf('`', i + 1);
      if (end > i + 1) {
        flush();
        spans.add(
          TextSpan(
            text: text.substring(i + 1, end),
            style: base.copyWith(
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Menlo', 'Courier'],
              backgroundColor:
                  base.color?.withValues(alpha: 0.08) ??
                  Colors.black.withValues(alpha: 0.06),
              fontSize: (base.fontSize ?? 15) - 1,
            ),
          ),
        );
        i = end + 1;
        continue;
      }
    }

    if (ch == '*' || ch == '_') {
      final end = text.indexOf(ch, i + 1);
      if (end > i + 1 && _isItalicBoundary(text, i, end, ch)) {
        flush();
        spans.add(
          TextSpan(
            text: text.substring(i + 1, end),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        i = end + 1;
        continue;
      }
    }

    buffer.write(ch);
    i++;
  }
  flush();
  return spans;
}

bool _isItalicBoundary(String text, int start, int end, String marker) {
  if (marker == '*') return true;
  final leftOk = start == 0 || !_isWordChar(text.codeUnitAt(start - 1));
  final rightOk =
      end == text.length - 1 || !_isWordChar(text.codeUnitAt(end + 1));
  return leftOk && rightOk;
}

bool _isWordChar(int code) =>
    (code >= 0x30 && code <= 0x39) ||
    (code >= 0x41 && code <= 0x5A) ||
    (code >= 0x61 && code <= 0x7A) ||
    code == 0x5F;

class _AikoCaret extends StatefulWidget {
  const _AikoCaret();

  @override
  State<_AikoCaret> createState() => _AikoCaretState();
}

class _AikoCaretState extends State<_AikoCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Padding(
        padding: EdgeInsets.only(left: 2),
        child: Text(
          '│',
          style: TextStyle(
            color: AikoColors.primaryBlue,
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }
}
