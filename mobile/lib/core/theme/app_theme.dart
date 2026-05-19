// Material 3 theme tuned for an Apple-style aesthetic — kept close to iOS conventions without going full Cupertino:
//
// • Typography uses the SF Pro / -apple-system fallback chain so the app reads as native on iOS/macOS/web,
//   and falls back to Roboto on Android. Sizes/weights mirror Apple's HIG (Large Title / Title 1 / Headline / etc.).
// • Components have iOS-y rounded corners (cards 18, buttons 14, fields 12), low-elevation surfaces, and
//   subtle separators rather than heavy borders.
// • Motion uses fast, eased curves (200ms standard) so transitions feel snappy like iOS.
//
// We deliberately stay on Material 3 instead of Cupertino so we keep one consistent component family on both platforms.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';


class AppTheme {
  // Existing brand seed — colors stay; this refactor only refines surface/typography/shape language.
  static const _seed = Color(0xFFB71C1C);

  // Apple system font fallback chain — "system-ui" works on web, ".SF Pro Display" / ".SF UI Text" on iOS,
  // and Roboto fills in on Android. Listing them all means each platform picks its native body font.
  static const _fontFamily = 'system-ui';
  static const _fontFamilyFallback = ['-apple-system', 'SF Pro Display', 'SF Pro Text', 'Roboto', 'Segoe UI', 'sans-serif'];

  /// Single light theme — dark mode is a future polish pass; current screens are tuned for light mode.
  static final ThemeData light = _build(Brightness.light);

  static ThemeData _build(Brightness b) {
    // ColorScheme.fromSeed with a heavily-saturated red derives onSurface/onSurfaceVariant with a faint pinkish tint.
    // On the light pink surfaces (also seed-derived) that produces near-invisible headline + chip labels.
    // Force near-black for primary text and clear gray for secondary so contrast is reliable on every screen.
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: b).copyWith(
      onSurface: b == Brightness.light ? const Color(0xFF111111) : const Color(0xFFE6E6E6),
      onSurfaceVariant: b == Brightness.light ? const Color(0xFF555555) : const Color(0xFFB8B8B8),
    );
    final textTheme = _buildTextTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      // iOS uses pure white scaffold + slightly cool gray for grouped surfaces. Our scheme already lands close.
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // App bars — flat, large-title friendly. surfaceTintColor: transparent disables M3's auto-tinting that was
      // washing out the SliverAppBar.large expanded title. iconTheme + actionsIconTheme force dark icons.
      appBarTheme: AppBarTheme(
        elevation: 0, scrolledUnderElevation: 0,
        backgroundColor: scheme.surface, foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurface),
        toolbarHeight: 56,
      ),

      // Cards — iOS-y radius, hairline tint instead of shadow, very light surface
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
      ),

      // Filled buttons — tall (50pt), 14pt radius, generous tap target. Matches iOS primary buttons.
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: scheme.outlineVariant),
      )),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      )),

      // Input fields — soft filled background, no heavy outlines unless focused. Echoes iOS form fields.
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.error, width: 1.0)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.error, width: 1.5)),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),

      // Chips — flat, pill-shaped, used in filter rows. Explicit label color so unselected labels stay readable
      // (the default inherited color was a tinted-from-seed near-white that disappeared on light pink surfaces).
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
        labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // Bottom sheets — rounded top with drag handle, like iOS Action Sheets
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        showDragHandle: true,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      // Dividers — hairline, very light. Matches iOS list separators.
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), thickness: 0.5, space: 0.5),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconColor: scheme.onSurfaceVariant,
      ),

      // Snack bars — floating with rounded corners (iOS-style toast shape)
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),

      // Tighter, eased page transitions — closer to iOS feel than Material's default fade-through
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),  // intentionally iOS-style on Android too
      }),

      splashFactory: NoSplash.splashFactory,  // iOS doesn't have ripple — drop it for parity
    );
  }

  /// TextTheme tuned to Apple's HIG sizes — Large Title 34/36, Title 1 28, Title 2 22, Headline 17, Body 17, Footnote 13.
  /// Mapped onto Material 3's slot names so existing widgets pick up the iOS-ish proportions.
  static TextTheme _buildTextTheme(ColorScheme s) {
    const f = _fontFamily;
    return TextTheme(
      displayLarge: const TextStyle(fontFamily: f, fontSize: 36, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displayMedium: const TextStyle(fontFamily: f, fontSize: 32, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      displaySmall: const TextStyle(fontFamily: f, fontSize: 28, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineLarge: const TextStyle(fontFamily: f, fontSize: 26, height: 1.2, fontWeight: FontWeight.w700),
      headlineMedium: const TextStyle(fontFamily: f, fontSize: 22, height: 1.25, fontWeight: FontWeight.w700),
      headlineSmall: const TextStyle(fontFamily: f, fontSize: 20, height: 1.3, fontWeight: FontWeight.w600),
      titleLarge: const TextStyle(fontFamily: f, fontSize: 17, height: 1.3, fontWeight: FontWeight.w600),
      titleMedium: const TextStyle(fontFamily: f, fontSize: 16, height: 1.35, fontWeight: FontWeight.w600),
      titleSmall: const TextStyle(fontFamily: f, fontSize: 14, height: 1.35, fontWeight: FontWeight.w600),
      bodyLarge: const TextStyle(fontFamily: f, fontSize: 17, height: 1.4, fontWeight: FontWeight.w400),
      bodyMedium: const TextStyle(fontFamily: f, fontSize: 15, height: 1.4, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontFamily: f, fontSize: 13, height: 1.4, fontWeight: FontWeight.w400, color: s.onSurfaceVariant),
      labelLarge: const TextStyle(fontFamily: f, fontSize: 14, height: 1.3, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontFamily: f, fontSize: 13, height: 1.3, fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
      labelSmall: TextStyle(fontFamily: f, fontSize: 11, height: 1.3, fontWeight: FontWeight.w500, color: s.onSurfaceVariant, letterSpacing: 0.2),
    );
  }
}
