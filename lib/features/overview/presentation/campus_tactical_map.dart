import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/parking_models.dart';
import 'campus_aerial_painter.dart';
import 'spatial_glass.dart';

/// Filter layers floating along the map's right edge.
enum TacticalMapLayer {
  all('All bays', Icons.grid_view_rounded),
  available('Available', Icons.check_circle_outline_rounded),
  held('Held', Icons.schedule_rounded),
  conflicts('Conflicts', Icons.report_problem_outlined),
  motorcycles('Motorcycles', Icons.two_wheeler_outlined);

  final String label;
  final IconData icon;
  const TacticalMapLayer(this.label, this.icon);
}

/// Full-bleed interactive campus map for the spatial Overview.
///
/// - Stylized aerial board ([CampusAerialPainter]) with Lots `B1–B5`.
/// - Lot pins with plain-language status, layer filters, smooth zoom-to-lot.
/// - Frosted callout card with `Open lot blueprint →`.
/// - [panels] are layered above the map but below the callout so the callout
///   is never hidden by the floating dashboard panels.
class CampusTacticalMap extends ConsumerStatefulWidget {
  final List<LotSummaryDto> lotSummaries;
  final List<SpaceDto> allSpaces;
  final bool awaitingTelemetry;
  final ValueChanged<String> onOpenLotBlueprint;
  final ValueChanged<LotSummaryDto> onInspectLotDetails;
  final EdgeInsets playInsets;
  final Widget? headerOverlay;
  final double layerPillsRight;
  final double layerPillsTop;
  final bool compact;
  final List<Widget> panels;

  const CampusTacticalMap({
    super.key,
    required this.lotSummaries,
    required this.allSpaces,
    required this.awaitingTelemetry,
    required this.onOpenLotBlueprint,
    required this.onInspectLotDetails,
    required this.playInsets,
    this.headerOverlay,
    this.layerPillsRight = 20,
    this.layerPillsTop = 20,
    this.compact = false,
    this.panels = const [],
  });

  @override
  ConsumerState<CampusTacticalMap> createState() => _CampusTacticalMapState();
}

