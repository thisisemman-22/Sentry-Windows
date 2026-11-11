import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/config/roster_mode.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/role_restricted_panel.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/auth_models.dart';

/// View 8: `Administration` — operator session, registered drivers/vehicles,
/// and system audit trail.
class AdministrationScreen extends ConsumerStatefulWidget {
  const AdministrationScreen({super.key});

  @override
  ConsumerState<AdministrationScreen> createState() =>
      _AdministrationScreenState();
}

class _AdministrationScreenState extends ConsumerState<AdministrationScreen> {
  int _adminSubTab = 0; // 0 = Drivers & vehicles, 1 = Audit log
  String? _guardForbiddenTestResult;

  void _openRegisterVehicleDialog(String userCode) {
    final codeCtrl = TextEditingController(text: 'V009');
    final plateCtrl = TextEditingController(text: 'BSU 2026');
    String selectedType = 'car';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Add vehicle for $userCode'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle code (e.g. V009)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      items: const [
                        DropdownMenuItem(value: 'car', child: Text('Car')),
                        DropdownMenuItem(
                          value: 'motorcycle',
                          child: Text('Motorcycle'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedType = v);
                      },
                      decoration:
                          const InputDecoration(labelText: 'Vehicle type'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: plateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'License plate (e.g. BSU 2026)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final actor = ref.read(authControllerProvider).profile!;
                    ref
                        .read(sentryScenarioProvider.notifier)
                        .registerParticipantVehicle(
                          actor: actor,
                          userCode: userCode,
                          vehicleCode: codeCtrl.text.trim(),
                          vehicleType: selectedType,
                          plateDisplay: plateCtrl.text.trim(),
                        );
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Register vehicle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final authState = ref.watch(authControllerProvider);
    final sysState = ref.watch(sentryScenarioProvider);
    final session = authState.session!;
    final profile = session.profile;
    final isAdmin = profile.role.isAdmin;

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Administration',
          subtitle:
              'Operator profile, registered campus vehicles, and the security audit trail.',
          actions: [
            if (isAdmin)
              SegmentTabs(
                labels: [
                  'Drivers & vehicles (${sysState.participantDirectory.length})',
                  'Audit log (${sysState.auditLogs.length})',
                ],
                icons: const [
                  Icons.directions_car_outlined,
                  Icons.policy_outlined,
                ],
                selected: _adminSubTab,
                onChanged: (i) => setState(() => _adminSubTab = i),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // 1. Operator Session Card
        Reveal(
          index: 1,
          child: SentryCard(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 14,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isAdmin ? p.text : SentryColors.crimson,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : Icons.shield_rounded,
                        color: isAdmin ? p.card : Colors.white,
                        size: 22,
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
                              profile.fullName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(width: 10),
                            StatusPill(
                              label: isAdmin ? 'Administrator' : 'Guard',
                              tone: isAdmin ? PillTone.ok : PillTone.crimson,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${profile.username} · ${profile.assignedStation} · Session valid until ${ManilaTime.formatTimeOnly(session.expiresAtUtc)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        final nextRoster =
                            sysState.rosterMode == RosterMode.classDemo
                                ? RosterMode.contractSynthetic
                                : RosterMode.classDemo;
                        ref
                            .read(sentryScenarioProvider.notifier)
                            .setRosterMode(nextRoster);
                      },
                      icon: const Icon(Icons.groups_2_outlined, size: 18),
                      label: Text(
                        sysState.rosterMode == RosterMode.classDemo
                            ? 'Roster: Class Demo'
                            : 'Roster: Synthetic',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('simulate_ws_1008_expiry_button'),
                      onPressed: () {
                        ref
                            .read(authControllerProvider.notifier)
                            .expireSessionWith1008();
                      },
                      icon: const Icon(Icons.timer_off_outlined, size: 18),
                      label: const Text('Test session expiry'),
                    ),
                    FilledButton.icon(
                      key: const Key('admin_logout_button'),
                      onPressed: () {
                        ref.read(authControllerProvider.notifier).signOut();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 2. Role-Gated Sections
        if (!isAdmin)
          Reveal(
            index: 2,
            child: RoleRestrictedPanel(
              title: 'Administrator access required',
              endpointPath:
                  'GET /api/v1/admin/audit-logs · /api/v1/participants/...',
              description:
                  'You are signed in as ${profile.fullName} (Guard). Managing vehicle registrations and reading the system audit log require an Administrator account.',
              lastSimulatedError: _guardForbiddenTestResult,
              onSimulateForbiddenCall: () {
                final res = ref
                    .read(sentryScenarioProvider.notifier)
                    .fetchAuditLogsForRole(UserRole.guard);
                setState(() {
                  _guardForbiddenTestResult =
                      '${res.error?.code}: ${res.error?.message}';
                });
              },
            ),
          )
        else
          SmoothSwitcher(
            switchKey: _adminSubTab,
            child: _adminSubTab == 0
                ? _buildParticipantsCard(context, p, profile)
                : _buildAuditLogsCard(context, p),
          ),
      ],
    );
  }

  Widget _buildParticipantsCard(
    BuildContext context,
    SentryPalette p,
    ProfileDto profile,
  ) {
    final sysState = ref.watch(sentryScenarioProvider);
    return SentryCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Registered drivers & vehicles',
            subtitle:
                'Add vehicles or toggle authorization status for campus participants.',
            hint:
                'Backed by P01–P06 (/api/v1/participants/...) with admission_evaluated: false.',
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < sysState.participantDirectory.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Builder(builder: (context) {
              final u = sysState.participantDirectory[i];
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: p.subtle,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${u.fullName} (${u.userCode})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              u.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          key: Key('p05_add_vehicle_${u.userCode}'),
                          onPressed: () =>
                              _openRegisterVehicleDialog(u.userCode),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add vehicle'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final v in u.vehicles)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: p.line),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  v.vehicleCode,
                                  style: SentryTheme.mono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: p.text,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                PlateBadge(
                                  plateText: v.plateNumberDisplay,
                                  rfidUid: v.rfidUid,
                                  isCompact: true,
                                ),
                                const SizedBox(width: 10),
                                StatusPill(
                                  label: v.authorizationStatus == 'authorized'
                                      ? 'Authorized'
                                      : 'Revoked',
                                  tone: v.authorizationStatus == 'authorized'
                                      ? PillTone.ok
                                      : PillTone.err,
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  key: Key(
                                      'p06_toggle_${u.userCode}_${v.vehicleCode}'),
                                  onPressed: () {
                                    ref
                                        .read(sentryScenarioProvider.notifier)
                                        .toggleVehicleAuthorizationStatus(
                                          actor: profile,
                                          userCode: u.userCode,
                                          vehicleCode: v.vehicleCode,
                                        );
                                  },
                                  child: Text(
                                    v.authorizationStatus == 'authorized'
                                        ? 'Revoke'
                                        : 'Authorize',
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
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditLogsCard(BuildContext context, SentryPalette p) {
    final sysState = ref.watch(sentryScenarioProvider);
    return SentryCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'System audit log',
            subtitle:
                'Chronological record of guard confirmations, reviews, and vehicle updates.',
            trailing: StatusPill(
              label: '${sysState.auditLogs.length} entries',
              tone: PillTone.ok,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < sysState.auditLogs.length; i++) ...[
            if (i > 0) Divider(color: p.line, height: 22),
            Builder(builder: (context) {
              final log = sysState.auditLogs[i];
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusPill(
                        label: log.action,
                        tone: PillTone.info,
                        monospace: true,
                      ),
                      const SizedBox(width: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Text(
                          log.summary,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: p.text,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${log.actorUserCode} · ${ManilaTime.formatShort(log.occurredAtUtc)}',
                    style: SentryTheme.mono(fontSize: 12.5, color: p.muted),
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
