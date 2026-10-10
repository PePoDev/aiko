import 'dart:math' as math;

import 'package:aiko/theme/aiko_colors.dart';
import 'package:aiko/theme/aiko_status_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('status text meets 4.5:1 on the panels it sits on', () {
    for (final background in [
      AikoColors.white,
      AikoColors.surfacePanel,
      AikoColors.surfacePanelStrong,
      AikoColors.appBackground,
    ]) {
      for (final text in [
        AikoStatusColors.light.successText,
        AikoStatusColors.light.warningText,
        AikoStatusColors.light.dangerText,
      ]) {
        expect(_contrast(text, background), greaterThanOrEqualTo(4.5));
      }
    }
    for (final background in [
      AikoColors.darkNavy,
      AikoColors.surfacePanelDark,
      AikoColors.surfacePanelDarkStrong,
      AikoColors.neutralInk, // snack bars
    ]) {
      for (final text in [
        AikoStatusColors.dark.successText,
        AikoStatusColors.dark.warningText,
        AikoStatusColors.dark.dangerText,
      ]) {
        expect(_contrast(text, background), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('textFor maps status fills to their text variants', () {
    const light = AikoStatusColors.light;
    expect(light.textFor(AikoColors.warningOrange), AikoColors.warningText);
    expect(light.textFor(AikoColors.successGreen), AikoColors.successText);
    expect(light.textFor(AikoColors.dangerRed), AikoColors.dangerText);
    expect(light.textFor(AikoColors.premiumPurple), AikoColors.premiumPurple);
    expect(
      AikoStatusColors.dark.textFor(AikoColors.warningOrange),
      AikoColors.warningTextDark,
    );
  });
}
