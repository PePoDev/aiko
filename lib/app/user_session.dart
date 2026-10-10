import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../features/aiko_assistant/application/aiko_chat_controller.dart';
import '../features/investments/application/investments_provider.dart';
import '../features/settings/data/line_link_repository.dart';
import 'providers.dart';

/// Resets per-user state that isn't a synced collection: the Ask Aiko
/// transcript (which is sent back as chat history) and the LINE link status.
/// Runs whenever the signed-in user changes, so the next user never sees or
/// sends the previous user's conversation.
void invalidateUserSessionState(
  void Function(ProviderOrFamily provider) invalidate,
) {
  invalidate(aikoChatControllerProvider);
  invalidate(lineLinkedProvider);
}

/// Reloads everything held for the signed-in user. Call it right after
/// signing in, signing out or deleting the account; pass `ref.invalidate`
/// (or `container.invalidate`).
void invalidateUserData(void Function(ProviderOrFamily provider) invalidate) {
  for (final provider in <ProviderOrFamily>[
    profileProvider,
    accountsProvider,
    transactionsProvider,
    categoriesProvider,
    categoryGroupsProvider,
    investmentsProvider,
  ]) {
    invalidate(provider);
  }
  invalidateUserSessionState(invalidate);
}
