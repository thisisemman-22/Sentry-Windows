import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/auth_models.dart';
import '../../../shared/models/spec_2026_models.dart';

/// Admin-only `Guests` workspace:
/// - Sub-tab 0: Visit Requests (`pending` | `approved` | `rejected` | `cancelled` | `expired`)
///   Approve or Reject (mandatory reason). Never reveals `BSUAL-XXXX` guest pass codes!
/// - Sub-tab 1: Guest Accounts (`Reset Password`, `Suspend` / `Reactivate`).
/// - Sub-tab 2: Overdue Guest Cars & History.
class GuestsScreen extends ConsumerStatefulWidget {
  const GuestsScreen({super.key});

  @override
  ConsumerState<GuestsScreen> createState() => _GuestsScreenState();
}

class _GuestsScreenState extends ConsumerState<GuestsScreen> {
  int _subTab = 0;
  String _statusFilter = 'all';
  String _searchQuery = '';
  String? _feedback;
  bool _feedbackIsError = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    final isAdmin = profile?.role.isAdmin ?? false;
    if (!isAdmin || profile == null) {
      return const ScreenScaffold(
        children: [
          PageIntro(
            title: 'Guests',
            subtitle: 'Campus guest visit approvals and guest accounts.',
          ),
          SizedBox(height: 18),
          RoleRestrictedPanel(
            featureName: 'Guest Visit Approvals & Accounts',
            minimumRole: 'administrator',
          ),
        ],
      );
    }

    final ops = ref.watch(desktopOpsControllerProvider);

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Guests',
          subtitle:
              'Review visitor requests, manage guest portal accounts, and monitor overdue guest vehicles.',
          actions: [
            SegmentTabs(
              keyPrefix: 'guests_subtab',
              labels: const [
                'Visit Requests',
                'Guest Accounts',
                'Overdue & History',
              ],
              icons: const [
                Icons.mark_email_read_outlined,
                Icons.badge_outlined,
                Icons.schedule_outlined,
              ],
              selected: _subTab,
              onChanged: (i) => setState(() {
                _subTab = i;
                _feedback = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Callout(
          tone: PillTone.info,
          icon: Icons.verified_user_outlined,
          title: 'Guest Pass Code Privacy',
          message:
              'Approved guests generate their 4-digit BSUAL- pass code inside their mobile app. Administrators never view pass codes; Security Guards verify the 4 digits at the gate.',
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 14),
          Callout(
            tone: _feedbackIsError ? PillTone.err : PillTone.ok,
            icon: _feedbackIsError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            title: _feedbackIsError ? 'Action blocked' : 'Updated',
            message: _feedback!,
          ),
        ],
        const SizedBox(height: 18),
        SmoothSwitcher(
          switchKey: _subTab,
          child: switch (_subTab) {
            0 => _buildVisitRequestsTab(context, ops.guestVisitRequests, profile),
            1 => _buildGuestAccountsTab(context, ops.guestAccounts, profile),
            _ => _buildOverdueAndHistoryTab(context, ops.guestVisitRequests),
          },
        ),
      ],
    );
  }

