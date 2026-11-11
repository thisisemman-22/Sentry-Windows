import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Window-wide pointer position. Written once by the app root and read
/// directly by every logo instance, so cursor movement never forces the
/// surrounding widget tree to rebuild.
class SentryPointer {
  SentryPointer._();
  static final ValueNotifier<Offset?> position = ValueNotifier<Offset?>(null);
}

/// SENTRY Interactive Shield Logo ported 1:1 from James Villaflor's `app.js`
/// (`emb()` and `initSentryLogoTracker()`).
///
/// Features:
/// - Exact 100x100 SVG coordinate geometry (Shield + Car Cabin/Body/Wheels + Headlight "Eyes")
/// - Smooth cursor-tracking eyes using `tanh(dist / reach)` falloff and `0.18` frame interpolation
/// - Perspective rim-narrowing (`w = 7.5 * (1 - 0.25 * toRim)`) as eyes look toward the shield edge
/// - Natural random blinking (`160ms` sine-wave lid closure every `2.6s - 5.8s`)
class SentryInteractiveLogo extends StatefulWidget {
  final double size;
  final Color shieldColor;
  final Color carBodyColor;
  final Color eyeColor;
  final bool enableTracking;
  final Offset? globalPointerPosition;

  const SentryInteractiveLogo({
    super.key,
    this.size = 40.0,
    this.shieldColor = const Color(0xFFC8102E),
    this.carBodyColor = const Color(0xFFFFFFFF),
    this.eyeColor = const Color(0xFF14151A),
    this.enableTracking = true,
    this.globalPointerPosition,
  });

  /// Inverted variant for Crimson Hero headers (White shield, Crimson car).
  const SentryInteractiveLogo.inverted({
    super.key,
    this.size = 120.0,
    this.shieldColor = const Color(0xFFFFFFFF),
    this.carBodyColor = const Color(0xFFC8102E),
    this.eyeColor = const Color(0xFF14151A),
    this.enableTracking = true,
    this.globalPointerPosition,
  });

  @override
  State<SentryInteractiveLogo> createState() => _SentryInteractiveLogoState();
}

class _SentryInteractiveLogoState extends State<SentryInteractiveLogo>
    with SingleTickerProviderStateMixin {
  static const double _maxX = 3.0;
  static const double _maxY = 2.5;

  late final Ticker _ticker;
  final math.Random _rng = math.Random();
  Timer? _blinkTimer;

  Offset _pos = Offset.zero;
  Offset _target = Offset.zero;
  int _blinkStartMs = -1000;
  int _nowMs = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.enableTracking) {
      _ticker.start();
      _scheduleNextBlink();
      SentryPointer.position.addListener(_onGlobalPointer);
    }
  }

  void _onGlobalPointer() {
    if (widget.globalPointerPosition == null) {
      _updateTargetFromPointer(SentryPointer.position.value);
    }
  }

  @override
  void didUpdateWidget(covariant SentryInteractiveLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.globalPointerPosition != oldWidget.globalPointerPosition &&
        widget.enableTracking) {
      _updateTargetFromPointer(widget.globalPointerPosition);
    }
  }

  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    final delayMs = 2600 + _rng.nextInt(3200);
    _blinkTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _blinkStartMs = DateTime.now().millisecondsSinceEpoch;
      _scheduleNextBlink();
    });
  }

  void _updateTargetFromPointer(Offset? globalPointer) {
    if (globalPointer == null || !mounted) {
      _target = Offset.zero;
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final dx = globalPointer.dx - center.dx;
    final dy = globalPointer.dy - center.dy;
    final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
    final reach = math.max(120.0, widget.size * 1.5);
    final f = _tanh(d / reach);
    _target = Offset((dx / d) * f * _maxX, (dy / d) * f * _maxY);
  }

  double _tanh(double x) {
    if (x > 20) return 1.0;
    if (x < -20) return -1.0;
    final e2x = math.exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
  }

  void _onTick(Duration elapsed) {
    _nowMs = DateTime.now().millisecondsSinceEpoch;
    final nextX = _pos.dx + (_target.dx - _pos.dx) * 0.18;
    final nextY = _pos.dy + (_target.dy - _pos.dy) * 0.18;
    final sinceBlink = _nowMs - _blinkStartMs;
    final isBlinking = sinceBlink >= 0 && sinceBlink <= 180;
    final isMoving = (_target - _pos).distance > 0.01;
    if (isMoving || isBlinking) {
      setState(() {
        _pos = Offset(nextX, nextY);
      });
    }
  }

  @override
  void dispose() {
    SentryPointer.position.removeListener(_onGlobalPointer);
    _blinkTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sinceBlink = _nowMs - _blinkStartMs;
    final double lid = (sinceBlink >= 0 && sinceBlink < 160)
        ? 1.0 - 0.9 * math.sin((sinceBlink / 160.0) * math.pi)
        : 1.0;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _SentryLogoPainter(
          shieldColor: widget.shieldColor,
          carBodyColor: widget.carBodyColor,
          eyeColor: widget.eyeColor,
          eyeOffset: _pos,
          lidFactor: lid,
        ),
      ),
    );
  }
}

