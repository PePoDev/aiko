# Release Gates: Aiko Personal Finance App

## Purpose

This document defines how Aiko records release validation when required tooling is unavailable in the current workspace.

## Required Gates

- `dart format --set-exit-if-changed .` must pass before release.
- `flutter analyze` must pass before release.
- `flutter test` must pass before release.
- Critical integration journeys must pass with local Supabase seeded.
- Profile-mode performance evidence must cover onboarding, transaction search, Home dashboard, Aiko Review, and calculators.
- Android build evidence must be recorded with production dart-defines.
- iOS build evidence must be recorded on macOS/Xcode with production dart-defines.

## Exception Policy

An environment-dependent gate may remain open only when its evidence file documents:

- the exact command attempted or expected,
- the blocking environment condition,
- the next required environment or tooling change,
- the affected task IDs,
- the owner who must rerun the gate before release.

Exception notes do not count as a pass. They keep the blocker visible until the correct environment is available.

## Current Environment-Dependent Gates

- T144: integration tests require a supported Flutter target and local Supabase readiness.
- T147: profile-mode performance requires Android/iOS emulator or device tooling.
- T148: Android build requires Android SDK and `ANDROID_HOME`.
- T149: iOS build requires macOS, Xcode, and signing configuration.
