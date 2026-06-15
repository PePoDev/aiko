import 'package:aiko/features/aiko_assistant/presentation/aiko_markdown.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = TextStyle(fontSize: 15);

  group('parseAikoMarkdownBlocks', () {
    test('plain text returns a single paragraph block', () {
      final blocks = parseAikoMarkdownBlocks('Hello world', base);
      expect(blocks, hasLength(1));
      expect(_textOf(blocks.first.spans), 'Hello world');
    });

    test('**bold** renders as a bold span', () {
      final blocks = parseAikoMarkdownBlocks('a **b** c', base);
      final spans = blocks.first.spans;
      expect(spans, hasLength(3));
      final bold = spans[1] as TextSpan;
      expect(bold.text, 'b');
      expect(bold.style?.fontWeight, FontWeight.w700);
    });

    test('__bold__ renders as a bold span', () {
      final blocks = parseAikoMarkdownBlocks('a __b__ c', base);
      final bold = blocks.first.spans.firstWhere(
        (s) => s is TextSpan && s.text == 'b',
      ) as TextSpan;
      expect(bold.style?.fontWeight, FontWeight.w700);
    });

    test('*italic* renders as an italic span', () {
      final blocks = parseAikoMarkdownBlocks('a *b* c', base);
      final italic = blocks.first.spans.firstWhere(
        (s) => s is TextSpan && s.text == 'b',
      ) as TextSpan;
      expect(italic.style?.fontStyle, FontStyle.italic);
    });

    test('_italic_ respects word boundaries (snake_case stays literal)', () {
      final blocks = parseAikoMarkdownBlocks('use snake_case here', base);
      expect(_textOf(blocks.first.spans), 'use snake_case here');
      expect(
        blocks.first.spans.every(
          (s) => s is! TextSpan || s.style?.fontStyle != FontStyle.italic,
        ),
        isTrue,
      );
    });

    test('_italic_ with boundary is italicised', () {
      final blocks = parseAikoMarkdownBlocks('an _italic_ word', base);
      final italic = blocks.first.spans.firstWhere(
        (s) => s is TextSpan && s.text == 'italic',
      ) as TextSpan;
      expect(italic.style?.fontStyle, FontStyle.italic);
    });

    test('inline code uses monospace + background', () {
      final blocks = parseAikoMarkdownBlocks('call `setState`', base);
      final code = blocks.first.spans.firstWhere(
        (s) => s is TextSpan && s.text == 'setState',
      ) as TextSpan;
      expect(code.style?.fontFamily, 'monospace');
      expect(code.style?.backgroundColor, isNotNull);
    });

    test('bullet lines render as a single bullet block with prefix', () {
      final blocks = parseAikoMarkdownBlocks('- one\n- two', base);
      expect(blocks, hasLength(1));
      final text = _textOf(blocks.first.spans);
      expect(text, contains('- one'));
      expect(text, contains('- two'));
    });

    test('• and * bullet markers both render', () {
      final blocks = parseAikoMarkdownBlocks('• one\n* two', base);
      final text = _textOf(blocks.first.spans);
      expect(text, contains('• one'));
      expect(text, contains('* two'));
    });

    test('blank line separates paragraphs', () {
      final blocks = parseAikoMarkdownBlocks('First.\n\nSecond.', base);
      expect(blocks, hasLength(2));
      expect(_textOf(blocks[0].spans), 'First.');
      expect(_textOf(blocks[1].spans), 'Second.');
    });

    test('heading is bold and larger than base', () {
      final blocks = parseAikoMarkdownBlocks('# Title', base);
      final block = blocks.first;
      expect(block.style?.fontWeight, FontWeight.w700);
      expect(block.style?.fontSize, greaterThan(base.fontSize!));
      expect(_textOf(block.spans), 'Title');
    });

    test('heading inline formatting preserved', () {
      final blocks = parseAikoMarkdownBlocks('# Hello **world**', base);
      final bold = blocks.first.spans.firstWhere(
        (s) => s is TextSpan && s.text == 'world',
      ) as TextSpan;
      expect(bold.style?.fontWeight, FontWeight.w700);
    });

    test('streaming: incomplete ** renders literally', () {
      final blocks = parseAikoMarkdownBlocks('Here is **foo', base);
      expect(_textOf(blocks.first.spans), 'Here is **foo');
    });

    test('streaming: incomplete * italic renders literally', () {
      final blocks = parseAikoMarkdownBlocks('a *foo', base);
      expect(_textOf(blocks.first.spans), 'a *foo');
    });

    test('mixed: paragraph + bullet + paragraph', () {
      final blocks = parseAikoMarkdownBlocks(
        'You have 2 goals:\n- A\n- B\nKeep going.',
        base,
      );
      expect(blocks, hasLength(3));
      expect(_textOf(blocks[0].spans), 'You have 2 goals:');
      expect(_textOf(blocks[1].spans), contains('- A'));
      expect(_textOf(blocks[1].spans), contains('- B'));
      expect(_textOf(blocks[2].spans), 'Keep going.');
    });

    test('bullet body with **bold** keeps the bold inside the bullet', () {
      final blocks = parseAikoMarkdownBlocks('- **A**: 1', base);
      final bold = blocks.first.spans.firstWhere(
        (s) => s is TextSpan && s.text == 'A',
      ) as TextSpan;
      expect(bold.style?.fontWeight, FontWeight.w700);
    });

    test('empty input returns no blocks', () {
      expect(parseAikoMarkdownBlocks('', base), isEmpty);
    });
  });

  group('AikoMarkdownText widget', () {
    testWidgets('renders markdown content without raw markers',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AikoTheme.light(),
          home: const Scaffold(
            body: AikoMarkdownText(
              content: 'Hello **there** world\n\n- One\n- Two',
            ),
          ),
        ),
      );
      expect(find.textContaining('there'), findsOneWidget);
      expect(find.textContaining('- One'), findsOneWidget);
      expect(find.textContaining('- Two'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('## '), findsNothing);
    });
  });
}

String _textOf(List<InlineSpan> spans) =>
    spans.whereType<TextSpan>().map((s) => s.text ?? '').join();
