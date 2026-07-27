# Aiko Rive Integration

**Date:** 2026-07-27  
**Status:** Approved design

## Goal

Introduce Rive as Aiko's motion runtime without moving application state or
finance rules into the animation. Start with the assistant's large empty-state
character and preserve the current PNG as a loading and error fallback.

## Rive Contract

The bundled file will live at `assets/rive/aiko.riv` and expose:

- artboard `Aiko`
- state machine `AikoState`
- default exported view model with `mood`, `active`, and `motionEnabled`

`mood` is a numeric value controlled by a Dart enum. `active` controls ambient
motion. `motionEnabled` lets the state machine choose static poses when the
platform requests reduced motion.

## Flutter Integration

A reusable `AikoCharacter` widget owns a Rive `FileLoader`, binds the default
view model, synchronizes widget state to Rive, and disposes the loader. It keeps
semantics in Flutter and displays an existing Aiko PNG while loading or after a
Rive failure.

The assistant stage replaces its randomized PNG and Flutter float controller
with `AikoCharacter`. Small transcript avatars remain SVG-based because a Rive
render surface per message would add cost without meaningful visual benefit.

## Missing Asset Behavior

The repository does not yet contain the final `.riv` export. The integration
must compile and retain a PNG fallback. Once the file is exported with the
contract above and placed at `assets/rive/aiko.riv`, no Dart changes should be
needed to activate the animation.

## Testing

- Unit-test stable Dart-to-Rive mood values.
- Widget-test the fallback, size, and semantics without requiring native Rive
  rendering.
- Retain existing assistant behavior and run the full Flutter test suite and
  analyzer.

## Deferred Rollout

Dashboard reactions, travel-mode expressions, and onboarding art remain
unchanged. They can adopt `AikoCharacter` after the final animation is approved
and the first integration is profiled on target devices.
