import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/fixtures/synthetic_fixtures.dart';
import '../../../shared/models/review_models.dart';

/// View 4: `Reviews` — calm master-detail queue for uncertain gate cases.
///
/// Progressive disclosure:
/// - Left: clean case cards with plate badge, plain reason, and status pill.
/// - Right: focused decision workspace. Raw correlation/decision/evidence UUIDs
///   open in a right-hand details sheet when needed.
class GuardReviewsScreen extends ConsumerStatefulWidget {
  const GuardReviewsScreen({super.key});

  @override
  ConsumerState<GuardReviewsScreen> createState() => _GuardReviewsScreenState();
}

class _GuardReviewsScreenState extends ConsumerState<GuardReviewsScreen> {
  String? _selectedCaseId;
  int _filterIndex = 0; // 0 = all, 1 = pending, 2 = resolved
  final TextEditingController _reasonCtrl = TextEditingController(
    text:
        'Verified student ID card and physical vehicle credentials at Gate 1 booth.',
  );
  int? _capturedExpectedVersion;
  String? _submissionFeedback;
  bool _submissionIsError = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _selectCase(GuardReviewQueueItem item) {
    setState(() {
      _selectedCaseId = item.reviewCaseId;
      _capturedExpectedVersion = item.currentAttemptVersion;
      _submissionFeedback = null;
      _submissionIsError = false;
    });
  }