class _SentryLogoPainter extends CustomPainter {
  final Color shieldColor;
  final Color carBodyColor;
  final Color eyeColor;
  final Offset eyeOffset;
  final double lidFactor;

  const _SentryLogoPainter({
    required this.shieldColor,
    required this.carBodyColor,
    required this.eyeColor,
    required this.eyeOffset,
    required this.lidFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100.0, size.height / 100.0);

    // 1. Shield Path: M50 4 L84 15 V47 Q84 73 50 92 Q16 73 16 47 V15 Z
    final shieldPath = Path()
      ..moveTo(50, 4)
      ..lineTo(84, 15)
      ..lineTo(84, 47)
      ..quadraticBezierTo(84, 73, 50, 92)
      ..quadraticBezierTo(16, 73, 16, 47)
      ..lineTo(16, 15)
      ..close();
    canvas.drawPath(shieldPath, Paint()..color = shieldColor);

    final bodyPaint = Paint()..color = carBodyColor;

    // 2. Car Cabin: M35 41 L41 29 H59 L65 41 Z
    final cabinPath = Path()
      ..moveTo(35, 41)
      ..lineTo(41, 29)
      ..lineTo(59, 29)
      ..lineTo(65, 41)
      ..close();
    canvas.drawPath(cabinPath, bodyPaint);

    // 3. Car Main Body & Wheels
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(29, 41, 42, 19), const Radius.circular(6)),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(33, 60, 9, 6), const Radius.circular(2.5)),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(58, 60, 9, 6), const Radius.circular(2.5)),
      bodyPaint,
    );

    // 4. Headlight Eyes (Left: cx=38.5, cy=50.5, tilt=+8 deg; Right: cx=61.5, cy=50.5, tilt=-8 deg)
    _drawEye(canvas, cx: 38.5, cy: 50.5, tiltDeg: 8.0, side: -1.0);
    _drawEye(canvas, cx: 61.5, cy: 50.5, tiltDeg: -8.0, side: 1.0);

    canvas.restore();
  }

  void _drawEye(
    Canvas canvas, {
    required double cx,
    required double cy,
    required double tiltDeg,
    required double side,
  }) {
    const double baseW = 7.5;
    const double baseH = 12.0;
    const double maxX = 3.0;

    final toRim = math.max(0.0, (eyeOffset.dx * side) / maxX);
    final w = baseW * (1.0 - 0.25 * toRim);
    final h = baseH * lidFactor;
    final rx = math.min(3.75, math.min(w / 2.0, h / 2.0));

    canvas.save();
    canvas.translate(eyeOffset.dx, eyeOffset.dy);
    canvas.translate(cx, cy);
    canvas.rotate(tiltDeg * math.pi / 180.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        Radius.circular(rx),
      ),
      Paint()..color = eyeColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SentryLogoPainter oldDelegate) {
    return oldDelegate.eyeOffset != eyeOffset ||
        oldDelegate.lidFactor != lidFactor ||
        oldDelegate.shieldColor != shieldColor ||
        oldDelegate.carBodyColor != carBodyColor;
  }
}
