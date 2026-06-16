import 'package:aiko/features/settings/data/line_link_repository.dart';
import 'package:aiko/features/settings/presentation/connect_line_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  Future<void> pump(WidgetTester tester, LineLinkRepository repo) {
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: ConnectLineScreen(repository: repo),
        ),
      ),
    );
  }

  testWidgets('shows success after a valid code connects', (tester) async {
    final repo = _FakeLineLinkRepository();

    await pump(tester, repo);
    await tester.enterText(find.byType(TextField), 'K7M2QP');
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();

    expect(repo.lastCode, 'K7M2QP');
    expect(find.textContaining('Connected!'), findsOneWidget);
  });

  testWidgets('shows the error message when connecting fails', (tester) async {
    final repo = _FakeLineLinkRepository(
      error: const LineLinkException('That code is invalid or expired.'),
    );

    await pump(tester, repo);
    await tester.enterText(find.byType(TextField), 'BADCODE');
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();

    expect(find.text('That code is invalid or expired.'), findsOneWidget);
  });
}

class _FakeLineLinkRepository implements LineLinkRepository {
  _FakeLineLinkRepository({this.error});

  final LineLinkException? error;
  String? lastCode;

  @override
  Future<void> connectWithCode(String rawCode) async {
    lastCode = rawCode;
    if (error != null) throw error!;
  }
}