class _CampusTacticalMapState extends ConsumerState<CampusTacticalMap>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  late final AnimationController _zoomCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  Animation<Matrix4>? _zoomAnim;
  TacticalMapLayer _layer = TacticalMapLayer.all;
  String? _focused;
  double _targetScale = 1;
  Offset _targetShift = Offset.zero;

  static const double _calloutWidth = 304;

  @override
  void initState() {
    super.initState();
    _zoomCtrl.addListener(() {
      final a = _zoomAnim;
      if (a != null) _transform.value = a.value;
    });
  }

  @override
  void didUpdateWidget(covariant CampusTacticalMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.awaitingTelemetry && _focused != null) {
      _focused = null;
      _transform.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _zoomCtrl.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    if (SentryMotion.reduced(context)) {
      _transform.value = target;
      return;
    }
    _zoomAnim = Matrix4Tween(begin: _transform.value.clone(), end: target)
        .animate(CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeOutCubic));
    _zoomCtrl.forward(from: 0);
  }

  void _focusLot(String code, CampusMapLayout layout) {
    if (widget.awaitingTelemetry) return;
    if (_focused == code) {
      _clearFocus();
      return;
    }
    final rect = layout.lots[code];
    if (rect == null) return;
    final s = widget.compact ? 1.1 : 1.18;
    final size = layout.size;
    final play = layout.play;
    final cw = math.min(_calloutWidth, play.width - 24);
    final dest = Offset(
      play.center.dx - (cw + 16) / 2,
      play.top + play.height * 0.42,
    );
    var t = dest - rect.center * s;
    t = Offset(
      t.dx.clamp(size.width - size.width * s, 0.0),
      t.dy.clamp(size.height - size.height * s, 0.0),
    );
    setState(() {
      _focused = code;
      _targetScale = s;
      _targetShift = t;
    });
    _animateTo(Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(t.dx, t.dy, 0));
  }

  void _clearFocus() {
    setState(() => _focused = null);
    _animateTo(Matrix4.identity());
  }

  bool _matches(LotSummaryDto lot) {
    switch (_layer) {
      case TacticalMapLayer.all:
        return true;
      case TacticalMapLayer.available:
        return lot.trulyAvailableSpaces > 0;
      case TacticalMapLayer.held:
        return lot.allocationHeld > 0;
      case TacticalMapLayer.conflicts:
        return lot.conflictCount > 0;
      case TacticalMapLayer.motorcycles:
        return _motoCount(lot.lotCode) > 0;
    }
  }

  int _motoCount(String code) => widget.allSpaces
      .where((s) => s.lotCode == code && s.compatibility == 'motorcycle_only')
      .length;

  String _metric(LotSummaryDto lot) {
    if (widget.awaitingTelemetry) return 'Awaiting data';
    switch (_layer) {
      case TacticalMapLayer.all:
        return lot.isSchematicPending && lot.totalSpaces == 0
            ? 'Survey pending'
            : '${lot.trulyAvailableSpaces}/${lot.totalSpaces} free';
      case TacticalMapLayer.available:
        return '${lot.trulyAvailableSpaces} free';
      case TacticalMapLayer.held:
        return '${lot.allocationHeld} held';
      case TacticalMapLayer.conflicts:
        return lot.conflictCount == 1 ? '1 conflict' : '${lot.conflictCount} conflicts';
      case TacticalMapLayer.motorcycles:
        return '${_motoCount(lot.lotCode)} moto bays';
    }
  }

  static String shortLotName(LotSummaryDto lot) {
    final meta = kCampusParkingLots.where((m) => m.lotCode == lot.lotCode).firstOrNull;
    if (meta == null) return lot.lotName;
    if (lot.lotName != meta.defaultName) return lot.lotName;
    return meta.shortTabLabel.split(' · ').last;
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final ins = widget.playInsets;
        final play = Rect.fromLTRB(
          ins.left,
          ins.top,
          math.max(ins.left + 220, size.width - ins.right),
          math.max(ins.top + 180, size.height - ins.bottom),
        );
        final layout = CampusMapLayout(size: size, play: play);
        final lots = layout.lots;
        final focusedLot = _focused == null
            ? null
            : widget.lotSummaries.where((l) => l.lotCode == _focused).firstOrNull;

        Widget? callout;
        if (focusedLot != null && lots[focusedLot.lotCode] != null) {
          final r = lots[focusedLot.lotCode]!;
          final screen = Rect.fromLTWH(
            _targetShift.dx + r.left * _targetScale,
            _targetShift.dy + r.top * _targetScale,
            r.width * _targetScale,
            r.height * _targetScale,
          );
          final cw = math.min(_calloutWidth, play.width - 24);
          var left = screen.right + 16;
          if (left + cw > play.right + 8) left = screen.left - 16 - cw;
          left = left.clamp(
              play.left, math.max(play.left, size.width - cw - 12.0));
          final top = screen.top
              .clamp(12.0, math.max(12.0, size.height - 300.0))
              .toDouble();
          callout = Positioned(
            left: left,
            top: top,
            width: cw,
            child: BentoReveal(
              key: ValueKey('callout_${focusedLot.lotCode}'),
              slideYBegin: 0.04,
              child: _LotCallout(
                key: Key('tactical_callout_${focusedLot.lotCode}'),
                lot: focusedLot,
                shortName: shortLotName(focusedLot),
                spaces: widget.allSpaces
                    .where((s) => s.lotCode == focusedLot.lotCode)
                    .toList(),
                onClose: _clearFocus,
                onBreakdown: () => widget.onInspectLotDetails(focusedLot),
                onOpen: () => widget.onOpenLotBlueprint(focusedLot.lotCode),
              ),
            ),
          );
        }

        final pills = [
          for (final layer in TacticalMapLayer.values)
            _LayerPill(
              key: Key('map_layer_${layer.name}'),
              layer: layer,
              selected: _layer == layer,
              onTap: () => setState(() => _layer = layer),
            ),
        ];

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 2.4,
                scaleEnabled: !widget.compact,
                onInteractionStart: (_) {
                  if (_focused != null) setState(() => _focused = null);
                },
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: CampusAerialPainter(
                            layout: layout,
                            isDark: p.isDark,
                            crimson: SentryColors.crimson,
                          ),
                        ),
                      ),
                      for (final lot in widget.lotSummaries)
                        if (lots[lot.lotCode] != null)
                          Positioned.fromRect(
                            rect: lots[lot.lotCode]!,
                            child: _LotOverlay(
                              key: Key('tactical_lot_${lot.lotCode}'),
                              lot: lot,
                              shortName: shortLotName(lot),
                              metric: _metric(lot),
                              highlighted: _matches(lot),
                              selected: _focused == lot.lotCode,
                              awaitingTelemetry: widget.awaitingTelemetry,
                              onTap: () => _focusLot(lot.lotCode, layout),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),

            // Scale bar & north arrow (bottom-left of the play area).
            Positioned(
              left: play.left + 4,
              top: play.bottom + 2,
              child: const IgnorePointer(child: _ScaleBar()),
            ),

            if (widget.awaitingTelemetry)
              Positioned.fromRect(
                rect: play,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SpatialGlass(
                      strong: true,
                      padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: SentryColors.crimson
                                    .withValues(alpha: p.isDark ? 0.18 : 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.local_parking_rounded,
                                  color: SentryColors.crimson),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Awaiting parking lot telemetry',
                              textAlign: TextAlign.center,
                              style: panelTitleStyle(p, size: 18),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Real bay occupancy and camera telemetry will populate once the backend connects.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: p.slate),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (widget.headerOverlay != null)
              Positioned(
                left: 20,
                top: 20,
                right: widget.compact ? 20 : widget.layerPillsRight,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: widget.headerOverlay!,
                ),
              ),

            Positioned(
              left: 20,
              right: widget.compact ? 20 : widget.layerPillsRight,
              top: widget.layerPillsTop,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final pill in pills) ...[pill, const SizedBox(width: 8)],
                  ],
                ),
              ),
            ),

            ...widget.panels,

            if (callout != null) callout,
          ],
        );
      },
    );
  }
}

