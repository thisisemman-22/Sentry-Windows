import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/parking_models.dart';

/// View 2: `Overview` — calm, single-glance campus summary.
///
/// Progressive disclosure:
/// - Top row: 4 large animated [MetricTile]s (one number + one plain label each).
/// - Left column: Lots A–D with a single animated [CapacityBar] per lot; click a
///   lot card to open its dual-state camera vs. reservation breakdown in a side
///   sheet without cluttering the main canvas.
/// - Right column: Recent gate activity + compact device health summary.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final sysState = ref.watch(sentryScenarioProvider);
    final kpis = sysState.computeDashboardKpis();
    final lotSummaries = sysState.computeLotSummaries();

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Campus overview',
          subtitle: 'Live gate flow and bay availability across Lots A to D.',
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                ref.read(selectedDesktopTabProvider.notifier).state =
                    DesktopNavTab.liveGateMonitoring;
              },
              icon: const Icon(Icons.videocam_outlined, size: 18),
              label: const Text('Open live gates'),
            ),
            FilledButton.icon(
              onPressed: () {
                ref.read(selectedDesktopTabProvider.notifier).state =
                    DesktopNavTab.parkingManagement;
              },
              icon: const Icon(Icons.local_parking_rounded, size: 18),
              label: const Text('View parking map'),
            ),
          ],
        ),
        const SizedBox(height: 26),

        // 1. 4-Card KPI Row (one big number per card)
        LayoutBuilder(
          builder: (context, constraints) {
            final tiles = [
              MetricTile(
                revealIndex: 1,
                label: 'CONFIRMED VEHICLES INSIDE CAMPUS',
                value: kpis.activeVisitsCount,
                caption: kpis.activeHoldsAwaitingPassageCount > 0
                    ? '${kpis.activeHoldsAwaitingPassageCount} waiting to cross at gate'
                    : 'All gate holds cleared',
                icon: Icons.directions_car_filled_outlined,
                tone: PillTone.ok,
                hint:
                    'Only counts vehicles that have physically crossed the gate. '
                    'Pre-passage 30s holds are tracked separately.',
                onTap: () {
                  ref.read(selectedDesktopTabProvider.notifier).state =
                      DesktopNavTab.accessLogs;
                },
              ),
              MetricTile(
                revealIndex: 2,
                label: 'Entries today',
                value: kpis.entriesTodayCount,
                suffix: 'in · ${kpis.exitsTodayCount} out',
                caption:
                    '${kpis.activeHoldsAwaitingPassageCount} active gate hold(s)',
                icon: Icons.swap_vert_circle_outlined,
                tone: PillTone.info,
                onTap: () {
                  ref.read(selectedDesktopTabProvider.notifier).state =
                      DesktopNavTab.liveGateMonitoring;
                },
              ),
              MetricTile(
                revealIndex: 3,
                label: 'Pending guard reviews',
                value: kpis.pendingGuardReviewsCount,
                caption: kpis.pendingGuardReviewsCount == 0
                    ? 'Queue is clear'
                    : 'Waiting for guard decision',
                icon: Icons.fact_check_outlined,
                tone: kpis.pendingGuardReviewsCount > 0
                    ? PillTone.warn
                    : PillTone.ok,
                onTap: () {
                  ref.read(selectedDesktopTabProvider.notifier).state =
                      DesktopNavTab.guardReviews;
                },
              ),
              MetricTile(
                revealIndex: 4,
                label: 'Free parking bays',
                value: kpis.trulyAvailableSpaces,
                suffix: '/ ${kpis.totalCampusSpaces}',
                caption:
                    '${kpis.occupiedSpaces} occupied · ${kpis.heldSpaces} held',
                icon: Icons.local_parking_rounded,
                tone: PillTone.crimson,
                hint:
                    'Bays with unknown or stale camera readings (${kpis.unknownOrStaleSpaces}) '
                    'are excluded from free count for safety.',
                onTap: () {
                  ref.read(selectedDesktopTabProvider.notifier).state =
                      DesktopNavTab.parkingManagement;
                },
              ),
            ];

            if (constraints.maxWidth < 920) {
              return Column(
                children: [
                  for (final t in tiles) ...[
                    t,
                    const SizedBox(height: 14),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: tiles[i]),
                ],
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // 2. Main Split: Parking Lots (Left) + Activity & Devices (Right)
        LayoutBuilder(
          builder: (context, constraints) {
            final lotsCard = Reveal(
              index: 5,
              child: SentryCard(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Parking lots A to D',
                      subtitle: 'Click any lot to inspect camera vs. reservation state.',
                      hint:
                          'Physical overhead camera state (empty / occupied / unknown) '
                          'is tracked separately from backend reservations (open / held / assigned).',
                      trailing: Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          LegendDot(color: p.ok, label: 'Free'),
                          LegendDot(color: p.crimson, label: 'Occupied'),
                          LegendDot(color: p.warn, label: 'Held (30s)'),
                          LegendDot(color: p.muted, label: 'Unknown'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < lotSummaries.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _LotSummaryRow(
                        lot: lotSummaries[i],
                        onTap: () => _showLotDetails(context, ref, lotSummaries[i]),
                      ),
                    ],
                  ],
                ),
              ),
            );

            final rightCol = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Reveal(
                  index: 6,
                  child: _RecentActivityCard(
                    events: sysState.recentActivityFeed,
                    onViewAll: () {
                      ref.read(selectedDesktopTabProvider.notifier).state =
                          DesktopNavTab.accessLogs;
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Reveal(
                  index: 7,
                  child: _DevicesCompactCard(
                    onlineCount: kpis.onlineDevicesCount,
                    totalCount: kpis.totalDevicesCount,
                    onInspect: () {
                      ref.read(selectedDesktopTabProvider.notifier).state =
                          DesktopNavTab.deviceMonitoring;
                    },
                  ),
                ),
              ],
            );

            if (constraints.maxWidth < 980) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  lotsCard,
                  const SizedBox(height: 18),
                  rightCol,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: lotsCard),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: rightCol),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showLotDetails(
    BuildContext context,
    WidgetRef ref,
    LotSummaryDto lot,
  ) {
    showDetailsSheet<void>(
      context,
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
            ref.read(selectedDesktopTabProvider.notifier).state =
                DesktopNavTab.parkingManagement;
          },
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Open in Parking map'),
        ),
      ],
    );
  }
}

