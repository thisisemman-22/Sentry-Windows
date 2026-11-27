import 'dart:async';
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
import '../../../shared/models/spec_2026_models.dart';

/// Guard Screen 3: `Guest Check` — full-screen gate workstation for verifying
/// approved `BSUAL-XXXX` guest passes:
/// 1. Fixed `BSUAL-` prefix (accepts typed 4 digits or pasted full codes,
///    normalizing case, spaces, and dashes).
/// 2. Lookup displays Guest Name, Visit Date & Time Window, and Vehicle (type &
///    plate) so the Guard matches physical ID before pressing Confirm.
/// 3. Cleanly handles wrong-code errors, 429 rate-limit lockout countdowns, and
///    outside-visit-window refusals.
class GuardGuestCheckScreen extends ConsumerStatefulWidget {
  const GuardGuestCheckScreen({super.key});

  @override
  ConsumerState<GuardGuestCheckScreen> createState() =>
      _GuardGuestCheckScreenState();
}

class _GuardGuestCheckScreenState
    extends ConsumerState<GuardGuestCheckScreen> {
  final TextEditingController _codeCtrl = TextEditingController();
  bool _isBusy = false;
  String? _errorCode;
  String? _errorMessage;
  String? _confirmedBanner;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _syncLockoutTimer(DateTime? lockoutUntilUtc) {
    final now = DateTime.now().toUtc();
    if (lockoutUntilUtc == null || !now.isBefore(lockoutUntilUtc)) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      return;
    }
    _countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      final until = ref.read(desktopOpsControllerProvider).guestPassLockoutUntilUtc;
      if (until == null || !DateTime.now().toUtc().isBefore(until)) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
      }
      setState(() {});
    });
  }

  Future<void> _lookupPass() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _errorCode = null;
      _errorMessage = null;
      _confirmedBanner = null;
    });
    final actor = ref.read(authControllerProvider).profile ??
        SentryFixtures.guardOperator;
    final res = await ref
        .read(desktopOpsControllerProvider.notifier)
        .lookupGuestGatePass(rawInput: _codeCtrl.text, actor: actor);
    if (!mounted) return;
    final lockout =
        ref.read(desktopOpsControllerProvider).guestPassLockoutUntilUtc;
    _syncLockoutTimer(lockout);
    setState(() {
      _isBusy = false;
      if (!res.ok) {
        _errorCode = res.error?.code;
        _errorMessage = res.error?.message ?? 'Unable to verify guest pass.';
      }
    });
  }

  Future<void> _confirmPass(GuestPassLookupDto lookup) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _errorCode = null;
      _errorMessage = null;
    });
    final actor = ref.read(authControllerProvider).profile ??
        SentryFixtures.guardOperator;
    final res = await ref
        .read(desktopOpsControllerProvider.notifier)
        .confirmGuestGatePass(lookup: lookup, actor: actor);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (res.ok && res.data != null) {
        _codeCtrl.clear();
        _confirmedBanner = res.data!.message;
      } else {
        _errorCode = res.error?.code;
        _errorMessage = res.error?.message ?? 'Confirmation failed.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final ops = ref.watch(desktopOpsControllerProvider);
    final config = ref.watch(appConfigProvider);
    final lookup = ops.activeGuestLookup;
    final now = DateTime.now().toUtc();
    final lockoutUntil = ops.guestPassLockoutUntilUtc;
    final isLockedOut = lockoutUntil != null && now.isBefore(lockoutUntil);
    final lockoutSeconds =
        isLockedOut ? (lockoutUntil.difference(now).inSeconds + 1) : 0;
    final normalizedPreview = normalizeGuestPassCode(_codeCtrl.text);

    return ScreenScaffold(
      children: [
        const PageIntro(
          title: 'Guest Check',
          subtitle:
              'Look up an approved BSUAL guest code, match the guest\'s physical ID, then Confirm so the gate can open by plate.',
          actions: [
            InfoHint(
              'Accepts 4 digits after the fixed BSUAL- prefix or pasted full codes '
              '(for example "bsual 1234" or "BSUAL-1234"). Three failed lookups trigger a cooldown.',
            ),
          ],
        ),
        const SizedBox(height: 22),

        // 1. Pass Code Entry Card
        Reveal(
          index: 1,
          child: SentryCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'Enter guest pass code',
                  subtitle: config.isMock
                      ? 'Demo passes: 1234 (active today) · 2030 (outside window) · any other code (error/429 test).'
                      : 'Ask the visitor to present the 4-digit BSUAL code from the SENTRY mobile app.',
                  trailing: normalizedPreview != null
                      ? StatusPill(
                          label: 'Normalized: $normalizedPreview',
                          tone: PillTone.info,
                          monospace: true,
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 600;
                    final inputRow = Row(
                      children: [
                        Container(
                          key: const Key('guest_check_prefix_badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: p.subtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.line),
                          ),
                          child: Text(
                            'BSUAL-',
                            style: SentryTheme.mono(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: p.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            key: const Key('guest_check_code_field'),
                            controller: _codeCtrl,
                            enabled: !isLockedOut && !_isBusy,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) {
                              if (!isLockedOut) _lookupPass();
                            },
                            decoration: const InputDecoration(
                              hintText: '1234 or paste BSUAL-1234',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    );

                    final lookupBtn = FilledButton.icon(
                      key: const Key('guest_check_lookup_button'),
                      onPressed: isLockedOut || _isBusy ? null : _lookupPass,
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: Text(
                        isLockedOut
                            ? 'Locked (${lockoutSeconds}s)'
                            : (_isBusy ? 'Checking…' : 'Lookup pass'),
                      ),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          inputRow,
                          const SizedBox(height: 12),
                          lookupBtn,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: inputRow),
                        const SizedBox(width: 12),
                        lookupBtn,
                      ],
                    );
                  },
                ),
                if (isLockedOut) ...[
                  const SizedBox(height: 16),
                  Callout(
                    key: const Key('guest_check_rate_limit_banner'),
                    tone: PillTone.err,
                    icon: Icons.lock_clock_rounded,
                    title: 'Too many failed attempts (429)',
                    message:
                        'Guest pass verification is temporarily locked. Try again in ${lockoutSeconds}s.',
                  ),
                ] else if (_errorCode == 'OUTSIDE_VISIT_WINDOW' &&
                    _errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Callout(
                    key: const Key('guest_check_outside_window_banner'),
                    tone: PillTone.warn,
                    icon: Icons.schedule_rounded,
                    title: 'Outside visit window',
                    message: _errorMessage!,
                  ),
                ] else if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Callout(
                    key: const Key('guest_check_error_banner'),
                    tone: PillTone.err,
                    icon: Icons.error_outline_rounded,
                    title: 'Guest pass rejected',
                    message: _errorMessage!,
                  ),
                ],
                if (_confirmedBanner != null) ...[
                  const SizedBox(height: 16),
                  Callout(
                    key: const Key('guest_check_confirmed_banner'),
                    tone: PillTone.ok,
                    icon: Icons.verified_rounded,
                    title: 'Guest entry confirmed',
                    message: _confirmedBanner!,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 2. Pre-Confirmation Guest Details Card (Verify physical ID before Confirm)
        if (lookup != null)
          Reveal(
            index: 2,
            child: SentryCard(
              key: const Key('guest_check_details_card'),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonogramAvatar(
                        name: lookup.guestFullName,
                        highlight: true,
                        size: 46,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lookup.guestFullName,
                              key: const Key('guest_check_guest_name'),
                              style: SentryTheme.display(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: p.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${lookup.hostName} · ${lookup.purpose}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: p.muted),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: lookup.passCode,
                        tone: PillTone.info,
                        monospace: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: p.subtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KeyValueRow(
                          label: 'Visit date',
                          value: formatPhtDate(lookup.visitDateUtc),
                          mono: true,
                        ),
                        KeyValueRow(
                          label: 'Time window',
                          value: lookup.windowLabel.isNotEmpty
                              ? lookup.windowLabel
                              : '${ManilaTime.formatShort(lookup.windowStartUtc)} – ${ManilaTime.formatShort(lookup.windowEndUtc)} PHT',
                          valueKey: const Key('guest_check_visit_window'),
                          mono: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 150,
                                child: Text(
                                  'Vehicle',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Expanded(
                                child: Wrap(
                                  key: const Key('guest_check_vehicle_info'),
                                  spacing: 10,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    PlateBadge(plateText: lookup.plateNumber),
                                    StatusPill(
                                      label: lookup.vehicleType.toUpperCase(),
                                      tone: PillTone.neutral,
                                      monospace: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton(
                        key: const Key('guest_check_clear_button'),
                        onPressed: _isBusy
                            ? null
                            : () => ref
                                .read(desktopOpsControllerProvider.notifier)
                                .clearGuestLookup(),
                        child: const Text('Clear'),
                      ),
                      FilledButton.icon(
                        key: const Key('guest_check_confirm_button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: SentryColors.crimson,
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            _isBusy ? null : () => _confirmPass(lookup),
                        icon: const Icon(Icons.verified_user_rounded, size: 18),
                        label: const Text('Confirm & Allow Plate'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          SentryCard(
            child: EmptyState(
              showBrandLogo: true,
              icon: Icons.badge_outlined,
              title: 'Ready to verify a guest pass',
              message:
                  'Look up a 4-digit BSUAL code to inspect the guest name, visit window, and vehicle plate before confirming entry.',
            ),
          ),
      ],
    );
  }
}