class _LayerPill extends StatefulWidget {
  final TacticalMapLayer layer;
  final bool selected;
  final VoidCallback onTap;
  const _LayerPill({
    super.key,
    required this.layer,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_LayerPill> createState() => _LayerPillState();
}

class _LayerPillState extends State<_LayerPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final sel = widget.selected;
    final bg = sel
        ? SentryColors.crimson
        : (p.isDark
            ? const Color(0xFF0C0D10).withValues(alpha: _hover ? 0.92 : 0.80)
            : Colors.white.withValues(alpha: _hover ? 0.98 : 0.88));
    final fg = sel ? Colors.white : p.text;
    return Semantics(
      button: true,
      selected: sel,
      label: 'Map layer ${widget.layer.label}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: SentryMotion.of(context, const Duration(milliseconds: 180)),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: sel
                    ? Colors.transparent
                    : (p.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFF0F172A).withValues(alpha: 0.08)),
              ),
              boxShadow: [
                BoxShadow(
                  color: sel
                      ? SentryColors.crimson.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: p.isDark ? 0.4 : 0.08),
                  blurRadius: sel ? 18 : 14,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.layer.icon, size: 16, color: fg),
                const SizedBox(width: 8),
                Text(
                  widget.layer.label,
                  style: TextStyle(
                    fontFamily: SentryTheme.sansFontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
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

class _LotOverlay extends StatefulWidget {
  final LotSummaryDto lot;
  final String shortName;
  final String metric;
  final bool highlighted;
  final bool selected;
  final bool awaitingTelemetry;
  final VoidCallback onTap;

  const _LotOverlay({
    super.key,
    required this.lot,
    required this.shortName,
    required this.metric,
    required this.highlighted,
    required this.selected,
    required this.awaitingTelemetry,
    required this.onTap,
  });

  @override
  State<_LotOverlay> createState() => _LotOverlayState();
}

class _LotOverlayState extends State<_LotOverlay> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final lot = widget.lot;
    final sel = widget.selected;
    final dim = !widget.highlighted && !sel;
    final pending = lot.isSchematicPending && lot.totalSpaces == 0;
    final statusColor = widget.awaitingTelemetry || pending
        ? p.muted
        : lot.conflictCount > 0
            ? p.err
            : lot.cameraStale
                ? p.warn
                : lot.trulyAvailableSpaces > 0
                    ? p.ok
                    : SentryColors.crimson;

    final fill = sel
        ? SentryColors.crimson.withValues(alpha: p.isDark ? 0.20 : 0.14)
        : dim
            ? (p.isDark
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.60))
            : (_hover
                ? SentryColors.crimson.withValues(alpha: 0.06)
                : Colors.transparent);
    final border = sel
        ? SentryColors.crimson
        : _hover && !widget.awaitingTelemetry
            ? SentryColors.crimson.withValues(alpha: 0.65)
            : (p.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFF0F172A).withValues(alpha: 0.06));

