import 'package:aiko/features/settings/data/profile_repository.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    binding.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  test('resolveInitialTheme returns dark when the device is in dark mode', () {
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

    expect(ProfileRepository.resolveInitialTheme(), PreferredTheme.dark);
  });

  test(
    'resolveInitialTheme returns light when the device is in light mode',
    () {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;

      expect(ProfileRepository.resolveInitialTheme(), PreferredTheme.light);
    },
  );
}