  void _submitReviewAction(GuardReviewQueueItem item, String action) {
    final actor = ref.read(authControllerProvider).profile ??
        SentryFixtures.guardOperator;
    final expectedVer = _capturedExpectedVersion ?? item.currentAttemptVersion;

    final result = ref.read(sentryScenarioProvider.notifier).submitGuardReview(
          reviewCaseId: item.reviewCaseId,
          action: action,
          reason: _reasonCtrl.text,
          expectedAttemptVersion: expectedVer,
          actor: actor,
        );

    setState(() {
      if (result.ok) {
        _submissionIsError = false;
        _submissionFeedback =
            'Recorded "$action" for ${item.reviewCaseId} (v$expectedVer -> v${result.data!.currentAttemptVersion}).';
        _capturedExpectedVersion = result.data!.currentAttemptVersion;
      } else {
        _submissionIsError = true;
        _submissionFeedback =
            '${result.error!.code}: ${result.error!.message}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final sysState = ref.watch(sentryScenarioProvider);

    final filteredQueue = sysState.reviewQueue.where((item) {
      if (_filterIndex == 1) return !item.isResolved;
      if (_filterIndex == 2) return item.isResolved;
      return true;
    }).toList();

    final selectedItem = filteredQueue.firstWhere(
      (r) => r.reviewCaseId == _selectedCaseId,
      orElse: () => filteredQueue.isNotEmpty
          ? filteredQueue.first
          : sysState.reviewQueue.first,
    );
    _capturedExpectedVersion ??= selectedItem.currentAttemptVersion;
    final canApprove = selectedItem.canApprove();

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Guard reviews',
          subtitle:
              'Cases where the camera or reader needed a human check before allowing entry.',
          actions: [
            SegmentTabs(
              labels: [
                'All (${sysState.reviewQueue.length})',
                'Pending (${sysState.reviewQueue.where((r) => !r.isResolved).length})',
                'Resolved (${sysState.reviewQueue.where((r) => r.isResolved).length})',
              ],
              selected: _filterIndex,
              onChanged: (i) => setState(() => _filterIndex = i),
            ),
          ],
        ),
        const SizedBox(height: 24),

        LayoutBuilder(
          builder: (context, constraints) {
            final queueColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (filteredQueue.isEmpty)
                  const SentryCard(
                    child: EmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'No cases in this view',
                      message: 'All matching review cases have been handled.',
                    ),
                  )
                else
                  for (var i = 0; i < filteredQueue.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Reveal(
                      index: i + 1,
                      child: _ReviewCaseCard(
                        item: filteredQueue[i],
                        selected: filteredQueue[i].reviewCaseId ==
                            selectedItem.reviewCaseId,
                        onTap: () => _selectCase(filteredQueue[i]),
                      ),
                    ),
                  ],
              ],
            );

            final inspectorCard = SmoothSwitcher(
              switchKey:
                  '${selectedItem.reviewCaseId}-${selectedItem.currentAttemptVersion}-${selectedItem.isResolved}',
              child: _buildInspectorCard(
                context,
                p,
                selectedItem,
                canApprove,
              ),
            );

            if (constraints.maxWidth < 960) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  queueColumn,
                  const SizedBox(height: 20),
                  inspectorCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: queueColumn),
                const SizedBox(width: 22),
                Expanded(flex: 7, child: inspectorCard),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildInspectorCard(
    BuildContext context,
    SentryPalette p,
    GuardReviewQueueItem selectedItem,
    bool canApprove,
  ) {
    final participant =
        SentryFixtures.findParticipantByCode(selectedItem.userCode);
    final rosterMode =
        ref.watch(sentryScenarioProvider.select((s) => s.rosterMode));

    return SentryCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlateBadge(
                    plateText: selectedItem.plateText,
                    rfidUid: selectedItem.rfidUid,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _humanReasonTitle(selectedItem.reasonCode),
                        style: SentryTheme.display(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: p.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${selectedItem.reviewCaseId} · ${_laneLabel(selectedItem.laneId)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('simulate_stale_version_button'),
                    onPressed: () {
                      ref
                          .read(sentryScenarioProvider.notifier)
                          .simulateConcurrentVersionBump(
                            selectedItem.reviewCaseId,
                          );
                    },
                    icon: const Icon(Icons.sync_problem_outlined, size: 17),
                    label: const Text('Test version conflict'),
                  ),
                  IconButton(
                    tooltip: 'Inspect raw IDs and evidence envelope',
                    onPressed: () =>
                        _showCaseTechnicalSheet(context, selectedItem),
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            selectedItem.reasonMessage,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: p.slate,
                ),
          ),
          const SizedBox(height: 20),

          if (selectedItem.isHardSecurityDenial ||
              selectedItem.isAttemptExpired()) ...[
            Container(
              key: const Key('hard_denial_security_callout'),
              child: Callout(
                tone: PillTone.err,
                icon: Icons.gpp_bad_outlined,
                title: 'Approval locked for security denials',
                message:
                    'Hard security denials (${selectedItem.reasonCode}) and expired holds cannot be overridden into an active visit. You may record a denial or escalate to an administrator.',
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Concise 3-row summary (IDs hidden in Info sheet)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: p.subtle,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                KeyValueRow(
                  label: 'Driver',
                  value: participant != null
                      ? '${participant.displayName(rosterMode)} (${participant.userCode})'
                      : (selectedItem.userCode ?? 'Unregistered visitor'),
                ),
                KeyValueRow(
                  label: 'Vehicle',
                  value:
                      '${selectedItem.vehicleCode ?? 'Unregistered'} · ${selectedItem.vehicleType}',
                  mono: true,
                ),
                KeyValueRow(
                  label: 'Face match score',
                  value: selectedItem.faceSimilarityScore != null
                      ? '${selectedItem.faceSimilarityScore!.toStringAsFixed(2)} cosine similarity'
                      : 'Not applicable',
                  mono: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Guard note (10–500 characters)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('guard_review_reason_field'),
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Describe how you verified the driver and vehicle…',
            ),
          ),

          const SizedBox(height: 16),

          if (_submissionFeedback != null) ...[
            Container(
              key: const Key('guard_review_feedback_banner'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _submissionIsError ? p.errTint : p.okTint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_submissionIsError ? p.err : p.ok)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _submissionIsError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 19,
                    color: _submissionIsError ? p.errText : p.okText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _submissionFeedback!,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _submissionIsError ? p.errText : p.okText,
                      ),
                    ),
                  ),
                  if (_submissionIsError &&
                      _submissionFeedback!.contains('STALE_VERSION'))
                    TextButton(
                      key: const Key('sync_latest_version_button'),
                      onPressed: () {
                        setState(() {
                          _capturedExpectedVersion =
                              selectedItem.currentAttemptVersion;
                          _submissionFeedback =
                              'Updated to v${selectedItem.currentAttemptVersion}. You can submit again now.';
                          _submissionIsError = false;
                        });
                      },
                      child: const Text('Sync & retry'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('guard_review_approve_button'),
                onPressed: canApprove
                    ? () => _submitReviewAction(selectedItem, 'approve')
                    : null,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Approve & hold bay'),
              ),
              OutlinedButton.icon(
                key: const Key('guard_review_deny_button'),
                onPressed: selectedItem.isResolved
                    ? null
                    : () => _submitReviewAction(selectedItem, 'deny'),
                icon: const Icon(Icons.block_outlined, size: 18),
                label: const Text('Deny entry'),
              ),
              OutlinedButton.icon(
                key: const Key('guard_review_escalate_button'),
                onPressed: selectedItem.isResolved
                    ? null
                    : () => _submitReviewAction(selectedItem, 'escalate'),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Escalate'),
              ),
            ],
          ),

          if (selectedItem.isResolved &&
              selectedItem.resolvedAction == 'approve') ...[
            const SizedBox(height: 20),
            Callout(
              tone: PillTone.ok,
              icon: Icons.verified_rounded,
              title: 'Approved — bay held for 30 seconds',
              message:
                  'Confirm once the vehicle physically crosses the barrier to start its active visit.',
              action: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: p.ok,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final actor = ref.read(authControllerProvider).profile ??
                      SentryFixtures.guardOperator;
                  ref
                      .read(sentryScenarioProvider.notifier)
                      .confirmVehicleCrossedGate(
                        laneId: selectedItem.laneId,
                        notes:
                            'Confirmed physical crossing after Guard Review approval (${selectedItem.reviewCaseId}).',
                        actor: actor,
                      );
                  ref.read(selectedDesktopTabProvider.notifier).state =
                      DesktopNavTab.liveGateMonitoring;
                },
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Confirm crossed'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCaseTechnicalSheet(
    BuildContext context,
    GuardReviewQueueItem item,
  ) {
    showDetailsSheet<void>(
      context,
      title: 'Case ${item.reviewCaseId}',
      subtitle: 'Raw contract identifiers and optimistic concurrency state.',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyValueRow(
            label: 'Reason code',
            value: item.reasonCode,
            mono: true,
          ),
          KeyValueRow(
            label: 'Correlation ID',
            value: item.correlationId,
            mono: true,
          ),
          KeyValueRow(
            label: 'Decision ID',
            value: item.decisionId,
            mono: true,
          ),
          KeyValueRow(
            label: 'Expected version',
            value: 'v$_capturedExpectedVersion',
            mono: true,
          ),
          KeyValueRow(
            label: 'Server version',
            value: 'v${item.currentAttemptVersion}',
            mono: true,
          ),
          KeyValueRow(
            label: 'Evidence events',
            value: item.evidenceEventIds.join('\n'),
            mono: true,
          ),
          if (item.supersedingDecisionId != null)
            KeyValueRow(
              label: 'Superseding decision',
              value: item.supersedingDecisionId!,
              mono: true,
            ),
        ],
      ),
    );
  }

  static String _humanReasonTitle(String code) {
    switch (code) {
      case 'IDENTITY_UNCERTAIN':
        return 'Uncertain plate or face read';
      case 'OCCUPANCY_CONFLICT':
        return 'Bay occupancy conflict';
      case 'IDENTITY_MISMATCH':
        return 'Driver does not match vehicle owner';
      case 'UNKNOWN_CREDENTIAL':
        return 'Unregistered plate or tag';
      case 'CREDENTIAL_REVOKED':
        return 'Revoked vehicle credential';
      case 'DUPLICATE_ACTIVE_VISIT':
        return 'Owner already has a vehicle inside';
      default:
        return code.replaceAll('_', ' ');
    }
  }

  static String _laneLabel(String laneId) {
    switch (laneId) {
      case 'lane-car-in':
        return 'Car entry lane';
      case 'lane-car-out':
        return 'Car exit lane';
      case 'lane-moto-in':
        return 'Motorcycle entry lane';
      case 'lane-moto-out':
        return 'Motorcycle exit lane';
      default:
        return laneId;
    }
  }
}

class _ReviewCaseCard extends StatelessWidget {
  final GuardReviewQueueItem item;
  final bool selected;
  final VoidCallback onTap;

  const _ReviewCaseCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SentryCard(
      key: Key('review_case_${item.reviewCaseId}'),
      selected: selected,
      padding: const EdgeInsets.all(18),
      radius: 16,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlateBadge(
                plateText: item.plateText,
                rfidUid: item.rfidUid,
                isCompact: true,
              ),
              const Spacer(),
              StatusPill(
                label: item.isResolved
                    ? 'Resolved (${item.resolvedAction})'
                    : item.isHardSecurityDenial
                        ? 'Hard denial'
                        : 'Needs review',
                tone: item.isResolved
                    ? PillTone.ok
                    : item.isHardSecurityDenial
                        ? PillTone.err
                        : PillTone.warn,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _GuardReviewsScreenState._humanReasonTitle(item.reasonCode),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            item.reasonMessage,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
