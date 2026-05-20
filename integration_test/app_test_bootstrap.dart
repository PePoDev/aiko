import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/test_app.dart';

Widget buildIntegrationTestApp() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  return const IntegrationTestStateResetWrapper();
}

class IntegrationTestStateResetWrapper extends StatefulWidget {
  const IntegrationTestStateResetWrapper({super.key});

  @override
  State<IntegrationTestStateResetWrapper> createState() =>
      _IntegrationTestStateResetWrapperState();
}

class _IntegrationTestStateResetWrapperState
    extends State<IntegrationTestStateResetWrapper> {
  bool _cleared = false;

  @override
  void initState() {
    super.initState();
    _clearStorage();
  }

  Future<void> _clearStorage() async {
    await const FlutterSecureStorage().deleteAll();
    if (mounted) {
      setState(() {
        _cleared = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_cleared) {
      return const SizedBox.shrink();
    }
    return buildTestApp();
  }
}