    final pillBg = sel
        ? SentryColors.crimson
        : (p.isDark
            ? const Color(0xFF0C0D10).withValues(alpha: 0.86)
            : Colors.white.withValues(alpha: 0.94));
    final pillFg = sel ? Colors.white : p.text;
    final pillSub = sel ? Colors.white.withValues(alpha: 0.82) : p.slate;

    final pin = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: SentryMotion.of(context, const Duration(milliseconds: 180)),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: sel
                    ? SentryColors.crimson.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: p.isDark ? 0.5 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: sel ? Colors.white : statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                lot.lotCode,
                style: TextStyle(
                  fontFamily: SentryTheme.sansFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: pillFg,
                ),
              ),
              Text(
                '  ·  ${widget.shortName}',
                style: TextStyle(
                  fontFamily: SentryTheme.sansFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: pillSub,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 1.5,
          height: 12,
          color: (sel ? SentryColors.crimson : p.text).withValues(alpha: 0.5),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: sel ? SentryColors.crimson : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: sel ? Colors.white : statusColor,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (sel ? SentryColors.crimson : statusColor).withValues(alpha: 0.45),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        if (!dim) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.isDark
                  ? const Color(0xFF0C0D10).withValues(alpha: 0.78)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              widget.metric,
              style: TextStyle(
                fontFamily: SentryTheme.sansFontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: !widget.awaitingTelemetry,
      label: 'Lot ${lot.lotCode} ${widget.shortName}, ${widget.metric}',
      child: MouseRegion(
        cursor: widget.awaitingTelemetry
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.awaitingTelemetry ? null : widget.onTap,
          child: AnimatedContainer(
            duration: SentryMotion.of(context, const Duration(milliseconds: 220)),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: sel ? 2 : 1.2),
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: SentryColors.crimson.withValues(alpha: 0.45),
                        blurRadius: 28,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: OverflowBox(
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: 0,
              maxHeight: double.infinity,
              child: AnimatedOpacity(
                duration: SentryMotion.of(context, const Duration(milliseconds: 180)),
                opacity: dim ? 0.55 : 1,
                child: pin,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScaleBar extends StatelessWidget {
  const _ScaleBar();

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final c = p.isDark ? Colors.white.withValues(alpha: 0.55) : p.slate;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.navigation_rounded, size: 13, color: c),
        const SizedBox(width: 10),
        Container(
          width: 56,
          height: 6,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: c, width: 1.2),
              right: BorderSide(color: c, width: 1.2),
              bottom: BorderSide(color: c, width: 1.2),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '50 m',
          style: TextStyle(
            fontFamily: SentryTheme.sansFontFamily,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: c,
          ),
        ),
      ],
    );
  }
}

class _LotCallout extends StatelessWidget {
  final LotSummaryDto lot;
  final String shortName;
  final List<SpaceDto> spaces;
  final VoidCallback onClose;
  final VoidCallback onBreakdown;
  final VoidCallback onOpen;

  const _LotCallout({
    super.key,
    required this.lot,
    required this.shortName,
    required this.spaces,
    required this.onClose,
    required this.onBreakdown,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final pending = lot.isSchematicPending && lot.totalSpaces == 0;
    final full = !pending && lot.trulyAvailableSpaces == 0;
    final badge = pending
        ? ('Survey pending', SoftChipTone.neutral)
        : lot.conflictCount > 0
            ? ('Needs attention', SoftChipTone.crimson)
            : full
                ? ('Lot full', SoftChipTone.crimson)
                : ('Open for entry', SoftChipTone.ok);
    final formal = spaces.where((s) => s.isFormalAllocatableBay).toList();

    return SpatialGlass(
      strong: true,
      radius: 22,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero: live miniature of the lot's bays.
          Container(
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: p.isDark ? const Color(0xFF111216) : const Color(0xFFDDE3EA),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: _MiniBayPainter(
                        spaces: formal,
                        palette: p,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: SoftChip(badge.$1, tone: badge.$2),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Material(
                    color: p.isDark
                        ? Colors.black.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.85),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onClose,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded, size: 16, color: p.text),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lot ${lot.lotCode} · $shortName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: panelTitleStyle(p, size: 18),
                ),
                const SizedBox(height: 3),
                Text(
                  pending
                      ? 'Near ${lot.nearestLandmark}'
                      : '${lot.totalSpaces} formal bays · near ${lot.nearestLandmark}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SentryTheme.sansFontFamily,
                    fontSize: 12.5,
                    color: p.muted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: BigFigure(
                        value: Text(
                          pending ? '—' : '${lot.trulyAvailableSpaces}',
                          style: bigFigureStyle(p, size: 34),
                        ),
                        unit: pending ? 'bays mapped' : 'of ${lot.totalSpaces} free',
                      ),
                    ),
                    if (!pending)
                      Text(
                        '${lot.physicalOccupied} parked',
                        style: TextStyle(
                          fontFamily: SentryTheme.sansFontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: p.slate,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                CapacityBar(
                  height: 7,
                  segments: [
                    CapacitySegment(lot.trulyAvailableSpaces, p.ok, 'free'),
                    CapacitySegment(lot.physicalOccupied, SentryColors.crimson, 'occupied'),
                    CapacitySegment(lot.allocationHeld, p.warn, 'held'),
                    CapacitySegment(lot.physicalUnknownOrStale, p.muted, 'unknown'),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (lot.allocationHeld > 0)
                      SoftChip('${lot.allocationHeld} held at gate',
                          tone: SoftChipTone.warn),
                    if (lot.conflictCount > 0)
                      SoftChip(
                          lot.conflictCount == 1
                              ? '1 conflict'
                              : '${lot.conflictCount} conflicts',
                          tone: SoftChipTone.crimson),
                    if (lot.physicalUnknownOrStale > 0)
                      SoftChip('${lot.physicalUnknownOrStale} unknown',
                          tone: SoftChipTone.neutral),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: Key('callout_open_lot_${lot.lotCode}'),
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: SentryColors.crimson,
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'Open lot blueprint',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 17),
              ],
            ),
          ),
          TextButton(
            onPressed: onBreakdown,
            child: const Text('Camera vs. reservation breakdown'),
          ),
        ],
      ),
    );
  }
}

