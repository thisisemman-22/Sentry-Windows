import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/spec_2026_models.dart';

/// Guard Screen 5: `Overdue Guest Cars` — dedicated list of guest vehicles that
/// entered campus and never exited past their approved visit window.
class GuardOverdueGuestsScreen extends ConsumerWidget {
  const GuardOverdueGuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final requests = ref.watch(
      desktopOpsControllerProvider.select((o) => o.guestVisitRequests),
    );
    final nowUtc = DateTime.now().toUtc();
    final overdue = requests.where((g) => g.isOverdue(nowUtc)).toList()
      ..sort((a, b) => a.windowEndUtc.compareTo(b.windowEndUtc));

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Overdue Guest Cars',
          subtitle:
              'Guest vehicles currently inside campus that did not exit before their visit window closed.',
          actions: [
            StatusPill(
              key: const Key('overdue_guest_count_pill'),
              label: '${overdue.length} overdue',
              tone: overdue.isEmpty ? PillTone.ok : PillTone.err,
              monospace: true,
            ),
          ],
        ),
        const SizedBox(height: 22),

        Reveal(
          index: 1,
          child: SentryCard(
            padding: const EdgeInsets.all(22),
            child: overdue.isEmpty
                ? const EmptyState(
                    showBrandLogo: true,
                    icon: Icons.verified_outlined,
                    title: 'No overdue guest cars',
                    message:
                        'All checked-in guest vehicles are currently within their approved visit window.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < overdue.length; i++) ...[
                        if (i > 0) Divider(color: p.line, height: 18),
                        _buildOverdueRow(context, overdue[i], nowUtc),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverdueRow(
    BuildContext context,
    GuestVisitRequestDto item,
    DateTime nowUtc,
  ) {
    final enteredUtc = item.checkedInAtUtc ?? item.windowStartUtc;
    final overdueBy = nowUtc.difference(item.windowEndUtc);
    final overdueLabel = 'Overdue ${ManilaTime.formatDuration(overdueBy)}';

    return SentryRowTile(
      key: Key('overdue_guest_row_${item.visitRequestId}'),
      leading: PlateBadge(
        plateText: item.plateNumber,
        isCompact: true,
      ),
      title: item.guestFullName,
      subtitle:
          'Entered ${ManilaTime.formatShort(enteredUtc)} PHT · Host: ${item.hostName}',
      badges: [
        StatusPill(
          label: item.vehicleType.toUpperCase(),
          tone: PillTone.neutral,
          monospace: true,
        ),
        StatusPill(
          label: overdueLabel,
          tone: PillTone.err,
          monospace: true,
        ),
      ],
      onTap: () => showDetailsSheet<void>(
        context,
        frosted: true,
        title: item.guestFullName,
        subtitle: '${item.plateNumber} · $overdueLabel',
        builder: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyValueRow(label: 'Vehicle plate', value: item.plateNumber, mono: true),
            KeyValueRow(label: 'Vehicle type', value: item.vehicleType),
            KeyValueRow(
              label: 'Entry time (PHT)',
              value: ManilaTime.formatDateTime(enteredUtc),
              mono: true,
            ),
            KeyValueRow(
              label: 'Window ended (PHT)',
              value: ManilaTime.formatDateTime(item.windowEndUtc),
              mono: true,
            ),
            KeyValueRow(
              label: 'Overdue duration',
              value: ManilaTime.formatDuration(overdueBy),
              mono: true,
            ),
            const Divider(height: 20),
            KeyValueRow(
              label: 'Host',
              value: '${item.hostName} (${item.hostDepartment})',
            ),
            KeyValueRow(label: 'Purpose', value: item.purpose),
          ],
        ),
      ),
    );
  }
}
