import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/account_details.dart';

abstract class AccountSubform extends ConsumerStatefulWidget {
  const AccountSubform({super.key});
}

abstract class AccountSubformState<T extends AccountSubform>
    extends ConsumerState<T> {
  AccountDetails getDetails();
  void resetTo(AccountDetails initial);
  String? validate();
}

/// Mixin for subforms that have no fields to validate or reset.
mixin NoOpSubformMixin<T extends StatefulWidget> on State<T> {
  AccountDetails getDetails() => const CashDetails();
  void resetTo(AccountDetails _) {}
  String? validate() => null;
}
