import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/fixtures/synthetic_fixtures.dart';
import '../../../shared/models/parking_models.dart';
import '../../../shared/models/spec_2026_models.dart';
import '../../overview/presentation/spatial_glass.dart';
import 'lot_blueprint_canvas.dart';

/// View 5: `Parking` — surveyed Lots `B1–B5` interactive overhead blueprints
/// & slide-out Bay Inspector Drawer.
class ParkingManagementScreen extends ConsumerStatefulWidget {
  const ParkingManagementScreen({super.key});

  @override
  ConsumerState<ParkingManagementScreen> createState() =>
      _ParkingManagementScreenState();
}

class _ParkingManagementScreenState
    extends ConsumerState<ParkingManagementScreen> {
  String? _selectedSpaceCode;

  ParkingLotZoneMeta _metaFor(String lotCode) {
    return kCampusParkingLots.firstWhere(
      (m) => m.lotCode == lotCode,
      orElse: () => kCampusParkingLots.first,
    );
  }

  String _tabLabelFor(ParkingLotZoneMeta meta, List<SpaceDto> allSpaces) {
    final overrideName = allSpaces
        .where((s) =>
            s.lotCode == meta.lotCode &&
            s.zoneName != null &&
            s.zoneName!.trim().isNotEmpty)
        .map((s) => s.zoneName!.trim())
        .firstOrNull;
    if (overrideName != null) {
      return '${meta.lotCode} · $overrideName';
    }
    return meta.shortTabLabel;
  }

  @override
  Widget build(BuildContext context) {
    final sysState = ref.watch(sentryScenarioProvider);
    final config = ref.watch(appConfigProvider);
    final selectedTab = ref.watch(selectedParkingLotProvider);
    final profile = ref.watch(authControllerProvider).profile;
    final isAdmin = profile?.role.isAdmin ?? false;

    final isMatrix = selectedTab == 'MATRIX';
    final isRules = selectedTab == 'RULES';
    final activeLotCode = (isMatrix || isRules) ? 'B1' : selectedTab;
    final activeMeta = _metaFor(activeLotCode);
    final lotSpaces =
        sysState.spaces.where((s) => s.lotCode == activeLotCode).toList();
    final awaitingTelemetry = config.isReal && lotSpaces.isEmpty;
    final formalSpaces =
        lotSpaces.where((s) => s.isFormalAllocatableBay).toList();
    final freeCount =
        formalSpaces.where((s) => s.isTrulyAvailableForAllocation).length;
    final zoneDisplayName = activeMeta.resolveName(sysState.spaces);

    // Camera online indicator for camera-sensed lots (B2-B4).
    final lotCamOnline = switch (activeLotCode) {
      'B2' || 'B3' || 'B4' => sysState.devices.any((d) {
          final loc = d.locationLabel.toUpperCase();
          return (loc.contains(activeLotCode) ||
                  d.deviceType.contains('camera')) &&
              d.effectiveStatus() == 'online';
        }),
      _ => false,
    };

    final floatingTabStrip = SpatialGlass(
      strong: true,
      radius: 999,
      padding: const EdgeInsets.all(5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final meta in kCampusParkingLots) ...[
              _LotTabPill(
                key: Key('parking_tab_${meta.lotCode}'),
                label: _tabLabelFor(meta, sysState.spaces),
                selected: selectedTab == meta.lotCode,
                onTap: () {
                  ref.read(selectedParkingLotProvider.notifier).state =
                      meta.lotCode;
                },
              ),
              const SizedBox(width: 6),
            ],
            _LotTabPill(
              key: const Key('parking_tab_MATRIX'),
              label: 'Building routing',
              selected: selectedTab == 'MATRIX',
              onTap: () {
                ref.read(selectedParkingLotProvider.notifier).state = 'MATRIX';
              },
            ),
            const SizedBox(width: 6),
            _LotTabPill(
              key: const Key('parking_tab_RULES'),
              label: 'Parking Rules',
              selected: selectedTab == 'RULES',
              onTap: () {
                ref.read(selectedParkingLotProvider.notifier).state = 'RULES';
              },
            ),
          ],
        ),
      ),
    );

    return ScreenScaffold(
      children: [
        const PageIntro(
          title: 'Parking map',
          subtitle:
              'Surveyed BatStateU Alangilan blueprints (Lots B1–B5) and campus parking rules. Click any bay for Inspector details.',
        ),
        const SizedBox(height: 18),
        SentryCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: isMatrix
                    ? 'Closest parking lots by building (Lots B1–B5)'
                    : isRules
                        ? 'Campus Parking Rules & Hold Policy'
                        : '$activeLotCode · $zoneDisplayName',
                subtitle: isMatrix
                    ? 'When a driver selects a destination building in the mobile app, SENTRY checks lots in this order (B5 is Overflow).'
                    : isRules
                        ? (isAdmin
                            ? 'View and edit parking hold windows, overflow routing, and operating rules. Changes are audited.'
                            : 'Read-only campus parking policy rules.')
                        : (awaitingTelemetry
                            ? '${activeMeta.dimensionsNote} · Clean schematic wireframe (awaiting live camera telemetry)'
                            : activeMeta.hasIndividualSlots
                                ? '$freeCount of ${formalSpaces.length} formal bays free · ${activeMeta.dimensionsNote}'
                                : 'Overflow pooled capacity · No individual slots'),
                trailing: (isMatrix || isRules)
                    ? null
                    : Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (activeMeta.manualEditLocked &&
                              activeMeta.hasIndividualSlots)
                            StatusPill(
                              label: lotCamOnline
                                  ? 'Camera Online · Locked'
                                  : 'Camera Offline · Locked',
                              tone: lotCamOnline ? PillTone.ok : PillTone.warn,
                              icon: lotCamOnline
                                  ? Icons.videocam_outlined
                                  : Icons.videocam_off_outlined,
                            )
                          else if (!activeMeta.manualEditLocked)
                            const StatusPill(
                              label: 'Manual Control (Admin)',
                              tone: PillTone.info,
                              icon: Icons.tune_rounded,
                            ),
                          if (activeMeta.isOverflow)
                            const StatusPill(
                              label: 'Overflow Zone',
                              tone: PillTone.warn,
                              icon: Icons.layers_outlined,
                            ),
                          if (activeMeta.isSchematicPending)
                            const StatusPill(
                              label: 'Schematic Pending',
                              tone: PillTone.neutral,
                              icon: Icons.architecture_outlined,
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              Stack(
                children: [
                  SmoothSwitcher(
                    switchKey: selectedTab,
                    child: isMatrix
                        ? _buildBuildingPriorityMatrix(context)
                        : isRules
                            ? _buildParkingRulesView(context, isAdmin)
                            : LotBlueprintCanvas(
                                lotMeta: activeMeta,
                                lotSpaces: lotSpaces,
                                selectedSpaceCode: _selectedSpaceCode,
                                awaitingTelemetry: awaitingTelemetry,
                                topInset: 74.0,
                                onRetryTelemetry: () {
                                  ref
                                      .read(sentryScenarioProvider.notifier)
                                      .refreshRealSnapshot();
                                },
                                onSelectSpace: (space) {
                                  setState(() =>
                                      _selectedSpaceCode = space.spaceCode);
                                  _openBayInspectorDrawer(
                                      context, space.spaceCode);
                                },
                              ),
                  ),
                  // Floating Translucent Lot Tabs kept OUTSIDE SmoothSwitcher so keys
                  // remain strictly unique during cross-fade transitions.
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: floatingTabStrip,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openBayInspectorDrawer(BuildContext context, String spaceCode) {
    showDetailsSheet<void>(
      context,
      frosted: true,
      title: 'Bay $spaceCode Inspector',
      subtitle: 'Dual-state overhead camera telemetry vs. FastAPI assignment.',
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final p = SentryPalette.of(context);
          final sysState = ref.watch(sentryScenarioProvider);
          final space = sysState.spaces
              .where((s) => s.spaceCode == spaceCode)
              .firstOrNull;
          if (space == null) {
            return const EmptyState(
              icon: Icons.local_parking_rounded,
              title: 'Space unavailable',
              message: 'No live state loaded for this space yet.',
            );
          }
          final isMoto = space.compatibility == 'motorcycle_only';
          final isMock = ref.watch(appConfigProvider).isMock;
          final actor = ref.watch(authControllerProvider).profile;
          final isAdmin = actor?.role.isAdmin ?? false;
          final lotMeta = _metaFor(space.lotCode);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusPill(
                    label: space.isUnconfirmed
                        ? 'Unconfirmed · Far-end'
                        : space.isInformalAisle
                            ? 'Informal / Not a formal bay'
                            : space.isTrulyAvailableForAllocation
                                ? 'Free for entry'
                                : space.hasOccupancyConflict
                                    ? 'Conflict'
                                    : space.isUnknownOrStale
                                        ? 'Unknown'
                                        : space.allocationStatus == 'held'
                                            ? 'Held (30s)'
                                            : 'In use',
                    tone: space.isUnconfirmed || space.isInformalAisle
                        ? PillTone.neutral
                        : space.isTrulyAvailableForAllocation
                            ? PillTone.ok
                            : space.hasOccupancyConflict
                                ? PillTone.err
                                : space.isUnknownOrStale
                                    ? PillTone.neutral
                                    : space.allocationStatus == 'held'
                                        ? PillTone.warn
                                        : PillTone.crimson,
                  ),
                  if (space.isAccessiblePwd)
                    const StatusPill(
                      label: 'PWD / Accessible',
                      tone: PillTone.info,
                      icon: Icons.accessible_rounded,
                    ),
                  if (isMoto)
                    const StatusPill(
                      label: 'motorcycle_only',
                      tone: PillTone.info,
                      icon: Icons.two_wheeler_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (space.isUnconfirmed) ...[
                const Callout(
                  tone: PillTone.neutral,
                  icon: Icons.texture_rounded,
                  title: 'Unconfirmed far-end bay',
                  message:
                      'Excluded from confirmed allocatable free totals pending camera verification.',
                ),
                const SizedBox(height: 14),
              ] else if (space.isInformalAisle) ...[
                const Callout(
                  tone: PillTone.warn,
                  icon: Icons.alt_route_rounded,
                  title: 'Informal aisle zone (non-bay)',
                  message:
                      'Tracked visually for aisle obstruction awareness; never allocated as a formal parking bay.',
                ),
                const SizedBox(height: 14),
              ] else if (space.hasOccupancyConflict) ...[
                const Callout(
                  tone: PillTone.err,
                  icon: Icons.report_problem_outlined,
                  title: 'Occupancy conflict',
                  message:
                      'Overhead camera sees a vehicle in this bay, but FastAPI has no active visit assigned to it.',
                ),
                const SizedBox(height: 14),
              ] else if (space.isUnknownOrStale) ...[
                const Callout(
                  tone: PillTone.warn,
                  icon: Icons.videocam_off_outlined,
                  title: 'Camera reading unavailable',
                  message:
                      'Excluded from free capacity until the overhead camera sends a fresh reading.',
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: p.subtle,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    KeyValueRow(
                      label: 'Slot / Space',
                      value: '${space.displaySlotLabel} (${space.spaceCode})',
                      mono: true,
                    ),
                    KeyValueRow(
                      label: 'Lot code',
                      value: space.lotCode,
                      mono: true,
                    ),
                    KeyValueRow(
                      label: 'Compatibility',
                      value: space.compatibility,
                      mono: true,
                    ),
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
                          ? '${space.assignedVehicleCode} (${space.assignedUserCode ?? 'N/A'})'
                          : 'None',
                      mono: true,
                    ),
                    KeyValueRow(
                      label: 'Last updated',
                      value:
                          ManilaTime.formatTimeOnly(space.lastObservedAtUtc),
                      mono: true,
                    ),
                    KeyValueRow(
                      label: 'Space UUID',
                      value: space.spaceId,
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
                  ],
                ),
              ),
              if (space.buildingDistanceMeters.isNotEmpty) ...[
                const SizedBox(height: 18),
                const SectionHeader(title: 'Walking distance to buildings'),
                const SizedBox(height: 8),
                for (final e in space.buildingDistanceMeters.entries)
                  KeyValueRow(
                    label: e.key,
                    value: '${e.value} meters',
                    mono: true,
                  ),
              ],
              if (!lotMeta.manualEditLocked) ...[
                const SizedBox(height: 18),
                if (isAdmin && actor != null)
                  SentryCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(
                          title: 'Lot B1 (CIT) manual slot controls',
                          subtitle:
                              'Administrator-only overrides for manually tracked bays.',
                        ),
                        const SizedBox(height: 8),
                        Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile(
                            key: Key('b1_slot_active_switch_${space.spaceCode}'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Slot Active (Allocatable)'),
                            value: space.isBayActive,
                            onChanged: (val) {
                              ref
                                  .read(sentryScenarioProvider.notifier)
                                  .toggleLotB1SpaceManual(
                                    spaceCode: space.spaceCode,
                                    actor: actor,
                                    isBayActive: val,
                                  );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          key: Key(
                              'b1_manual_status_toggle_${space.spaceCode}'),
                          onPressed: () {
                            final nextStatus =
                                space.physicalStatus == 'vacant'
                                    ? 'occupied'
                                    : 'vacant';
                            ref
                                .read(sentryScenarioProvider.notifier)
                                .toggleLotB1SpaceManual(
                                  spaceCode: space.spaceCode,
                                  actor: actor,
                                  physicalStatus: nextStatus,
                                );
                          },
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: Text(
                            space.physicalStatus == 'vacant'
                                ? 'Mark Manually Occupied'
                                : 'Mark Manually Available',
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Callout(
                    tone: PillTone.neutral,
                    icon: Icons.lock_outline_rounded,
                    title: 'Read-only bay view',
                    message:
                        'Guards monitor bay occupancy in read-only mode. Only Administrators can adjust Lot B1 manual bays.',
                  ),
              ] else ...[
                const SizedBox(height: 18),
                const Callout(
                  key: Key('camera_locked_slot_notice'),
                  tone: PillTone.info,
                  icon: Icons.videocam_outlined,
                  title: 'Camera-sensed lot — manual slot edits are locked',
                  message:
                      'Lots B2–B4 are tracked automatically by overhead vision telemetry and cannot be manually toggled.',
                ),
              ],
              if (isMock && lotMeta.lotCode == 'B1' && isAdmin) ...[
                const SizedBox(height: 12),
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
          );
        },
      ),
    );
  }

  Widget _buildParkingRulesView(BuildContext context, bool isAdmin) {
    final p = SentryPalette.of(context);
    final ops = ref.watch(desktopOpsControllerProvider);
    final actor = ref.watch(authControllerProvider).profile;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 76, 22, 22),
      decoration: BoxDecoration(
        color: p.subtle.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ops.parkingRules.isEmpty)
            const EmptyState(
              icon: Icons.gavel_rounded,
              title: 'No parking rules loaded',
              message:
                  'Live campus parking rules will load here when synced from FastAPI.',
            )
          else
            for (var i = 0; i < ops.parkingRules.length; i++) ...[
              if (i > 0) Divider(color: p.line, height: 22),
              _buildRuleRow(context, p, ops.parkingRules[i], isAdmin, actor),
            ],
          if (ops.parkingRuleHistory.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionHeader(
              title: 'Rule change history',
              subtitle: 'Audited edits to campus parking rules.',
            ),
            const SizedBox(height: 10),
            for (final ch in ops.parkingRuleHistory.take(10))
              KeyValueRow(
                label: '${ch.ruleTitle} (${ch.actorUserCode})',
                value:
                    '${ch.previousValue} -> ${ch.newValue} · ${ManilaTime.formatDateTime(ch.changedAtUtc)}',
                mono: true,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRuleRow(
    BuildContext context,
    SentryPalette p,
    ParkingRuleDto rule,
    bool isAdmin,
    dynamic actor,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rule.title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                rule.description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: p.muted),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusPill(
              label: rule.valueText,
              tone: PillTone.info,
              monospace: true,
            ),
            if (isAdmin && actor != null)
              OutlinedButton.icon(
                key: Key('edit_parking_rule_${rule.ruleKey}'),
                onPressed: () => _openEditRuleDialog(context, rule, actor),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _openEditRuleDialog(
    BuildContext context,
    ParkingRuleDto rule,
    dynamic actor,
  ) async {
    final ctrl = TextEditingController(text: rule.valueText);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update ${rule.title}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            key: Key('parking_rule_value_field_${rule.ruleKey}'),
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Rule value',
              hintText: 'Enter updated rule setting',
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Key('parking_rule_save_${rule.ruleKey}'),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updated == null || updated.isEmpty || !mounted) return;
    await ref.read(desktopOpsControllerProvider.notifier).updateParkingRule(
          ruleKey: rule.ruleKey,
          valueText: updated,
          actor: actor,
        );
  }

  Widget _buildBuildingPriorityMatrix(BuildContext context) {
    final p = SentryPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 76, 22, 22),
      decoration: BoxDecoration(
        color: p.subtle.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
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
                    runSpacing: 6,
                    children: List.generate(row.orderedLots.length, (idx) {
                      final lotCode = row.orderedLots[idx];
                      return StatusPill(
                        label: lotCode == 'B5'
                            ? '${idx + 1}. $lotCode (Overflow)'
                            : '${idx + 1}. Lot $lotCode',
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
          duration:
              SentryMotion.of(context, const Duration(milliseconds: 180)),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? SentryColors.crimson : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: SentryColors.crimson.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : p.text,
            ),
          ),
        ),
      ),
    );
  }
}