  Widget _buildVisitRequestsTab(
    BuildContext context,
    List<GuestVisitRequestDto> requests,
    ProfileDto actor,
  ) {
    final p = SentryPalette.of(context);
    final q = _searchQuery.trim().toLowerCase();
    final filtered = requests.where((r) {
      if (_statusFilter != 'all' && r.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return r.guestFullName.toLowerCase().contains(q) ||
          r.guestEmail.toLowerCase().contains(q) ||
          r.hostName.toLowerCase().contains(q) ||
          r.plateNumber.toLowerCase().contains(q) ||
          r.purpose.toLowerCase().contains(q);
    }).toList();

    return SentryCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  key: const Key('guest_requests_search_field'),
                  decoration: const InputDecoration(
                    labelText: 'Search guest, host, or plate',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              for (final status in const [
                'all',
                'pending',
                'approved',
                'rejected',
                'cancelled',
                'expired',
              ])
                FilterChip(
                  key: Key('guest_filter_$status'),
                  label: Text(status == 'all' ? 'All' : status),
                  selected: _statusFilter == status,
                  onSelected: (_) => setState(() => _statusFilter = status),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No matching guest requests',
              message:
                  'Live campus visit requests will appear here once submitted.',
            )
          else
            for (var i = 0; i < filtered.length; i++) ...[
              if (i > 0) Divider(color: p.line, height: 22),
              _buildRequestRow(context, p, filtered[i], actor),
            ],
        ],
      ),
    );
  }

  Widget _buildRequestRow(
    BuildContext context,
    SentryPalette p,
    GuestVisitRequestDto req,
    ProfileDto actor,
  ) {
    final tone = switch (req.status) {
      'approved' => PillTone.ok,
      'pending' => PillTone.warn,
      'rejected' => PillTone.err,
      _ => PillTone.neutral,
    };

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    req.guestFullName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  PlateBadge(plateText: req.plateNumber),
                  StatusPill(
                    label: req.status,
                    tone: tone,
                    monospace: true,
                  ),
                  if (req.isOverdue())
                    const StatusPill(
                      label: 'Overdue inside campus',
                      tone: PillTone.err,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Host: ${req.hostName} (${req.hostDepartment}) · Purpose: ${req.purpose}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Window (Asia/Manila): ${ManilaTime.formatDateTime(req.windowStartUtc)} -> ${ManilaTime.formatTimeOnly(req.windowEndUtc)}',
                style: SentryTheme.mono(fontSize: 12, color: p.muted),
              ),
              if (req.rejectionReason != null &&
                  req.rejectionReason!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Rejection reason: ${req.rejectionReason}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: p.errText),
                ),
              ],
            ],
          ),
        ),
        if (req.status == 'pending')
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.icon(
                key: Key('approve_guest_req_${req.visitRequestId}'),
                onPressed: () async {
                  final res = await ref
                      .read(desktopOpsControllerProvider.notifier)
                      .reviewGuestVisitRequest(
                        visitRequestId: req.visitRequestId,
                        approve: true,
                        actor: actor,
                      );
                  if (!mounted) return;
                  setState(() {
                    _feedbackIsError = !res.ok;
                    _feedback = res.ok
                        ? 'Approved visit for ${req.guestFullName}. Pass code remains private to guest mobile app.'
                        : (res.error?.message ?? 'Approval failed.');
                  });
                },
                icon: const Icon(Icons.check_rounded, size: 17),
                label: const Text('Approve'),
              ),
              OutlinedButton.icon(
                key: Key('reject_guest_req_${req.visitRequestId}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SentryColors.crimson,
                ),
                onPressed: () => _openRejectDialog(context, req, actor),
                icon: const Icon(Icons.close_rounded, size: 17),
                label: const Text('Reject'),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _openRejectDialog(
    BuildContext context,
    GuestVisitRequestDto req,
    ProfileDto actor,
  ) async {
    final reasonCtrl = TextEditingController();
    final confirmedReason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final canSubmit = reasonCtrl.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text('Reject guest visit — ${req.guestFullName}'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'A clear rejection reason is mandatory before declining a guest visit request.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('guest_reject_reason_field'),
                    controller: reasonCtrl,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Rejection reason *',
                      hintText: 'e.g. Outside approved host visiting hours',
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
                key: const Key('guest_confirm_reject_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: SentryColors.crimson,
                  foregroundColor: Colors.white,
                ),
                onPressed: canSubmit
                    ? () => Navigator.of(ctx).pop(reasonCtrl.text.trim())
                    : null,
                child: const Text('Confirm Reject'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmedReason == null || confirmedReason.isEmpty || !mounted) return;
    final res = await ref
        .read(desktopOpsControllerProvider.notifier)
        .reviewGuestVisitRequest(
          visitRequestId: req.visitRequestId,
          approve: false,
          rejectionReason: confirmedReason,
          actor: actor,
        );
    if (!mounted) return;
    setState(() {
      _feedbackIsError = !res.ok;
      _feedback = res.ok
          ? 'Rejected visit for ${req.guestFullName}: $confirmedReason'
          : (res.error?.message ?? 'Rejection failed.');
    });
  }

  Widget _buildGuestAccountsTab(
    BuildContext context,
    List<GuestAccountDto> accounts,
    ProfileDto actor,
  ) {
    final p = SentryPalette.of(context);
    return SentryCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Guest portal accounts',
            subtitle:
                'Reset forgotten passwords back to the General Password or suspend abusive guest accounts.',
          ),
          const SizedBox(height: 14),
          if (accounts.isEmpty)
            const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'No guest accounts loaded',
              message: 'Guest accounts will appear here when synced.',
            )
          else
            for (var i = 0; i < accounts.length; i++) ...[
              if (i > 0) Divider(color: p.line, height: 22),
              Wrap(
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
                            accounts[i].fullName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          StatusPill(
                            label: accounts[i].status,
                            tone: accounts[i].status == 'active'
                                ? PillTone.ok
                                : accounts[i].status == 'suspended'
                                    ? PillTone.err
                                    : PillTone.warn,
                            monospace: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${accounts[i].email} · ${accounts[i].phone}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        key: Key('reset_guest_pwd_${accounts[i].guestAccountId}'),
                        onPressed: () {
                          ref
                              .read(desktopOpsControllerProvider.notifier)
                              .resetGuestAccountPassword(
                                guestAccountId: accounts[i].guestAccountId,
                                actor: actor,
                              );
                          setState(() {
                            _feedbackIsError = false;
                            _feedback =
                                'Reset ${accounts[i].fullName} to the General Password (first-login change required).';
                          });
                        },
                        icon: const Icon(Icons.lock_reset_rounded, size: 17),
                        label: const Text('Reset Password'),
                      ),
                      OutlinedButton.icon(
                        key: Key(
                            'toggle_guest_suspend_${accounts[i].guestAccountId}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accounts[i].status == 'suspended'
                              ? p.okText
                              : SentryColors.crimson,
                        ),
                        onPressed: () {
                          final suspend = accounts[i].status != 'suspended';
                          ref
                              .read(desktopOpsControllerProvider.notifier)
                              .toggleGuestAccountSuspend(
                                guestAccountId: accounts[i].guestAccountId,
                                suspend: suspend,
                                actor: actor,
                              );
                          setState(() {
                            _feedbackIsError = false;
                            _feedback = suspend
                                ? 'Suspended guest account ${accounts[i].fullName}.'
                                : 'Reactivated guest account ${accounts[i].fullName}.';
                          });
                        },
                        icon: Icon(
                          accounts[i].status == 'suspended'
                              ? Icons.play_circle_outline_rounded
                              : Icons.block_rounded,
                          size: 17,
                        ),
                        label: Text(
                          accounts[i].status == 'suspended'
                              ? 'Reactivate'
                              : 'Suspend',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildOverdueAndHistoryTab(
    BuildContext context,
    List<GuestVisitRequestDto> requests,
  ) {
    final p = SentryPalette.of(context);
    final overdue = requests.where((r) => r.isOverdue()).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SentryCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Overdue guest vehicles (${overdue.length})',
                subtitle:
                    'Guest cars currently inside campus past their approved window.',
              ),
              const SizedBox(height: 12),
              if (overdue.isEmpty)
                const EmptyState(
                  icon: Icons.verified_outlined,
                  title: 'No overdue guest vehicles',
                  message: 'All active campus guests are within window.',
                )
              else
                for (var i = 0; i < overdue.length; i++) ...[
                  if (i > 0) Divider(color: p.line, height: 18),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          PlateBadge(plateText: overdue[i].plateNumber),
                          Text(
                            '${overdue[i].guestFullName} · Host: ${overdue[i].hostName}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      StatusPill(
                        label:
                            'Window ended ${ManilaTime.formatDateTime(overdue[i].windowEndUtc)}',
                        tone: PillTone.err,
                        monospace: true,
                      ),
                    ],
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SentryCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Guest visit log',
                subtitle:
                    'Historical record of approved, rejected, cancelled, and expired visits.',
              ),
              const SizedBox(height: 12),
              for (final r in requests)
                KeyValueRow(
                  label: '${r.guestFullName} (${r.plateNumber})',
                  value:
                      '${r.status} · ${ManilaTime.formatDateTime(r.windowStartUtc)}',
                  mono: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
