import '../domain/account.dart';
import '../domain/account_details.dart';

abstract final class SharedLimitResolver {
  /// Returns the list of credit-card accounts that need updating because
  /// they shared a limit with the deleted [deletedId]. The returned accounts
  /// have [CreditCardDetails.sharesLimit] flipped to false.
  static List<Account> resolve({
    required List<Account> accounts,
    required String deletedId,
  }) {
    final result = <Account>[];
    for (final a in accounts) {
      if (a.type != AccountType.creditCard) continue;
      final details = a.resolvedDetails;
      if (details is! CreditCardDetails) continue;
      if (!details.sharesLimit) continue;
      if (details.sharedLimitAccountId != deletedId) continue;
      result.add(
        a.copyWith(
          details: details.copyWith(
            sharesLimit: false,
            clearSharedLimitAccountId: true,
          ),
        ),
      );
    }
    return result;
  }
}
