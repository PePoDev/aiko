import 'package:flutter/material.dart';

import 'aiko_colors.dart';
import 'aiko_typography.dart';

class AikoTheme {
  const AikoTheme._();

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AikoColors.primaryBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: AikoColors.primaryBlue,
          onPrimary: AikoColors.white,
          secondary: AikoColors.deepBlue,
          onSecondary: AikoColors.white,
          tertiary: AikoColors.premiumPurple,
          onTertiary: AikoColors.white,
          surface: AikoColors.surfacePanel,
          surfaceContainerHighest: AikoColors.surfacePanelStrong,
          onSurface: AikoColors.darkNavy,
          outline: AikoColors.border,
          outlineVariant: AikoColors.borderSubtle,
          error: AikoColors.dangerRed,
          onError: AikoColors.white,
        );

    return _base(
      scheme,
      scaffoldBackgroundColor: AikoColors.appBackground,
      cardColor: AikoColors.surfacePanel,
      cardBorderColor: AikoColors.borderSubtle,
      inputFillColor: const Color(0xFFE8EDFF),
      mutedColor: AikoColors.mutedText,
    );
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AikoColors.primaryBlue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AikoColors.softBlue,
          onPrimary: AikoColors.darkNavy,
          secondary: AikoColors.primaryBlue,
          onSecondary: AikoColors.white,
          tertiary: const Color(0xFFB894F5),
          onTertiary: AikoColors.darkNavy,
          surface: AikoColors.surfacePanelDark,
          surfaceContainerHighest: AikoColors.surfacePanelDarkStrong,
          onSurface: AikoColors.white,
          outline: const Color(0xFF414B60),
          outlineVariant: const Color(0xFF293348),
          error: const Color(0xFFF87171),
          onError: AikoColors.darkNavy,
        );

    return _base(
      scheme,
      scaffoldBackgroundColor: AikoColors.darkNavy,
      cardColor: AikoColors.surfacePanelDark,
      cardBorderColor: const Color(0xFF293348),
      inputFillColor: AikoColors.surfacePanelDarkStrong,
      mutedColor: const Color(0xFFBAC3D6),
    );
  }

  static ThemeData _base(
    ColorScheme scheme, {
    required Color scaffoldBackgroundColor,
    required Color cardColor,
    required Color cardBorderColor,
    required Color inputFillColor,
    required Color mutedColor,
  }) {
    final textTheme = AikoTypography.textTheme(scheme.onSurface);
    final radius = BorderRadius.circular(8);
    final inputBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.outline),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      textTheme: textTheme,
      disabledColor: mutedColor.withValues(alpha: 0.6),
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: cardBorderColor),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.outlineVariant,
          disabledForegroundColor: mutedColor,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        constraints: const BoxConstraints(minHeight: 54),
        labelStyle: textTheme.bodyMedium?.copyWith(color: mutedColor),
        hintStyle: textTheme.bodyMedium?.copyWith(color: mutedColor),
        prefixIconColor: mutedColor,
        suffixIconColor: scheme.onSurface,
        border: inputBorder,
        enabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          disabledForegroundColor: mutedColor,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: mutedColor),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: radius),
        minLeadingWidth: 28,
        horizontalTitleGap: 12,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : mutedColor,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.onPrimary : scheme.onSurface,
          );
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outlineVariant,
        circularTrackColor: scheme.outlineVariant,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: inputFillColor,
        selectedColor: scheme.primary,
        disabledColor: scheme.outlineVariant,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimary,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primary;
            }
            return inputFillColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.onPrimary;
            }
            return scheme.onSurface;
          }),
          side: WidgetStateProperty.all(BorderSide(color: scheme.outline)),
          textStyle: WidgetStateProperty.all(textTheme.labelLarge),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: radius),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return mutedColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: 0.25);
          }
          return scheme.outlineVariant;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: AikoColors.neutralInk,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AikoColors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
