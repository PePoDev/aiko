# Final Profile Results

Validation date: 2026-05-18

Completed local checks:

- `dart format --set-exit-if-changed .`: passed.
- `flutter analyze`: passed.
- `flutter test`: passed, 34 tests.

Blocked checks:

- Integration tests: blocked because Flutter selected Linux desktop and CMake is not installed.
- Android build/profile: blocked because no Android SDK/`ANDROID_HOME` is available.
- iOS build/profile: blocked because this Linux toolchain does not include iOS build support; requires macOS and Xcode.

Next profile run should use Android Studio/Android SDK or an iOS/macOS runner and record startup, transaction search, Home refresh, Aiko Review, and calculator input timings.
