import 'dart:math' as math;
import 'package:flutter/material.dart';

/// SENTRY motion language.
///
/// The mockup's signature curve is `cubic-bezier(0.16, 1, 0.3, 1)` — a fast
/// start with a long, soft landing. Every transition in the app uses it so
/// motion feels like one family. All helpers respect the OS "reduce motion"
/// setting (`MediaQuery.disableAnimations`) and collapse to instant changes.
class SentryMotion {
  SentryMotion._();

  /// `cubic-bezier(0.16, 1, 0.3, 1)` from `style.css`.
  static const Curve emphasized = Cubic(0.16, 1, 0.3, 1);
  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve exit = Cubic(0.3, 0, 1, 1);

  static const Duration micro = Duration(milliseconds: 140);
  static const Duration short = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 380);
  static const Duration long = Duration(milliseconds: 620);

  /// Delay between consecutive items in a staggered reveal.
  static const Duration stagger = Duration(milliseconds: 55);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Progressive entrance: content fades in and rises smoothly using a frame-synced
/// [AnimationController] with a staggered [Interval] (no `Timer` leaks).
///
/// Use [index] for staggering siblings: `Reveal(index: i, child: ...)`.
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration? delay;
  final double offsetY;
  final bool scale;

  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.delay,
    this.offsetY = 14,
    this.scale = false,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    final delayMs =
        (widget.delay ?? (SentryMotion.stagger * widget.index)).inMilliseconds;
    final moveMs = SentryMotion.long.inMilliseconds;
    final totalMs = math.max(1, delayMs + moveMs);
    final startFraction = (delayMs / totalMs).clamp(0.0, 0.85);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(startFraction, 1.0, curve: SentryMotion.standard),
    );
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(startFraction, 1.0, curve: SentryMotion.emphasized),
      ),
    );
    _scale = Tween<double>(
      begin: widget.scale ? 0.97 : 1.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(startFraction, 1.0, curve: SentryMotion.emphasized),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SentryMotion.reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: _slide.value,
            child: widget.scale
                ? Transform.scale(scale: _scale.value, child: child)
                : child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Animated integer that counts up/down smoothly when its value changes.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String suffix;
  final String prefix;

  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: SentryMotion.of(context, SentryMotion.long),
      curve: SentryMotion.emphasized,
      builder: (context, v, _) => Text(
        '$prefix${v.round()}$suffix',
        style: style,
        semanticsLabel: '$prefix$value$suffix',
      ),
    );
  }
}

/// Cross-fades + slides between children keyed by [switchKey].
/// Use for detail panes and swapping content in place.
class SmoothSwitcher extends StatelessWidget {
  final Object switchKey;
  final Widget child;
  final Axis axis;

  const SmoothSwitcher({
    super.key,
    required this.switchKey,
    required this.child,
    this.axis = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: SentryMotion.of(context, SentryMotion.medium),
      switchInCurve: SentryMotion.emphasized,
      switchOutCurve: SentryMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, anim) {
        final offset = axis == Axis.vertical
            ? Tween(begin: const Offset(0, 0.02), end: Offset.zero)
            : Tween(begin: const Offset(0.02, 0), end: Offset.zero);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset.animate(anim), child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(switchKey), child: child),
    );
  }
}
