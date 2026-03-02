import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  // Figma/Tailwind tokens mapped to Flutter theme.
  static const Color colorBgPrimary = Color(0xFF0A0A0F);
  static const Color colorBgSecondary = Color(0xFF18181F);
  static const Color colorBgElevated = Color(0xFF222229);
  static const Color colorBgCard = Color(0xFF1A1A22);

  static const Color colorTextPrimary = Color(0xFFF5F5F7);
  static const Color colorTextSecondary = Color(0xFFA0A0A8);
  static const Color colorTextTertiary = Color(0xFF6E6E76);

  static const Color colorAccentPrimary = Color(0xFFA855F7);
  static const Color colorAccentPrimaryHover = Color(0xFF9333EA);
  static const Color colorAccentSecondary = Color(0xFF06B6D4);

  static const Color colorStatusSuccess = Color(0xFF10B981);
  static const Color colorStatusWarning = Color(0xFFF59E0B);
  static const Color colorStatusDanger = Color(0xFFEF4444);

  static const Color colorStrokeSubtle = Color(0xFF2A2A32);
  static const Color colorStrokeMedium = Color(0xFF3A3A42);

  // Backward-compatible aliases used in existing widgets.
  static const Color brandBg = colorBgPrimary;
  static const Color brandSurface = colorBgSecondary;
  static const Color brandSurfaceAlt = colorBgCard;
  static const Color brandAccent = colorAccentPrimary;

  static ThemeData dark() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    final scheme =
        const ColorScheme(
          brightness: Brightness.dark,
          primary: colorAccentPrimary,
          onPrimary: Colors.white,
          secondary: colorAccentSecondary,
          onSecondary: Colors.white,
          error: colorStatusDanger,
          onError: Colors.white,
          surface: colorBgSecondary,
          onSurface: colorTextPrimary,
        ).copyWith(
          outline: colorStrokeSubtle,
          outlineVariant: colorStrokeMedium,
          surfaceContainer: colorBgCard,
          surfaceContainerHigh: colorBgElevated,
        );

    final textTheme = GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: colorTextPrimary, displayColor: colorTextPrimary);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: colorStrokeSubtle),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: colorBgPrimary,
      canvasColor: colorBgPrimary,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: colorBgCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: colorStrokeSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorBgSecondary,
        hintStyle: textTheme.bodyMedium?.copyWith(color: colorTextSecondary),
        labelStyle: textTheme.labelMedium?.copyWith(color: colorTextSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: colorAccentPrimary),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: colorStatusDanger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: colorStatusDanger),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colorBgElevated,
        selectedColor: colorAccentPrimary.withValues(alpha: 0.2),
        side: const BorderSide(color: colorStrokeSubtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: textTheme.labelMedium?.copyWith(color: colorTextSecondary),
      ),
      dividerColor: colorStrokeSubtle,
      dividerTheme: const DividerThemeData(
        color: colorStrokeSubtle,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorBgElevated.withValues(alpha: 0.95),
        indicatorColor: colorAccentPrimary.withValues(alpha: 0.16),
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorTextPrimary : colorTextTertiary,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
                color: selected ? colorAccentPrimary : colorTextTertiary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ) ??
              const TextStyle();
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorBgElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorTextPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
