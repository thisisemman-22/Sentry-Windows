import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/fixtures/synthetic_fixtures.dart';
import '../../../shared/models/spec_2026_models.dart';

/// Guard Screen 4: `Manual Entry` — hand-entered gate log for Guest Motorcycles
/// and Guests on Foot.
class GuardManualEntryScreen extends ConsumerStatefulWidget {
  const GuardManualEntryScreen({super.key});

  @override
  ConsumerState<GuardManualEntryScreen> createState() =>
      _GuardManualEntryScreenState();
}

class _GuardManualEntryScreenState
    extends ConsumerState<GuardManualEntryScreen> {
  int _entryMode = 0; // 0 = Guest Motorcycle, 1 = Guest on Foot
  final TextEditingController _guestNameCtrl = TextEditingController();
  final TextEditingController _passCodeCtrl = TextEditingController();
  final TextEditingController _plateDescCtrl = TextEditingController();
  final TextEditingController _purposeIdCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _feedback;
  bool _feedbackIsError = false;

  @override
  void dispose() {
    _guestNameCtrl.dispose();
    _passCodeCtrl.dispose();
    _plateDescCtrl.dispose();
    _purposeIdCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _feedback = null;
      _feedbackIsError = false;
    });
    final actor = ref.read(authControllerProvider).profile ??
        SentryFixtures.guardOperator;
    final category = _entryMode == 0 ? 'guest_motorcycle' : 'guest_on_foot';
    final res = await ref
        .read(desktopOpsControllerProvider.notifier)
        .recordManualGuestEntry(
          entryCategory: category,
          guestFullName: _guestNameCtrl.text,
          rawPassCode: _passCodeCtrl.text,
          plateOrDescription: _entryMode == 0 ? _plateDescCtrl.text : null,
          purposeAndIdCheck: _entryMode == 1 ? _purposeIdCtrl.text : null,
          notes: _notesCtrl.text,
          actor: actor,
        );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (res.ok && res.data != null) {
        _feedbackIsError = false;
        _feedback =
            'Recorded ${res.data!.isMotorcycle ? 'guest motorcycle' : 'guest on foot'} entry for ${res.data!.guestFullName}.';
        _guestNameCtrl.clear();
        _passCodeCtrl.clear();
        _plateDescCtrl.clear();
        _purposeIdCtrl.clear();
        _notesCtrl.clear();
      } else {
        _feedbackIsError = true;
        _feedback = res.error?.message ?? 'Unable to record manual entry.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final entries = ref.watch(
      desktopOpsControllerProvider.select((o) => o.manualGuestEntries),
    );

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Manual Entry',
          subtitle:
              'Record gate entry by hand for guest motorcycles and visitors arriving on foot.',
          actions: [
            SegmentTabs(
              keyPrefix: 'manual_entry_type',
              labels: const ['Guest Motorcycle', 'Guest on Foot'],
              icons: const [
                Icons.two_wheeler_rounded,
                Icons.directions_walk_rounded,
              ],
              selected: _entryMode,
              onChanged: (i) => setState(() {
                _entryMode = i;
                _feedback = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 22),

        Reveal(
          index: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final formCard = _buildFormCard(context, p);
              final listCard = _buildEntriesCard(context, p, entries);
              if (constraints.maxWidth < 980) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    formCard,
                    const SizedBox(height: 18),
                    listCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: formCard),
                  const SizedBox(width: 20),
                  Expanded(flex: 6, child: listCard),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context, SentryPalette p) {
    final isMoto = _entryMode == 0;
    return SentryCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: isMoto
                ? 'Guest motorcycle entry'
                : 'Guest on foot entry',
            subtitle: isMoto
                ? 'Motorcycles have no campus RFID tag; record plate or description below.'
                : 'Walk-in guests do not occupy a parking bay; record physical ID check below.',
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('manual_entry_guest_name_field'),
            controller: _guestNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Guest full name *',
              hintText: 'e.g. Juan Dela Cruz',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('manual_entry_pass_code_field'),
            controller: _passCodeCtrl,
            decoration: InputDecoration(
              labelText: isMoto
                  ? 'Pass code (optional, BSUAL-XXXX or 4 digits)'
                  : 'Pass code (optional if approved, BSUAL-XXXX)',
              hintText: 'e.g. 1234 or BSUAL-1234',
            ),
          ),
          const SizedBox(height: 14),
          if (isMoto)
            TextField(
              key: const Key('manual_entry_plate_desc_field'),
              controller: _plateDescCtrl,
              decoration: const InputDecoration(
                labelText: 'Plate number or motorcycle description *',
                hintText: 'e.g. MC 8821 · Black Honda Click 125',
              ),
            )
          else
            TextField(
              key: const Key('manual_entry_purpose_id_field'),
              controller: _purposeIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Purpose & physical ID check *',
                hintText: 'e.g. Verified PRC ID · Visiting CICS Office',
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('manual_entry_notes_field'),
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Guard notes',
              hintText: 'Optional gate observation or escort instructions…',
            ),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 16),
            Callout(
              key: const Key('manual_entry_feedback_banner'),
              tone: _feedbackIsError ? PillTone.err : PillTone.ok,
              icon: _feedbackIsError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              title: _feedbackIsError ? 'Check entry details' : 'Entry logged',
              message: _feedback!,
            ),
          ],
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('manual_entry_submit_button'),
              style: FilledButton.styleFrom(
                backgroundColor: SentryColors.crimson,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSubmitting ? null : _submit,
              icon: const Icon(Icons.edit_note_rounded, size: 19),
              label: Text(
                _isSubmitting
                    ? 'Saving…'
                    : (isMoto
                        ? 'Record Motorcycle Entry'
                        : 'Record Walk-In Entry'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesCard(
    BuildContext context,
    SentryPalette p,
    List<ManualGuestEntryDto> entries,
  ) {
    return SentryCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Recent manual entries (${entries.length})',
            subtitle: 'Hand-logged during this shift.',
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const EmptyState(
              showBrandLogo: true,
              icon: Icons.receipt_long_outlined,
              title: 'No manual entries yet',
              message:
                  'Guest motorcycles and guests on foot recorded by hand will appear here.',
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) Divider(color: p.line, height: 18),
                  SentryRowTile(
                    key: Key('manual_entry_row_${entries[i].entryId}'),
                    leading: entries[i].plateOrDescription != null
                        ? PlateBadge(
                            plateText: entries[i].plateOrDescription,
                            isCompact: true,
                          )
                        : MonogramAvatar(name: entries[i].guestFullName),
                    title: entries[i].guestFullName,
                    subtitle: entries[i].isMotorcycle
                        ? (entries[i].plateOrDescription ?? 'Guest Motorcycle')
                        : (entries[i].purposeAndIdCheck ?? 'Guest on Foot'),
                    badges: [
                      StatusPill(
                        label: entries[i].isMotorcycle
                            ? 'Motorcycle'
                            : 'On Foot',
                        tone: PillTone.info,
                      ),
                      if (entries[i].passCode != null)
                        StatusPill(
                          label: entries[i].passCode!,
                          tone: PillTone.neutral,
                          monospace: true,
                        ),
                    ],
                    onTap: () => showDetailsSheet<void>(
                      context,
                      frosted: true,
                      title: entries[i].guestFullName,
                      subtitle: entries[i].isMotorcycle
                          ? 'Manual Guest Motorcycle Entry'
                          : 'Manual Guest on Foot Entry',
                      builder: (ctx) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (entries[i].plateOrDescription != null)
                            KeyValueRow(
                              label: 'Plate / description',
                              value: entries[i].plateOrDescription!,
                            ),
                          if (entries[i].purposeAndIdCheck != null)
                            KeyValueRow(
                              label: 'Purpose / ID check',
                              value: entries[i].purposeAndIdCheck!,
                            ),
                          if (entries[i].passCode != null)
                            KeyValueRow(
                              label: 'Pass code',
                              value: entries[i].passCode!,
                              mono: true,
                            ),
                          if (entries[i].notes.isNotEmpty)
                            KeyValueRow(label: 'Notes', value: entries[i].notes),
                          const Divider(height: 20),
                          KeyValueRow(
                            label: 'Recorded by',
                            value: entries[i].recordedByUserCode,
                            mono: true,
                          ),
                          KeyValueRow(
                            label: 'Time (PHT)',
                            value: ManilaTime.formatDateTime(
                                entries[i].recordedAtUtc),
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
}
