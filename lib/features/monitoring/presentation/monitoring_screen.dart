import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/auth_models.dart';
import '../../access_logs/presentation/access_logs_screen.dart';
import '../../device_monitoring/presentation/device_monitoring_screen.dart';
import '../../guard_reviews/presentation/guard_reviews_screen.dart';
import '../../live_gate_monitoring/presentation/live_gate_monitoring_screen.dart';

/// Unified `Monitoring` workspace hosting:
/// - Sub-tab 0: Live Gates (Entry/Exit lanes + BSUAL- 4-digit Guest Pass Verification)
/// - Sub-tab 1: Review Cases (Exception review queue)
/// - Sub-tab 2: Entries & Exits (Access logs)
/// - Sub-tab 3: Cameras & Devices (Site devices telemetry)
/// - Sub-tab 4: Guard Accounts (Admin only — Guard roster CRUD)
class MonitoringScreen extends ConsumerWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final profile = ref.watch(authControllerProvider).profile;
    final isAdmin = profile?.role.isAdmin ?? false;
    final maxTab = isAdmin ? 4 : 3;
    final rawTab = ref.watch(monitoringSubTabProvider);
    final subTab = rawTab.clamp(0, maxTab);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          decoration: BoxDecoration(
            color: p.card.withValues(alpha: 0.85),
            border: Border(bottom: BorderSide(color: p.line)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentTabs(
              keyPrefix: 'monitoring_subtab',
              labels: [
                'Live Gates',
                'Review Cases',
                'Entries & Exits',
                'Cameras & Devices',
                if (isAdmin) 'Guard Accounts',
              ],
              icons: [
                Icons.sensors_rounded,
                Icons.rule_folder_outlined,
                Icons.history_rounded,
                Icons.router_outlined,
                if (isAdmin) Icons.security_rounded,
              ],
              selected: subTab,
              onChanged: (i) {
                ref.read(monitoringSubTabProvider.notifier).state = i;
              },
            ),
          ),
        ),
        Expanded(
          child: SmoothSwitcher(
            switchKey: subTab,
            child: switch (subTab) {
              0 => const LiveGateMonitoringScreen(),
              1 => const GuardReviewsScreen(),
              2 => const AccessLogsScreen(),
              3 => const DeviceMonitoringScreen(),
              _ => const _GuardAccountsAdminTab(),
            },
          ),
        ),
      ],
    );
  }
}

class _GuardAccountsAdminTab extends ConsumerStatefulWidget {
  const _GuardAccountsAdminTab();

  @override
  ConsumerState<_GuardAccountsAdminTab> createState() =>
      _GuardAccountsAdminTabState();
}

class _GuardAccountsAdminTabState
    extends ConsumerState<_GuardAccountsAdminTab> {
  String? _banner;

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null || !profile.role.isAdmin) {
      return const ScreenScaffold(
        children: [
          RoleRestrictedPanel(
            featureName: 'Security Guard Accounts',
            minimumRole: 'administrator',
          ),
        ],
      );
    }
    final ops = ref.watch(desktopOpsControllerProvider);

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Guard accounts',
          subtitle:
              'Administrator-only roster for security guard desktop logins and gate assignments.',
          actions: [
            FilledButton.icon(
              key: const Key('guard_add_btn'),
              onPressed: () => _openGuardDialog(context, actor: profile),
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Add Guard'),
            ),
          ],
        ),
        if (_banner != null) ...[
          const SizedBox(height: 14),
          Callout(
            tone: PillTone.ok,
            icon: Icons.check_circle_outline_rounded,
            title: 'Guard Roster Updated',
            message: _banner!,
          ),
        ],
        const SizedBox(height: 18),
        SentryCard(
          padding: const EdgeInsets.all(20),
          child: ops.guardAccounts.isEmpty
              ? const EmptyState(
                  icon: Icons.security_outlined,
                  title: 'No guard accounts loaded',
                  message: 'Guard accounts will populate here once synced.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < ops.guardAccounts.length; i++) ...[
                      if (i > 0) Divider(color: p.line, height: 22),
                      _buildGuardRow(context, p, ops.guardAccounts[i], profile),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildGuardRow(
    BuildContext context,
    SentryPalette p,
    ProfileDto guard,
    ProfileDto actor,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  guard.fullName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                StatusPill(
                  label: guard.userCode,
                  tone: PillTone.neutral,
                  monospace: true,
                ),
                StatusPill(
                  label: guard.isActive ? 'active' : 'inactive',
                  tone: guard.isActive ? PillTone.ok : PillTone.err,
                  monospace: true,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${guard.email ?? guard.username} · Station: ${guard.assignedStation}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              key: Key('guard_edit_${guard.userCode}'),
              onPressed: () =>
                  _openGuardDialog(context, actor: actor, existing: guard),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            ),
            OutlinedButton.icon(
              key: Key('guard_toggle_${guard.userCode}'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    guard.isActive ? SentryColors.crimson : p.okText,
              ),
              onPressed: () {
                ref
                    .read(desktopOpsControllerProvider.notifier)
                    .toggleGuardActive(guard.userId, actor: actor);
                setState(() {
                  _banner =
                      '${guard.isActive ? 'Deactivated' : 'Activated'} guard ${guard.fullName} (${guard.userCode}).';
                });
              },
              icon: Icon(
                guard.isActive
                    ? Icons.person_off_outlined
                    : Icons.check_circle_outline_rounded,
                size: 16,
              ),
              label: Text(guard.isActive ? 'Deactivate' : 'Activate'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openGuardDialog(
    BuildContext context, {
    required ProfileDto actor,
    ProfileDto? existing,
  }) async {
    final codeCtrl = TextEditingController(text: existing?.userCode ?? '');
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final stationCtrl = TextEditingController(
      text: existing?.assignedStation ?? 'Main Gate Booth 1',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Security Guard' : 'Edit Guard'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('guard_dialog_code_field'),
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Guard Code (e.g. G002)'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('guard_dialog_name_field'),
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('guard_dialog_email_field'),
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email / Login'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('guard_dialog_station_field'),
                controller: stationCtrl,
                decoration: const InputDecoration(labelText: 'Assigned Station'),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('guard_dialog_save_btn'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true &&
        codeCtrl.text.trim().isNotEmpty &&
        nameCtrl.text.trim().isNotEmpty &&
        mounted) {
      ref.read(desktopOpsControllerProvider.notifier).addOrUpdateGuardAccount(
            existingUserId: existing?.userId,
            userCode: codeCtrl.text,
            fullName: nameCtrl.text,
            email: emailCtrl.text.trim().isEmpty
                ? '${codeCtrl.text.trim().toLowerCase()}@sentry.batstateu.edu.ph'
                : emailCtrl.text,
            assignedStation: stationCtrl.text,
            actor: actor,
          );
      setState(() {
        _banner =
            '${existing == null ? 'Added' : 'Updated'} guard ${nameCtrl.text.trim()} (${codeCtrl.text.trim().toUpperCase()}).';
      });
    }
  }
}
