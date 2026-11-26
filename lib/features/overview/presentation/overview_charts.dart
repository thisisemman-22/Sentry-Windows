import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../shared/models/attempt_models.dart';
import '../../../shared/models/parking_models.dart';
import '../../../shared/models/visit_models.dart';
import 'spatial_glass.dart';

// ---------------------------------------------------------------------------
// 1. Campus Mix — Concentric Multi-Ring Arc Card (Vinora "Varietal Mix" style)
// ---------------------------------------------------------------------------

class CampusMixDonutCard extends StatefulWidget {
  final List<LotSummaryDto> lotSummaries;
  final List<SpaceDto> spaces;
  final bool hasLiveSnapshot;
  final VoidCallback? onOpenParking;

  const CampusMixDonutCard({
    super.key,
    required this.lotSummaries,
    required this.spaces,
    required this.hasLiveSnapshot,
    this.onOpenParking,
  });

  @override
  State<CampusMixDonutCard> createState() => _CampusMixDonutCardState();
}

class _CampusMixDonutCardState extends State<CampusMixDonutCard> {
  bool _byVehicle = false;

  static const List<Color> _ringColors = [
    SentryColors.crimson,
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF38BDF8),
    Color(0xFFA855F7),
  ];

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final formalSpaces =
        widget.spaces.where((s) => s.isFormalAllocatableBay).toList();
    final totalFormal = formalSpaces.length;
    final totalFree =
        formalSpaces.where((s) => s.isTrulyAvailableForAllocation).length;

    final entries = <_ConcentricArcEntry>[];
    if (widget.hasLiveSnapshot && formalSpaces.isNotEmpty) {
      if (_byVehicle) {
        final cars = formalSpaces
            .where((s) => s.compatibility != 'motorcycle_only')
            .length;
        final motos = formalSpaces
            .where((s) => s.compatibility == 'motorcycle_only')
            .length;
        final denom = math.max(1, totalFormal);
        entries.addAll([
          _ConcentricArcEntry(
            label: 'Car bays',
            detail: '$cars bays',
            fraction: (cars / denom).clamp(0.0, 1.0),
            percentText: '${((cars / denom) * 100).round()}%',
            color: SentryColors.crimson,
          ),
          _ConcentricArcEntry(
            label: 'Motorcycle',
            detail: '$motos bays',
            fraction: (motos / denom).clamp(0.0, 1.0),
            percentText: '${((motos / denom) * 100).round()}%',
            color: const Color(0xFFA855F7),
          ),
          _ConcentricArcEntry(
            label: 'Available now',
            detail: '$totalFree free',
            fraction: (totalFree / denom).clamp(0.0, 1.0),
            percentText: '${((totalFree / denom) * 100).round()}%',
            color: p.ok,
          ),
        ]);
      } else {
        final activeLots = widget.lotSummaries
            .where((l) => l.totalSpaces > 0 || !l.isSchematicPending)
            .toList();
        final denom = math.max(1, totalFormal);
        for (var i = 0; i < activeLots.length && i < 4; i++) {
          final lot = activeLots[i];
          final share = (lot.totalSpaces / denom).clamp(0.0, 1.0);
          final freeRatio = lot.totalSpaces > 0
              ? (lot.trulyAvailableSpaces / lot.totalSpaces).clamp(0.0, 1.0)
              : 0.0;
          entries.add(
            _ConcentricArcEntry(
              label: lot.lotCode == 'B5' ? 'B5 Overflow' : 'Lot ${lot.lotCode}',
              detail: '${lot.trulyAvailableSpaces}/${lot.totalSpaces}',
              fraction: math.max(0.14, freeRatio),
              percentText: '${(share * 100).round()}%',
              color: _ringColors[i % _ringColors.length],
            ),
          );
        }
      }
    }

    return SpatialGlass(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      radius: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactRing = constraints.maxWidth < 290;
          final ringSize = compactRing ? 108.0 : 128.0;
          final ringGap = compactRing ? 12.0 : 16.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Campus mix', style: panelTitleStyle(p, size: 19)),
                        const SizedBox(height: 2),
                        Text(
                          widget.hasLiveSnapshot
                              ? (_byVehicle
                                  ? 'Formal bays by vehicle class'
                                  : 'Capacity share across Lots B1–B5')
                              : 'Awaiting live telemetry',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: SentryTheme.sansFontFamily,
                            fontSize: 12.5,
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ModeTogglePill(
                    leftLabel: 'Lots',
                    rightLabel: 'Vehicles',
                    isRight: _byVehicle,
                    onChanged: (v) => setState(() => _byVehicle = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!widget.hasLiveSnapshot)
                SizedBox(
                  height: 134,
                  child: Row(
                    children: [
                      SizedBox(
                        width: ringSize,
                        height: ringSize,
                        child: CustomPaint(
                          painter: _ConcentricArcsPainter(
                            entries: const [],
                            trackColor: p.line.withValues(alpha: 0.45),
                            progress: 1.0,
                          ),
                          child: Center(
                            child: Text(
                              '—',
                              style: bigFigureStyle(p, size: 26, color: p.muted),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: ringGap),
                      Expanded(
                        child: Text(
                          'Awaiting live telemetry',
                          style: TextStyle(
                            fontFamily: SentryTheme.sansFontFamily,
                            fontSize: 13,
                            color: p.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 134,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: widget.onOpenParking,
                        child: SizedBox(
                          width: ringSize,
                          height: ringSize,
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey('concentric_$_byVehicle'),
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: SentryMotion.of(
                                context, SentryMotion.donutTransition),
                            curve: Curves.easeOutCubic,
                            builder: (context, progress, _) => CustomPaint(
                              painter: _ConcentricArcsPainter(
                                entries: entries,
                                trackColor: p.isDark
                                    ? Colors.white.withValues(alpha: 0.07)
                                    : const Color(0xFF0F172A)
                                        .withValues(alpha: 0.07),
                                progress: progress,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedCount(
                                      value: totalFree,
                                      style: bigFigureStyle(
                                        p,
                                        size: compactRing ? 20 : 24,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'FREE',
                                      style: SentryTheme.eyebrow(color: p.muted)
                                          .copyWith(
                                        fontSize: 8.5,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: ringGap),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < entries.length; i++) ...[
                              if (i > 0) const SizedBox(height: 5),
                              _LegendPercentRow(entry: entries[i], palette: p),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LegendPercentRow extends StatelessWidget {
  final _ConcentricArcEntry entry;
  final SentryPalette palette;

  const _LegendPercentRow({required this.entry, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: entry.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${entry.label} · ${entry.detail}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: SentryTheme.sansFontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.slate,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          entry.percentText,
          style: SentryTheme.display(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: palette.text,
          ),
        ),
      ],
    );
  }
}

class _ModeTogglePill extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool isRight;
  final ValueChanged<bool> onChanged;

  const _ModeTogglePill({
    required this.leftLabel,
    required this.rightLabel,
    required this.isRight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFF0F172A).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(context, p, leftLabel, !isRight, () => onChanged(false)),
          _chip(context, p, rightLabel, isRight, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    SentryPalette p,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: SentryMotion.of(context, const Duration(milliseconds: 160)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? SentryColors.crimson : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: SentryTheme.sansFontFamily,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : p.muted,
          ),
        ),
      ),
    );
  }
}

class _ConcentricArcEntry {
  final String label;
  final String detail;
  final double fraction;
  final String percentText;
  final Color color;

  const _ConcentricArcEntry({
    required this.label,
    required this.detail,
    required this.fraction,
    required this.percentText,
    required this.color,
  });
}

class _ConcentricArcsPainter extends CustomPainter {
  final List<_ConcentricArcEntry> entries;
  final Color trackColor;
  final double progress;

  _ConcentricArcsPainter({
    required this.entries,
    required this.trackColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) / 2 - 5;
    const stroke = 5.5;
    const gap = 3.8;
    const startAngle = 135 * math.pi / 180;
    const maxSweep = 270 * math.pi / 180;

    final ringCount = entries.isEmpty ? 3 : math.min(4, entries.length);
    for (var i = 0; i < ringCount; i++) {
      final r = maxR - i * (stroke + gap);
      if (r <= 14) break;
      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawArc(
        rect,
        startAngle,
        maxSweep,
        false,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );

      if (i < entries.length) {
        final e = entries[i];
        final sweep = maxSweep * e.fraction.clamp(0.08, 1.0) * progress;
        canvas.drawArc(
          rect,
          startAngle,
          sweep,
          false,
          Paint()
            ..color = e.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricArcsPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.entries != entries;
}

// ---------------------------------------------------------------------------
// 2. Gate Activity — Full-Track Capsule Bar Chart (Vinora "Harvest Forecast")
// ---------------------------------------------------------------------------

class GateActivityBarChartCard extends StatelessWidget {
  final List<VisitDto> visits;
  final List<AttemptDto> attemptHistory;
  final bool hasLiveSnapshot;
  final VoidCallback? onExpand;

  const GateActivityBarChartCard({
    super.key,
    required this.visits,
    required this.attemptHistory,
    required this.hasLiveSnapshot,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final buckets = _computeHourlyBuckets();
    final peak = buckets.fold<int>(0, (m, b) => math.max(m, b.count));

    return SpatialGlass(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gate activity', style: panelTitleStyle(p, size: 19)),
                    const SizedBox(height: 2),
                    Text(
                      hasLiveSnapshot
                          ? 'Vehicles processed per hour (Asia/Manila)'
                          : 'Awaiting live telemetry',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SentryTheme.sansFontFamily,
                        fontSize: 12.5,
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasLiveSnapshot && peak > 0) ...[
                        SoftChip('Peak: $peak/hr', tone: SoftChipTone.crimson),
                        const SizedBox(width: 6),
                      ],
                      const SoftChip('Today · PHT', tone: SoftChipTone.neutral),
                      if (onExpand != null) ...[
                        const SizedBox(width: 6),
                        GlassIconButton(
                          icon: Icons.north_east_rounded,
                          tooltip: 'Open access logs',
                          onPressed: onExpand!,
                          size: 32,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 134,
            child: !hasLiveSnapshot || peak == 0
                ? Stack(
                    children: [
                      CustomPaint(
                        size: Size.infinite,
                        painter: _CapsuleTrackBarPainter(
                          buckets: buckets,
                          peak: 0,
                          progress: 1.0,
                          isDark: p.isDark,
                          trackColor: p.isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFF0F172A)
                                  .withValues(alpha: 0.05),
                          labelColor: p.muted,
                        ),
                      ),
                      Center(
                        child: Text(
                          'Awaiting live telemetry',
                          style: TextStyle(
                            fontFamily: SentryTheme.sansFontFamily,
                            fontSize: 13,
                            color: p.muted,
                          ),
                        ),
                      ),
                    ],
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: SentryMotion.of(
                        context, SentryMotion.chartTransition),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _CapsuleTrackBarPainter(
                        buckets: buckets,
                        peak: peak,
                        progress: t,
                        isDark: p.isDark,
                        trackColor: p.isDark
                            ? Colors.white.withValues(alpha: 0.055)
                            : const Color(0xFF0F172A).withValues(alpha: 0.055),
                        labelColor: p.muted,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<_HourBucket> _computeHourlyBuckets() {
    final timestamps = <DateTime>[
      for (final v in visits) v.enteredAtUtc,
      for (final v in visits)
        if (v.exitedAtUtc != null) v.exitedAtUtc!,
      for (final a in attemptHistory) a.startedAtUtc,
    ];
    if (!hasLiveSnapshot || timestamps.isEmpty) {
      return [
        for (var h = 7; h <= 16; h++)
          _HourBucket(
            hour: h,
            shortLabel: '${h.toString().padLeft(2, '0')}h',
            count: 0,
          ),
      ];
    }

    final manilaDates = timestamps.map(ManilaTime.toManila).toList()..sort();
    final latestHour = manilaDates.last.hour.clamp(9, 23);
    final startHour = (latestHour - 9).clamp(0, 14);
    final counts = <int, int>{};
    for (final m in manilaDates) {
      counts[m.hour] = (counts[m.hour] ?? 0) + 1;
    }

    return [
      for (var i = 0; i < 10; i++)
        _HourBucket(
          hour: startHour + i,
          shortLabel: '${(startHour + i).toString().padLeft(2, '0')}h',
          count: counts[startHour + i] ?? 0,
        ),
    ];
  }
}

class _HourBucket {
  final int hour;
  final String shortLabel;
  final int count;
  const _HourBucket({
    required this.hour,
    required this.shortLabel,
    required this.count,
  });
}

class _CapsuleTrackBarPainter extends CustomPainter {
  final List<_HourBucket> buckets;
  final int peak;
  final double progress;
  final bool isDark;
  final Color trackColor;
  final Color labelColor;

  _CapsuleTrackBarPainter({
    required this.buckets,
    required this.peak,
    required this.progress,
    required this.isDark,
    required this.trackColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    const leftAxisW = 24.0;
    const topCalloutH = 30.0;
    const bottomLabelH = 20.0;
    const trackTop = topCalloutH;
    final trackBottom = size.height - bottomLabelH;
    final trackH = math.max(24.0, trackBottom - trackTop);

    final maxScale = peak <= 0 ? 6 : ((peak + 1) ~/ 2 + 1) * 2;
    final yTicks = [maxScale, maxScale ~/ 2, 0];
    for (var i = 0; i < yTicks.length; i++) {
      final frac = i / (yTicks.length - 1);
      final y = trackTop + frac * trackH;
      final tp = TextPainter(
        text: TextSpan(
          text: '${yTicks[i]}',
          style: TextStyle(
            fontFamily: SentryTheme.monoFontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: labelColor.withValues(alpha: 0.75),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    const plotLeft = leftAxisW;
    final plotW = math.max(40.0, size.width - plotLeft);
    final slotW = plotW / buckets.length;
    final barW = (slotW * 0.48).clamp(10.0, 20.0);
    final radius = Radius.circular(barW / 2);

    var peakIndex = -1;
    for (var i = 0; i < buckets.length; i++) {
      if (peak > 0 && buckets[i].count == peak) {
        peakIndex = i;
      }
    }

    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final cx = plotLeft + slotW * i + slotW / 2;

      final trackRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barW / 2, trackTop, barW, trackH),
        radius,
      );
      canvas.drawRRect(trackRect, Paint()..color = trackColor);

      if (peak > 0 && b.count > 0) {
        final isPeak = i == peakIndex;
        final frac = (b.count / maxScale).clamp(0.14, 1.0) * progress;
        final fillH = math.max(barW, trackH * frac);
        final fillRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, trackBottom - fillH, barW, fillH),
          radius,
        );

        if (isPeak) {
          canvas.drawRRect(
            fillRect.inflate(2),
            Paint()
              ..color = SentryColors.crimson.withValues(alpha: 0.32)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
        }

        final fillPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isPeak
                ? const [Color(0xFFFF4D6A), SentryColors.crimson]
                : (isDark
                    ? [
                        Colors.white.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0.22),
                      ]
                    : [
                        const Color(0xFF334155),
                        const Color(0xFF94A3B8),
                      ]),
          ).createShader(fillRect.outerRect);
        canvas.drawRRect(fillRect, fillPaint);

        if (isPeak) {
          final pillText = '${b.shortLabel} · ${b.count}/hr';
          final tp = TextPainter(
            text: TextSpan(
              text: pillText,
              style: const TextStyle(
                fontFamily: SentryTheme.sansFontFamily,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final pw = tp.width + 14;
          final ph = tp.height + 5;
          final px = (cx - pw / 2).clamp(plotLeft, size.width - pw);
          final pillRRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(px, 4, pw, ph),
            const Radius.circular(999),
          );
          canvas.drawRRect(
            pillRRect,
            Paint()..color = SentryColors.crimson,
          );
          tp.paint(canvas, Offset(px + 7, 6.5));
        }
      }

      final xTp = TextPainter(
        text: TextSpan(
          text: b.shortLabel,
          style: TextStyle(
            fontFamily: SentryTheme.sansFontFamily,
            fontSize: 10,
            fontWeight: i == peakIndex ? FontWeight.w800 : FontWeight.w500,
            color: i == peakIndex
                ? (isDark ? Colors.white : SentryColors.crimson)
                : labelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      xTp.paint(canvas, Offset(cx - xTp.width / 2, trackBottom + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _CapsuleTrackBarPainter old) =>
      old.progress != progress ||
      old.peak != peak ||
      old.isDark != isDark ||
      old.buckets != buckets;
}

// ---------------------------------------------------------------------------
// 3. Ticked Semi-Circular Radial Gauge (Vinora "Vintage progress" 68% TODAY)
// ---------------------------------------------------------------------------

class CapacityRadialGauge extends StatelessWidget {
  final double ratio;
  final bool active;
  final Color activeColor;
  final double width;
  final double height;

  const CapacityRadialGauge({
    super.key,
    required this.ratio,
    required this.active,
    required this.activeColor,
    this.width = 132,
    this.height = 70,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final clamped = active ? ratio.clamp(0.0, 1.0) : 0.0;

    return SizedBox(
      width: width,
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: clamped),
        duration: SentryMotion.of(context, SentryMotion.chartTransition),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _TickedSemiGaugePainter(
            value: active ? v : 0.0,
            trackColor: p.isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFF0F172A).withValues(alpha: 0.10),
            tickColor: p.isDark
                ? Colors.white.withValues(alpha: 0.22)
                : const Color(0xFF0F172A).withValues(alpha: 0.22),
            fillColor: active ? activeColor : p.muted,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    active ? '${(v * 100).round()}%' : '—',
                    style: SentryTheme.display(
                      fontSize: active ? 22 : 20,
                      fontWeight: FontWeight.w700,
                      color: active ? p.text : p.muted,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'TODAY',
                    style: SentryTheme.eyebrow(color: p.muted)
                        .copyWith(fontSize: 8.5, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TickedSemiGaugePainter extends CustomPainter {
  final double value;
  final Color trackColor;
  final Color tickColor;
  final Color fillColor;

  _TickedSemiGaugePainter({
    required this.value,
    required this.trackColor,
    required this.tickColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = math.pi * 1.02;
    const totalSweep = math.pi * 0.96;
    const stroke = 7.0;
    final center = Offset(size.width / 2, size.height - 6);
    final outerR = math.min(size.width / 2 - 4, size.height - 8);
    final arcR = outerR - 8;
    if (arcR <= 10) return;

    const tickCount = 25;
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < tickCount; i++) {
      final t = i / (tickCount - 1);
      final angle = startAngle + totalSweep * t;
      final isMajor = i % 4 == 0;
      final r0 = outerR - (isMajor ? 4.5 : 2.5);
      final r1 = outerR;
      canvas.drawLine(
        Offset(center.dx + math.cos(angle) * r0,
            center.dy + math.sin(angle) * r0),
        Offset(center.dx + math.cos(angle) * r1,
            center.dy + math.sin(angle) * r1),
        tickPaint,
      );
    }

    final rect = Rect.fromCircle(center: center, radius: arcR);
    canvas.drawArc(
      rect,
      startAngle,
      totalSweep,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    if (value > 0.005) {
      canvas.drawArc(
        rect,
        startAngle,
        totalSweep * value.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TickedSemiGaugePainter old) =>
      old.value != value ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor;
}

// ---------------------------------------------------------------------------
// 4. Micro Sparkline & Lollipop Stems for the 2x2 KPI Tiles
// ---------------------------------------------------------------------------

class MiniSparkline extends StatelessWidget {
  final List<double> points;
  final Color color;
  final bool active;
  final bool showDotGrid;
  final double width;
  final double height;

  const MiniSparkline({
    super.key,
    required this.points,
    required this.color,
    required this.active,
    this.showDotGrid = false,
    this.width = double.infinity,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          points: active ? points : const [0.4, 0.4, 0.4, 0.4],
          color: active ? color : p.line,
          fill: active && !showDotGrid,
          showDotGrid: showDotGrid,
          dotColor: p.isDark
              ? Colors.white.withValues(alpha: 0.10)
              : const Color(0xFF0F172A).withValues(alpha: 0.10),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final bool fill;
  final bool showDotGrid;
  final Color dotColor;

  _SparklinePainter({
    required this.points,
    required this.color,
    required this.fill,
    required this.showDotGrid,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showDotGrid) {
      final dp = Paint()..color = dotColor;
      for (double x = 4; x < size.width; x += 12) {
        for (double y = 4; y < size.height; y += 9) {
          canvas.drawCircle(Offset(x, y), 1.0, dp);
        }
      }
    }

    if (points.length < 2) return;
    final maxV = points.reduce(math.max);
    final minV = points.reduce(math.min);
    final span = math.max(1.0, maxV - minV);

    final coords = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final norm = maxV == minV ? 0.45 : (points[i] - minV) / span;
      final y = size.height - 5 - norm * (size.height - 12);
      coords.add(Offset(x, y));
    }

    final path = Path()..moveTo(coords.first.dx, coords.first.dy);
    for (var i = 0; i < coords.length - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(coords.last.dx, size.height)
        ..lineTo(coords.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.34),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    if (showDotGrid && coords.length >= 2) {
      final hi = coords[coords.length - 2];
      canvas.drawCircle(hi, 4.5, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(hi, 2.8, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.points != points ||
      old.color != color ||
      old.fill != fill ||
      old.showDotGrid != showDotGrid;
}

class LollipopStemMicroChart extends StatelessWidget {
  final List<double> values;
  final String maxLabel;
  final Color accentColor;
  final bool active;

  const LollipopStemMicroChart({
    super.key,
    required this.values,
    required this.maxLabel,
    required this.accentColor,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return SizedBox(
      height: 38,
      child: CustomPaint(
        size: Size.infinite,
        painter: _LollipopStemPainter(
          values: values,
          maxLabel: maxLabel,
          accentColor: accentColor,
          active: active,
          isDark: p.isDark,
          lineColor: p.isDark
              ? Colors.white.withValues(alpha: 0.22)
              : const Color(0xFF0F172A).withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _LollipopStemPainter extends CustomPainter {
  final List<double> values;
  final String maxLabel;
  final Color accentColor;
  final bool active;
  final bool isDark;
  final Color lineColor;

  _LollipopStemPainter({
    required this.values,
    required this.maxLabel,
    required this.accentColor,
    required this.active,
    required this.isDark,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const topY = 9.0;
    final bottomY = size.height - 2;
    final dashPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    for (double x = 36; x < size.width; x += 6) {
      canvas.drawLine(
          Offset(x, topY), Offset(math.min(x + 3, size.width), topY), dashPaint);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: maxLabel,
        style: TextStyle(
          fontFamily: SentryTheme.sansFontFamily,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF0C0D10) : Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, topY - tp.height / 2 - 2, tp.width + 10, tp.height + 4),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.85)
            : const Color(0xFF334155),
    );
    tp.paint(canvas, Offset(5, topY - tp.height / 2));

    if (values.isEmpty) return;
    var maxIdx = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] >= values[maxIdx]) maxIdx = i;
    }

    final startX = pillRect.width + 10;
    final availW = math.max(20.0, size.width - startX - 6);
    final step = values.length > 1 ? availW / (values.length - 1) : 0.0;

    for (var i = 0; i < values.length; i++) {
      final x = startX + step * i;
      final frac = active ? values[i].clamp(0.25, 1.0) : 0.3;
      final y = bottomY - (bottomY - topY) * frac;
      final isHi = active && i == maxIdx;
      final c = isHi
          ? accentColor
          : (isDark
              ? Colors.white.withValues(alpha: 0.65)
              : const Color(0xFF64748B));
      canvas.drawLine(
        Offset(x, bottomY),
        Offset(x, y),
        Paint()
          ..color = c
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(x, y), isHi ? 4.0 : 2.8, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(covariant _LollipopStemPainter old) =>
      old.values != values || old.active != active || old.isDark != isDark;
}
