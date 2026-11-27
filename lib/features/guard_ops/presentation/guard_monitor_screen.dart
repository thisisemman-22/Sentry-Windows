import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/fixtures/synthetic_fixtures.dart';
import '../../../shared/models/device_models.dart';
import '../../../shared/models/parking_models.dart';

/// Guard Screen 2: `Monitor` — Live `B1–B5` availability (read-only),
/// camera online/offline status, and live entries & exits stream.
class GuardMonitorScreen extends ConsumerStatefulWidget {
  const GuardMonitorScreen({super.key});

  @override
  ConsumerState<GuardMonitorScreen> createState() => _GuardMonitorScreenState();
}

class _GuardMonitorScreenState extends ConsumerState<GuardMonitorScreen> {
  int _streamFilter = 0; // 0 = All, 1 = Entries, 2 = Exits

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final sysState = ref.watch(sentryScenarioProvider);
    final ops = ref.watch(desktopOpsControllerProvider);
    final config = ref.watch(appConfigProvider);
    final lots = sysState.computeLotSummaries();
    final awaitingPassage = sysState.activeLaneAttempts.values
        .where((a) =>
            a.latestDecision?.outcome == 'allowed' && !a.passageConfirmed)
        .toList();

    final streamItems = _buildStreamItems(sysState.visits, ops.manualGuestEntries);
    final filteredStream = streamItems.where((entry) {
      if (_streamFilter == 1) return !entry.isExit;
      if (_streamFilter == 2) return entry.isExit;
      return true;
    }).toList();

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Monitor',
          subtitle:
              'Live B1–B5 lot availability (read-only), camera online/offline status, and real-time entries and exits.',
          actions: [
            if (config.isReal)
              OutlinedButton.icon(
                key: const Key('guard_monitor_refresh_button'),
                onPressed: () {
                  ref.read(sentryScenarioProvider.notifier).refreshRealSnapshot();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // 1. Live B1–B5 Read-Only Lot Availability Strip
        Reveal(
          index: 1,
          child: sysState.spaces.isEmpty
              ? SentryCard(
                  child: EmptyState(
                    showBrandLogo: true,
                    icon: Icons.local_parking_outlined,
                    title: 'Awaiting lot telemetry',
                    message:
                        'Live B1–B5 bay availability will populate once FastAPI telemetry connects.',
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 1040
                        ? 5
                        : (constraints.maxWidth >= 680 ? 3 : 2);
                    const spacing = 12.0;
                    final cardWidth =
                        (constraints.maxWidth - spacing * (cols - 1)) / cols;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final lot in lots)
                          SizedBox(
                            width: cardWidth,
                            child: _ReadOnlyLotCard(
                              lot: lot,
                              onTap: () => _showLotReadOnlySheet(context, lot),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 20),

        if (awaitingPassage.isNotEmpty) ...[
          Reveal(
            index: 2,
            child: Callout(
              tone: PillTone.ok,
              icon: Icons.sensors_rounded,
              title:
                  '${awaitingPassage.length} vehicle awaiting physical barrier crossing',
              message: awaitingPassage
                  .map((a) =>
                      '${a.plateText ?? a.rfidUid ?? a.vehicleCode ?? 'Vehicle'} at ${a.laneId}')
                  .join(' · '),
              action: FilledButton.icon(
                key: const Key('guard_monitor_confirm_crossing_btn'),
                style: FilledButton.styleFrom(
                  backgroundColor: p.ok,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final first = awaitingPassage.first;
                  final actor = ref.read(authControllerProvider).profile ??
                      SentryFixtures.guardOperator;
                  ref
                      .read(sentryScenarioProvider.notifier)
                      .confirmVehicleCrossedGate(
                        laneId: first.laneId,
                        notes:
                            'Guard ${actor.userCode} confirmed barrier crossing from Monitor screen.',
                        actor: actor,
                      );
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                label: const Text('Confirm crossed'),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 2. Two-column Cameras Status & Live Entries/Exits Stream
        Reveal(
          index: 3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final camerasCard = _buildCamerasCard(context, p, sysState.devices);
              final streamCard = _buildStreamCard(context, p, filteredStream);
              if (constraints.maxWidth < 980) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    camerasCard,
                    const SizedBox(height: 16),
                    streamCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: camerasCard),
                  const SizedBox(width: 18),
                  Expanded(flex: 7, child: streamCard),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCamerasCard(
    BuildContext context,
    SentryPalette p,
    List<DeviceDto> devices,
  ) {
    final onlineCount =
        devices.where((d) => d.effectiveStatus() == 'online').length;
    return SentryCard(
      key: const Key('guard_monitor_cameras_card'),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Cameras & devices',
            subtitle: 'Gate readers and overhead bay cameras (read-only).',
            trailing: devices.isEmpty
                ? null
                : StatusPill(
                    label: '$onlineCount / ${devices.length} online',
                    tone: onlineCount == devices.length
                        ? PillTone.ok
                        : PillTone.warn,
                    monospace: true,
                  ),
          ),
          const SizedBox(height: 14),
          if (devices.isEmpty)
            const EmptyState(
              showBrandLogo: true,
              icon: Icons.videocam_off_outlined,
              title: 'No device telemetry',
              message:
                  'Camera online/offline statuses will appear once hardware heartbeats connect.',
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < devices.length; i++) ...[
                  if (i > 0) Divider(color: p.line, height: 18),
                  SentryRowTile(
                    leading: Icon(
                      devices[i].deviceType == 'rfid_reader'
                          ? Icons.nfc_rounded
                          : (devices[i].deviceType == 'gate_controller'
                              ? Icons.toll_rounded
                              : Icons.videocam_outlined),
                      size: 20,
                      color: devices[i].effectiveStatus() == 'online'
                          ? p.okText
                          : (devices[i].effectiveStatus() == 'degraded'
                              ? p.warnText
                              : SentryColors.crimson),
                    ),
                    title: '${devices[i].deviceCode} · ${devices[i].displayName}',
                    subtitle: devices[i].locationLabel,
                    badges: [
                      StatusPill.fromDeviceStatus(devices[i].effectiveStatus()),
                    ],
                    onTap: () => showDetailsSheet<void>(
                      context,
                      frosted: true,
                      title:
                          '${devices[i].deviceCode} · ${devices[i].displayName}',
                      subtitle: devices[i].locationLabel,
                      builder: (ctx) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          KeyValueRow(
                            label: 'Status',
                            value: devices[i].effectiveStatus(),
                          ),
                          KeyValueRow(
                            label: 'Device type',
                            value: devices[i].deviceType,
                            mono: true,
                          ),
                          KeyValueRow(
                            label: 'Last heartbeat',
                            value: ManilaTime.formatDateTime(
                                devices[i].lastReceivedAtUtc),
                            mono: true,
                          ),
                          if (devices[i].lastErrorCode != null)
                            KeyValueRow(
                              label: 'Last error',
                              value: devices[i].lastErrorCode!,
                              mono: true,
                            ),
                        ],
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

  Widget _buildStreamCard(
    BuildContext context,
    SentryPalette p,
    List<_StreamEventItem> items,
  ) {
    return SentryCard(
      key: const Key('guard_monitor_stream_card'),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Live entries & exits',
            subtitle: 'Recent vehicle passages and manual guest entries.',
            trailing: SegmentTabs(
              keyPrefix: 'guard_stream_filter',
              labels: const ['All', 'Entries', 'Exits'],
              selected: _streamFilter,
              onChanged: (i) => setState(() => _streamFilter = i),
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const EmptyState(
              showBrandLogo: true,
              icon: Icons.directions_car_outlined,
              title: 'No gate movement recorded',
              message:
                  'Live campus entries and exits will stream here as vehicles cross Gates 1 and 2.',
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(color: p.line, height: 18),
                  SentryRowTile(
                    leading: items[i].plateOrCode != null
                        ? PlateBadge(
                            plateText: items[i].plateOrCode,
                            isCompact: true,
                          )
                        : MonogramAvatar(name: items[i].title),
                    title: items[i].title,
                    subtitle: items[i].subtitle,
                    badges: [
                      StatusPill(
                        label: items[i].isExit ? 'Exited' : 'Inside',
                        tone: items[i].isExit ? PillTone.neutral : PillTone.ok,
                      ),
                      Text(
                        ManilaTime.formatShort(items[i].timestampUtc),
                        style: SentryTheme.mono(fontSize: 11.5, color: p.muted),
                      ),
                    ],
                    onTap: () => showDetailsSheet<void>(
                      context,
                      frosted: true,
                      title: items[i].title,
                      subtitle: items[i].subtitle,
                      builder: (ctx) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          KeyValueRow(
                            label: 'Direction',
                            value: items[i].isExit ? 'Exit' : 'Entry',
                          ),
                          KeyValueRow(
                            label: 'Timestamp (PHT)',
                            value:
                                ManilaTime.formatDateTime(items[i].timestampUtc),
                            mono: true,
                          ),
                          KeyValueRow(
                            label: 'Details',
                            value: items[i].detailLine,
                          ),
                        ],
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

  List<_StreamEventItem> _buildStreamItems(
    List<dynamic> visits,
    List<dynamic> manualEntries,
  ) {
    final items = <_StreamEventItem>[];
    for (final v in visits) {
      final isExit = !v.isActive;
      final ts = isExit ? (v.exitedAtUtc ?? v.enteredAtUtc) : v.enteredAtUtc;
      items.add(_StreamEventItem(
        title: '${v.userCode} · ${v.vehicleCode} (${v.vehicleType})',
        subtitle:
            '${v.lotCode} · ${v.spaceCode} · ${isExit ? v.exitLaneId ?? 'Gate 2' : v.entryLaneId}',
        plateOrCode: v.vehicleCode,
        isExit: isExit,
        timestampUtc: ts,
        detailLine:
            'Visit ${v.visitCode} (${v.status}) via ${isExit ? v.exitConfirmationSource ?? 'sensor' : v.entryConfirmationSource}.',
      ));
    }
    for (final m in manualEntries) {
      items.add(_StreamEventItem(
        title: m.guestFullName,
        subtitle:
            'Manual ${m.isMotorcycle ? 'Guest Motorcycle' : 'Guest on Foot'}${m.passCode != null ? ' · ${m.passCode}' : ''}',
        plateOrCode: m.plateOrDescription,
        isExit: false,
        timestampUtc: m.recordedAtUtc,
        detailLine:
            'Recorded by ${m.recordedByUserCode}${m.notes.isNotEmpty ? ' · ${m.notes}' : ''}',
      ));
    }
    items.sort((a, b) => b.timestampUtc.compareTo(a.timestampUtc));
    return items.take(12).toList();
  }

  void _showLotReadOnlySheet(BuildContext context, LotSummaryDto lot) {
    showDetailsSheet<void>(
      context,
      frosted: true,
      title: 'Lot ${lot.lotCode} · ${lot.lotName}',
      subtitle: 'Read-only live occupancy summary (managed by Administrators).',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyValueRow(label: 'Landmark', value: lot.nearestLandmark),
          KeyValueRow(
            label: 'Available bays',
            value: lot.isOverflow
                ? 'Overflow Zone (aggregate tracking)'
                : '${lot.trulyAvailableSpaces} / ${lot.totalSpaces}',
            mono: true,
          ),
          if (!lot.isOverflow) ...[
            KeyValueRow(
              label: 'Occupied bays',
              value: '${lot.physicalOccupied}',
              mono: true,
            ),
            KeyValueRow(
              label: 'Held (30s)',
              value: '${lot.allocationHeld}',
              mono: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadOnlyLotCard extends StatelessWidget {
  final LotSummaryDto lot;
  final VoidCallback onTap;

  const _ReadOnlyLotCard({required this.lot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final ratio = lot.totalSpaces > 0
        ? (lot.physicalOccupied + lot.allocationHeld) / lot.totalSpaces
        : 0.0;
    final hasSpace = lot.trulyAvailableSpaces > 0;
    final statusTone = lot.isOverflow
        ? PillTone.info
        : (hasSpace ? PillTone.ok : PillTone.err);
    final statusLabel = lot.isOverflow
        ? 'Overflow'
        : (hasSpace ? 'Available' : 'Full');

    return SentryCard(
      key: Key('guard_monitor_lot_${lot.lotCode}'),
      padding: const EdgeInsets.all(16),
      radius: 16,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                lot.lotCode,
                style: SentryTheme.display(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                ),
              ),
              const Spacer(),
              StatusPill(label: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            lot.nearestLandmark,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 10),
          Text(
            lot.isOverflow
                ? 'Aggregate overflow'
                : '${lot.trulyAvailableSpaces} / ${lot.totalSpaces} free',
            style: SentryTheme.mono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: lot.isOverflow ? 0.35 : ratio.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: p.subtle,
              valueColor: AlwaysStoppedAnimation(
                lot.isOverflow
                    ? p.info
                    : (hasSpace ? p.ok : SentryColors.crimson),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamEventItem {
  final String title;
  final String subtitle;
  final String? plateOrCode;
  final bool isExit;
  final DateTime timestampUtc;
  final String detailLine;

  const _StreamEventItem({
    required this.title,
    required this.subtitle,
    this.plateOrCode,
    required this.isExit,
    required this.timestampUtc,
    required this.detailLine,
  });
}
