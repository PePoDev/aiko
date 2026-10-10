import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

/// The Rive runtime is optional: Aiko falls back to PNG art until it's ready.
/// On the web it is a WebAssembly download from a CDN, so it loads in the
/// background, only when the animation is bundled, and a slow or failed
/// download never blocks or breaks app startup.
abstract final class AikoRiveRuntime {
  static const asset = 'assets/rive/aiko.riv';

  /// Becomes true once the runtime is initialized; `AikoCharacter` switches
  /// from the PNG fallback to the animation then.
  static final ready = ValueNotifier<bool>(false);

  static Future<void>? _initializing;

  static Future<void> initialize({
    AssetBundle? bundle,
    Duration timeout = const Duration(seconds: 10),
  }) => _initializing ??= _initialize(bundle ?? rootBundle, timeout);

  static Future<void> _initialize(AssetBundle bundle, Duration timeout) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      if (!manifest.listAssets().contains(asset)) return;
      await rive.RiveNative.init().timeout(timeout);
      ready.value = true;
    } catch (error) {
      debugPrint('[aiko] Rive runtime unavailable, using PNG art: $error');
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _initializing = null;
    ready.value = false;
  }
}
