import 'package:flutter/material.dart';
import 'sentry_colors.dart';

/// SENTRY typography, shape and component theme (Light + Pure OLED Dark).
///
/// Typography (all bundled, SIL OFL):
/// - **Schibsted Grotesk** — editorial display face for page titles, section
///   headers and large figures. Gives SENTRY a confident, newspaper-like voice.
/// - **Atkinson Hyperlegible Next** — body/UI face designed by the Braille
///   Institute for low-vision readers. Distinct letterforms reduce misreads
///   on a busy guardhouse screen.
/// - **Atkinson Hyperlegible Mono** — plates, codes, timers and similarity
///   scores. `0/O`, `1/I/l`, `5/S`, `8/B` are unmistakable — critical for plates.
///
/// Rules kept from the design reference: no italics anywhere, tabular figures
/// for numbers, rounded physical cards, pill badges and `#C8102E` focus rings.
class SentryTheme {
  SentryTheme._();

  static const String displayFontFamily = 'SchibstedGrotesk';
  static const String sansFontFamily = 'AtkinsonHyperlegibleNext';
  static const String monoFontFamily = 'AtkinsonHyperlegibleMono';

  /// Monospace style for plates, codes, timers and scores.
  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0.2,
  }) {
    return TextStyle(
      fontFamily: monoFontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: FontStyle.normal,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Display style (Schibsted Grotesk) for headings and hero numbers.
  static TextStyle display({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: displayFontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: FontStyle.normal,
      letterSpacing: letterSpacing ?? -0.02 * fontSize,
      height: height ?? 1.1,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Small uppercase eyebrow label used above section titles.
  static TextStyle eyebrow({Color? color}) {
    return TextStyle(
      fontFamily: sansFontFamily,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
      height: 1.2,
      color: color,
      fontStyle: FontStyle.normal,
    );
  }

  static ThemeData light() => _buildTheme(Brightness.light);
  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final p = SentryPalette(isDark: isDark);

    TextStyle d(double size, FontWeight w, Color c) =>
        display(fontSize: size, fontWeight: w, color: c);

    TextStyle s(double size, FontWeight w, Color c, {double height = 1.45}) =>
        TextStyle(
          fontFamily: sansFontFamily,
          fontSize: size,
          fontWeight: w,
          color: c,
          height: height,
          fontStyle: FontStyle.normal,
        );

    final textTheme = TextTheme(
      displayLarge: d(44, FontWeight.w800, p.text),
      displayMedium: d(34, FontWeight.w800, p.text),
      displaySmall: d(28, FontWeight.w800, p.text),
      headlineLarge: d(26, FontWeight.w800, p.text),
      headlineMedium: d(22, FontWeight.w700, p.text),
      headlineSmall: d(19, FontWeight.w700, p.text),
      titleLarge: d(17, FontWeight.w700, p.text),
      titleMedium: s(15, FontWeight.w700, p.text, height: 1.3),
      titleSmall: s(14, FontWeight.w700, p.text, height: 1.3),
      bodyLarge: s(15.5, FontWeight.w400, p.text),
      bodyMedium: s(14.5, FontWeight.w400, p.slate),
      bodySmall: s(13, FontWeight.w400, p.muted),
      labelLarge: s(14, FontWeight.w700, p.text, height: 1.2),
      labelMedium: s(13, FontWeight.w600, p.slate, height: 1.2),
      labelSmall: s(12, FontWeight.w600, p.muted, height: 1.2),
    );

    final focusRing = BorderSide(color: p.crimson, width: 2);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: sansFontFamily,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.card,
      cardColor: p.card,
      dividerColor: p.line,
      focusColor: p.crimson.withValues(alpha: 0.12),
      hoverColor: p.text.withValues(alpha: 0.04),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: SentryColors.crimson,
        onPrimary: Colors.white,
        secondary: p.text,
        onSecondary: p.card,
        error: p.err,
        onError: Colors.white,
        surface: p.card,
        onSurface: p.text,
        surfaceContainerHighest: p.subtle,
        outline: p.line,
      ),
      textTheme: textTheme,
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.line, width: 1),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: s(13, FontWeight.w500, isDark ? p.bg : Colors.white,
            height: 1.35),
        decoration: BoxDecoration(
          color: isDark ? Colors.white : SentryColors.lightText,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.subtle,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: s(14.5, FontWeight.w400, p.muted),
        labelStyle: s(14, FontWeight.w600, p.slate),
        floatingLabelStyle: s(14, FontWeight.w700, p.crimson),
        helperStyle: s(12.5, FontWeight.w400, p.muted),
        errorStyle: s(12.5, FontWeight.w600, p.errText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: focusRing,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.err, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.err, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SentryColors.crimson,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: s(14, FontWeight.w700, Colors.white, height: 1.1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SentryColors.crimson,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: s(14, FontWeight.w700, Colors.white, height: 1.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(44, 46),
          side: BorderSide(color: p.line, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: s(14, FontWeight.w700, p.text, height: 1.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.crimsonHover,
          minimumSize: const Size(44, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: const StadiumBorder(),
          textStyle: s(14, FontWeight.w700, p.crimsonHover, height: 1.1),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: p.slate,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
              s(13.5, FontWeight.w700, p.text, height: 1.1)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.subtle,
        selectedColor: p.text,
        side: BorderSide(color: p.line),
        shape: const StadiumBorder(),
        labelStyle: s(13, FontWeight.w600, p.text, height: 1.1),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? p.subtle : SentryColors.lightText,
        contentTextStyle: s(14, FontWeight.w500, Colors.white),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        width: 520,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: d(22, FontWeight.w800, p.text),
        contentTextStyle: s(14.5, FontWeight.w400, p.slate),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(false),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
        thumbColor: WidgetStatePropertyAll(p.muted.withValues(alpha: 0.35)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
