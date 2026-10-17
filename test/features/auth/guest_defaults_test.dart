import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/features/auth/data/guest_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OfflineAccount account(
    String id, {
    String owner = 'local:guest',
    String name = 'Cash',
    String type = 'cash',
    String balance = '0',
  }) => OfflineAccount(
    id: id,
    userId: owner,
    name: name,
    type: type,
    currency: 'THB',
    currentBalance: balance,
  );

  test('finds the untouched Cash and Bank accounts, in any language', () {
    final unused = unusedGuestDefaultAccounts([
      account('cash'),
      account('bank', name: 'บัญชีธนาคาร', type: 'bank', balance: '0.00'),
    ], const []);

    expect(unused.map((a) => a.id), ['cash', 'bank']);
  });

  test('keeps accounts the guest used, renamed or funded', () {
    final unused = unusedGuestDefaultAccounts(
      [
        account('spent'),
        account('renamed', name: 'Wallet'),
        account('funded', balance: '150'),
        account('other-type', type: 'bank'),
        account('signed-in', owner: 'real-uid'),
      ],
      [
        OfflineTransaction(
          id: 't1',
          userId: 'local:guest',
          accountId: 'spent',
          type: 'expense',
          amount: '0',
          currency: 'THB',
          date: DateTime(2026),
        ),
      ],
    );

    expect(unused, isEmpty);
  });
}
