import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../core/widgets/vehicle_top_down_svg.dart';
import '../../../shared/fixtures/synthetic_fixtures.dart';
import '../../../shared/models/parking_models.dart';

/// View 5: `Parking` — overhead lot blueprint & calm bay inspector.
class ParkingManagementScreen extends ConsumerStatefulWidget {
  const ParkingManagementScreen({super.key});

  @override
  ConsumerState<ParkingManagementScreen> createState() =>
      _ParkingManagementScreenState();
}

class _ParkingManagementScreenState
    extends ConsumerState<ParkingManagementScreen> {
  String _selectedTab = 'A'; // 'A' | 'B' | 'C' | 'D' | 'MATRIX'
  String? _selectedSpaceCode;

  static const _tabs = [
    ('A', 'Lot A · STEER Hub'),
    ('B', 'Lot B · CEAFA'),
    ('C', 'Lot C · Gymnasium'),
    ('D', 'Lot D · RGR Annex'),
    ('MATRIX', 'Building routing'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final sysState = ref.watch(sentryScenarioProvider);

    final activeLotCode = _selectedTab == 'MATRIX' ? 'A' : _selectedTab;
    final lotSpaces =
        sysState.spaces.where((s) => s.lotCode == activeLotCode).toList();
    final selectedSpace = lotSpaces
            .where((s) => s.spaceCode == _selectedSpaceCode)
            .firstOrNull ??
        lotSpaces.firstOrNull;

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Parking map',
          subtitle:
              'Live overhead view of every bay across Lots A to D. Click a bay to inspect.',
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (code, label) in _tabs)
                  _LotTabPill(
                    key: Key('parking_tab_$code'),
                    label: label,
                    selected: _selectedTab == code,
                    onTap: () => setState(() => _selectedTab = code),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        SmoothSwitcher(
          switchKey: _selectedTab,
          child: _selectedTab == 'MATRIX'
              ? _buildBuildingPriorityMatrix(context)
              : selectedSpace == null
                  ? SentryCard(
                      child: EmptyState(
                        icon: Icons.local_parking_rounded,
                        title: 'Awaiting lot telemetry',
                        message:
                            'Waiting for lot space telemetry from backend.',
                        action: OutlinedButton.icon(
                          key: const Key('parking_retry_button'),
                          onPressed: () {
                            ref
                                .read(sentryScenarioProvider.notifier)
                                .refreshRealSnapshot();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final blueprint = _buildBlueprintCard(
                          context,
                          p,
                          lotSpaces,
                          selectedSpace,
                        );
                        final inspector = SmoothSwitcher(
                          switchKey:
                              '${selectedSpace.spaceCode}-${selectedSpace.physicalStatus}-${selectedSpace.allocationStatus}-${selectedSpace.isStale}',
                          child: _buildBayInspector(context, p, selectedSpace),
                        );

                    if (constraints.maxWidth < 960) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          blueprint,
                          const SizedBox(height: 20),
                          inspector,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: blueprint),
                        const SizedBox(width: 22),
                        Expanded(flex: 4, child: inspector),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBlueprintCard(
    BuildContext context,
    SentryPalette p,
    List<SpaceDto> lotSpaces,
    SpaceDto selectedSpace,
  ) {
    final freeCount =
        lotSpaces.where((s) => s.isTrulyAvailableForAllocation).length;

    return SentryCard(
      padding: const EdgeInsets.all(24),
      color: p.lotGround,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Lot $_selectedTab overhead blueprint',
            subtitle: '$freeCount of ${lotSpaces.length} bays free right now',
            trailing: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                LegendDot(color: p.ok, label: 'Free'),
                LegendDot(color: p.warn, label: 'Held (30s)'),
                LegendDot(color: p.crimson, label: 'Occupied'),
                LegendDot(color: p.muted, label: 'Unknown'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    for (final s in lotSpaces.take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BayCard(
                          space: s,
                          selected: s.spaceCode == selectedSpace.spaceCode,
                          onTap: () =>
                              setState(() => _selectedSpaceCode = s.spaceCode),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 416,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: p.subtle.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.symmetric(
                    vertical: BorderSide(color: p.line, width: 1.5),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.north_rounded, size: 18, color: p.muted),
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'DRIVEWAY',
                        style: SentryTheme.eyebrow(color: p.muted),
                      ),
                    ),
                    Icon(Icons.south_rounded, size: 18, color: p.muted),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    for (final s in lotSpaces.skip(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BayCard(
                          space: s,
                          selected: s.spaceCode == selectedSpace.spaceCode,
                          onTap: () =>
                              setState(() => _selectedSpaceCode = s.spaceCode),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBayInspector(
    BuildContext context,
    SentryPalette p,
    SpaceDto space,
  ) {
    final isMoto = space.compatibility == 'motorcycle_only';
    return SentryCard(
      padding: const EdgeInsets.all(24),
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
                      'Bay ${space.spaceCode}',
                      style: SentryTheme.display(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMoto ? 'Motorcycle bay' : 'Car bay',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: space.isTrulyAvailableForAllocation
                    ? 'Free for entry'
                    : space.hasOccupancyConflict
                        ? 'Conflict'
                        : space.isUnknownOrStale
                            ? 'Unknown'
                            : space.allocationStatus == 'held'
                                ? 'Held (30s)'
                                : 'In use',
                tone: space.isTrulyAvailableForAllocation
                    ? PillTone.ok
                    : space.hasOccupancyConflict
                        ? PillTone.err
                        : space.isUnknownOrStale
                            ? PillTone.neutral
                            : space.allocationStatus == 'held'
                                ? PillTone.warn
                                : PillTone.crimson,
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Raw bay IDs and building distances',
                onPressed: () => _showBayTechnicalSheet(context, space),
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (space.hasOccupancyConflict) ...[
            const Callout(
              tone: PillTone.err,
              icon: Icons.report_problem_outlined,
              title: 'Occupancy conflict',
              message:
                  'Overhead camera sees a vehicle in this bay, but the backend has no active visit assigned to it.',
            ),
            const SizedBox(height: 16),
          ] else if (space.isUnknownOrStale) ...[
            const Callout(
              tone: PillTone.warn,
              icon: Icons.videocam_off_outlined,
              title: 'Camera reading unavailable',
              message:
                  'This bay is excluded from free capacity until the overhead camera sends a fresh reading.',
            ),
            const SizedBox(height: 16),
          ],

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: p.subtle,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                KeyValueRow(
                  label: 'Camera sees',
                  value: space.isStale
                      ? 'Stale reading'
                      : space.physicalStatus,
                  trailing: StatusPill.fromPhysicalSpace(
                    space.physicalStatus,
                    isStale: space.isStale,
                  ),
                ),
                KeyValueRow(
                  label: 'Reservation',
                  value: space.allocationStatus,
                  trailing:
                      StatusPill.fromAllocationSpace(space.allocationStatus),
                ),
                KeyValueRow(
                  label: 'Vehicle',
                  value: space.assignedVehicleCode != null
                      ? '${space.assignedVehicleCode} (${space.assignedUserCode})'
                      : 'None',
                  mono: true,
                ),
                KeyValueRow(
                  label: 'Last updated',
                  value: ManilaTime.formatTimeOnly(space.lastObservedAtUtc),
                  mono: true,
                ),
              ],
            ),
          ),

          if (ref.watch(appConfigProvider).isMock) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              key: const Key('cycle_bay_physical_status_btn'),
              onPressed: () {
                ref
                    .read(sentryScenarioProvider.notifier)
                    .cycleSpacePhysicalStatus(space.spaceCode);
              },
              icon: const Icon(Icons.cameraswitch_outlined, size: 18),
              label: const Text('Cycle camera state'),
            ),
          ],
        ],
      ),
    );
  }

  void _showBayTechnicalSheet(BuildContext context, SpaceDto space) {
    showDetailsSheet<void>(
      context,
      title: 'Bay ${space.spaceCode} metadata',
      subtitle: 'Contract identifiers and walking distance to campus buildings.',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyValueRow(label: 'Space UUID', value: space.spaceId, mono: true),
          KeyValueRow(
            label: 'Compatibility',
            value: space.compatibility,
            mono: true,
          ),
          KeyValueRow(
            label: 'Camera confidence',
            value: space.confidence?.toStringAsFixed(2) ?? 'N/A',
            mono: true,
          ),
          KeyValueRow(
            label: 'Assignment ID',
            value: space.assignmentId ?? 'None',
            mono: true,
          ),
          KeyValueRow(
            label: 'Active visit ID',
            value: space.visitId ?? 'None (null while held)',
            mono: true,
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Walking distance to buildings'),
          const SizedBox(height: 10),
          for (final e in space.buildingDistanceMeters.entries)
            KeyValueRow(
              label: e.key,
              value: '${e.value} meters',
              mono: true,
            ),
        ],
      ),
    );
  }

  Widget _buildBuildingPriorityMatrix(BuildContext context) {
    final p = SentryPalette.of(context);
    return SentryCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Closest parking lots by building',
            subtitle:
                'When a driver selects a destination building in the mobile app, SENTRY checks lots in this order.',
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < SentryFixtures.buildingPriorityRows.length; i++) ...[
            if (i > 0) Divider(color: p.line, height: 22),
            Builder(builder: (context) {
              final row = SentryFixtures.buildingPriorityRows[i];
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          row.buildingCode,
                          style: SentryTheme.mono(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: p.crimson,
                          ),
                        ),
                      ),
                      Text(
                        row.buildingName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: List.generate(row.orderedLots.length, (idx) {
                      return StatusPill(
                        label: '${idx + 1}. Lot ${row.orderedLots[idx]}',
                        tone: idx == 0 ? PillTone.crimson : PillTone.neutral,
                        monospace: true,
                      );
                    }),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _LotTabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LotTabPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: SentryMotion.of(context, SentryMotion.short),
          curve: SentryMotion.emphasized,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? SentryColors.crimson : p.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? SentryColors.crimson : p.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : p.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _BayCard extends StatelessWidget {
  final SpaceDto space;
  final bool selected;
  final VoidCallback onTap;

  const _BayCard({
    required this.space,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    Color bg = p.card;
    Color? accent;

    if (space.hasOccupancyConflict) {
      bg = p.errTint;
      accent = p.err;
    } else if (space.isUnknownOrStale) {
      bg = p.subtle;
    } else if (space.allocationStatus == 'held') {
      bg = p.warnTint;
      accent = p.warn;
    } else if (space.isTrulyAvailableForAllocation) {
      bg = p.okTint;
      accent = p.ok;
    } else if (space.allocationStatus == 'assigned') {
      bg = p.crimsonTint;
      accent = p.crimson;
    }

    final isMoto = space.compatibility == 'motorcycle_only';

    return SentryCard(
      key: Key('bay_card_${space.spaceCode}'),
      selected: selected,
      color: bg,
      accent: accent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 16,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  space.spaceCode,
                  style: SentryTheme.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isMoto
                      ? Icons.two_wheeler_outlined
                      : Icons.directions_car_outlined,
                  size: 16,
                  color: p.muted,
                ),
                const Spacer(),
                if (!space.isUnknownOrStale &&
                    space.physicalStatus == 'occupied')
                  VehicleTopDownSvg(
                    vehicleType: isMoto ? 'motorcycle' : 'car',
                    primaryColor: space.hasOccupancyConflict
                        ? p.err
                        : SentryColors.crimson,
                    width: 44,
                    height: 22,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                StatusPill.fromPhysicalSpace(
                  space.physicalStatus,
                  isStale: space.isStale,
                ),
                if (space.allocationStatus != 'unassigned')
                  StatusPill.fromAllocationSpace(space.allocationStatus),
                if (space.hasOccupancyConflict)
                  const StatusPill(label: 'Conflict', tone: PillTone.err),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
