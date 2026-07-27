import 'dart:async';
import 'dart:convert';

import 'package:aiko/features/aiko_character/presentation/aiko_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  test('maps Aiko moods to stable Rive values and fallback assets', () {
    expect(AikoMood.neutral.riveValue, 0.0);
    expect(AikoMood.thinking.riveValue, 1.0);
    expect(AikoMood.happy.riveValue, 2.0);
    expect(AikoMood.worried.riveValue, 3.0);
    expect(AikoMood.celebrating.riveValue, 4.0);

    expect(
      AikoMood.neutral.fallbackAsset,
      'assets/images/aiko/aiko_welcome.png',
    );
    expect(
      AikoMood.thinking.fallbackAsset,
      'assets/images/aiko/aiko_thinking.png',
    );
    expect(AikoMood.happy.fallbackAsset, 'assets/images/aiko/aiko_happy.png');
    expect(
      AikoMood.worried.fallbackAsset,
      'assets/images/aiko/aiko_warning.png',
    );
    expect(
      AikoMood.celebrating.fallbackAsset,
      'assets/images/aiko/aiko_celebrating.png',
    );
  });

  testWidgets('can unmount while the Rive asset load is pending', (
    tester,
  ) async {
    const fallbackAsset = 'assets/images/aiko/aiko_welcome.png';
    final fallbackBytes = await rootBundle.load(fallbackAsset);
    final manifestBytes = await rootBundle.load('AssetManifest.bin');
    final riveAssetResponse = Completer<ByteData?>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var riveAssetRequested = false;
    var riveAssetResponseDelivered = false;

    messenger.setMockMessageHandler('flutter/assets', (message) {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (key == 'assets/rive/aiko.riv') {
        riveAssetRequested = true;
        return riveAssetResponse.future.whenComplete(() {
          riveAssetResponseDelivered = true;
        });
      }
      return Future<ByteData?>.value(switch (key) {
        'AssetManifest.bin' => manifestBytes,
        fallbackAsset => fallbackBytes,
        _ => null,
      });
    });

    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: AikoCharacter(mood: AikoMood.neutral, semanticLabel: 'Aiko'),
        ),
      );

      expect(riveAssetRequested, isTrue);
      expect(riveAssetResponse.isCompleted, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      riveAssetResponse.complete(null);
      for (var pump = 0; pump < 10 && !riveAssetResponseDelivered; pump++) {
        await tester.pump();
      }
      await tester.pump();

      expect(riveAssetResponseDelivered, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      if (!riveAssetResponse.isCompleted) {
        riveAssetResponse.complete(null);
      }
      messenger.setMockMessageHandler('flutter/assets', null);
    }
  });

  testWidgets('syncs the cached reduced-motion setting after loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AikoCharacter(
            mood: AikoMood.thinking,
            semanticLabel: 'Aiko is thinking',
          ),
        ),
      ),
    );
    final viewModel = _CompleteViewModelInstance();
    final builder = tester.widget<rive.RiveWidgetBuilder>(
      find.byType(rive.RiveWidgetBuilder),
    );

    expect(() => builder.onLoaded!(_loadedState(viewModel)), returnsNormally);
    expect(viewModel.mood.value, 1.0);
    expect(viewModel.active.value, isTrue);
    expect(viewModel.motionEnabled.value, isFalse);
  });

  for (final missingBinding in ['mood', 'active', 'motionEnabled']) {
    testWidgets('falls back when the Rive view model lacks $missingBinding', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AikoCharacter(
            mood: AikoMood.thinking,
            semanticLabel: 'Aiko is thinking',
          ),
        ),
      );
      final builderFinder = find.byType(rive.RiveWidgetBuilder);
      final builder = tester.widget<rive.RiveWidgetBuilder>(builderFinder);
      final loadedState = _loadedState(
        _CompleteViewModelInstance(missingBinding: missingBinding),
      );

      builder.onLoaded!(loadedState);
      final visual = builder.builder(
        tester.element(builderFinder),
        loadedState,
      );

      expect(visual, isA<Image>());
      final image = visual as Image;
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/aiko/aiko_thinking.png',
      );
    });
  }

  testWidgets('renders the initial sized semantic mood fallback', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: AikoCharacter(
              key: ValueKey('aiko-character-test'),
              mood: AikoMood.thinking,
              semanticLabel: 'Aiko is thinking',
              size: 180,
            ),
          ),
        ),
      );

      final character = find.byKey(const ValueKey('aiko-character-test'));
      expect(character, findsOneWidget);
      expect(find.bySemanticsLabel('Aiko is thinking'), findsOneWidget);
      expect(tester.getSize(character), const Size.square(180));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/aiko/aiko_thinking.png',
      );
    } finally {
      semantics.dispose();
    }
  });
}

rive.RiveLoaded _loadedState(rive.ViewModelInstance viewModelInstance) {
  return _LoadedState(viewModelInstance);
}

final class _LoadedState implements rive.RiveLoaded {
  _LoadedState(this.viewModelInstance);

  @override
  final rive.ViewModelInstance? viewModelInstance;

  @override
  rive.RiveWidgetController get controller =>
      throw StateError('Invalid Rive contracts must not render a controller.');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _CompleteViewModelInstance implements rive.ViewModelInstance {
  _CompleteViewModelInstance({this.missingBinding});

  final String? missingBinding;
  final mood = _NumberProperty(0);
  final active = _BooleanProperty(false);
  final motionEnabled = _BooleanProperty(false);

  @override
  rive.ViewModelInstanceNumber? number(String path) {
    return path == 'mood' && missingBinding != path ? mood : null;
  }

  @override
  rive.ViewModelInstanceBoolean? boolean(String path) {
    if (missingBinding == path) {
      return null;
    }
    return switch (path) {
      'active' => active,
      'motionEnabled' => motionEnabled,
      _ => null,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _NumberProperty implements rive.ViewModelInstanceNumber {
  _NumberProperty(this.value);

  @override
  double value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _BooleanProperty implements rive.ViewModelInstanceBoolean {
  _BooleanProperty(this.value);

  @override
  bool value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
