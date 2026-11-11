import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/demo_controls_sheet.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/fixtures/synthetic_fixtures.dart';
import '../../../shared/models/attempt_models.dart';

/// View 3: `Live Gates` — calm, task-focused gate workstation.
///
/// Progressive disclosure:
/// - Top: 4 lane cards showing which vehicle is at each gate right now.
/// - Center: One clear decision banner with the primary guard action
///   ("Confirm vehicle crossed") and a calm 4-step progress bar.
/// - Bottom: 3 clean verification cards (Vehicle credential, Face match with
///   calibrated cosine similarity, and Driver & bay). Raw UUIDs, model
///   versions, and event metadata open in a right-hand details sheet on demand.
class LiveGateMonitoringScreen extends ConsumerWidget {
  const LiveGateMonitoringScreen({super.key});

  static const List<_LaneSpec> _lanes = [
    _LaneSpec(
      laneId: 'lane-car-in',
      title: 'Car entry',
      gateLabel: 'Gate 1 · Plate + Face',
      icon: Icons.directions_car_rounded,
    ),
    _LaneSpec(
      laneId: 'lane-car-out',
      title: 'Car exit',
      gateLabel: 'Gate 2 · Plate only',
      icon: Icons.logout_rounded,
    ),
    _LaneSpec(
      laneId: 'lane-moto-in',
      title: 'Motorcycle entry',
      gateLabel: 'Gate 1 · RFID + Face',
      icon: Icons.two_wheeler_rounded,
    ),
    _LaneSpec(
      laneId: 'lane-moto-out',
      title: 'Motorcycle exit',
      gateLabel: 'Gate 2 · RFID only',
      icon: Icons.exit_to_app_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final sysState = ref.watch(sentryScenarioProvider);
    final selectedLaneId = ref.watch(focusedLaneProvider);
    final attempt = sysState.activeLaneAttempts[selectedLaneId];
    final participant = SentryFixtures.findParticipantByCode(attempt?.userCode);
    final config = ref.watch(appConfigProvider);

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Live gates',
          subtitle:
              'Verify vehicles at each lane and confirm when an allowed vehicle crosses the barrier.',
          actions: [
            if (attempt != null)
              OutlinedButton.icon(
                onPressed: () => _showTechnicalDetails(context, attempt),
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: const Text('Technical details'),
              ),
            if (config.isMock)
              OutlinedButton.icon(
                onPressed: () => showDemoControlsSheet(context),
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('Simulate encounter'),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // 1. 4-Lane Selector Cards
        Reveal(
          index: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cards = _lanes.map((lane) {
                final isSelected = selectedLaneId == lane.laneId;
                final laneAttempt = sysState.activeLaneAttempts[lane.laneId];
                final outcome =
                    laneAttempt?.latestDecision?.outcome ?? 'idle';

                return SentryCard(
                  key: Key('lane_tab_${lane.laneId}'),
                  selected: isSelected,
                  padding: const EdgeInsets.all(18),
                  radius: 18,
                  onTap: () {
                    ref.read(focusedLaneProvider.notifier).state = lane.laneId;
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected ? p.crimsonTint : p.subtle,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              lane.icon,
                              size: 19,
                              color: isSelected ? p.crimson : p.slate,
                            ),
                          ),
                          const Spacer(),
                          StatusPill.fromDecisionOutcome(outcome),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        lane.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        laneAttempt?.plateText ??
                            laneAttempt?.rfidUid ??
                            lane.gateLabel,
                        style: laneAttempt != null
                            ? SentryTheme.mono(
                                fontSize: 13,
                                color: p.slate,
                              )
                            : Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList();

              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    for (final c in cards) ...[
                      c,
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 22),

        // 2. Active Lane Content with Smooth Transition
        SmoothSwitcher(
          switchKey:
              '$selectedLaneId-${attempt?.correlationId ?? 'empty'}-${attempt?.attemptVersion ?? 0}-${attempt?.state ?? ''}',
          child: attempt == null
              ? const SentryCard(
                  child: EmptyState(
                    icon: Icons.sensors_off_rounded,
                    title: 'No vehicle at this lane',
                    message:
                        'When a camera or RFID reader detects a vehicle, it will appear here automatically.',
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Primary Decision & Passage Action Banner
                    _DecisionHeroBanner(
                      attempt: attempt,
                      onConfirmPassage: () =>
                          _openConfirmPassageDialog(context, ref, attempt),
                      onCancelHold: () {
                        ref
                            .read(sentryScenarioProvider.notifier)
                            .cancelAttemptBeforePassage(attempt.laneId);
                      },
                      onOpenReview: () {
                        ref.read(selectedDesktopTabProvider.notifier).state =
                            DesktopNavTab.guardReviews;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Three Clean Verification Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          _CredentialCard(attempt: attempt),
                          _FaceMatchCard(attempt: attempt),
                          _ParticipantBayCard(
                            attempt: attempt,
                            ownerName: participant?.displayName(
                                  sysState.rosterMode,
                                ) ??
                                'Unregistered visitor',
                            userCode: participant?.userCode,
                          ),
                        ];
                        if (constraints.maxWidth < 920) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final c in cards) ...[
                                c,
                                const SizedBox(height: 14),
                              ],
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 16),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _openConfirmPassageDialog(
    BuildContext context,
    WidgetRef ref,
    AttemptDto attempt,
  ) {
    final p = SentryPalette.of(context);
    final isEntry = attempt.direction == 'entry';
    final defaultNote = isEntry
        ? 'Witnessed ${attempt.vehicleType} (${attempt.vehicleCode ?? 'vehicle'}) physical crossing at Gate 1 entry lane.'
        : 'Witnessed ${attempt.vehicleType} (${attempt.vehicleCode ?? 'vehicle'}) physical departure at Gate exit lane.';
    final notesCtrl = TextEditingController(text: defaultNote);
    String? validationError;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: Text(
                isEntry
                    ? 'Confirm vehicle crossed entry gate'
                    : 'Confirm vehicle exited campus',
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEntry
                          ? 'This converts the 30-second hold on bay ${attempt.spaceCode ?? 'assigned bay'} into an active campus visit.'
                          : 'This closes the active visit and marks bay ${attempt.spaceCode ?? ''} as open again.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Witnessed crossing at gate'),
                          onPressed: () {
                            setModalState(() {
                              notesCtrl.text =
                                  'Witnessed vehicle physical crossing at Gate 1 lane.';
                              validationError = null;
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('Sensor blocked; guard verified'),
                          onPressed: () {
                            setModalState(() {
                              notesCtrl.text =
                                  'Barrier sensor occluded; guard verified physical passage across loop.';
                              validationError = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('passage_attestation_notes_field'),
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Guard note (10–500 characters)',
                        errorText: validationError,
                        fillColor: p.subtle,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  key: const Key('submit_passage_attestation_button'),
                  onPressed: () {
                    final actor = ref.read(authControllerProvider).profile ??
                        SentryFixtures.guardOperator;
                    final result = ref
                        .read(sentryScenarioProvider.notifier)
                        .confirmVehicleCrossedGate(
                          laneId: attempt.laneId,
                          notes: notesCtrl.text,
                          actor: actor,
                        );
                    if (!result.ok) {
                      setModalState(() {
                        validationError = result.error?.message;
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(isEntry ? 'Confirm entry' : 'Confirm exit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTechnicalDetails(BuildContext context, AttemptDto attempt) {
    showDetailsSheet<void>(
      context,
      title: 'Technical telemetry',
      subtitle: 'Raw contract fields and model metadata for this gate attempt.',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Attempt envelope'),
          const SizedBox(height: 8),
          KeyValueRow(
            label: 'Correlation ID',
            value: attempt.correlationId,
            mono: true,
          ),
          KeyValueRow(
            label: 'Attempt version',
            value: 'v${attempt.attemptVersion}',
            mono: true,
          ),
          KeyValueRow(
            label: 'State machine',
            value: attempt.state,
            mono: true,
          ),
          KeyValueRow(
            label: 'Reason code',
            value: attempt.latestDecision?.reasonCode ?? 'NONE',
            mono: true,
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'AI & reader metadata'),
          const SizedBox(height: 8),
          if (attempt.vehicleType == 'car') ...[
            KeyValueRow(
              label: 'YOLO detection',
              value: attempt.detectionConfidence?.toStringAsFixed(2) ?? 'N/A',
              mono: true,
            ),
            KeyValueRow(
              label: 'OCR confidence',
              value: attempt.ocrConfidence?.toStringAsFixed(2) ?? 'N/A',
              mono: true,
            ),
            KeyValueRow(
              label: 'Plate model',
              value: attempt.plateModelVersion ?? 'yolo-plate-v1.2',
              mono: true,
            ),
          ] else ...[
            KeyValueRow(
              label: 'RFID reader',
              value: attempt.rfidReaderModel ?? 'rc522',
              mono: true,
            ),
            KeyValueRow(
              label: 'Firmware',
              value: attempt.rfidFirmwareVersion ?? 'esp32-rc522-fw-v1.0.8',
              mono: true,
            ),
          ],
          KeyValueRow(
            label: 'ArcFace model',
            value: attempt.faceModelVersion ?? 'arcface-r100-v1.1',
            mono: true,
          ),
          KeyValueRow(
            label: 'Trigger event ID',
            value: attempt.faceTriggerEventId ??
                (attempt.direction == 'exit'
                    ? 'Exempt on exit'
                    : '80000000-0000-4000-8000-000000000011'),
            mono: true,
          ),
        ],
      ),
    );
  }
}

class _LaneSpec {
  final String laneId;
  final String title;
  final String gateLabel;
  final IconData icon;

  const _LaneSpec({
    required this.laneId,
    required this.title,
    required this.gateLabel,
    required this.icon,
  });
}

class _DecisionHeroBanner extends StatelessWidget {
  final AttemptDto attempt;
  final VoidCallback onConfirmPassage;
  final VoidCallback onCancelHold;
  final VoidCallback onOpenReview;

  const _DecisionHeroBanner({
    required this.attempt,
    required this.onConfirmPassage,
    required this.onCancelHold,
    required this.onOpenReview,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final canConfirm = attempt.canConfirmPassage();
    final needsReview = attempt.state == 'guard_review_required';
    final isDenied = attempt.state == 'authorization_denied' ||
        attempt.state == 'expired';

    final accent = canConfirm
        ? p.ok
        : needsReview
            ? p.warn
            : isDenied
                ? p.err
                : p.info;

    return SentryCard(
      padding: const EdgeInsets.all(24),
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 14,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill.fromAttemptState(attempt.state),
                        if (attempt.spaceCode != null)
                          StatusPill(
                            label:
                                'Bay ${attempt.spaceCode} (${attempt.assignmentStatus ?? 'held'})',
                            tone: attempt.assignmentStatus == 'assigned'
                                ? PillTone.ok
                                : PillTone.warn,
                            icon: Icons.local_parking_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      attempt.latestDecision?.reasonMessage ??
                          'Verifying vehicle credentials…',
                      style: SentryTheme.display(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (attempt.canCancelBeforePassage)
                    OutlinedButton.icon(
                      key: const Key('cancel_attempt_button'),
                      onPressed: onCancelHold,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Cancel hold'),
                    ),
                  if (canConfirm)
                    FilledButton.icon(
                      key: const Key('confirm_vehicle_crossed_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.ok,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onConfirmPassage,
                      icon: const Icon(Icons.check_circle_rounded, size: 19),
                      label: const Text('Confirm vehicle crossed'),
                    ),
                  if (needsReview)
                    FilledButton.icon(
                      onPressed: onOpenReview,
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('Review case'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _CalmProgressSteps(stageNumber: attempt.currentStageNumber),
        ],
      ),
    );
  }
}

class _CalmProgressSteps extends StatelessWidget {
  final int stageNumber;
  const _CalmProgressSteps({required this.stageNumber});

  static const _labels = [
    '1. Detected',
    '2. Identity checked',
    '3. Bay held (30s)',
    '4. Crossed gate',
  ];

  int get _mappedStep {
    if (stageNumber >= 6) return 4;
    if (stageNumber >= 3) return 3;
    if (stageNumber >= 2) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final active = _mappedStep;
    return Row(
      children: List.generate(_labels.length, (index) {
        final step = index + 1;
        final reached = active >= step;
        final color = reached
            ? (active == 4 ? p.ok : SentryColors.crimson)
            : p.line;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < _labels.length - 1 ? 10 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: SentryMotion.of(context, SentryMotion.medium),
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _labels[index],
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
                    color: reached ? p.text : p.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _CredentialCard extends StatelessWidget {
  final AttemptDto attempt;
  const _CredentialCard({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final isCar = attempt.vehicleType == 'car';
    final recognized = attempt.plateRecognitionStatus == 'recognized' ||
        attempt.rfidUid != null;
    return SentryCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: isCar ? 'License plate' : 'RFID tag',
            trailing: StatusPill(
              label: recognized ? 'Read clearly' : 'Uncertain read',
              tone: recognized ? PillTone.ok : PillTone.warn,
            ),
          ),
          const SizedBox(height: 16),
          PlateBadge(
            plateText: attempt.plateText,
            rfidUid: attempt.rfidUid,
          ),
          const SizedBox(height: 16),
          if (isCar)
            _SimpleRow(
              label: 'OCR confidence',
              value: attempt.ocrConfidence?.toStringAsFixed(2) ?? 'N/A',
            )
          else
            _SimpleRow(
              label: 'Tag UID',
              value: attempt.rfidUid ?? 'N/A',
            ),
        ],
      ),
    );
  }
}

class _FaceMatchCard extends StatelessWidget {
  final AttemptDto attempt;
  const _FaceMatchCard({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final status = attempt.faceRecognitionStatus;
    final tone = status == 'matched'
        ? PillTone.ok
        : status == 'not_required'
            ? PillTone.info
            : status == 'uncertain'
                ? PillTone.warn
                : PillTone.err;
    final label = status == 'matched'
        ? 'Matched'
        : status == 'not_required'
            ? 'Not needed on exit'
            : status == 'uncertain'
                ? 'Uncertain'
                : 'Mismatch';

    return SentryCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Driver face check',
            hint:
                'Measured as calibrated ArcFace cosine similarity in [-1.0, 1.0], '
                'never as a percentage.',
            trailing: StatusPill(label: label, tone: tone),
          ),
          const SizedBox(height: 18),
          Text(
            attempt.formattedFaceCosineSimilarity,
            key: const Key('face_cosine_similarity_value'),
            style: SentryTheme.mono(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          const SizedBox(height: 12),
          _SimpleRow(
            label: 'Direction rule',
            value: attempt.direction == 'exit'
                ? 'Exit lane (plate/RFID only)'
                : 'Entry requires face match',
          ),
        ],
      ),
    );
  }
}

class _ParticipantBayCard extends StatelessWidget {
  final AttemptDto attempt;
  final String ownerName;
  final String? userCode;

  const _ParticipantBayCard({
    required this.attempt,
    required this.ownerName,
    this.userCode,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return SentryCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Driver & bay',
            trailing: attempt.vehicleCode != null
                ? StatusPill(
                    label: attempt.vehicleCode!,
                    tone: PillTone.crimson,
                    monospace: true,
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            userCode != null ? '$ownerName ($userCode)' : ownerName,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _SimpleRow(
            label: 'Parking bay',
            value: attempt.spaceCode != null
                ? 'Lot ${attempt.lotCode} · ${attempt.spaceCode}'
                : 'No bay held',
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active visit',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  attempt.committedVisitId ?? 'None yet (pre-passage)',
                  key: const Key('attempt_committed_visit_id'),
                  textAlign: TextAlign.right,
                  style: SentryTheme.mono(fontSize: 12.5, color: p.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  final String label;
  final String value;
  const _SimpleRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: SentryTheme.mono(fontSize: 13, color: p.text),
          ),
        ),
      ],
    );
  }
}
