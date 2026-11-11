import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/roster_mode.dart';
import '../core/motion/motion.dart';
import '../core/theme/sentry_colors.dart';
import '../core/theme/sentry_theme.dart';
import '../core/widgets/ui/sentry_ui.dart';
import '../shared/models/auth_models.dart';
import 'providers.dart';

/// A single demo gate encounter (thesis test case).
class DemoScenario {
  final String code;
  final String title;
  final String description;
  final String expected;
  final PillTone tone;
  final IconData icon;
  final String lane;

  const DemoScenario({
    required this.code,
    required this.title,
    required this.description,
    required this.expected,
    required this.tone,
    required this.icon,
    required this.lane,
  });
}

const demoScenarios = <DemoScenario>[
  DemoScenario(
    code: 'T01',
    title: 'Car arrives — allowed',
    description: 'Registered student car, plate and face match.',
    expected: 'Allowed · bay held',
    tone: PillTone.ok,
    icon: Icons.directions_car_rounded,
    lane: 'lane-car-in',
  ),
  DemoScenario(
    code: 'T04',
    title: 'Motorcycle arrives — allowed',
    description: 'RFID tag and face both verified.',
    expected: 'Allowed · bay held',
    tone: PillTone.ok,
    icon: Icons.two_wheeler_rounded,
    lane: 'lane-moto-in',
  ),
  DemoScenario(
    code: 'T02',
    title: 'Plate OK, wrong driver',
    description: 'Face does not match the plate owner.',
    expected: 'Denied · identity mismatch',
    tone: PillTone.err,
    icon: Icons.face_retouching_off_rounded,
    lane: 'lane-car-in',
  ),
  DemoScenario(
    code: 'T03',
    title: 'Unknown plate',
    description: 'Plate is not registered to anyone.',
    expected: 'Denied · unknown credential',
    tone: PillTone.err,
    icon: Icons.help_center_outlined,
    lane: 'lane-car-in',
  ),
  DemoScenario(
    code: 'T06',
    title: 'Revoked RFID tag',
    description: 'Motorcycle tag was deactivated.',
    expected: 'Denied · credential revoked',
    tone: PillTone.err,
    icon: Icons.credit_card_off_outlined,
    lane: 'lane-moto-in',
  ),
  DemoScenario(
    code: 'T07',
    title: 'Second car, same owner',
    description: 'Owner already has a car inside campus.',
    expected: 'Denied · duplicate visit',
    tone: PillTone.err,
    icon: Icons.content_copy_rounded,
    lane: 'lane-car-in',
  ),
  DemoScenario(
    code: 'T13',
    title: 'Blurry plate or face',
    description: 'System is unsure and asks a guard.',
    expected: 'Sent to Reviews',
    tone: PillTone.warn,
    icon: Icons.blur_on_rounded,
    lane: 'lane-car-in',
  ),
  DemoScenario(
    code: 'T16',
    title: 'Hold times out',
    description: 'Allowed car never crosses within 30s.',
    expected: 'Expired · bay released',
    tone: PillTone.warn,
    icon: Icons.timer_off_outlined,
    lane: 'lane-car-in',
  ),
  DemoScenario(
    code: 'T20',
    title: 'Car leaves campus',
    description: 'Exit lane reads the plate.',
    expected: 'Exit recorded',
    tone: PillTone.info,
    icon: Icons.logout_rounded,
    lane: 'lane-car-out',
  ),
];

/// Opens the Demo tools side sheet (mock mode only).
Future<void> showDemoControlsSheet(BuildContext context) {
  return showDetailsSheet<void>(
    context,
    title: 'Demo tools',
    subtitle: 'Simulate gate encounters for the thesis defense. '
        'Only visible in mock mode.',
    width: 560,
    builder: (ctx) => const _DemoControlsBody(),
  );
}

