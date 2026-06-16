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
