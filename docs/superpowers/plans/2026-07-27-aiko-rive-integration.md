# Aiko Rive Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable state-driven Rive character and use it on the Aiko assistant's empty stage while retaining the existing PNG fallback.

**Architecture:** Flutter and Riverpod continue to own application state. `AikoCharacter` translates a small `AikoMood` enum into the exported Rive view model and owns the Rive file loader; the Rive state machine owns only visual transitions. The assistant stage consumes this widget and no longer owns a separate float animation.

**Tech Stack:** Flutter 3.44, Dart 3.12, Rive Flutter 0.14, flutter_test

---

## File Structure

- Create `assets/rive/README.md`: records the binary export contract without checking in a placeholder binary.
- Create `lib/features/aiko_character/presentation/aiko_character.dart`: mood mapping, Rive loading/data binding, accessibility, and fallback rendering.
- Create `test/features/aiko_character/aiko_character_test.dart`: mood mapping and fallback widget coverage.
- Modify `pubspec.yaml`: add Rive and register the Rive asset directory.
- Modify `pubspec.lock`: resolve the Rive runtime and native dependencies.
- Modify `lib/main.dart`: initialize Rive before building the app.
- Modify `lib/features/aiko_assistant/presentation/aiko_assistant_screen.dart`: replace the large PNG/float stage with `AikoCharacter`.

### Task 1: Runtime Setup

**Files:**
- Create: `assets/rive/README.md`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/main.dart`

- [ ] **Step 1: Add the runtime dependency and asset directory**

Add `rive: ^0.14.10` to dependencies and `assets/rive/` to Flutter assets. Add an asset README documenting `Aiko`, `AikoState`, and the `mood`, `active`, and `motionEnabled` properties.

- [ ] **Step 2: Resolve dependencies**

Run: `flutter pub get`

Expected: dependency resolution succeeds and `pubspec.lock` records `rive` and `rive_native` while retaining the user's existing dependency changes.

- [ ] **Step 3: Initialize Rive**

Update `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import 'app/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await rive.RiveNative.init();
  final bootstrap = AppBootstrap.fromEnvironment();
  await bootstrap.initialize();
  runApp(bootstrap.buildApp());
}
```

- [ ] **Step 4: Check formatting and dependency resolution**

Run: `dart format lib/main.dart`

Expected: formatter exits successfully.

### Task 2: Character Contract and Fallback

**Files:**
- Create: `test/features/aiko_character/aiko_character_test.dart`
- Create: `lib/features/aiko_character/presentation/aiko_character.dart`

- [ ] **Step 1: Write the failing mood contract test**

Cover explicit values and fallbacks:

```dart
test('maps Aiko moods to stable Rive values and fallback assets', () {
  expect(AikoMood.neutral.riveValue, 0);
  expect(AikoMood.thinking.riveValue, 1);
  expect(AikoMood.happy.riveValue, 2);
  expect(AikoMood.worried.riveValue, 3);
  expect(AikoMood.celebrating.riveValue, 4);
  expect(
    AikoMood.thinking.fallbackAsset,
    'assets/images/aiko/aiko_thinking.png',
  );
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/aiko_character/aiko_character_test.dart`

Expected: FAIL because `aiko_character.dart` does not exist.

- [ ] **Step 3: Implement the stable mood mapping**

Create `AikoMood` and an extension with exhaustive switches for `riveValue` and `fallbackAsset`. Use explicit values rather than enum indexes so enum reordering cannot break the animation contract.

- [ ] **Step 4: Write the failing widget fallback test**

Pump `AikoCharacter` with `AikoMood.thinking`, a 180 pixel size, and the semantic label `Aiko is thinking`. After asynchronous loading settles, assert the key, semantics label, `SizedBox.square` dimensions, and thinking PNG fallback are present.

- [ ] **Step 5: Implement `AikoCharacter`**

Use `FileLoader.fromAsset('assets/rive/aiko.riv', riveFactory: Factory.rive)`, select `Aiko` and `AikoState`, and bind `DataBind.auto()`. Synchronize `mood`, `active`, and `motionEnabled`; use `MediaQuery.disableAnimationsOf(context)` for reduced motion. Render the mood PNG for `RiveLoading` and `RiveFailed`, wrap rendering in Flutter semantics, and dispose only the owned file loader because `RiveWidgetBuilder` owns its controller and view model lifecycle.

- [ ] **Step 6: Run the focused test**

Run: `flutter test test/features/aiko_character/aiko_character_test.dart`

Expected: PASS. The intentionally absent `.riv` export reaches the handled fallback state.

### Task 3: Assistant Stage Integration

**Files:**
- Modify: `lib/features/aiko_assistant/presentation/aiko_assistant_screen.dart:9,632-693`

- [ ] **Step 1: Replace the stage implementation**

Import `aiko_character.dart`, convert `_AikoStage` to a stateless widget, remove randomized PNG selection and `AnimationController`, and render:

```dart
const AikoCharacter(
  key: ValueKey('aiko-stage-character'),
  mood: AikoMood.thinking,
  semanticLabel: 'Aiko is thinking',
  size: 220,
)
```

Keep the existing greeting bubble, scrolling, spacing, and stage key behavior.

- [ ] **Step 2: Format changed Dart files**

Run: `dart format lib/main.dart lib/features/aiko_character/presentation/aiko_character.dart lib/features/aiko_assistant/presentation/aiko_assistant_screen.dart test/features/aiko_character/aiko_character_test.dart`

Expected: formatter exits successfully.

- [ ] **Step 3: Run focused tests**

Run: `flutter test test/features/aiko_character/aiko_character_test.dart test/features/aiko_assistant/http_chat_engine_test.dart test/features/aiko_assistant/financial_context_test.dart`

Expected: all tests pass.

### Task 4: Verification

**Files:**
- Review all changed files from Tasks 1-3.

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`

Expected: all tests pass. If the host lacks Rive's native test library, run `dart run rive_native:setup --verbose --clean --platform windows` and rerun the suite.

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`

Expected: no issues.

- [ ] **Step 3: Inspect the final diff**

Run: `git diff -- docs/superpowers/specs/2026-07-27-aiko-rive-integration-design.md docs/superpowers/plans/2026-07-27-aiko-rive-integration.md assets/rive/README.md pubspec.yaml pubspec.lock lib/main.dart lib/features/aiko_character/presentation/aiko_character.dart lib/features/aiko_assistant/presentation/aiko_assistant_screen.dart test/features/aiko_character/aiko_character_test.dart`

Expected: only the approved Rive integration appears; existing staged work remains intact. Do not stage or commit without an explicit user request.
