import 'package:aiko/shared/widgets/screen_states.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('screen state exposes title and message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AikoTheme.light(),
        home: const AikoScreenState.empty(title: 'Empty', message: 'Add data'),
      ),
    );

    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('Add data'), findsOneWidget);
  });
}
