import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('idea onboarding flows from splash to login', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Your Personal'), findsOneWidget);
    expect(find.textContaining('Smarter insights'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text("Hi, I'm Aiko!", skipOffstage: false), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("What's your", skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Save More', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("Let's add your", skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Bank Account', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Search for your bank'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!', skipOffstage: false), findsOneWidget);
    expect(find.text('Log In', skipOffstage: false), findsOneWidget);
  });
}
