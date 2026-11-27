import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../motion/motion.dart';
import '../../theme/sentry_colors.dart';
import '../../theme/sentry_theme.dart';
import '../sentry_interactive_logo.dart';
import '../status_pills.dart';

export '../status_pills.dart' show PillTone, StatusPill;

/// Shared SENTRY UI kit.
///
/// Design principles (applies to every screen):
/// 1. **One primary thing per card.** Lead with the answer (a number, a
///    status, a plate); push explanations into [InfoHint] tooltips or a
///    [showDetailsSheet] side panel.
/// 2. **Plain language first.** "Waiting at gate", not
///    `authorization_allowed`. Technical terms live in hints/details.
/// 3. **Never color alone.** Status always pairs color with an icon + word.
/// 4. **Big, calm targets.** 44px minimum hit area, visible focus ring.

// ---------------------------------------------------------------------------
// Tone helpers
// ---------------------------------------------------------------------------

class ToneColors {
  final Color fg;
  final Color bg;
  final Color solid;
  const ToneColors(this.fg, this.bg, this.solid);

  factory ToneColors.of(BuildContext context, PillTone tone) {
    final p = SentryPalette.of(context);
    switch (tone) {
      case PillTone.ok:
        return ToneColors(p.okText, p.okTint, p.ok);
      case PillTone.warn:
        return ToneColors(p.warnText, p.warnTint, p.warn);
      case PillTone.err:
        return ToneColors(p.errText, p.errTint, p.err);
      case PillTone.info:
        return ToneColors(p.info, p.infoTint, p.info);
      case PillTone.crimson:
        return ToneColors(p.crimsonHover, p.crimsonTint, p.crimson);
      case PillTone.neutral:
        return ToneColors(p.slate, p.subtle, p.muted);
    }
  }
}

// ---------------------------------------------------------------------------
// SentryCard — physical card with hover lift + keyboard focus ring
// ---------------------------------------------------------------------------

class SentryCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? color;
  final Color? accent;
  final double radius;
  final bool selected;

  const SentryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.onTap,
    this.semanticLabel,
    this.color,
    this.accent,
    this.radius = 20,
    this.selected = false,
  });

  @override
  State<SentryCard> createState() => _SentryCardState();
}

class _SentryCardState extends State<SentryCard> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final interactive = widget.onTap != null;
    final lifted = interactive && (_hover || _focus);
    final restingBorder =
        p.isDark ? const Color(0xFF1F1F26) : p.cardBorder;
    final borderColor = widget.selected
        ? p.crimson
        : _focus
            ? p.crimson
            : (widget.accent?.withValues(alpha: 0.55) ?? restingBorder);

    final card = AnimatedContainer(
      duration: SentryMotion.of(context, SentryMotion.short),
      curve: SentryMotion.emphasized,
      transform: Matrix4.translationValues(0, lifted ? -1.5 : 0, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? p.card,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: borderColor,
          width: widget.selected || _focus ? 1.5 : 1,
        ),
        boxShadow: lifted ? p.shadowRaised : p.shadowSoft,
      ),
      child: widget.child,
    );

    if (!interactive) {
      return Semantics(
        container: true,
        label: widget.semanticLabel,
        child: card,
      );
    }

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: card,
        ),
      ),
    );
  }
}

/// Lightweight frosted-glass surface for floating spatial overlays (search bar,
/// map layer pills, blueprint zoom/tab controls, and callouts).
///
/// Caps blur sigma at <= 10.0 so Windows desktop rendering remains smooth at 60fps.
class FrostedSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadows;

  const FrostedSurface({
    super.key,
    required this.child,
    this.radius = 16,
    this.blurSigma = 10.0,
    this.padding,
    this.color,
    this.borderColor,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final sigma = blurSigma.clamp(0.0, 10.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? p.card.withValues(alpha: p.isDark ? 0.80 : 0.84),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ??
                  p.line.withValues(alpha: p.isDark ? 0.85 : 0.95),
              width: 1,
            ),
            boxShadow: shadows ?? p.shadowSoft,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Headers
// ---------------------------------------------------------------------------

/// Page-level intro: big editorial title + one calm sentence + actions.
class PageIntro extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const PageIntro({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Reveal(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        runSpacing: 14,
        spacing: 24,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: SentryTheme.display(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: p.text,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: p.muted,
                          fontSize: 14.5,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty)
            Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
  }
}

/// Section header inside a card: title, optional hint and trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? hint;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.hint,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final titleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: SentryTheme.display(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(width: 6),
          InfoHint(hint!),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560 && trailing != null;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 10),
              trailing!,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  titleWidget,
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        );
      },
    );
  }
}

