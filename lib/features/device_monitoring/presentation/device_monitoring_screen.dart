import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/device_models.dart';

/// View 7: `Devices` — calm health list for cameras, RFID readers, and gate
/// controllers. Clicking any device opens its firmware, boot ID, and sequence
/// counters in a right-hand details sheet.
class DeviceMonitoringScreen extends ConsumerWidget {
  const DeviceMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final sysState = ref.watch(sentryScenarioProvider);

    return ScreenScaffold(
      children: [
        const PageIntro(
          title: 'Site devices',
          subtitle:
              'Cameras, RFID readers, and gate controllers across campus. Click any device for firmware and heartbeat details.',
          actions: [
            InfoHint(
              'Heartbeat cadence is 10s (offline after 30s). '
              'For safety, no remote barrier-open button exists here; '
              'gates only actuate on verified access decisions. '
              'If an overhead lot camera goes offline, its bays become unknown (never counted as free).',
            ),
          ],
        ),
        const SizedBox(height: 24),

        for (var i = 0; i < sysState.devices.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Reveal(
            index: i + 1,
            child: _DeviceRowCard(
              device: sysState.devices[i],
              palette: p,
              onInspect: () =>
                  _showDeviceDetails(context, sysState.devices[i]),
            ),
          ),
        ],
      ],
    );
  }

  void _showDeviceDetails(BuildContext context, DeviceDto dev) {
    final status = dev.effectiveStatus();
    showDetailsSheet<void>(
      context,
      title: '${dev.deviceCode} · ${dev.displayName}',
      subtitle: dev.locationLabel,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusPill.fromDeviceStatus(status),
              if (dev.lastErrorCode != null) ...[
                const SizedBox(width: 8),
                StatusPill(
                  label: dev.lastErrorCode!,
                  tone: PillTone.err,
                  monospace: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Producer & firmware'),
          const SizedBox(height: 8),
          KeyValueRow(label: 'Producer ID', value: dev.producerId, mono: true),
          KeyValueRow(label: 'Device type', value: dev.deviceType, mono: true),
          KeyValueRow(
            label: 'Software version',
            value: dev.softwareVersion,
            mono: true,
          ),
          KeyValueRow(label: 'Boot ID', value: dev.bootId, mono: true),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Heartbeat telemetry'),
          const SizedBox(height: 8),
          KeyValueRow(
            label: 'Sequence number',
            value: '#${dev.sequenceNumber}',
            mono: true,
          ),
          KeyValueRow(
            label: 'Uptime',
            value: ManilaTime.formatDuration(
              Duration(seconds: dev.uptimeSeconds),
            ),
            mono: true,
          ),
          KeyValueRow(
            label: 'Last heartbeat',
            value: ManilaTime.formatDateTime(dev.lastReceivedAtUtc),
            mono: true,
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Capabilities'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cap in dev.capabilities)
                StatusPill(
                  label: cap,
                  tone: PillTone.info,
                  monospace: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceRowCard extends ConsumerWidget {
  final DeviceDto device;
  final SentryPalette palette;
  final VoidCallback onInspect;

  const _DeviceRowCard({
    required this.device,
    required this.palette,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = device.effectiveStatus();
    final accent = status == 'offline'
        ? palette.err
        : status == 'degraded'
            ? palette.warn
            : null;

    return SentryCard(
      key: Key('device_card_${device.deviceCode}'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      accent: accent,
      onTap: onInspect,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.subtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  device.deviceCode,
                  style: SentryTheme.mono(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: palette.crimson,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        device.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 10),
                      StatusPill.fromDeviceStatus(status),
                      if (device.lastErrorCode != null) ...[
                        const SizedBox(width: 8),
                        StatusPill(
                          label: device.lastErrorCode!,
                          tone: PillTone.err,
                          monospace: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${device.locationLabel} · Last seen ${ManilaTime.formatTimeOnly(device.lastReceivedAtUtc)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            children: [
              OutlinedButton(
                key: Key('dev_${device.deviceCode}_online_btn'),
                onPressed: () {
                  ref
                      .read(sentryScenarioProvider.notifier)
                      .setDeviceSimulatedStatus(device.deviceCode, 'online');
                },
                child: const Text('Online'),
              ),
              OutlinedButton(
                key: Key('dev_${device.deviceCode}_degraded_btn'),
                onPressed: () {
                  ref
                      .read(sentryScenarioProvider.notifier)
                      .setDeviceSimulatedStatus(device.deviceCode, 'degraded');
                },
                child: const Text('Degraded'),
              ),
              OutlinedButton(
                key: Key('dev_${device.deviceCode}_offline_btn'),
                onPressed: () {
                  ref
                      .read(sentryScenarioProvider.notifier)
                      .setDeviceSimulatedStatus(device.deviceCode, 'offline');
                },
                child: const Text('Offline'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