/// Paints a live miniature of a lot: one rounded cell per formal bay colored
/// by state (free / occupied / held / unknown).
class _MiniBayPainter extends CustomPainter {
  final List<SpaceDto> spaces;
  final SentryPalette palette;
  _MiniBayPainter({required this.spaces, required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final n = spaces.length;
    final stripe = Paint()
      ..color = palette.isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    for (double x = 8; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stripe);
    }
    if (n == 0) return;
    final cols = math.max(1, (n / 2).ceil());
    final cellW = (size.width - 24) / cols;
    const cellH = 24.0;
    final rows = [size.height / 2 - cellH - 3, size.height / 2 + 3];
    for (var i = 0; i < n; i++) {
      final s = spaces[i];
      final row = i < cols ? 0 : 1;
      final col = i % cols;
      final rect = Rect.fromLTWH(
          12 + col * cellW + 1.5, rows[row] + 8, cellW - 3, cellH);
      final color = s.isTrulyAvailableForAllocation
          ? palette.ok
          : s.hasOccupancyConflict
              ? palette.err
              : s.isUnknownOrStale
                  ? palette.muted
                  : s.allocationStatus == 'held'
                      ? palette.warn
                      : SentryColors.crimson;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = color.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBayPainter old) =>
      old.spaces != spaces || old.palette.isDark != palette.isDark;
}
