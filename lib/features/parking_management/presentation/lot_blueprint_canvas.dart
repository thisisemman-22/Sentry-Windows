import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../core/widgets/vehicle_top_down_svg.dart';
import '../../../shared/models/parking_models.dart';
import '../../overview/presentation/spatial_glass.dart';

/// Interactive overhead blueprint canvas for BatStateU Alangilan Campus
/// Parking Lots `B1–B5`.
///
/// Supports animated zoom/pan via [InteractiveViewer] inside a spatial
/// architectural drafting grid canvas with floating translucent lot tabs,
/// bottom-left floating legend chips, bottom-right floating zoom controls
/// (`+`, `-`, `Reset`), and crisp selection rings.
class LotBlueprintCanvas extends StatefulWidget {
  final ParkingLotZoneMeta lotMeta;
  final List<SpaceDto> lotSpaces;
  final String? selectedSpaceCode;
  final bool awaitingTelemetry;
  final ValueChanged<SpaceDto> onSelectSpace;
  final VoidCallback? onRetryTelemetry;
  final double topInset;

  const LotBlueprintCanvas({
    super.key,
    required this.lotMeta,
    required this.lotSpaces,
    required this.selectedSpaceCode,
    required this.awaitingTelemetry,
    required this.onSelectSpace,
    this.onRetryTelemetry,
    this.topInset = 74.0,
  });

  @override
  State<LotBlueprintCanvas> createState() => _LotBlueprintCanvasState();
}