/// Small "?" that reveals a technical explanation on hover/focus.
/// Keeps the main UI plain-language while preserving the thesis detail.
class InfoHint extends StatelessWidget {
  final String message;
  final double size;
  const InfoHint(this.message, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Tooltip(
      message: message,
      preferBelow: false,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: 'More info: $message',
        child: Focus(
          child: Builder(builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: focused ? Border.all(color: p.crimson, width: 2) : null,
              ),
              child: Icon(Icons.help_outline_rounded,
                  size: size, color: p.muted),
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MetricTile — one big number, one short label
// ---------------------------------------------------------------------------

class MetricTile extends StatelessWidget {
  final String label;
  final int value;
  final String? valueDisplay;
  final String? suffix;
  final String? caption;
  final IconData icon;
  final PillTone tone;
  final VoidCallback? onTap;
  final String? hint;
  final int revealIndex;
  final Key? valueKey;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueDisplay,
    this.suffix,
    this.caption,
    this.tone = PillTone.neutral,
    this.onTap,
    this.hint,
    this.revealIndex = 0,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final t = ToneColors.of(context, tone);
    return Reveal(
      index: revealIndex,
      child: SentryCard(
        onTap: onTap,
        semanticLabel: '$label: $value${suffix ?? ''}. ${caption ?? ''}',
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: t.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 21, color: t.solid),
                ),
                const Spacer(),
                if (hint != null) InfoHint(hint!),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_outward_rounded, size: 18, color: p.muted),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (valueDisplay != null)
                  Text(
                    valueDisplay!,
                    key: valueKey,
                    style: SentryTheme.display(fontSize: 40, color: p.text),
                  )
                else
                  AnimatedCount(
                    key: valueKey,
                    value: value,
                    style: SentryTheme.display(fontSize: 40, color: p.text),
                  ),
                if (suffix != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      suffix!,
                      style: SentryTheme.display(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (Theme.of(context).textTheme.titleSmall ??
                            const TextStyle())
                        .copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(
                caption!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Capacity bar — animated stacked bar (free / occupied / held / unknown)
// ---------------------------------------------------------------------------

class CapacitySegment {
  final int count;
  final Color color;
  final String label;
  const CapacitySegment(this.count, this.color, this.label);
}

class CapacityBar extends StatelessWidget {
  final List<CapacitySegment> segments;
  final double height;
  const CapacityBar({super.key, required this.segments, this.height = 10});

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final total = segments.fold<int>(0, (a, s) => a + s.count);
    final label = segments.map((s) => '${s.count} ${s.label}').join(', ');
    return Semantics(
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: total == 0
              ? ColoredBox(color: p.subtle)
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: SentryMotion.of(context, SentryMotion.long),
                  curve: SentryMotion.emphasized,
                  builder: (context, t, _) => Row(
                    children: [
                      for (final s in segments)
                        if (s.count > 0)
                          Expanded(
                            flex: (s.count * 1000 * t).round().clamp(1, 1 << 30),
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              color: s.color,
                            ),
                          ),
                      Expanded(
                        flex: ((1 - t) * total * 1000).round().clamp(0, 1 << 30),
                        child: ColoredBox(color: p.subtle),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Colored dot + label legend item.
class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status dot with gentle pulse (live indicators)
// ---------------------------------------------------------------------------

class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool pulsing;
  const PulseDot({
    super.key,
    required this.color,
    this.size = 9,
    this.pulsing = true,
  });

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final shouldAnimate = widget.pulsing && !SentryMotion.reduced(context);
    if (shouldAnimate && !_c.isAnimating) {
      _c.repeat();
    } else if (!shouldAnimate && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = SentryMotion.emphasized.transform(_c.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulsing)
                Container(
                  width: s + s * 1.4 * t,
                  height: s + s * 1.4 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                  ),
                ),
              Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Segmented tabs with sliding indicator
// ---------------------------------------------------------------------------

class SegmentTabs extends StatelessWidget {
  final List<String> labels;
  final List<IconData>? icons;
  final int selected;
  final ValueChanged<int> onChanged;

  /// Each tab gets `Key('${keyPrefix}_$index')` (used by widget tests).
  final String? keyPrefix;

  const SegmentTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.icons,
    this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.subtle,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: p.line, width: 1),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var i = 0; i < labels.length; i++)
            _SegmentButton(
              key: keyPrefix == null ? null : Key('${keyPrefix}_$i'),
              label: labels[i],
              icon: icons != null && i < icons!.length ? icons![i] : null,
              selected: i == selected,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final activeBg = p.isDark ? const Color(0xFF26262E) : Colors.white;
    final fg = selected ? p.text : p.muted;
    final iconColor = selected ? SentryColors.crimson : p.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: SentryMotion.of(context, SentryMotion.short),
            curve: SentryMotion.emphasized,
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: -1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 7),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Key / value row, empty state, callouts
// ---------------------------------------------------------------------------

class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final Widget? trailing;
  final Key? valueKey;

  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.trailing,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: SelectableText(
              value,
              key: valueKey,
              style: mono
                  ? SentryTheme.mono(fontSize: 13.5, color: p.text)
                  : Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: p.text, fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool showBrandLogo;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.showBrandLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Reveal(
      scale: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBrandLogo)
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SentryColors.crimson.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const SentryInteractiveLogo(size: 46),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: p.subtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: p.muted),
              ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SentryTheme.display(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Tinted inline message (success / warning / error / info).
class Callout extends StatelessWidget {
  final PillTone tone;
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const Callout({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = ToneColors.of(context, tone);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.solid.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: t.solid),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: t.fg,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      message!,
                      style: TextStyle(fontSize: 13.5, color: t.fg, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 12), action!],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Details side sheet (progressive disclosure)
// ---------------------------------------------------------------------------

/// Slides a details panel in from the right. Use it for everything that is
/// "nice to know" (IDs, raw scores, timestamps, audit trail) so the main
/// screen stays calm. Closes with Esc or clicking the scrim.
Future<T?> showDetailsSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
  List<Widget> Function(BuildContext)? actionsBuilder,
  double width = 520,
  bool frosted = false,
}) {
  final reduced = SentryMotion.reduced(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close details',
    barrierColor: Colors.black.withValues(alpha: frosted ? 0.28 : 0.32),
    transitionDuration: reduced
        ? Duration.zero
        : Duration(milliseconds: frosted ? 220 : 380),
    pageBuilder: (ctx, _, __) {
      final p = SentryPalette.of(ctx);
      final screenW = MediaQuery.sizeOf(ctx).width;
      final sheetW = (screenW - 28).clamp(280.0, width);
      final sheetBody = Material(
        color: frosted
            ? p.card.withValues(alpha: p.isDark ? 0.88 : 0.92)
            : p.card,
        elevation: 0,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: sheetW,
          height: double.infinity,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  Navigator.of(ctx).maybePop(),
            },
            child: FocusScope(
              autofocus: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(26, 22, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  style: SentryTheme.display(
                                    fontSize: 24,
                                    color: p.text,
                                  ),
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: Theme.of(ctx).textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close (Esc)',
                          onPressed: () => Navigator.of(ctx).maybePop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: p.line, height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(26, 18, 26, 26),
                      child: builder(ctx),
                    ),
                  ),
                  if (actionsBuilder != null) ...[
                    Divider(color: p.line, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 10,
                        children: actionsBuilder(ctx),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

      final panel = frosted
          ? ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: p.line, width: 1),
                    boxShadow: p.shadowRaised,
                  ),
                  child: sheetBody,
                ),
              ),
            )
          : sheetBody;

      return SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: panel,
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: frosted ? Curves.easeOutCubic : SentryMotion.emphasized,
        reverseCurve: SentryMotion.exit,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: SentryMotion.standard),
        child: SlideTransition(
          position: Tween(begin: const Offset(0.12, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Shows a lightweight, accessible toast message.
void showSentryToast(BuildContext context, String message,
    {PillTone tone = PillTone.ok}) {
  final t = ToneColors.of(context, tone);
  final icon = switch (tone) {
    PillTone.ok => Icons.check_circle_rounded,
    PillTone.warn => Icons.warning_amber_rounded,
    PillTone.err => Icons.error_outline_rounded,
    _ => Icons.info_outline_rounded,
  };
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: t.solid, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Standard content padding + max width wrapper for every screen.
class ScreenScaffold extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  const ScreenScaffold({
    super.key,
    required this.children,
    this.maxWidth = 1480,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 640;
    final padding = compact
        ? const EdgeInsets.fromLTRB(16, 18, 16, 32)
        : (w < 1320
            ? const EdgeInsets.fromLTRB(24, 24, 24, 40)
            : const EdgeInsets.fromLTRB(36, 30, 36, 48));
    return Scrollbar(
      child: SingleChildScrollView(
        padding: padding,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Clean initials avatar circle for member, guest, and guard rows.
class MonogramAvatar extends StatelessWidget {
  final String name;
  final bool highlight;
  final double size;

  const MonogramAvatar({
    super.key,
    required this.name,
    this.highlight = false,
    this.size = 36,
  });

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight ? p.crimsonTint : p.subtle,
        shape: BoxShape.circle,
        border: Border.all(
          color: highlight
              ? SentryColors.crimson.withValues(alpha: 0.25)
              : p.line,
        ),
      ),
      child: Text(
        _initials,
        style: SentryTheme.display(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: highlight ? SentryColors.crimson : p.text,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Calm, hover-responsive desktop list row (2-3 data points max; technical
/// metadata opens via [onTap] in a frosted details drawer).
class SentryRowTile extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const SentryRowTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.actions = const [],
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
  });

  @override
  State<SentryRowTile> createState() => _SentryRowTileState();
}

class _SentryRowTileState extends State<SentryRowTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final trailingWidgets = <Widget>[
      ...widget.badges,
      ...widget.actions,
      if (widget.onTap != null)
        Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: _hover ? p.text : p.muted,
        ),
    ];

    final rowContent = AnimatedContainer(
      duration: SentryMotion.of(context, SentryMotion.short),
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _hover && widget.onTap != null
            ? p.subtle.withValues(alpha: 0.65)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow =
              constraints.maxWidth < 600 && trailingWidgets.isNotEmpty;
          final mainRow = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                    ),
                    if (widget.subtitle != null &&
                        widget.subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: p.muted,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isNarrow && trailingWidgets.isNotEmpty) ...[
                const SizedBox(width: 14),
                Flexible(
                  fit: FlexFit.loose,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: trailingWidgets,
                  ),
                ),
              ],
            ],
          );

          if (!isNarrow) return mainRow;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              mainRow,
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: trailingWidgets,
              ),
            ],
          );
        },
      ),
    );

    if (widget.onTap == null) return rowContent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: rowContent,
      ),
    );
  }
}

/// Calm RBAC callout panel shown whenever a restricted view is opened by
/// a non-Administrator account (never exposes admin controls).
class RoleRestrictedPanel extends StatelessWidget {
  final String featureName;
  final String minimumRole;

  const RoleRestrictedPanel({
    super.key,
    required this.featureName,
    this.minimumRole = 'administrator',
  });

  @override
  Widget build(BuildContext context) {
    return SentryCard(
      padding: const EdgeInsets.all(24),
      child: EmptyState(
        showBrandLogo: true,
        icon: Icons.admin_panel_settings_outlined,
        title: 'Administrator access required',
        message:
            '$featureName requires "$minimumRole" privileges. Your account remains scoped to operational guard duties.',
      ),
    );
  }
}
