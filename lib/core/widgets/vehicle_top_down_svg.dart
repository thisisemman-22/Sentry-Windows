import 'package:flutter/material.dart';

/// Top-down architectural vector Car and Motorcycle graphics ported from
/// James Villaflor's `app.js` (`topCarSvg()` and `topMotoSvg()`) for the
/// Overhead Parking Blueprint (`Lots A–D`).
class VehicleTopDownSvg extends StatelessWidget {
  final String vehicleType; // 'car' | 'motorcycle'
  final Color primaryColor;
  final double width;
  final double height;

  const VehicleTopDownSvg({
    super.key,
    required this.vehicleType,
    this.primaryColor = const Color(0xFFC8102E),
    this.width = 48,
    this.height = 26,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: vehicleType == 'motorcycle'
            ? _TopDownMotorcyclePainter(primaryColor: primaryColor)
            : _TopDownCarPainter(primaryColor: primaryColor),
      ),
    );
  }
}

class _TopDownCarPainter extends CustomPainter {
  final Color primaryColor;

  const _TopDownCarPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 80.0, size.height / 44.0);

    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(12, 2, 16, 5), const Radius.circular(2)),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(52, 2, 16, 5), const Radius.circular(2)),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(12, 37, 16, 5), const Radius.circular(2)),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(52, 37, 16, 5), const Radius.circular(2)),
      wheelPaint,
    );

    // Chassis
    final bodyPaint = Paint()..color = primaryColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 6, 72, 32), const Radius.circular(10)),
      bodyPaint,
    );

    // Windshield & Cabin Glass
    final glassPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(18, 10, 44, 24), const Radius.circular(6)),
      glassPaint,
    );

    // Roof panel
    final roofPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(27, 12, 26, 20), const Radius.circular(4)),
      roofPaint,
    );

    // Headlight beams (right side front)
    final beamPaint = Paint()..color = const Color(0xFFFDE68A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(72, 9, 3, 6), const Radius.circular(1.5)),
      beamPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(72, 29, 3, 6), const Radius.circular(1.5)),
      beamPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TopDownCarPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor;
}

class _TopDownMotorcyclePainter extends CustomPainter {
  final Color primaryColor;

  const _TopDownMotorcyclePainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64.0, size.height / 32.0);

    // Front & Rear Tires
    final tirePaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 12, 14, 8), const Radius.circular(4)),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(46, 12, 14, 8), const Radius.circular(4)),
      tirePaint,
    );

    // Handlebars
    final barPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(45, 4), const Offset(45, 28), barPaint);

    // Tank & Seat Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(14, 9, 34, 14), const Radius.circular(7)),
      Paint()..color = primaryColor,
    );

    // Rider Helmet / Seat Accent
    canvas.drawCircle(
      const Offset(28, 16),
      5.5,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TopDownMotorcyclePainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor;
}
