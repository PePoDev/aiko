import 'package:aiko/app/providers.dart';
import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/categories/data/category_repository.dart';
import 'package:aiko/features/categories/domain/category.dart';
import 'package:aiko/features/export/presentation/export_screen.dart';
import 'package:aiko/features/transactions/data/transaction_repository.dart';
import 'package:aiko/features/transactions/domain/transaction.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Each load takes a moment, as a real store does: long enough for a provider
// that nothing holds to be disposed before it finishes.
const _loadTime = Duration(milliseconds: 5);

class _Accounts extends AccountRepository {
  @override
  Future<List<Account>> list() async {
    await Future<void>.delayed(_loadTime);
    return const [];
  }
}

class _Categories extends CategoryRepository {
  @override
  Future<String> currentUserId() async {
    await Future<void>.delayed(_loadTime);
    return 'user';
  }

  @override
  Future<List<Category>> list({String? userId}) async {
    await Future<void>.delayed(_loadTime);
    return const [];
  }
}

class _Transactions extends TransactionRepository {
  @override
  Future<List<FinanceTransaction>> list() async {
    await Future<void>.delayed(_loadTime);
    return const [];
  }
}

void main() {
  // Opening or reloading the page directly: no other screen has loaded the
  // categories or transactions, so only this screen can keep them alive.
  testWidgets('exports when no other screen has loaded the data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(_Accounts()),
          categoryRepositoryProvider.overrideWithValue(_Categories()),
          transactionRepositoryProvider.overrideWithValue(_Transactions()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExportScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Share Export Document'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(_loadTime);
    }

    expect(find.textContaining("Couldn't create the export"), findsNothing);
    // The data loaded and was empty; the export got as far as saying so.
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
