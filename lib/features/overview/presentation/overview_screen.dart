import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/desktop_shell.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/attempt_models.dart';
import '../../../shared/models/parking_models.dart';
import '../../../shared/models/spec_2026_models.dart';
import '../../access_logs/presentation/report_export_dialog.dart';
import 'campus_tactical_map.dart';
import 'overview_charts.dart';
import 'spatial_glass.dart';

/// View 2: `Overview` — Full-bleed Spatial Command-Center Canvas inspired by
/// the Vinora OS reference adapted into BatStateU Crimson + Pure OLED / Porcelain.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final sysState = ref.watch(sentryScenarioProvider);
    final opsState = ref.watch(desktopOpsControllerProvider);
    final config = ref.watch(appConfigProvider);
    final isAdmin =
        ref.watch(authControllerProvider.select((s) => s.role.isAdmin));
    final kpis = sysState.computeDashboardKpis();
    final lotSummaries = sysState.computeLotSummaries();
    final hasLiveSnapshot = !config.isReal ||
        sysState.spaces.isNotEmpty ||
        sysState.visits.isNotEmpty ||
        sysState.devices.isNotEmpty;
    final awaitingLotTelemetry = config.isReal && sysState.spaces.isEmpty;
    final activeAttempt = _pickFocusAttempt(sysState.activeLaneAttempts.values);
    final occupancyRatio = kpis.totalCampusSpaces > 0
        ? (1.0 - (kpis.trulyAvailableSpaces / kpis.totalCampusSpaces))
            .clamp(0.0, 1.0)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktopSpatial =
            constraints.maxWidth >= 1020 && constraints.maxHeight >= 640;

        if (!desktopSpatial) {
          return _CompactSpatialOverview(
            sysState: sysState,
            kpis: kpis,
            lotSummaries: lotSummaries,
            hasLiveSnapshot: hasLiveSnapshot,
            awaitingLotTelemetry: awaitingLotTelemetry,
            isRealMode: config.isReal,
            activeAttempt: activeAttempt,
            occupancyRatio: occupancyRatio,
            onInspectLot: (lot) => _showLotDetails(context, ref, lot),
          );
        }

        final rightPanelW = constraints.maxWidth >= 1380 ? 412.0 : 356.0;
        final mapOverlayHeader = Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _FloatingSearchPill(
              onTap: () => showCommandPalette(context, ref),
            ),
            if (config.isReal)
              _GlassActionButton(
                key: const Key('overview_retry_button'),
                icon: Icons.refresh_rounded,
                label: 'Retry',
                onPressed: () {
                  ref
                      .read(sentryScenarioProvider.notifier)
                      .refreshRealSnapshot();
                },
              ),
            const SpatialGlass(
              radius: 999,
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: ExportReportMenuButton(
                buttonKey: Key('overview_export_report_button'),
                defaultScope: ReportExportScope.parkingUtilization,
              ),
            ),
            _GlassActionButton(
              icon: Icons.videocam_outlined,
              label: 'Gate lanes',
              onPressed: () {
                ref.read(monitoringSubTabProvider.notifier).state = 0;
                ref.read(selectedDesktopTabProvider.notifier).state =
                    DesktopNavTab.monitoring;
              },
            ),
          ],
        );

        final rightColumn = Positioned(
          top: 18,
          right: 18,
          bottom: 18,
          width: rightPanelW,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (config.isReal && sysState.lastRealApiError != null) ...[
                  SpatialGlass(
                    strong: true,
                    radius: 20,
                    padding: const EdgeInsets.all(16),
                    child: Callout(
                      tone: PillTone.warn,
                      icon: Icons.cloud_off_rounded,
                      title: 'FastAPI backend unreachable',
                      message:
                          '${sysState.lastRealApiError!.code}: ${sysState.lastRealApiError!.message}',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                BentoReveal(
                  index: 3,
                  child: _CampusOverviewBentoPanel(
                    kpis: kpis,
                    activeLanesCount: sysState.activeLaneAttempts.length,
                    hasLiveSnapshot: hasLiveSnapshot,
                    awaitingLotTelemetry: awaitingLotTelemetry,
                    occupancyRatio: occupancyRatio,
                  ),
                ),
                const SizedBox(height: 12),
                BentoReveal(
                  index: 4,
                  child: _ActiveGateEncounterCard(
                    attempt: activeAttempt,
                    hasLiveSnapshot: hasLiveSnapshot,
                    onJumpToGate: (laneId) {
                      if (laneId != null) {
                        ref.read(focusedLaneProvider.notifier).state = laneId;
                      }
                      ref.read(monitoringSubTabProvider.notifier).state = 0;
                      ref.read(selectedDesktopTabProvider.notifier).state =
                          DesktopNavTab.monitoring;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                BentoReveal(
                  index: 5,
                  child: _RecentActivityGlassCard(
                    events: sysState.recentActivityFeed,
                    onlineDevices: kpis.onlineDevicesCount,
                    totalDevices: kpis.totalDevicesCount,
                    onViewAll: () {
                      ref.read(monitoringSubTabProvider.notifier).state = 2;
                      ref.read(selectedDesktopTabProvider.notifier).state =
                          DesktopNavTab.monitoring;
                    },
                    onInspectDevices: () {
                      ref.read(monitoringSubTabProvider.notifier).state = 3;
                      ref.read(selectedDesktopTabProvider.notifier).state =
                          DesktopNavTab.monitoring;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                BentoReveal(
                  index: 6,
                  child: _SystemHealthGlassCard(
                    health: opsState.systemHealth,
                    onlineDevices: kpis.onlineDevicesCount,
                    totalDevices: kpis.totalDevicesCount,
                    hasLiveSnapshot: hasLiveSnapshot,
                    canRetryDeadLetters: isAdmin,
                    onRetryDeadLetter: (id) async {
                      final actor = ref.read(authControllerProvider).profile;
                      if (actor == null) return;
                      await ref
                          .read(desktopOpsControllerProvider.notifier)
                          .retryDeadLetter(id, actor: actor);
                    },
                  ),
                ),
              ],
            ),
          ),
        );

        final bottomChartsRow = Positioned(
          left: 18,
          bottom: 18,
          right: rightPanelW + 30,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 46,
                child: BentoReveal(
                  index: 1,
                  child: CampusMixDonutCard(
                    lotSummaries: lotSummaries,
                    spaces: sysState.spaces,
                    hasLiveSnapshot:
                        !awaitingLotTelemetry && sysState.spaces.isNotEmpty,
                    onOpenParking: () {
                      ref.read(selectedDesktopTabProvider.notifier).state =
                          DesktopNavTab.parking;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 54,
                child: BentoReveal(
                  index: 2,
                  child: GateActivityBarChartCard(
                    visits: sysState.visits,
                    attemptHistory: sysState.attemptHistory,
                    hasLiveSnapshot: hasLiveSnapshot,
                    onExpand: () {
                      ref.read(monitoringSubTabProvider.notifier).state = 2;
                      ref.read(selectedDesktopTabProvider.notifier).state =
                          DesktopNavTab.monitoring;
                    },
                  ),
                ),
              ),
            ],
          ),
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.lotGround,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: p.line, width: 1),
              ),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CampusTacticalMap(
                  lotSummaries: lotSummaries,
                  allSpaces: sysState.spaces,
                  awaitingTelemetry: awaitingLotTelemetry,
                  playInsets: EdgeInsets.fromLTRB(
                    20,
                    118,
                    rightPanelW + 28,
                    242,
                  ),
                  layerPillsRight: rightPanelW + 28,
                  layerPillsTop: 74,
                  headerOverlay: mapOverlayHeader,
                  onInspectLotDetails: (lot) =>
                      _showLotDetails(context, ref, lot),
                  onOpenLotBlueprint: (lotCode) {
                    ref.read(selectedParkingLotProvider.notifier).state =
                        lotCode;
                    ref.read(selectedDesktopTabProvider.notifier).state =
                        DesktopNavTab.parking;
                  },
                  panels: [
                    bottomChartsRow,
                    rightColumn,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static AttemptDto? _pickFocusAttempt(Iterable<AttemptDto> attempts) {
    if (attempts.isEmpty) return null;
    for (final a in attempts) {
      if (a.state == 'guard_review_required') return a;
    }
    for (final a in attempts) {
      if (a.state == 'authorization_allowed') return a;
    }
    return attempts.first;
  }

  static void _showLotDetails(
    BuildContext context,
    WidgetRef ref,
    LotSummaryDto lot,
  ) {
    showDetailsSheet<void>(
      context,
      frosted: true,
      title: 'Lot ${lot.lotCode} · ${lot.lotName}',
      subtitle: 'Near ${lot.nearestLandmark} · ${lot.totalSpaces} bays total',
      builder: (ctx) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lot.conflictCount > 0) ...[
              Callout(
                tone: PillTone.err,
                icon: Icons.report_problem_outlined,
                title: '${lot.conflictCount} occupancy conflict detected',
                message:
                    'Camera occupancy disagrees with backend assignment. '
                    'Check the Parking map to resolve.',
              ),
              const SizedBox(height: 16),
            ],
            const SectionHeader(
              title: 'Overhead camera reading',
              subtitle: 'What the lot camera physically sees right now.',
            ),
            const SizedBox(height: 10),
            KeyValueRow(
              label: 'Empty bays',
              value: '${lot.physicalAvailable}',
              mono: true,
              trailing: const StatusPill(label: 'Empty', tone: PillTone.ok),
            ),
            KeyValueRow(
              label: 'Occupied bays',
              value: '${lot.physicalOccupied}',
              mono: true,
              trailing:
                  const StatusPill(label: 'Occupied', tone: PillTone.crimson),
            ),
            KeyValueRow(
              label: 'Unknown / stale',
              value: '${lot.physicalUnknownOrStale}',
              mono: true,
              trailing:
                  const StatusPill(label: 'Unknown', tone: PillTone.neutral),
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Backend reservation state',
              subtitle: 'Holds and confirmed visits managed by FastAPI.',
            ),
            const SizedBox(height: 10),
            KeyValueRow(
              label: 'Open (unassigned)',
              value: '${lot.allocationUnassigned}',
              mono: true,
              trailing: const StatusPill(label: 'Open', tone: PillTone.ok),
            ),
            KeyValueRow(
              label: 'Held at gate (30s)',
              value: '${lot.allocationHeld}',
              mono: true,
              trailing: const StatusPill(label: 'Held', tone: PillTone.warn),
            ),
            KeyValueRow(
              label: 'Assigned to visit',
              value: '${lot.allocationAssigned}',
              mono: true,
              trailing:
                  const StatusPill(label: 'Assigned', tone: PillTone.crimson),
            ),
          ],
        );
      },
      actionsBuilder: (ctx) => [
        FilledButton.icon(
          onPressed: () {
            Navigator.of(ctx).maybePop();
            ref.read(selectedParkingLotProvider.notifier).state = lot.lotCode;
            ref.read(selectedDesktopTabProvider.notifier).state =
                DesktopNavTab.parking;
          },
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Open in Parking map'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compact / Narrow Viewport Fallback (< 1020px or height < 640px)
// ---------------------------------------------------------------------------

class _CompactSpatialOverview extends ConsumerWidget {
  final dynamic sysState;
  final dynamic kpis;
  final List<LotSummaryDto> lotSummaries;
  final bool hasLiveSnapshot;
  final bool awaitingLotTelemetry;
  final bool isRealMode;
  final AttemptDto? activeAttempt;
  final double occupancyRatio;
  final ValueChanged<LotSummaryDto> onInspectLot;

  const _CompactSpatialOverview({
    required this.sysState,
    required this.kpis,
    required this.lotSummaries,
    required this.hasLiveSnapshot,
    required this.awaitingLotTelemetry,
    required this.isRealMode,
    required this.activeAttempt,
    required this.occupancyRatio,
    required this.onInspectLot,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    return ScreenScaffold(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _FloatingSearchPill(onTap: () => showCommandPalette(context, ref)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isRealMode)
                  OutlinedButton.icon(
                    key: const Key('overview_retry_button'),
                    onPressed: () {
                      ref
                          .read(sentryScenarioProvider.notifier)
                          .refreshRealSnapshot();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                const ExportReportMenuButton(
                  buttonKey: Key('overview_export_report_button'),
                  defaultScope: ReportExportScope.parkingUtilization,
                ),
                FilledButton.icon(
                  onPressed: () {
                    ref.read(selectedDesktopTabProvider.notifier).state =
                        DesktopNavTab.parking;
                  },
                  icon: const Icon(Icons.local_parking_rounded, size: 18),
                  label: const Text('Parking map'),
                ),
              ],
            ),
          ],
        ),
        if (isRealMode && sysState.lastRealApiError != null) ...[
          const SizedBox(height: 14),
          Callout(
            tone: PillTone.warn,
            icon: Icons.cloud_off_rounded,
            title: 'FastAPI backend unreachable',
            message:
                '${sysState.lastRealApiError!.code}: ${sysState.lastRealApiError!.message}',
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 410,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.lotGround,
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(24),
              ),
              child: CampusTacticalMap(
                lotSummaries: lotSummaries,
                allSpaces: sysState.spaces as List<SpaceDto>,
                awaitingTelemetry: awaitingLotTelemetry,
                compact: true,
                layerPillsTop: 14,
                playInsets: const EdgeInsets.fromLTRB(16, 68, 16, 22),
                onInspectLotDetails: onInspectLot,
                onOpenLotBlueprint: (lotCode) {
                  ref.read(selectedParkingLotProvider.notifier).state = lotCode;
                  ref.read(selectedDesktopTabProvider.notifier).state =
                      DesktopNavTab.parking;
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CampusOverviewBentoPanel(
          kpis: kpis,
          activeLanesCount: (sysState.activeLaneAttempts as Map).length,
          hasLiveSnapshot: hasLiveSnapshot,
          awaitingLotTelemetry: awaitingLotTelemetry,
          occupancyRatio: occupancyRatio,
        ),
        const SizedBox(height: 16),
        CampusMixDonutCard(
          lotSummaries: lotSummaries,
          spaces: sysState.spaces as List<SpaceDto>,
          hasLiveSnapshot:
              !awaitingLotTelemetry && (sysState.spaces as List).isNotEmpty,
          onOpenParking: () {
            ref.read(selectedDesktopTabProvider.notifier).state =
                DesktopNavTab.parking;
          },
        ),
        const SizedBox(height: 16),
        GateActivityBarChartCard(
          visits: sysState.visits,
          attemptHistory: sysState.attemptHistory,
          hasLiveSnapshot: hasLiveSnapshot,
        ),
        const SizedBox(height: 16),
        _ActiveGateEncounterCard(
          attempt: activeAttempt,
          hasLiveSnapshot: hasLiveSnapshot,
          onJumpToGate: (laneId) {
            if (laneId != null) {
              ref.read(focusedLaneProvider.notifier).state = laneId;
            }
            ref.read(monitoringSubTabProvider.notifier).state = 0;
            ref.read(selectedDesktopTabProvider.notifier).state =
                DesktopNavTab.monitoring;
          },
        ),
        const SizedBox(height: 16),
        _RecentActivityGlassCard(
          events: sysState.recentActivityFeed as List<String>,
          onlineDevices: kpis.onlineDevicesCount as int,
          totalDevices: kpis.totalDevicesCount as int,
          onViewAll: () {
            ref.read(monitoringSubTabProvider.notifier).state = 2;
            ref.read(selectedDesktopTabProvider.notifier).state =
                DesktopNavTab.monitoring;
          },
          onInspectDevices: () {
            ref.read(monitoringSubTabProvider.notifier).state = 3;
            ref.read(selectedDesktopTabProvider.notifier).state =
                DesktopNavTab.monitoring;
          },
        ),
        const SizedBox(height: 16),
        _SystemHealthGlassCard(
          health: ref.watch(desktopOpsControllerProvider).systemHealth,
          onlineDevices: kpis.onlineDevicesCount as int,
          totalDevices: kpis.totalDevicesCount as int,
          hasLiveSnapshot: hasLiveSnapshot,
          canRetryDeadLetters:
              ref.watch(authControllerProvider.select((s) => s.role.isAdmin)),
          onRetryDeadLetter: (id) async {
            final actor = ref.read(authControllerProvider).profile;
            if (actor == null) return;
            await ref
                .read(desktopOpsControllerProvider.notifier)
                .retryDeadLetter(id, actor: actor);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top-left Search Bar & Frosted Glass Action Pill
// ---------------------------------------------------------------------------

class _FloatingSearchPill extends StatelessWidget {
  final VoidCallback onTap;
  const _FloatingSearchPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const Key('overview_floating_search_bar'),
        onTap: onTap,
        child: SpatialGlass(
          strong: true,
          radius: 999,
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 18, color: p.crimson),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: Text(
                  'Search lot, bay, plate, or driver...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SentryTheme.sansFontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: p.slate,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: p.subtle,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.line),
                ),
                child: Text(
                  'Ctrl+K',
                  style: SentryTheme.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: p.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _GlassActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: SpatialGlass(
          strong: true,
          radius: 999,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: p.text),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontFamily: SentryTheme.sansFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card A — Campus Overview 2×2 Micro-Cards (Vinora "Vintage Overview" style)
// ---------------------------------------------------------------------------

class _CampusOverviewBentoPanel extends ConsumerWidget {
  final dynamic kpis;
  final int activeLanesCount;
  final bool hasLiveSnapshot;
  final bool awaitingLotTelemetry;
  final double occupancyRatio;

  const _CampusOverviewBentoPanel({
    required this.kpis,
    required this.activeLanesCount,
    required this.hasLiveSnapshot,
    required this.awaitingLotTelemetry,
    required this.occupancyRatio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final entries = kpis.entriesTodayCount as int;
    final exits = kpis.exitsTodayCount as int;
    final inside = kpis.activeVisitsCount as int;
    final holds = kpis.activeHoldsAwaitingPassageCount as int;
    final reviews = kpis.pendingGuardReviewsCount as int;

    return SpatialGlass(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Campus overview',
                  style: panelTitleStyle(p, size: 20),
                ),
              ),
              GlassIconButton(
                icon: Icons.north_east_rounded,
                tooltip: 'Open parking map',
                onPressed: () {
                  ref.read(selectedDesktopTabProvider.notifier).state =
                      DesktopNavTab.parking;
                },
                size: 34,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassTile(
                  height: 132,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  onTap: () {
                    ref.read(monitoringSubTabProvider.notifier).state = 2;
                    ref.read(selectedDesktopTabProvider.notifier).state =
                        DesktopNavTab.monitoring;
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Confirmed inside',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tileLabelStyle(p),
                            ),
                          ),
                          Icon(Icons.directions_car_filled_outlined,
                              size: 16, color: p.muted),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: BigFigure(
                              value: hasLiveSnapshot
                                  ? AnimatedCount(
                                      value: inside,
                                      style: bigFigureStyle(p, size: 28),
                                    )
                                  : Text('—',
                                      style: bigFigureStyle(p,
                                          size: 28, color: p.muted)),
                              unit: hasLiveSnapshot ? 'parked' : null,
                            ),
                          ),
                          if (hasLiveSnapshot) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: SoftChip(
                                  holds > 0 ? '$holds held' : 'Clear',
                                  tone: holds > 0
                                      ? SoftChipTone.warn
                                      : SoftChipTone.ok,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      if (!hasLiveSnapshot)
                        Text(
                          'Awaiting backend connection',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11),
                        )
                      else
                        MiniSparkline(
                          points: [
                            1.0,
                            (inside + 1).toDouble(),
                            (entries + 1).toDouble(),
                            (exits + inside + 2).toDouble(),
                            (inside + holds + 2).toDouble(),
                          ],
                          color: SentryColors.crimson,
                          active: true,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassTile(
                  height: 132,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  onTap: () {
                    ref.read(monitoringSubTabProvider.notifier).state = 0;
                    ref.read(selectedDesktopTabProvider.notifier).state =
                        DesktopNavTab.monitoring;
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Active gate lanes',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tileLabelStyle(p),
                            ),
                          ),
                          Icon(Icons.videocam_outlined,
                              size: 16, color: p.muted),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: hasLiveSnapshot
                                ? AnimatedCount(
                                    value: activeLanesCount,
                                    style: bigFigureStyle(p, size: 28),
                                  )
                                : Text('—',
                                    style: bigFigureStyle(p,
                                        size: 28, color: p.muted)),
                          ),
                          if (hasLiveSnapshot) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: SoftChip(
                                  activeLanesCount > 0
                                      ? '$activeLanesCount active'
                                      : 'Standby',
                                  tone: activeLanesCount > 0
                                      ? SoftChipTone.ok
                                      : SoftChipTone.neutral,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      if (!hasLiveSnapshot)
                        Text(
                          'Awaiting backend connection',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11),
                        )
                      else
                        LollipopStemMicroChart(
                          values: [
                            0.45,
                            0.72,
                            0.62,
                            activeLanesCount > 0 ? 0.96 : 0.4,
                            0.55,
                            0.48,
                          ],
                          maxLabel: 'Max 4',
                          accentColor: SentryColors.crimson,
                          active: true,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GlassTile(
                  height: 132,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  onTap: () {
                    ref.read(monitoringSubTabProvider.notifier).state = 1;
                    ref.read(selectedDesktopTabProvider.notifier).state =
                        DesktopNavTab.monitoring;
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pending reviews',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tileLabelStyle(p),
                            ),
                          ),
                          Icon(Icons.fact_check_outlined,
                              size: 16, color: p.muted),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: hasLiveSnapshot
                                ? AnimatedCount(
                                    value: reviews,
                                    style: bigFigureStyle(p, size: 28),
                                  )
                                : Text('—',
                                    style: bigFigureStyle(p,
                                        size: 28, color: p.muted)),
                          ),
                          if (hasLiveSnapshot) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: SoftChip(
                                  reviews > 0 ? 'Needs guard' : 'Clear',
                                  tone: reviews > 0
                                      ? SoftChipTone.warn
                                      : SoftChipTone.ok,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      if (!hasLiveSnapshot)
                        Text(
                          'Awaiting backend connection',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11),
                        )
                      else
                        MiniSparkline(
                          showDotGrid: true,
                          points: [
                            2.0,
                            3.0,
                            reviews + 2.0,
                            (reviews + 1).toDouble(),
                            reviews.toDouble(),
                          ],
                          color: reviews > 0 ? p.warn : p.ok,
                          active: true,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassTile(
                  height: 132,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  onTap: () {
                    ref.read(selectedDesktopTabProvider.notifier).state =
                        DesktopNavTab.parking;
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Campus capacity',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tileLabelStyle(p),
                            ),
                          ),
                          Icon(Icons.donut_large_rounded,
                              size: 16, color: p.muted),
                        ],
                      ),
                      const Spacer(),
                      if (!hasLiveSnapshot) ...[
                        Center(
                          child: Text(
                            '—',
                            style:
                                bigFigureStyle(p, size: 28, color: p.muted),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Awaiting backend connection',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11),
                        ),
                      ] else
                        Center(
                          child: CapacityRadialGauge(
                            ratio: occupancyRatio,
                            active: !awaitingLotTelemetry,
                            activeColor: occupancyRatio > 0.85
                                ? SentryColors.crimson
                                : occupancyRatio > 0.65
                                    ? p.warn
                                    : SentryColors.crimson,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card B — Active Gate Encounter (Vinora "Harvest order · Rows picked 3/4")
// ---------------------------------------------------------------------------

class _ActiveGateEncounterCard extends StatelessWidget {
  final AttemptDto? attempt;
  final bool hasLiveSnapshot;
  final ValueChanged<String?> onJumpToGate;

  const _ActiveGateEncounterCard({
    required this.attempt,
    required this.hasLiveSnapshot,
    required this.onJumpToGate,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final a = attempt;

    if (a == null) {
      return SpatialGlass(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.subtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.videocam_outlined, color: p.muted, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active gate lane',
                      style: panelTitleStyle(p, size: 16)),
                  Text(
                    hasLiveSnapshot
                        ? 'All 4 gate lanes idle · monitoring'
                        : 'Awaiting live gate feed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            GlassIconButton(
              icon: Icons.north_east_rounded,
              tooltip: 'Inspect gate lanes',
              onPressed: () => onJumpToGate(null),
              size: 34,
            ),
          ],
        ),
      );
    }

    final stage = a.currentStageNumber.clamp(1, 6);
    final litSegments = (stage / 6 * 4).ceil().clamp(1, 4);
    final pct = ((stage / 6) * 100).round();

    return SpatialGlass(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_humanLaneName(a.laneId)} · ${a.spaceCode ?? 'Gate check'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: SentryTheme.sansFontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PlateBadge(
                          plateText: a.plateText,
                          rfidUid: a.rfidUid,
                          isCompact: true,
                        ),
                        if (a.faceSimilarityScore != null)
                          SoftChip(
                            'ArcFace ${a.faceSimilarityScore!.toStringAsFixed(2)}',
                            tone: SoftChipTone.neutral,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: Icons.videocam_outlined,
                tooltip: 'Open in Live Gates',
                onPressed: () => onJumpToGate(a.laneId),
                size: 36,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Verification stage $stage/6',
                style: TextStyle(
                  fontFamily: SentryTheme.sansFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: p.slate,
                ),
              ),
              Text(
                '$pct%',
                style: SentryTheme.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: SentryMotion.of(
                        context, const Duration(milliseconds: 220)),
                    height: 22,
                    decoration: BoxDecoration(
                      color: i < litSegments
                          ? SentryColors.crimson
                          : (p.isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFF0F172A)
                                  .withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _humanLaneName(String laneId) {
    switch (laneId) {
      case 'lane-car-in':
        return 'North Car Entry';
      case 'lane-car-out':
        return 'North Car Exit';
      case 'lane-moto-in':
        return 'Motorcycle Entry';
      case 'lane-moto-out':
        return 'Motorcycle Exit';
      default:
        return laneId;
    }
  }
}

// ---------------------------------------------------------------------------
// Card C — Recent Gate Activity (Vinora "Recent Messages" clean 2-line list)
// ---------------------------------------------------------------------------

class _RecentActivityGlassCard extends StatelessWidget {
  final List<String> events;
  final int onlineDevices;
  final int totalDevices;
  final VoidCallback onViewAll;
  final VoidCallback onInspectDevices;

  const _RecentActivityGlassCard({
    required this.events,
    required this.onlineDevices,
    required this.totalDevices,
    required this.onViewAll,
    required this.onInspectDevices,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final devicesHealthy = totalDevices > 0 && onlineDevices == totalDevices;

    return SpatialGlass(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent gate activity',
                  style: panelTitleStyle(p, size: 17),
                ),
              ),
              if (totalDevices > 0)
                GestureDetector(
                  onTap: onInspectDevices,
                  child: SoftChip(
                    '$onlineDevices/$totalDevices online',
                    tone: devicesHealthy
                        ? SoftChipTone.ok
                        : SoftChipTone.warn,
                  ),
                ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: EmptyState(
                icon: Icons.history_toggle_off_rounded,
                title: 'No recent gate activity',
                message: 'Live gate passage and review events will appear here.',
              ),
            )
          else
            for (var i = 0; i < events.take(3).length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _ReadableActivityTile(raw: events[i], palette: p),
            ],
        ],
      ),
    );
  }
}

class _ReadableActivityTile extends StatelessWidget {
  final String raw;
  final SentryPalette palette;
  const _ReadableActivityTile({required this.raw, required this.palette});

  @override
  Widget build(BuildContext context) {
    final parsed = _humanizeActivity(raw);
    final (Color bg, Color fg, IconData icon) = switch (parsed.tone) {
      SoftChipTone.ok => (palette.okTint, palette.ok, Icons.check_rounded),
      SoftChipTone.warn => (
          palette.warnTint,
          palette.warnText,
          Icons.visibility_outlined
        ),
      SoftChipTone.crimson => (
          palette.errTint,
          palette.errText,
          Icons.warning_amber_rounded
        ),
      SoftChipTone.neutral => (palette.subtle, palette.slate, Icons.sensors_rounded),
    };

    return GlassTile(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parsed.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SentryTheme.sansFontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                Text(
                  parsed.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SentryTheme.sansFontFamily,
                    fontSize: 12,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'PHT',
            style: SentryTheme.mono(fontSize: 10.5, color: palette.muted),
          ),
        ],
      ),
    );
  }

  static ({String title, String subtitle, SoftChipTone tone}) _humanizeActivity(
      String msg) {
    final upper = msg.toUpperCase();
    final parts = msg.split(':');
    final source = parts.length > 1 ? parts.first.trim() : 'Gate event';
    final detail = parts.length > 1 ? parts.sublist(1).join(':').trim() : msg;

    final tone = (upper.contains('DENIED') ||
            upper.contains('CONFLICT') ||
            upper.contains('EXPIRED'))
        ? SoftChipTone.crimson
        : (upper.contains('CONFIRMED') || upper.contains('ALLOWED'))
            ? SoftChipTone.ok
            : SoftChipTone.warn;

    String cleanSource = source
        .replaceAll('GATE-NORTH/CAR-IN', 'North Car Entry')
        .replaceAll('GATE-NORTH/MOTO-IN', 'Motorcycle Entry')
        .replaceAll('GATE-NORTH/CAR-OUT', 'North Car Exit')
        .replaceAll('LOT B1 OVERHEAD CAM', 'Lot B1 Camera');

    return (
      title: detail,
      subtitle: cleanSource,
      tone: tone,
    );
  }
}

// ---------------------------------------------------------------------------
// Card D — System Health & Failed Deliveries (Dead Letters)
// ---------------------------------------------------------------------------

class _SystemHealthGlassCard extends StatelessWidget {
  final SystemHealthDto health;
  final int onlineDevices;
  final int totalDevices;
  final bool hasLiveSnapshot;
  final bool canRetryDeadLetters;
  final Future<void> Function(String id) onRetryDeadLetter;

  const _SystemHealthGlassCard({
    required this.health,
    required this.onlineDevices,
    required this.totalDevices,
    required this.hasLiveSnapshot,
    required this.canRetryDeadLetters,
    required this.onRetryDeadLetter,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final failedLetters =
        health.deadLetters.where((d) => d.status == 'failed').toList();
    final isHealthy =
        health.overallStatus == 'healthy' && failedLetters.isEmpty;
    final hasHealth =
        hasLiveSnapshot && health.overallStatus != 'unknown';

    return SpatialGlass(
      key: const Key('dashboard_system_health_card'),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'System health',
                  style: panelTitleStyle(p, size: 16.5),
                ),
              ),
              SoftChip(
                !hasHealth
                    ? 'Awaiting telemetry'
                    : (isHealthy ? 'Healthy' : 'Degraded'),
                tone: !hasHealth
                    ? SoftChipTone.neutral
                    : (isHealthy ? SoftChipTone.ok : SoftChipTone.warn),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            !hasHealth
                ? 'Scheduler & cameras awaiting connection'
                : 'Scheduler ${health.schedulerStatus == 'running' ? 'running' : 'degraded'} · $onlineDevices/$totalDevices cameras online',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: p.muted,
                  fontSize: 12.5,
                ),
          ),
          if (failedLetters.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Failed Deliveries (${failedLetters.length})',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.warnText,
                  ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < failedLetters.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              GlassTile(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${failedLetters[i].channel.toUpperCase()} · ${failedLetters[i].recipient}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: SentryTheme.sansFontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: p.text,
                            ),
                          ),
                          Text(
                            failedLetters[i].errorMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: SentryTheme.sansFontFamily,
                              fontSize: 11.5,
                              color: p.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canRetryDeadLetters) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        key: Key('dead_letter_retry_${failedLetters[i].id}'),
                        onPressed: () =>
                            onRetryDeadLetter(failedLetters[i].id),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
