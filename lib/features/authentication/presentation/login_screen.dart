import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/sentry_interactive_logo.dart';
import '../../../core/widgets/ui/sentry_ui.dart';

/// View 1: Editorial, calm sign-in experience inspired by `design_reference/index.html`.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  bool _obscurePassword = true;
  int _selectedPersona = 0; // 0 = Guard, 1 = Admin
  final List<DateTime> _logoTapTimestamps = [];

  @override
  void initState() {
    super.initState();
    final isMock = ref.read(appConfigProvider).isMock;
    _usernameCtrl = TextEditingController(
      text: isMock ? 'guard01@sentry.test' : '',
    );
    _passwordCtrl = TextEditingController(
      text: isMock ? 'sentry2026' : '',
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _unlockDeveloperTestMode() {
    ref.read(devModeUnlockedProvider.notifier).state = true;
    ref.read(sentryScenarioProvider.notifier).enableDeveloperMockMode();
    if (_usernameCtrl.text.trim().isEmpty) {
      _selectPersona(_selectedPersona);
    }
    showSentryToast(
      context,
      'Developer Test Mode Enabled',
      tone: PillTone.ok,
    );
  }

  void _handleLogoTap() {
    final now = DateTime.now();
    _logoTapTimestamps.removeWhere(
      (t) => now.difference(t) > const Duration(seconds: 2),
    );
    _logoTapTimestamps.add(now);
    if (_logoTapTimestamps.length >= 5) {
      _logoTapTimestamps.clear();
      _unlockDeveloperTestMode();
    }
  }

  void _selectPersona(int index) {
    setState(() {
      _selectedPersona = index;
      if (index == 0) {
        _usernameCtrl.text = 'guard01@sentry.test';
        _passwordCtrl.text = 'sentry2026';
      } else {
        _usernameCtrl.text = 'admin01@sentry.test';
        _passwordCtrl.text = 'sentry2026';
      }
    });
  }

  Future<void> _submitLogin() async {
    await ref.read(authControllerProvider.notifier).signIn(
          username: _usernameCtrl.text,
          password: _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final authState = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final config = ref.watch(appConfigProvider);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(
          LogicalKeyboardKey.keyD,
          control: true,
          shift: true,
          alt: true,
        ): _unlockDeveloperTestMode,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: p.bg,
          body: Stack(
            children: [
              // Subtle top-right theme toggle
              Positioned(
                top: 24,
                right: 28,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (config.isMock)
                      const StatusPill(
                        label: 'Developer Test Mode',
                        tone: PillTone.neutral,
                        icon: Icons.science_outlined,
                        tooltip: 'Developer test mode unlocked for this session',
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: themeMode == ThemeMode.dark
                          ? 'Switch to light mode'
                          : 'Switch to dark mode',
                      onPressed: () {
                        ref.read(themeModeProvider.notifier).state =
                            themeMode == ThemeMode.dark
                                ? ThemeMode.light
                                : ThemeMode.dark;
                      },
                      icon: Icon(
                        themeMode == ThemeMode.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                    ),
                  ],
                ),
              ),

              // Centered editorial split stage
              Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1020),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 780;
                        final hero = _buildEditorialLeft(context);
                        final form =
                            _buildFormCard(context, authState, config.isMock);
                        if (!wide) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              hero,
                              const SizedBox(height: 28),
                              form,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 11, child: hero),
                            const SizedBox(width: 56),
                            Expanded(flex: 10, child: form),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorialLeft(BuildContext context) {
    final p = SentryPalette.of(context);
    return Reveal(
      index: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: SentryColors.crimson,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'BATSTATEU TNEU · ALANGILAN CAMPUS',
                style: SentryTheme.eyebrow(color: p.crimson),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            key: const Key('login_logo_hero'),
            behavior: HitTestBehavior.opaque,
            onTap: _handleLogoTap,
            child: const _LogoHero(),
          ),
          const SizedBox(height: 24),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Smarter campus entry.\n'),
                TextSpan(
                  text: 'Zero waiting.',
                  style: TextStyle(color: p.crimson),
                ),
              ],
            ),
            style: SentryTheme.display(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: p.text,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'Real-time gate verification, live bay availability across Lots A to D, and calm decision support for campus security.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: p.slate,
                    height: 1.6,
                  ),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              StatusPill(
                label: 'Plate + Face entry',
                tone: PillTone.neutral,
                icon: Icons.directions_car_outlined,
              ),
              StatusPill(
                label: 'RFID + Face motorcycles',
                tone: PillTone.neutral,
                icon: Icons.two_wheeler_outlined,
              ),
              StatusPill(
                label: 'Lots A–D live bays',
                tone: PillTone.neutral,
                icon: Icons.local_parking_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    AuthState authState,
    bool isMock,
  ) {
    final p = SentryPalette.of(context);
    return Reveal(
      index: 1,
      scale: true,
      child: SentryCard(
        padding: const EdgeInsets.all(34),
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Sign in to Guard & ICT Console',
                      style: SentryTheme.display(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                  ),
                ),
                const InfoHint(
                  'Authorized for campus guards and ICT administrators. '
                  'Student accounts use the SENTRY mobile app. '
                  'Protected under RA 10173 (Data Privacy Act).',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isMock
                  ? 'Choose a demo role or enter your operator credentials.'
                  : 'Enter your operator credentials to sign in.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            if (authState.sessionExpiredBanner != null) ...[
              Callout(
                tone: PillTone.warn,
                icon: Icons.timer_off_outlined,
                title: 'Session ended',
                message: authState.sessionExpiredBanner,
              ),
              const SizedBox(height: 16),
            ],

            if (authState.errorBanner != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.errTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.err.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 20, color: p.errText),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        authState.errorBanner!,
                        key: const Key('login_error_banner'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: p.errText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (isMock) ...[
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: p.subtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _PersonaButton(
                        key: const Key('persona_guard_chip'),
                        label: 'Guard desk',
                        selected: _selectedPersona == 0,
                        icon: Icons.shield_outlined,
                        onTap: () => _selectPersona(0),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _PersonaButton(
                        key: const Key('persona_admin_chip'),
                        label: 'Administrator',
                        selected: _selectedPersona == 1,
                        icon: Icons.admin_panel_settings_outlined,
                        onTap: () => _selectPersona(1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            Text(
              'Email or username',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('login_username_field'),
              controller: _usernameCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                hintText: isMock
                    ? 'guard01@sentry.test'
                    : 'operator@g.batstate-u.edu.ph',
              ),
              onSubmitted: (_) => _submitLogin(),
            ),
            const SizedBox(height: 16),

            Text(
              'Password',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('login_password_field'),
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              onSubmitted: (_) => _submitLogin(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                hintText: 'Enter password',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: FilledButton.icon(
                key: const Key('login_submit_button'),
                onPressed: authState.isLoading ? null : _submitLogin,
                icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                label: Text(
                  authState.isLoading ? 'Signing in…' : 'Sign in',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Crimson hero tile with the inverted interactive logo and calm sonar rings.
class _LogoHero extends StatefulWidget {
  const _LogoHero();

  @override
  State<_LogoHero> createState() => _LogoHeroState();
}

class _LogoHeroState extends State<_LogoHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SentryMotion.reduced(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: SentryColors.crimson,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => CustomPaint(
                size: const Size(220, 220),
                painter: _SonarPainter(_ctrl.value),
              ),
            ),
          ),
          const SentryInteractiveLogo.inverted(size: 132),
        ],
      ),
    );
  }
}

class _SonarPainter extends CustomPainter {
  final double t;
  const _SonarPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.28 * (1 - phase));
      canvas.drawCircle(c, 60 + phase * 50, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SonarPainter old) => old.t != t;
}

class _PersonaButton extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _PersonaButton({
    super.key,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final fg = selected ? (p.isDark ? p.bg : Colors.white) : p.slate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: SentryMotion.of(context, SentryMotion.short),
          curve: SentryMotion.emphasized,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? p.text : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? p.crimsonHover : fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
