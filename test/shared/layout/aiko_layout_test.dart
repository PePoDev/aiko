import 'package:aiko/shared/layout/aiko_adaptive_columns.dart';
import 'package:aiko/shared/layout/aiko_breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AikoBreakpoints.layoutFor', () {
    test('phones and narrow windows are compact', () {
      expect(AikoBreakpoints.layoutFor(390), AikoLayout.compact);
      expect(AikoBreakpoints.layoutFor(839.9), AikoLayout.compact);
    });

    test('tablets and desktop windows are expanded', () {
      expect(AikoBreakpoints.layoutFor(840), AikoLayout.expanded);
      expect(AikoBreakpoints.layoutFor(1440), AikoLayout.expanded);
    });
  });

  group('AikoBreakpoints.contentWidthFor', () {
    test('Overview gets the widest column', () {
      expect(AikoBreakpoints.contentWidthFor('/home'), 1320);
    });

    test('chat and forms stay readable', () {
      expect(AikoBreakpoints.contentWidthFor('/aiko'), 960);
      expect(AikoBreakpoints.contentWidthFor('/settings'), 880);
      expect(AikoBreakpoints.contentWidthFor('/profile'), 880);
    });

    test('a tool under /settings is not narrowed like Settings', () {
      expect(
        AikoBreakpoints.contentWidthFor('/settings/chance-of-success'),
        1120,
      );
      expect(AikoBreakpoints.contentWidthFor('/transactions'), 1120);
      expect(AikoBreakpoints.contentWidthFor('/portfolio/allocation'), 1120);
    });

    test('the Overview column fits two card columns', () {
      expect(
        AikoBreakpoints.contentWidthFor('/home'),
        greaterThan(AikoBreakpoints.twoColumnContent),
      );
    });
  });

  group('splitIntoColumns', () {
    test('one column keeps the order', () {
      expect(splitIntoColumns([1, 2, 3], 1), [
        [1, 2, 3],
      ]);
    });

    test('two columns deal items left to right', () {
      expect(splitIntoColumns([0, 1, 2, 3, 4, 5], 2), [
        [0, 2, 4],
        [1, 3, 5],
      ]);
      expect(splitIntoColumns([0, 1, 2], 2), [
        [0, 2],
        [1],
      ]);
    });

    test('keeps every item exactly once', () {
      final items = List.generate(7, (i) => i);
      final columns = splitIntoColumns(items, 3);
      expect(columns.expand((c) => c).toList()..sort(), items);
    });
  });
}
