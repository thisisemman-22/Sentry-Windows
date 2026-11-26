import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';

/// Floating frosted panel used across the spatial Overview.
///
/// Mirrors the reference's tinted-glass surfaces: dark smoked glass in OLED
/// mode, milky glass in light mode, a soft long shadow and a hairline edge.
/// Blur is capped at sigma 10 to keep Windows rendering at 60fps.
class SpatialGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool strong;

  const SpatialGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final fill = p.isDark
        ? const Color(0xFF0C0D10).withValues(alpha: strong ? 0.90 : 0.78)
        : Colors.white.withValues(alpha: strong ? 0.94 : 0.84);
    final edge = p.isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFF0F172A).withValues(alpha: 0.07);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: p.isDark
                ? Colors.black.withValues(alpha: 0.55)
                : const Color(0xFF0F172A).withValues(alpha: 0.14),
            blurRadius: 34,
            offset: const Offset(0, 16),
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: edge),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Inner tile inside a [SpatialGlass] panel (the reference's nested cards).
class GlassTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double? height;

  const GlassTile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.onTap,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverTile(onTap: onTap, height: height, padding: padding, child: child);
  }
}

class _HoverTile extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double? height;
  const _HoverTile({
    required this.child,
    required this.padding,
    required this.onTap,
    required this.height,
  });

  @override
  State<_HoverTile> createState() => _HoverTileState();
}

class _HoverTileState extends State<_HoverTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final interactive = widget.onTap != null;
    final base = p.isDark
        ? Colors.white.withValues(alpha: _hover ? 0.065 : 0.04)
        : (_hover ? Colors.white : const Color(0xFFF7F9FB));
    final edge = p.isDark
        ? Colors.white.withValues(alpha: _hover ? 0.12 : 0.06)
        : (_hover
            ? SentryColors.crimson.withValues(alpha: 0.25)
            : const Color(0xFF0F172A).withValues(alpha: 0.06));
    final tile = AnimatedContainer(
      duration: SentryMotion.of(context, const Duration(milliseconds: 180)),
      curve: Curves.easeOutCubic,
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: edge),
      ),
      child: widget.child,
    );
    if (!interactive) return tile;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: tile,
      ),
    );
  }
}

enum SoftChipTone { crimson, ok, warn, neutral }

/// Small rounded status chip ("On target", "Rising" in the reference).
class SoftChip extends StatelessWidget {
  final String label;
  final SoftChipTone tone;
  final IconData? icon;

  const SoftChip(this.label, {super.key, this.tone = SoftChipTone.crimson, this.icon});

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final (Color bg, Color fg) = switch (tone) {
      SoftChipTone.crimson => (
          SentryColors.crimson.withValues(alpha: p.isDark ? 0.22 : 0.10),
          p.isDark ? const Color(0xFFFF8A9A) : SentryColors.crimson,
        ),
      SoftChipTone.ok => (p.okTint, p.okText),
      SoftChipTone.warn => (p.warnTint, p.warnText),
      SoftChipTone.neutral => (
          p.isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFF0F172A).withValues(alpha: 0.05),
          p.slate,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: SentryTheme.sansFontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Square glass icon button (the reference's "↗" affordance).
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFF0F172A).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 18, color: p.text),
          ),
        ),
      ),
    );
  }
}

/// Large figure + small unit ("24.1 °Bx" in the reference).
class BigFigure extends StatelessWidget {
  final Widget value;
  final String? unit;
  const BigFigure({super.key, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          value,
          if (unit != null) ...[
            const SizedBox(width: 5),
            Text(
              unit!,
              style: TextStyle(
                fontFamily: SentryTheme.sansFontFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: p.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

TextStyle bigFigureStyle(SentryPalette p, {double size = 32, Color? color}) =>
    SentryTheme.display(
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color ?? p.text,
      letterSpacing: -0.04 * size,
      height: 1.0,
    );

TextStyle panelTitleStyle(SentryPalette p, {double size = 20}) =>
    SentryTheme.display(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: p.text,
      letterSpacing: -0.02 * size,
    );

TextStyle tileLabelStyle(SentryPalette p) => TextStyle(
      fontFamily: SentryTheme.sansFontFamily,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: p.slate,
      height: 1.2,
    );