class _LotSummaryRow extends StatelessWidget {
  final LotSummaryDto lot;
  final VoidCallback onTap;

  const _LotSummaryRow({
    required this.lot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final free = (lot.physicalAvailable - lot.allocationHeld)
        .clamp(0, lot.totalSpaces);

    return SentryCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      radius: 16,
      color: p.subtle,
      accent: lot.conflictCount > 0
          ? p.err
          : lot.cameraStale
              ? p.warn
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SentryColors.crimson,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  lot.lotCode,
                  style: SentryTheme.display(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lot.lotName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Near ${lot.nearestLandmark}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (lot.conflictCount > 0) ...[
                StatusPill(
                  label: '${lot.conflictCount} conflict',
                  tone: PillTone.err,
                  icon: Icons.report_problem_outlined,
                ),
                const SizedBox(width: 8),
              ] else if (lot.cameraStale) ...[
                const StatusPill(
                  label: 'Camera stale',
                  tone: PillTone.warn,
                  icon: Icons.videocam_off_outlined,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '$free / ${lot.totalSpaces} free',
                style: SentryTheme.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
            ],
          ),
          const SizedBox(height: 14),
          CapacityBar(
            segments: [
              CapacitySegment(free, p.ok, 'free'),
              CapacitySegment(lot.physicalOccupied, p.crimson, 'occupied'),
              CapacitySegment(lot.allocationHeld, p.warn, 'held'),
              CapacitySegment(
                  lot.physicalUnknownOrStale, p.muted, 'unknown/stale'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final List<String> events;
  final VoidCallback onViewAll;

  const _RecentActivityCard({
    required this.events,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return SentryCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Recent gate activity',
            trailing: TextButton(
              onPressed: onViewAll,
              child: const Text('All logs'),
            ),
          ),
          const SizedBox(height: 14),
          for (final msg in events.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActivityRow(message: msg, palette: p),
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String message;
  final SentryPalette palette;

  const _ActivityRow({required this.message, required this.palette});

  @override
  Widget build(BuildContext context) {
    final upper = message.toUpperCase();
    final isBad = upper.contains('DENIED') ||
        upper.contains('CONFLICT') ||
        upper.contains('EXPIRED');
    final isGood = upper.contains('CONFIRMED') || upper.contains('ALLOWED');
    final color = isBad
        ? palette.err
        : isGood
            ? palette.ok
            : palette.warn;
    final icon = isBad
        ? Icons.block_rounded
        : isGood
            ? Icons.check_circle_outline_rounded
            : Icons.sensors_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.subtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevicesCompactCard extends StatelessWidget {
  final int onlineCount;
  final int totalCount;
  final VoidCallback onInspect;

  const _DevicesCompactCard({
    required this.onlineCount,
    required this.totalCount,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    final allHealthy = onlineCount == totalCount;
    return SentryCard(
      onTap: onInspect,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: allHealthy
                  ? SentryPalette.of(context).okTint
                  : SentryPalette.of(context).warnTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.router_outlined,
              color: allHealthy
                  ? SentryPalette.of(context).ok
                  : SentryPalette.of(context).warn,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$onlineCount of $totalCount site devices online',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  allHealthy
                      ? 'All cameras and RFID readers responding'
                      : '${totalCount - onlineCount} device needs attention',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusPill(
            label: allHealthy ? 'All online' : 'Check devices',
            tone: allHealthy ? PillTone.ok : PillTone.warn,
          ),
        ],
      ),
    );
  }
}
