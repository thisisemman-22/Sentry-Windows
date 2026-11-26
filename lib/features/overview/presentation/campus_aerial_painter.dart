import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Normalized geometry of the stylized BatStateU Alangilan campus board.
///
/// All lot / building rectangles live inside [play] (the region of the map
/// not covered by floating panels). Roads, ground and tree canopy extend to
/// the full canvas so the map still reads as a continuous aerial view under
/// the frosted panels — exactly like the reference's full-bleed imagery.
class CampusMapLayout {
  final Size size;
  final Rect play;

  const CampusMapLayout({required this.size, required this.play});

  Rect _n(double x, double y, double w, double h) => Rect.fromLTWH(
        play.left + x * play.width,
        play.top + y * play.height,
        w * play.width,
        h * play.height,
      );

  Map<String, Rect> get lots => {
        'B1': _n(0.03, 0.05, 0.17, 0.41),
        'B3': _n(0.47, 0.05, 0.17, 0.41),
        'B2': _n(0.79, 0.27, 0.20, 0.23),
        'B4': _n(0.22, 0.65, 0.15, 0.31),
        'B5': _n(0.56, 0.65, 0.22, 0.29),
      };

  List<(String, Rect)> get buildings => [
        ('CEAFA', _n(0.225, 0.08, 0.215, 0.33)),
        ('GYM · STEER HUB', _n(0.79, 0.03, 0.20, 0.19)),
        ('CET', _n(0.02, 0.66, 0.17, 0.25)),
        ('REGISTRAR', _n(0.82, 0.68, 0.17, 0.20)),
      ];

  double get roadWidth => (play.height * 0.05).clamp(16.0, 30.0);

  /// Main east–west road (full canvas width).
  Rect get mainRoad => Rect.fromCenter(
        center: Offset(size.width / 2, play.top + play.height * 0.565),
        width: size.width + 40,
        height: roadWidth,
      );

  /// North–south service road between B3 and the Gym.
  Rect get serviceRoad {
    final x = play.left + play.width * 0.735;
    return Rect.fromLTRB(x - roadWidth / 2, -20, x + roadWidth / 2, mainRoad.center.dy);
  }

  /// Gate road from the main road down to the main gate.
  Rect get gateRoad {
    final x = play.left + play.width * 0.45;
    return Rect.fromLTRB(
        x - roadWidth / 2, mainRoad.center.dy, x + roadWidth / 2, size.height + 20);
  }

  Offset get mainGate => Offset(gateRoad.center.dx, play.bottom - 6);
}

/// Paints a calm, stylized aerial campus in SENTRY's palette: OLED asphalt
/// and smoked roofs in dark mode, porcelain roads and soft sage canopy in
/// light mode. Parking lots render painted bay stripes (the visual rhyme of
/// the reference's vineyard rows).
class CampusAerialPainter extends CustomPainter {
  final CampusMapLayout layout;
  final bool isDark;
  final Color crimson;

  CampusAerialPainter({
    required this.layout,
    required this.isDark,
    required this.crimson,
  });

  Color get _ground => isDark ? const Color(0xFF07080A) : const Color(0xFFE7ECF0);
  Color get _grass => isDark ? const Color(0xFF0D1410) : const Color(0xFFD9E4DA);
  Color get _road => isDark ? const Color(0xFF17181D) : const Color(0xFFFBFCFD);
  Color get _roadEdge => isDark ? const Color(0xFF22242B) : const Color(0xFFD2D9E1);
  Color get _lane => isDark ? const Color(0xFF3A3D46) : const Color(0xFFC4CCD6);
  Color get _asphalt => isDark ? const Color(0xFF111216) : const Color(0xFFD6DCE3);
  Color get _stripe => isDark
      ? Colors.white.withValues(alpha: 0.16)
      : Colors.white.withValues(alpha: 0.95);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;

