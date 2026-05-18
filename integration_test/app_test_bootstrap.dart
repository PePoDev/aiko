import 'package:flutter/widgets.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/test_app.dart';

Widget buildIntegrationTestApp() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  return buildTestApp();
}
