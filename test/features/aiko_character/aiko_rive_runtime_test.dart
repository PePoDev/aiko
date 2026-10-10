import 'package:aiko/features/aiko_character/application/aiko_rive_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(AikoRiveRuntime.resetForTesting);

  test('stays on the PNG fallback when the animation is not bundled', () async {
    await AikoRiveRuntime.initialize();

    expect(AikoRiveRuntime.ready.value, isFalse);
  });

  test('initializes at most once', () {
    expect(
      identical(AikoRiveRuntime.initialize(), AikoRiveRuntime.initialize()),
      isTrue,
    );
  });
}