    // Ground with soft vignette.
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          radius: 1.2,
          colors: isDark
              ? [const Color(0xFF0C0E10), _ground]
              : [const Color(0xFFF1F4F6), _ground],
        ).createShader(full),
    );

    _paintGrass(canvas, size);
    _paintTrees(canvas, size);
    _paintRoads(canvas, size);
    for (final e in layout.lots.entries) {
      _paintLot(canvas, e.key, e.value);
    }
    for (final b in layout.buildings) {
      _paintBuilding(canvas, b.$1, b.$2);
    }
    _paintGate(canvas);
  }

  void _paintGrass(Canvas canvas, Size size) {
    final paint = Paint()..color = _grass;
    final p = layout.play;
    final patches = <Rect>[
      Rect.fromLTWH(-20, -20, p.left + p.width * 0.70, layout.mainRoad.top + 10),
      Rect.fromLTWH(p.left + p.width * 0.76, -20, size.width, layout.mainRoad.top + 10),
      Rect.fromLTWH(-20, layout.mainRoad.bottom + 6, layout.gateRoad.left + 6, size.height),
      Rect.fromLTWH(layout.gateRoad.right + 6, layout.mainRoad.bottom + 6, size.width,
          size.height),
    ];
    for (final r in patches) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(10), const Radius.circular(28)),
        paint,
      );
    }
  }

  void _paintTrees(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    final p = layout.play;
    final clusters = <Offset>[
      Offset(p.left + p.width * 0.67, p.top + p.height * 0.10),
      Offset(p.left + p.width * 0.68, p.top + p.height * 0.33),
      Offset(p.left + p.width * 0.205, p.top + p.height * 0.47),
      Offset(p.left + p.width * 0.50, p.top + p.height * 0.80),
      Offset(p.left + p.width * 0.40, p.top + p.height * 0.92),
      Offset(p.left + p.width * 0.83, p.top + p.height * 0.94),
      Offset(p.left + p.width * 0.08, p.top + p.height * 0.96),
      // Canopy beyond the play area (visible through the frosted panels).
      Offset(size.width * 0.92, size.height * 0.12),
      Offset(size.width * 0.88, size.height * 0.48),
      Offset(size.width * 0.95, size.height * 0.82),
      Offset(size.width * 0.20, size.height * 0.94),
      Offset(size.width * 0.60, size.height * 0.97),
      Offset(size.width * 0.04, size.height * 0.08),
    ];
    final unit = (p.shortestSide * 0.045).clamp(9.0, 22.0);
    for (final c in clusters) {
      final count = 5 + rnd.nextInt(5);
      for (var i = 0; i < count; i++) {
        final o = c +
            Offset((rnd.nextDouble() - 0.5) * unit * 5,
                (rnd.nextDouble() - 0.5) * unit * 3.4);
        final r = unit * (0.65 + rnd.nextDouble() * 0.75);
        // Canopy shadow.
        canvas.drawCircle(
          o + Offset(r * 0.35, r * 0.45),
          r,
          Paint()
            ..color = Colors.black.withValues(alpha: isDark ? 0.55 : 0.10)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        final rect = Rect.fromCircle(center: o, radius: r);
        canvas.drawCircle(
          o,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.4),
              colors: isDark
                  ? [const Color(0xFF233629), const Color(0xFF111C15)]
                  : [const Color(0xFFD3E2D2), const Color(0xFFAFC7B1)],
            ).createShader(rect),
        );
      }
    }
  }

  void _paintRoads(Canvas canvas, Size size) {
    for (final r in [layout.mainRoad, layout.serviceRoad, layout.gateRoad]) {
      final rr = RRect.fromRectAndRadius(r, Radius.circular(layout.roadWidth / 2));
      canvas.drawRRect(rr.inflate(2), Paint()..color = _roadEdge);
      canvas.drawRRect(rr, Paint()..color = _road);
    }
    // Rounded junction fillets.
    final j1 = Offset(layout.serviceRoad.center.dx, layout.mainRoad.center.dy);
    final j2 = Offset(layout.gateRoad.center.dx, layout.mainRoad.center.dy);
    for (final j in [j1, j2]) {
      canvas.drawCircle(j, layout.roadWidth * 0.9, Paint()..color = _road);
    }

    // Dashed center lanes.
    final lane = Paint()
      ..color = _lane
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    void dashed(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      for (double d = 0; d < total; d += 18) {
        canvas.drawLine(a + dir * d, a + dir * math.min(d + 9, total), lane);
      }
    }

    final m = layout.mainRoad;
    dashed(Offset(m.left, m.center.dy), Offset(m.right, m.center.dy));
    final s = layout.serviceRoad;
    dashed(Offset(s.center.dx, s.top), Offset(s.center.dx, m.top - 4));
    final g = layout.gateRoad;
    dashed(Offset(g.center.dx, m.bottom + 4), Offset(g.center.dx, g.bottom));
  }

  void _paintLot(Canvas canvas, String code, Rect r) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(14));
    canvas.drawRRect(
      rr.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.6 : 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(rr, Paint()..color = _asphalt);
    canvas.save();
    canvas.clipRRect(rr);

    final inner = r.deflate(9);
    final stripe = Paint()
      ..color = _stripe
      ..strokeWidth = 1.3;
    final pending = code == 'B4';
    if (!pending) {
      final tall = inner.height > inner.width * 0.9;
      if (tall) {
        // Two banks of bays with a driving aisle in between.
        final aisle = inner.height * 0.16;
        final bankH = (inner.height - aisle) / 2;
        for (final top in [inner.top, inner.top + bankH + aisle]) {
          for (double x = inner.left; x <= inner.right + 0.1; x += 11) {
            canvas.drawLine(Offset(x, top), Offset(x, top + bankH), stripe);
          }
        }
      } else {
        final aisle = inner.width * 0.12;
        final bankW = (inner.width - aisle) / 2;
        for (final left in [inner.left, inner.left + bankW + aisle]) {
          for (double y = inner.top; y <= inner.bottom + 0.1; y += 10) {
            canvas.drawLine(Offset(left, y), Offset(left + bankW, y), stripe);
          }
        }
      }
      if (code == 'B2') {
        // Violet motorcycle strip along the top edge.
        final moto = Rect.fromLTWH(inner.left, inner.top, inner.width, 7);
        canvas.drawRRect(
          RRect.fromRectAndRadius(moto, const Radius.circular(3)),
          Paint()..color = const Color(0xFF7C3AED).withValues(alpha: 0.55),
        );
      }
    } else {
      // Schematic pending: dashed survey outline.
      final dash = Paint()
        ..color = _stripe
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(inner, const Radius.circular(8)));
      for (final metric in path.computeMetrics()) {
        for (double d = 0; d < metric.length; d += 12) {
          canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length)), dash);
        }
      }
    }
    canvas.restore();
  }

  void _paintBuilding(Canvas canvas, String label, Rect r) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(12));
    canvas.drawRRect(
      rr.shift(const Offset(8, 12)),
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.75 : 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF24252C), const Color(0xFF15161A)]
              : [Colors.white, const Color(0xFFEFF2F6)],
        ).createShader(r),
    );
    canvas.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFF0F172A).withValues(alpha: 0.06),
    );
    // Rooftop units.
    final unitPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : const Color(0xFF0F172A).withValues(alpha: 0.05);
    final u = (r.shortestSide * 0.16).clamp(6.0, 16.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(r.right - u * 2.6, r.top + u * 0.8, u * 1.7, u), const Radius.circular(3)),
      unitPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(r.right - u * 2.6, r.top + u * 2.2, u * 1.7, u), const Radius.circular(3)),
      unitPaint,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'AtkinsonHyperlegibleNext',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: isDark
              ? Colors.white.withValues(alpha: 0.38)
              : const Color(0xFF475569).withValues(alpha: 0.75),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(10, r.width - 20));
    tp.paint(canvas, Offset(r.left + 10, r.bottom - tp.height - 9));
  }

  void _paintGate(Canvas canvas) {
    final g = layout.mainGate;
    canvas.drawCircle(g, 9, Paint()..color = crimson.withValues(alpha: 0.22));
    canvas.drawCircle(g, 4.5, Paint()..color = crimson);
  }

  @override
  bool shouldRepaint(covariant CampusAerialPainter old) =>
      old.isDark != isDark || old.layout.size != layout.size || old.layout.play != layout.play;
}
