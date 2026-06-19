import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shared theme — Apple/iOS-inspired Material 3 with red seed. Used by buyer + partner apps so visual
/// language stays consistent across the ecosystem.
///
/// Customise per app by deriving from this and overriding specific tokens (e.g. the partner app uses
/// 56pt buttons + slightly bigger typography for one-hand thumb reach).
class AppTheme {
  /// Brand red — used as the ColorScheme seed.
  static const Color seedRed = Color(0xFFB71C1C);

  static ThemeData buildLight({Color seed = seedRed, double buttonHeight = 50}) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        // Override seed-derived pinks to near-black / neutral grey for text — keeps typography crisp.
        onSurface: const Color(0xFF1C1B1F),
        onSurfaceVariant: const Color(0xFF49454F),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      }),
      scaffoldBackgroundColor: const Color(0xFFFEF7F7),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFFFEF7F7),
        toolbarHeight: 56,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 0.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(buttonHeight - 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