class _DemoControlsBody extends ConsumerWidget {
  const _DemoControlsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final roster = ref.watch(sentryScenarioProvider.select((s) => s.rosterMode));
    final healthy =
        ref.watch(sentryScenarioProvider.select((s) => s.wsState.isHealthy));
    final role = ref.watch(authControllerProvider).role;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Text(text.toUpperCase(),
              style: SentryTheme.eyebrow(color: p.muted)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label('Gate encounters'),
        for (var i = 0; i < demoScenarios.length; i++)
          Reveal(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ScenarioTile(scenario: demoScenarios[i]),
            ),
          ),
        const SizedBox(height: 20),
        label('Environment'),
        _ToggleRow(
          icon: Icons.groups_2_outlined,
          title: 'Roster',
          subtitle: roster == RosterMode.classDemo
              ? 'Class demo names (CoE 4102)'
              : 'Synthetic test roster (DEMO001–008)',
          trailing: SegmentedButton<RosterMode>(
            key: const Key('sidebar_roster_toggle'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: RosterMode.classDemo, label: Text('Class')),
              ButtonSegment(
                  value: RosterMode.contractSynthetic, label: Text('Synthetic')),
            ],
            selected: {roster},
            onSelectionChanged: (s) => ref
                .read(sentryScenarioProvider.notifier)
                .setRosterMode(s.first),
          ),
        ),
        _ToggleRow(
          icon: Icons.switch_account_outlined,
          title: 'Signed-in role',
          subtitle: 'Preview what each role can see',
          trailing: SegmentedButton<UserRole>(
            key: const Key('sidebar_role_switch_button'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: UserRole.guard, label: Text('Guard')),
              ButtonSegment(value: UserRole.administrator, label: Text('Admin')),
            ],
            selected: {role.isAdmin ? UserRole.administrator : UserRole.guard},
            onSelectionChanged: (s) => ref
                .read(authControllerProvider.notifier)
                .switchDemoPersona(s.first),
          ),
        ),
        const SizedBox(height: 20),
        label('Failure drills'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              key: const Key('simulate_lag_button'),
              onPressed: () {
                final c = ref.read(sentryScenarioProvider.notifier);
                healthy ? c.toggleSimulatedOfflineLag() : c.forceFullSnapshotResync();
              },
              icon: Icon(healthy ? Icons.wifi_off_rounded : Icons.refresh_rounded,
                  size: 18),
              label: Text(healthy ? 'Drop connection' : 'Reconnect & resync'),
            ),
            OutlinedButton.icon(
              key: const Key('simulate_ws_1008_expiry_button'),
              onPressed: () {
                Navigator.of(context).maybePop();
                ref.read(authControllerProvider.notifier).expireSessionWith1008();
              },
              icon: const Icon(Icons.timer_off_outlined, size: 18),
              label: const Text('Expire session'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScenarioTile extends ConsumerWidget {
  final DemoScenario scenario;
  const _ScenarioTile({required this.scenario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final t = ToneColors.of(context, scenario.tone);
    return SentryCard(
      key: Key('sim_${scenario.code}'),
      padding: const EdgeInsets.all(14),
      radius: 16,
      semanticLabel:
          'Run scenario ${scenario.code}: ${scenario.title}. Expected: ${scenario.expected}',
      onTap: () {
        ref.read(sentryScenarioProvider.notifier).triggerScenario(scenario.code);
        ref.read(focusedLaneProvider.notifier).state = scenario.lane;
        ref.read(selectedDesktopTabProvider.notifier).state =
            scenario.code == 'T13'
                ? DesktopNavTab.guardReviews
                : DesktopNavTab.liveGateMonitoring;
        Navigator.of(context).maybePop();
      },
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(scenario.icon, color: t.solid, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scenario.title,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(scenario.description,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(scenario.code,
                  style: SentryTheme.mono(fontSize: 12, color: p.muted)),
              const SizedBox(height: 4),
              Text(
                scenario.expected,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: t.fg),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: p.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
