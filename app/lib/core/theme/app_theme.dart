import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const Color brandBg = Color(0xFF0B0B0F);
  static const Color brandSurface = Color(0xFF101018);
  static const Color brandSurfaceAlt = Color(0xFF141420);
  static const Color brandAccent = Color(0xFF7E7BFF);

  static ThemeData dark() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brandAccent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: brandAccent,
          surface: brandSurface,
          onSurface: const Color(0xFFF2F2F6),
          outline: Colors.white.withValues(alpha: 0.1),
        );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: brandBg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
      ),
      dividerColor: Colors.white.withValues(alpha: 0.1),
    );
  }
}
