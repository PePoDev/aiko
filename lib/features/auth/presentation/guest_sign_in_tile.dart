import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/aiko_colors.dart';

/// For guests (a cloud build used without an account): signing in backs up
/// what they recorded on this device and syncs it to their other devices.
/// The login screen claims their records into the account.
class GuestSignInTile extends StatelessWidget {
  const GuestSignInTile({this.contentPadding, super.key});

  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: contentPadding,
      leading: const Icon(
        Icons.cloud_upload_outlined,
        color: AikoColors.primaryBlue,
      ),
      title: Text(context.l10n.guestSignInToSync),
      subtitle: Text(context.l10n.guestSignInToSyncSubtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/auth'),
    );
  }
}
