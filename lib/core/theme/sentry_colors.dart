import 'package:flutter/material.dart';

/// Exact SENTRY Design System color tokens extracted from Team 5's mockup (`style.css`).
/// Supports both Light Mode and Pure OLED Dark Command Center Mode.
class SentryColors {
  SentryColors._();

  // Primary BatStateU Crimson Brand Tokens
  static const Color crimson = Color(0xFFC8102E);
  static const Color crimsonHover = Color(0xFFB91C1C);
  static const Color crimsonDeep = Color(0xFF991B1B);
  static const Color crimsonDarkAccent = Color(0xFFF87171);
  static const Color crimsonSoftLight = Color(0xFFFEF2F2);
  static const Color crimsonPinkBadge = Color(0xFFFBE4E6);
  static const Color crimsonSoftDark = Color(0xFF2A0E14);

  // Light Mode Surfaces & Ink
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightStageBg = Color(0xFFEAE6E7);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSubtle = Color(0xFFF1F5F9);
  static const Color lightLotGround = Color(0xFFE3E9F1);
  static const Color lightLine = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightSlate = Color(0xFF475569);
  static const Color lightMuted = Color(0xFF64748B);

  // Dark Mode (OLED Command Center) Surfaces & Ink
  static const Color darkBg = Color(0xFF000000);
  static const Color darkCard = Color(0xFF121215);
  static const Color darkSubtle = Color(0xFF18181C);
  static const Color darkLotGround = Color(0xFF0A0A0D);
  static const Color darkLine = Color(0xFF24242A);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkSlate = Color(0xFFCBD5E1);
  static const Color darkMuted = Color(0xFF94A3B8);

  // Semantic Status: Available / Allowed / Online (OK)
  static const Color okLight = Color(0xFF059669);
  static const Color okTextLight = Color(0xFF065F46);
  static const Color okTintLight = Color(0xFFD1FAE5);
  static const Color okDark = Color(0xFF10B981);
  static const Color okTextDark = Color(0xFF34D399);
  static const Color okTintDark = Color(0x3810B981);

  // Semantic Status: Held / Review Required / Degraded (Warning)
  static const Color warnLight = Color(0xFFD97706);
  static const Color warnTextLight = Color(0xFF92400E);
  static const Color warnTintLight = Color(0xFFFEF3C7);
  static const Color warnDark = Color(0xFFF59E0B);
  static const Color warnTextDark = Color(0xFFFCD34D);
  static const Color warnTintDark = Color(0x38F59E0B);

  // Semantic Status: Denied / Conflict / Offline (Error)
  static const Color errLight = Color(0xFFC8102E);
  static const Color errTextLight = Color(0xFFB91C1C);
  static const Color errTintLight = Color(0xFFFEF2F2);
  static const Color errDark = Color(0xFFEF4444);
  static const Color errTextDark = Color(0xFFF87171);
  static const Color errTintDark = Color(0x29EF4444);

  // Semantic Status: Telemetry / Info
  static const Color infoLight = Color(0xFF0284C7);
  static const Color infoTintLight = Color(0xFFF0F9FF);
  static const Color infoDark = Color(0xFF38BDF8);
  static const Color infoTintDark = Color(0x2438BDF8);
}

/// Theme-aware palette helper so widgets can resolve Light vs. OLED Dark tokens cleanly.
class SentryPalette {
  final bool isDark;

  const SentryPalette({required this.isDark});

  factory SentryPalette.of(BuildContext context) {
    return SentryPalette(
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  Color get crimson => SentryColors.crimson;
  Color get crimsonHover =>
      isDark ? SentryColors.crimsonDarkAccent : SentryColors.crimsonHover;
  Color get crimsonTint =>
      isDark ? SentryColors.crimsonSoftDark : SentryColors.crimsonSoftLight;
  Color get bg => isDark ? SentryColors.darkBg : SentryColors.lightBg;
  Color get card => isDark ? SentryColors.darkCard : SentryColors.lightCard;
  Color get subtle =>
      isDark ? SentryColors.darkSubtle : SentryColors.lightSubtle;
  Color get lotGround =>
      isDark ? SentryColors.darkLotGround : SentryColors.lightLotGround;
  Color get line => isDark ? SentryColors.darkLine : SentryColors.lightLine;
  Color get text => isDark ? SentryColors.darkText : SentryColors.lightText;
  Color get slate => isDark ? SentryColors.darkSlate : SentryColors.lightSlate;
  Color get muted => isDark ? SentryColors.darkMuted : SentryColors.lightMuted;

  Color get ok => isDark ? SentryColors.okDark : SentryColors.okLight;
  Color get okText =>
      isDark ? SentryColors.okTextDark : SentryColors.okTextLight;
  Color get okTint =>
      isDark ? SentryColors.okTintDark : SentryColors.okTintLight;

  Color get warn => isDark ? SentryColors.warnDark : SentryColors.warnLight;
  Color get warnText =>
      isDark ? SentryColors.warnTextDark : SentryColors.warnTextLight;
  Color get warnTint =>
      isDark ? SentryColors.warnTintDark : SentryColors.warnTintLight;

  Color get err => isDark ? SentryColors.errDark : SentryColors.errLight;
  Color get errText =>
      isDark ? SentryColors.errTextDark : SentryColors.errTextLight;
  Color get errTint =>
      isDark ? SentryColors.errTintDark : SentryColors.errTintLight;

  Color get info => isDark ? SentryColors.infoDark : SentryColors.infoLight;
  Color get infoTint =>
      isDark ? SentryColors.infoTintDark : SentryColors.infoTintLight;

  /// Soft resting card shadow (mockup: `0 16px 36px -16px rgba(15,23,42,.28)`).
  List<BoxShadow> get shadowSoft => isDark
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -8,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 30,
            offset: Offset(0, 14),
            spreadRadius: -14,
          ),
        ];

  /// Raised shadow for hovered / focused cards.
  List<BoxShadow> get shadowRaised => isDark
      ? const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 36,
            offset: Offset(0, 16),
            spreadRadius: -10,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x330F172A),
            blurRadius: 40,
            offset: Offset(0, 20),
            spreadRadius: -16,
          ),
        ];

  /// Card border: mockup removes borders in dark mode and relies on depth.
  Color get cardBorder => isDark ? const Color(0x00000000) : line;
}