class _LotBlueprintCanvasState extends State<LotBlueprintCanvas>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformCtrl = TransformationController();
  late final AnimationController _zoomAnimCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnim;

  @override
  void initState() {
    super.initState();
    _zoomAnimCtrl.addListener(() {
      if (_zoomAnim != null) {
        _transformCtrl.value = _zoomAnim!.value;
      }
    });
  }

  @override
  void didUpdateWidget(covariant LotBlueprintCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lotMeta.lotCode != widget.lotMeta.lotCode) {
      _zoomAnimCtrl.stop();
      _transformCtrl.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _zoomAnimCtrl.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  void _animateToMatrix(Matrix4 target) {
    if (SentryMotion.reduced(context)) {
      _transformCtrl.value = target;
      return;
    }
    _zoomAnim = Matrix4Tween(
      begin: _transformCtrl.value.clone(),
      end: target,
    ).animate(
      CurvedAnimation(parent: _zoomAnimCtrl, curve: Curves.easeOutCubic),
    );
    _zoomAnimCtrl.forward(from: 0);
  }

  void _zoomBy(double factor) {
    final next = _transformCtrl.value.clone()
      ..scaleByDouble(factor, factor, 1.0, 1.0);
    final currentScale = next.getMaxScaleOnAxis();
    if (currentScale < 0.45 || currentScale > 2.2) return;
    _animateToMatrix(next);
  }

  void _resetZoom() {
    _animateToMatrix(Matrix4.identity());
  }

  SpaceDto _findOrPlaceholder({
    required String spaceCode,
    required String slotLabel,
    SpaceSlotCategory category = SpaceSlotCategory.formal,
    String compatibility = 'car_only',
    bool isPwd = false,
    bool isPartlyOutOfView = false,
    bool isFarEnd = false,
  }) {
    for (final s in widget.lotSpaces) {
      if (s.spaceCode == spaceCode) return s;
    }
    return SpaceDto(
      spaceId: 'wireframe-$spaceCode',
      spaceCode: spaceCode,
      lotCode: widget.lotMeta.lotCode,
      slotLabel: slotLabel,
      slotCategory: category,
      isAccessiblePwd: isPwd,
      isPartlyOutOfView: isPartlyOutOfView,
      isFarEnd: isFarEnd,
      compatibility: compatibility,
      physicalStatus: widget.awaitingTelemetry ? 'awaiting' : 'unknown',
      allocationStatus: 'unassigned',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final lotCode = widget.lotMeta.lotCode;
    final zoneDisplayName = widget.lotMeta.resolveName(widget.lotSpaces);

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasHeight = constraints.maxWidth < 700 ? 560.0 : 740.0;
        final legendChips = [
          if (!widget.awaitingTelemetry) ...[
            LegendDot(color: p.ok, label: 'Free'),
            LegendDot(color: p.warn, label: 'Held 30s'),
            LegendDot(color: p.crimson, label: 'Occupied'),
            LegendDot(color: p.err, label: 'Conflict'),
          ] else ...[
            LegendDot(color: p.muted, label: 'Awaiting telemetry'),
          ],
          const LegendDot(color: Color(0xFF0284C7), label: 'PWD / Accessible'),
          const LegendDot(color: Color(0xFF7C3AED), label: 'Motorcycle'),
          LegendDot(color: p.muted, label: 'Informal Aisle'),
          if (!widget.awaitingTelemetry)
            LegendDot(
              color: p.muted.withValues(alpha: 0.55),
              label: 'Unknown',
            ),
        ];

        return Container(
          height: (lotCode == 'B4' || lotCode == 'B5') ? null : canvasHeight,
          constraints: (lotCode == 'B4' || lotCode == 'B5')
              ? const BoxConstraints(minHeight: 380)
              : null,
          decoration: BoxDecoration(
            color: p.isDark ? const Color(0xFF0A0B0E) : const Color(0xFFE5EAF0),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.line, width: 1.4),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ArchitecturalGridPainter(
                    minorColor: p.line.withValues(alpha: p.isDark ? 0.28 : 0.45),
                    majorColor: p.line.withValues(alpha: p.isDark ? 0.52 : 0.78),
                    isDark: p.isDark,
                  ),
                ),
              ),
              if (lotCode == 'B4')
                Padding(
                  padding: EdgeInsets.fromLTRB(22, widget.topInset, 22, 74),
                  child: _buildLotB4SchematicPending(context, p),
                )
              else if (lotCode == 'B5')
                Padding(
                  padding: EdgeInsets.fromLTRB(22, widget.topInset, 22, 74),
                  child: _buildLotB5OverflowGrid(context, p),
                )
              else
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transformCtrl,
                    constrained: false,
                    minScale: 0.45,
                    maxScale: 2.2,
                    boundaryMargin: const EdgeInsets.all(64),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, widget.topInset, 24, 76),
                      child: switch (lotCode) {
                        'B1' => _buildLotB1Schematic(context, p),
                        'B2' => _buildLotB2Schematic(context, p),
                        _ => _buildLotB3Schematic(context, p),
                      },
                    ),
                  ),
                ),

              // Centered frosted notice when DATA_SOURCE=real is awaiting telemetry
              if (widget.awaitingTelemetry)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SpatialGlass(
                        strong: true,
                        radius: 22,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 22),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
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
                                child: const Icon(
                                  Icons.local_parking_rounded,
                                  color: SentryColors.crimson,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Awaiting lot telemetry',
                                textAlign: TextAlign.center,
                                style: SentryTheme.display(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: p.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Waiting for live bay availability for Lot $lotCode ($zoneDisplayName). Clean wireframe is shown below without mock occupancy.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (widget.onRetryTelemetry != null) ...[
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  key: const Key('parking_retry_button'),
                                  onPressed: widget.onRetryTelemetry,
                                  icon:
                                      const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Floating Bottom-Left Legend Chips
              Positioned(
                bottom: 12,
                left: 12,
                right: 172,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SpatialGlass(
                    strong: true,
                    radius: 999,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < legendChips.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            legendChips[i],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Bottom-Right Zoom / Reset Controls (+, -, Reset)
              Positioned(
                bottom: 12,
                right: 12,
                child: SpatialGlass(
                  strong: true,
                  radius: 999,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const Key('blueprint_zoom_out_btn'),
                        tooltip: 'Zoom out',
                        constraints:
                            const BoxConstraints(minWidth: 34, minHeight: 34),
                        padding: EdgeInsets.zero,
                        onPressed: () => _zoomBy(0.85),
                        icon: const Icon(Icons.remove_rounded, size: 18),
                      ),
                      TextButton(
                        key: const Key('blueprint_reset_zoom_btn'),
                        onPressed: _resetZoom,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(
                          'Reset',
                          style: SentryTheme.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('blueprint_zoom_in_btn'),
                        tooltip: 'Zoom in',
                        constraints:
                            const BoxConstraints(minWidth: 34, minHeight: 34),
                        padding: EdgeInsets.zero,
                        onPressed: () => _zoomBy(1.18),
                        icon: const Icon(Icons.add_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDirectionBanner(SentryPalette p, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: p.subtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: p.muted),
          const SizedBox(width: 8),
          Text(
            label,
            style: SentryTheme.eyebrow(color: p.muted),
          ),
        ],
      ),
    );
  }

  /// Surveyed Schematic #1: Lot B1 — Albert Einstein / CEAFA Left
  /// - Left column: L1 (bottom) up to L10 (confirmed) + L11 (top, hatched unconfirmed)
  /// - Right column: R1 (bottom) up to R8 + R9–R10 far-end + R11 (top, hatched unconfirmed)
  /// - Center middle block: M7, M6, M5 stacked above M2; M1, M2, M3 side-by-side; M4 bottom horizontal
  Widget _buildLotB1Schematic(BuildContext context, SentryPalette p) {
    final leftSlots = [
      for (var i = 11; i >= 1; i--)
        _findOrPlaceholder(
          spaceCode: 'B1-L$i',
          slotLabel: 'L$i',
          category: i == 11
              ? SpaceSlotCategory.unconfirmedFarEnd
              : SpaceSlotCategory.formal,
          isFarEnd: i == 11,
        ),
    ];
    final rightSlots = [
      for (var i = 11; i >= 1; i--)
        _findOrPlaceholder(
          spaceCode: 'B1-R$i',
          slotLabel: 'R$i',
          category: i == 11
              ? SpaceSlotCategory.unconfirmedFarEnd
              : SpaceSlotCategory.formal,
          isFarEnd: i >= 9,
        ),
    ];
    final mSlots = {
      for (var i = 1; i <= 7; i++)
        i: _findOrPlaceholder(spaceCode: 'B1-M$i', slotLabel: 'M$i'),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDirectionBanner(
          p,
          'FAR END OF LOT · 2.4M × 5.0M BAYS',
          Icons.north_rounded,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left Column L11 -> L1
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < leftSlots.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _BlueprintSlotTile(
                    space: leftSlots[i],
                    width: 144,
                    height: 44,
                    selected: leftSlots[i].spaceCode == widget.selectedSpaceCode,
                    awaitingTelemetry: widget.awaitingTelemetry,
                    onTap: () => widget.onSelectSpace(leftSlots[i]),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 24),

            // Center Middle Block (M7/M6/M5 stacked above M2; M1-M3 row; M4 horizontal)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DRIVEWAY AISLE',
                  style: SentryTheme.eyebrow(color: p.muted),
                ),
                const SizedBox(height: 14),
                // Upper-middle 3 stacked bays centered above M2
                _BlueprintSlotTile(
                  space: mSlots[7]!,
                  width: 118,
                  height: 44,
                  selected: mSlots[7]!.spaceCode == widget.selectedSpaceCode,
                  awaitingTelemetry: widget.awaitingTelemetry,
                  onTap: () => widget.onSelectSpace(mSlots[7]!),
                ),
                const SizedBox(height: 4),
                _BlueprintSlotTile(
                  space: mSlots[6]!,
                  width: 118,
                  height: 44,
                  selected: mSlots[6]!.spaceCode == widget.selectedSpaceCode,
                  awaitingTelemetry: widget.awaitingTelemetry,
                  onTap: () => widget.onSelectSpace(mSlots[6]!),
                ),
                const SizedBox(height: 4),
                _BlueprintSlotTile(
                  space: mSlots[5]!,
                  width: 118,
                  height: 44,
                  selected: mSlots[5]!.spaceCode == widget.selectedSpaceCode,
                  awaitingTelemetry: widget.awaitingTelemetry,
                  onTap: () => widget.onSelectSpace(mSlots[5]!),
                ),
                const SizedBox(height: 8),
                // Lower-middle 3 side-by-side vertical bays M1, M2, M3
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final idx in const [1, 2, 3]) ...[
                      if (idx > 1) const SizedBox(width: 6),
                      _BlueprintSlotTile(
                        space: mSlots[idx]!,
                        width: 96,
                        height: 92,
                        verticalBay: true,
                        selected:
                            mSlots[idx]!.spaceCode == widget.selectedSpaceCode,
                        awaitingTelemetry: widget.awaitingTelemetry,
                        onTap: () => widget.onSelectSpace(mSlots[idx]!),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Bottom horizontal bay M4
                _BlueprintSlotTile(
                  space: mSlots[4]!,
                  width: 300,
                  height: 46,
                  selected: mSlots[4]!.spaceCode == widget.selectedSpaceCode,
                  awaitingTelemetry: widget.awaitingTelemetry,
                  onTap: () => widget.onSelectSpace(mSlots[4]!),
                ),
                const SizedBox(height: 16),
              ],
            ),

            const SizedBox(width: 24),
            // Right Column R11 -> R1
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < rightSlots.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _BlueprintSlotTile(
                    space: rightSlots[i],
                    width: 144,
                    height: 44,
                    selected: rightSlots[i].spaceCode == widget.selectedSpaceCode,
                    awaitingTelemetry: widget.awaitingTelemetry,
                    onTap: () => widget.onSelectSpace(rightSlots[i]),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDirectionBanner(
          p,
          'LOT B1 ENTRANCE & EXIT DRIVEWAY',
          Icons.south_rounded,
        ),
      ],
    );
  }

  /// Surveyed Schematic #2: Lot B2 — Gymnasium & STEER Hub
  /// - Far-left motorcycle strip: MB10 at top, gap, 1 down to 9 at bottom (`motorcycle_only`)
  /// - Left car column: L1 (top) down to L8 (partly out of view)
  /// - Center informal aisle: A1 (top), A2 (mid), A3 (lower-left), A4 (taller lower-right)
  /// - Right car column: R1 (top) down to R10 (partly out of view)
  Widget _buildLotB2Schematic(BuildContext context, SentryPalette p) {
    final mb10 = _findOrPlaceholder(
      spaceCode: 'B2-MB10',
      slotLabel: 'MB10',
      compatibility: 'motorcycle_only',
    );
    final moto1To9 = [
      for (var i = 1; i <= 9; i++)
        _findOrPlaceholder(
          spaceCode: 'B2-MB$i',
          slotLabel: '$i',
          compatibility: 'motorcycle_only',
        ),
    ];
    final leftCars = [
      for (var i = 1; i <= 8; i++)
        _findOrPlaceholder(
          spaceCode: 'B2-L$i',
          slotLabel: 'L$i',
          isPartlyOutOfView: i == 8,
        ),
    ];
    final rightCars = [
      for (var i = 1; i <= 10; i++)
        _findOrPlaceholder(
          spaceCode: 'B2-R$i',
          slotLabel: 'R$i',
          isPartlyOutOfView: i == 10,
        ),
    ];
    final aisle = {
      for (var i = 1; i <= 4; i++)
        i: _findOrPlaceholder(
          spaceCode: 'B2-A$i',
          slotLabel: 'A$i',
          category: SpaceSlotCategory.informalAisle,
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Far-left Motorcycle Strip
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MOTO STRIP',
                style: SentryTheme.eyebrow(color: const Color(0xFF7C3AED)),
              ),
              const SizedBox(height: 8),
              _BlueprintSlotTile(
                space: mb10,
                width: 118,
                height: 50,
                selected: mb10.spaceCode == widget.selectedSpaceCode,
                awaitingTelemetry: widget.awaitingTelemetry,
                onTap: () => widget.onSelectSpace(mb10),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < moto1To9.length; i++) ...[
                if (i > 0) const SizedBox(height: 5),
                _BlueprintSlotTile(
                  space: moto1To9[i],
                  width: 118,
                  height: 50,
                  selected: moto1To9[i].spaceCode == widget.selectedSpaceCode,
                  awaitingTelemetry: widget.awaitingTelemetry,
                  onTap: () => widget.onSelectSpace(moto1To9[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 22),

        // Left Car Column (L1..L8)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LEFT COLUMN', style: SentryTheme.eyebrow(color: p.muted)),
            const SizedBox(height: 8),
            for (var i = 0; i < leftCars.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              _BlueprintSlotTile(
                space: leftCars[i],
                width: 146,
                height: 56,
                selected: leftCars[i].spaceCode == widget.selectedSpaceCode,
                awaitingTelemetry: widget.awaitingTelemetry,
                onTap: () => widget.onSelectSpace(leftCars[i]),
              ),
            ],
          ],
        ),
        const SizedBox(width: 16),

        // Center Informal Aisle Zones (A1..A4)
        SizedBox(
          width: 226,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'INFORMAL AISLE (NON-BAY)',
                style: SentryTheme.eyebrow(color: p.muted),
              ),
              const SizedBox(height: 22),
              _BlueprintSlotTile(
                space: aisle[1]!,
                width: 170,
                height: 58,
                selected: aisle[1]!.spaceCode == widget.selectedSpaceCode,
                awaitingTelemetry: widget.awaitingTelemetry,
                onTap: () => widget.onSelectSpace(aisle[1]!),
              ),
              const SizedBox(height: 64),
              _BlueprintSlotTile(
                space: aisle[2]!,
                width: 170,
                height: 58,
                selected: aisle[2]!.spaceCode == widget.selectedSpaceCode,
                awaitingTelemetry: widget.awaitingTelemetry,
                onTap: () => widget.onSelectSpace(aisle[2]!),
              ),
              const SizedBox(height: 54),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BlueprintSlotTile(
                    space: aisle[3]!,
                    width: 102,
                    height: 68,
                    selected: aisle[3]!.spaceCode == widget.selectedSpaceCode,
                    awaitingTelemetry: widget.awaitingTelemetry,
                    onTap: () => widget.onSelectSpace(aisle[3]!),
                  ),
                  const SizedBox(width: 8),
                  _BlueprintSlotTile(
                    space: aisle[4]!,
                    width: 112,
                    height: 102,
                    selected: aisle[4]!.spaceCode == widget.selectedSpaceCode,
                    awaitingTelemetry: widget.awaitingTelemetry,
                    onTap: () => widget.onSelectSpace(aisle[4]!),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Right Car Column (R1..R10)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('RIGHT COLUMN', style: SentryTheme.eyebrow(color: p.muted)),
            const SizedBox(height: 8),
            for (var i = 0; i < rightCars.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              _BlueprintSlotTile(
                space: rightCars[i],
                width: 146,
                height: 52,
                selected: rightCars[i].spaceCode == widget.selectedSpaceCode,
                awaitingTelemetry: widget.awaitingTelemetry,
                onTap: () => widget.onSelectSpace(rightCars[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Surveyed Schematic #3: Lot B3 — Albert Einstein / CEAFA Right
  /// - Left column: L1 (top) down to L9 (bottom, level with R10)
  /// - Center: A3 (top), A1 (larger jeepney-length block), A2 (lower-mid) [all informal],
  ///   + formal center-bottom painted bay C1 aligned with L8–L9 / R9–R10
  /// - Right column: R1 (top) down to R10 (bottom, PWD / Accessible badge + icon)
  Widget _buildLotB3Schematic(BuildContext context, SentryPalette p) {
    final leftCars = [
      for (var i = 1; i <= 9; i++)
        _findOrPlaceholder(spaceCode: 'B3-L$i', slotLabel: 'L$i'),
    ];
    final rightCars = [
      for (var i = 1; i <= 10; i++)
        _findOrPlaceholder(
          spaceCode: 'B3-R$i',
          slotLabel: 'R$i',
          isPwd: i == 10,
        ),
    ];
    final c1 = _findOrPlaceholder(
      spaceCode: 'B3-C1',
      slotLabel: 'C1',
      category: SpaceSlotCategory.formalCenterPainted,
    );
    final a3 = _findOrPlaceholder(
      spaceCode: 'B3-A3',
      slotLabel: 'A3',
      category: SpaceSlotCategory.informalAisle,
    );
    final a1 = _findOrPlaceholder(
      spaceCode: 'B3-A1',
      slotLabel: 'A1',
      category: SpaceSlotCategory.informalAisle,
    );
    final a2 = _findOrPlaceholder(
      spaceCode: 'B3-A2',
      slotLabel: 'A2',
      category: SpaceSlotCategory.informalAisle,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Left Car Column L1..L9 (offset down by 1 bay = 50px so L9 bottoms align with R10!)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LEFT COLUMN (L1–L9)', style: SentryTheme.eyebrow(color: p.muted)),
            const SizedBox(height: 8),
            const SizedBox(height: 50),
            for (var i = 0; i < leftCars.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              _BlueprintSlotTile(
                space: leftCars[i],
                width: 150,
                height: 46,
                selected: leftCars[i].spaceCode == widget.selectedSpaceCode,
                awaitingTelemetry: widget.awaitingTelemetry,
                onTap: () => widget.onSelectSpace(leftCars[i]),
              ),
            ],
          ],
        ),
        const SizedBox(width: 24),

        // Center Informal Aisle + Center Painted Bay C1
        SizedBox(
          width: 204,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'INFORMAL / CENTER BAY',
                style: SentryTheme.eyebrow(color: p.muted),
              ),
              const SizedBox(height: 14),
              _BlueprintSlotTile(
                space: a3,
                width: 184,
                height: 48,
                selected: a3.spaceCode == widget.selectedSpaceCode,
                awaitingTelemetry: widget.awaitingTelemetry,
                onTap: () => widget.onSelectSpace(a3),
              ),
              const SizedBox(height: 16),
              _BlueprintSlotTile(
                space: a1,
                width: 184,
                height: 98,
                customSubTag: 'Jeepney-len',
                selected: a1.spaceCode == widget.selectedSpaceCode,
                awaitingTelemetry: widget.awaitingTelemetry,
                onTap: () => widget.onSelectSpace(a1),
              ),
              const SizedBox(height: 16),
              _BlueprintSlotTile(
                space: a2,
                width: 184,
                height: 54,
                selected: a2.spaceCode == widget.selectedSpaceCode,
                awaitingTelemetry: widget.awaitingTelemetry,
                onTap: () => widget.onSelectSpace(a2),
              ),
              const SizedBox(height: 102),
              // Center formal painted bay aligned with L8–L9 / R9–R10
              _BlueprintSlotTile(
                space: c1,
                width: 184,
                height: 76,
                customSubTag: 'Center formal',
                selected: c1.spaceCode == widget.selectedSpaceCode,
                awaitingTelemetry: widget.awaitingTelemetry,
                onTap: () => widget.onSelectSpace(c1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),

        // Right Car Column R1..R10 (R10 carries explicit PWD badge & icon)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('RIGHT COLUMN (R1–R10)', style: SentryTheme.eyebrow(color: p.muted)),
            const SizedBox(height: 8),
            for (var i = 0; i < rightCars.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              _BlueprintSlotTile(
                space: rightCars[i],
                width: 156,
                height: 46,
                selected: rightCars[i].spaceCode == widget.selectedSpaceCode,
                awaitingTelemetry: widget.awaitingTelemetry,
                onTap: () => widget.onSelectSpace(rightCars[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Schematic #4: Lot B4 — CET Building (Schematic Pending + dynamic backend grid)
  Widget _buildLotB4SchematicPending(BuildContext context, SentryPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Callout(
          tone: PillTone.neutral,
          icon: Icons.architecture_outlined,
          title: 'Lot B4 (CET) — Survey schematic pending; awaiting backend space coordinates',
          message:
              'Once backend coordinates for CET Building spaces are published, dynamic bay cards render below automatically.',
        ),
        if (widget.lotSpaces.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildDynamicSpaceGrid(),
        ],
      ],
    );
  }

  /// Schematic #5: Lot B5 — Overflow Lot (Dynamic Grid)
  Widget _buildLotB5OverflowGrid(BuildContext context, SentryPalette p) {
    if (widget.lotSpaces.isEmpty) {
      return const Callout(
        tone: PillTone.neutral,
        icon: Icons.layers_outlined,
        title: 'Overflow Zone — Wireframe ready',
        message:
            'Overflow bays for Lot B5 appear dynamically as soon as live telemetry is received.',
      );
    }
    return _buildDynamicSpaceGrid();
  }

  Widget _buildDynamicSpaceGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final s in widget.lotSpaces)
          _BlueprintSlotTile(
            space: s,
            width: 168,
            height: 68,
            selected: s.spaceCode == widget.selectedSpaceCode,
            awaitingTelemetry: widget.awaitingTelemetry,
            onTap: () => widget.onSelectSpace(s),
          ),
      ],
    );
  }
}

class _BlueprintSlotTile extends StatelessWidget {
  final SpaceDto space;
  final double width;
  final double height;
  final bool selected;
  final bool awaitingTelemetry;
  final bool verticalBay;
  final String? customSubTag;
  final VoidCallback onTap;

  const _BlueprintSlotTile({
    required this.space,
    required this.width,
    required this.height,
    required this.selected,
    required this.awaitingTelemetry,
    this.verticalBay = false,
    this.customSubTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final isMoto = space.compatibility == 'motorcycle_only';
    final isPwd = space.isAccessiblePwd;
    final isUnconfirmed = space.isUnconfirmed;
    final isInformal = space.isInformalAisle;
    final isCenterPainted =
        space.slotCategory == SpaceSlotCategory.formalCenterPainted;

    Color bg = p.card;
    Color borderColor = selected ? p.crimson : p.line;
    double borderWidth = selected ? 2.2 : 1.2;

    if (awaitingTelemetry) {
      bg = p.card;
      if (isUnconfirmed) bg = p.subtle;
    } else if (isUnconfirmed) {
      bg = p.subtle;
    } else if (isInformal) {
      bg = space.physicalStatus == 'occupied'
          ? p.warnTint
          : p.subtle.withValues(alpha: 0.75);
      borderColor = selected ? p.crimson : p.muted;
    } else if (space.hasOccupancyConflict) {
      bg = p.errTint;
      borderColor = selected ? p.text : p.err;
      borderWidth = 2.0;
    } else if (space.isUnknownOrStale) {
      bg = p.subtle;
    } else if (space.allocationStatus == 'held') {
      bg = p.warnTint;
      borderColor = p.warn;
    } else if (space.isTrulyAvailableForAllocation) {
      bg = p.okTint;
      borderColor = isCenterPainted
          ? const Color(0xFF0D9488)
          : (isMoto ? const Color(0xFF7C3AED) : p.ok);
    } else if (space.allocationStatus == 'assigned' ||
        space.physicalStatus == 'occupied') {
      bg = p.crimsonTint;
      borderColor = p.crimson;
    }

    if (isCenterPainted && !selected) {
      borderColor = const Color(0xFF0D9488);
      borderWidth = 2.0;
    } else if (isMoto && !selected) {
      borderColor = const Color(0xFF7C3AED);
    } else if (isPwd && !selected) {
      borderColor = const Color(0xFF0284C7);
      borderWidth = 2.0;
    }

    final statusShort = awaitingTelemetry
        ? (isUnconfirmed
            ? 'Unconfirmed'
            : (isInformal ? 'Informal' : 'Awaiting'))
        : isUnconfirmed
            ? 'Unconfirmed'
            : isInformal
                ? (space.physicalStatus == 'occupied'
                    ? 'Informal · Occ'
                    : 'Informal / Aisle')
                : space.hasOccupancyConflict
                    ? 'Conflict'
                    : space.isUnknownOrStale
                        ? 'Unknown'
                        : space.allocationStatus == 'held'
                            ? 'Held (30s)'
                            : space.isTrulyAvailableForAllocation
                                ? 'Free'
                                : 'Occupied';

    final selectedRingColor = space.isTrulyAvailableForAllocation
        ? p.ok
        : SentryColors.crimson;
    if (selected) {
      borderColor = selectedRingColor;
      borderWidth = 2.4;
    }

    final core = AnimatedContainer(
      duration: SentryMotion.of(context, const Duration(milliseconds: 180)),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: isInformal
            ? null
            : Border.all(color: borderColor, width: borderWidth),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: selectedRingColor.withValues(alpha: 0.32),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (isUnconfirmed)
            const Positioned.fill(
              child: CustomPaint(painter: _DiagonalHatchPainter()),
            ),
          if (isInformal)
            Positioned.fill(
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: borderColor,
                  strokeWidth: selected ? 2.2 : 1.5,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: verticalBay ? 4 : 2,
            ),
            child: verticalBay
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          space.displaySlotLabel,
                          style: SentryTheme.mono(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: p.text,
                          ),
                        ),
                      ),
                      if (!awaitingTelemetry &&
                          !isUnconfirmed &&
                          space.physicalStatus == 'occupied')
                        RotatedBox(
                          quarterTurns: 1,
                          child: VehicleTopDownSvg(
                            vehicleType: isMoto ? 'motorcycle' : 'car',
                            primaryColor: space.hasOccupancyConflict
                                ? p.err
                                : SentryColors.crimson,
                            width: 34,
                            height: 18,
                          ),
                        )
                      else
                        Icon(
                          isMoto
                              ? Icons.two_wheeler_outlined
                              : Icons.directions_car_outlined,
                          size: 16,
                          color: p.muted,
                        ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          statusShort,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: p.slate,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                space.displaySlotLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SentryTheme.mono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: p.text,
                                ).copyWith(height: 1.05),
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (isPwd)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.accessible_rounded,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'PWD',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1.05,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (isMoto)
                              const Icon(
                                Icons.two_wheeler_outlined,
                                size: 13,
                                color: Color(0xFF7C3AED),
                              ),
                            const Spacer(),
                            if (!awaitingTelemetry &&
                                !isUnconfirmed &&
                                space.physicalStatus == 'occupied')
                              VehicleTopDownSvg(
                                vehicleType: isMoto ? 'motorcycle' : 'car',
                                primaryColor: space.hasOccupancyConflict
                                    ? p.err
                                    : SentryColors.crimson,
                                width: 28,
                                height: 13,
                              ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                customSubTag != null
                                    ? '$statusShort · $customSubTag'
                                    : (space.isPartlyOutOfView
                                        ? '$statusShort · Edge'
                                        : statusShort),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w700,
                                  color: space.hasOccupancyConflict
                                      ? p.errText
                                      : (isUnconfirmed ? p.muted : p.slate),
                                  height: 1.05,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );

    if (awaitingTelemetry) {
      return Tooltip(
        message: '${space.spaceCode} · Awaiting telemetry',
        child: core,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('bay_card_${space.spaceCode}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: core,
      ),
    );
  }
}

class _DiagonalHatchPainter extends CustomPainter {
  const _DiagonalHatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.22)
      ..strokeWidth = 1.2;
    const step = 10.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    final path = Path()..addRRect(rrect);
    const dashLen = 6.0;
    const gapLen = 4.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = math.min(dist + dashLen, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class _ArchitecturalGridPainter extends CustomPainter {
  final Color minorColor;
  final Color majorColor;
  final bool isDark;

  const _ArchitecturalGridPainter({
    required this.minorColor,
    required this.majorColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final foliageTint = Paint()
      ..color = isDark
          ? const Color(0xFF0E1812).withValues(alpha: 0.45)
          : const Color(0xFFCCE0D0).withValues(alpha: 0.45);
    canvas.drawCircle(
        Offset(size.width * 0.94, size.height * 0.14), 110, foliageTint);
    canvas.drawCircle(
        Offset(size.width * 0.90, size.height * 0.78), 140, foliageTint);

    final minor = Paint()
      ..color = minorColor
      ..strokeWidth = 0.7;
    final major = Paint()
      ..color = majorColor
      ..strokeWidth = 1.0;

    const minorStep = 24.0;
    const majorEvery = 4;

    for (var i = 0; i * minorStep <= size.width; i++) {
      final x = i * minorStep;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i % majorEvery == 0 ? major : minor,
      );
    }
    for (var j = 0; j * minorStep <= size.height; j++) {
      final y = j * minorStep;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        j % majorEvery == 0 ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArchitecturalGridPainter oldDelegate) =>
      oldDelegate.minorColor != minorColor ||
      oldDelegate.majorColor != majorColor ||
      oldDelegate.isDark != isDark;
}
