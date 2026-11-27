import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/sentry_interactive_logo.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import 'guard_activation_dialog.dart';
import 'guard_password_reset_dialog.dart';

/// View 1: Full-height split sign-in screen for SENTRY Guard & ICT Console.
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
          identifier: _usernameCtrl.text,
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
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 780;
              final compactHeight = constraints.maxHeight < 760;
              final hero = _buildEditorialLeft(
                context,
                compactHeight: compactHeight,
              );
              final form = _buildFormColumn(
                context,
                authState,
                config.isMock,
              );

              return Stack(
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 10,
                          child: ColoredBox(
                            color: SentryColors.crimson,
                            child: Center(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: compactHeight ? 24 : 48,
                                ),
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 460),
                                  child: hero,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 11,
                          child: ColoredBox(
                            color: p.bg,
                            child: Center(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 36,
                                  vertical: compactHeight ? 24 : 48,
                                ),
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 420),
                                  child: form,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ColoredBox(
                            color: SentryColors.crimson,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(28, 60, 28, 32),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 420),
                                  child: hero,
                                ),
                              ),
                            ),
                          ),
                          ColoredBox(
                            color: p.bg,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(28, 32, 28, 40),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 420),
                                  child: form,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Top-right theme toggle & Developer Test Mode indicator
                  Positioned(
                    top: 20,
                    right: 24,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (config.isMock)
                          const StatusPill(
                            label: 'Developer Test Mode',
                            tone: PillTone.neutral,
                            icon: Icons.science_outlined,
                            tooltip:
                                'Developer test mode unlocked for this session',
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: themeMode == ThemeMode.dark
                              ? 'Switch to light mode'
                              : 'Switch to dark mode',
                          color: wide ? p.slate : Colors.white,
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEditorialLeft(
    BuildContext context, {
    required bool compactHeight,
  }) {
    final verticalGap = compactHeight ? 18.0 : 24.0;
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
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'BATSTATEU TNEU · ALANGILAN CAMPUS',
                  style: SentryTheme.eyebrow(color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: verticalGap),
          GestureDetector(
            key: const Key('login_logo_hero'),
            behavior: HitTestBehavior.opaque,
            onTap: _handleLogoTap,
            child: _LogoHero(compact: compactHeight),
          ),
          SizedBox(height: verticalGap),
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'Smarter campus entry.\n'),
                TextSpan(
                  text: 'Zero waiting.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            style: SentryTheme.display(
              fontSize: compactHeight ? 36 : 42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    SentryPalette p, {
    required String hintText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    final radius = BorderRadius.circular(10);
    return InputDecoration(
      filled: true,
      fillColor: p.card,
      constraints: const BoxConstraints.tightFor(height: 48),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(
        minWidth: 44,
        maxHeight: 48,
      ),
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.line, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.line, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.crimson, width: 1.5),
      ),
    );
  }

  Widget _buildFormColumn(
    BuildContext context,
    AuthState authState,
    bool isMock,
  ) {
    final p = SentryPalette.of(context);
    return Reveal(
      index: 1,
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
                    'Sign in',
                    style: SentryTheme.display(
                      fontSize: 28,
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
          const SizedBox(height: 24),

          if (authState.infoBanner != null) ...[
            Callout(
              tone: PillTone.ok,
              icon: Icons.check_circle_outline_rounded,
              title: 'Account update',
              message: authState.infoBanner,
            ),
            const SizedBox(height: 16),
          ],

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
            Semantics(
              liveRegion: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: p.errTint,
                    border: Border(
                      left: BorderSide(color: p.err, width: 3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: p.err,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          authState.errorBanner!,
                          key: const Key('login_error_banner'),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: p.errText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (isMock) ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: p.subtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.line, width: 1),
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
                  const SizedBox(width: 4),
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
            const SizedBox(height: 16),
          ],

          Text(
            'University ID',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('login_username_field'),
            controller: _usernameCtrl,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              p,
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
            decoration: _inputDecoration(
              p,
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              hintText: 'Enter password',
              suffixIcon: IconButton(
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                ),
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
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: const Key('login_submit_button'),
              style: FilledButton.styleFrom(
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: authState.isLoading ? null : _submitLogin,
              icon: const Icon(Icons.arrow_forward_rounded, size: 19),
              label: Text(
                authState.isLoading ? 'Signing in…' : 'Sign in',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.line, width: 1)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              children: [
                _FooterLink(
                  key: const Key('guard_activation_link'),
                  label: 'Guard first-time activation',
                  onPressed: authState.isLoading
                      ? null
                      : () => showGuardActivationDialog(context),
                ),
                _FooterLink(
                  key: const Key('guard_password_reset_link'),
                  label: 'Forgot password?',
                  onPressed: authState.isLoading
                      ? null
                      : () => showGuardPasswordResetDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Crimson hero tile with the inverted interactive logo and calm sonar rings.
class _LogoHero extends StatefulWidget {
  final bool compact;

  const _LogoHero({this.compact = false});

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
    final tileSize = widget.compact ? 152.0 : 180.0;
    final tileRadius = widget.compact ? 20.0 : 24.0;
    return Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        color: SentryColors.crimson,
        borderRadius: BorderRadius.circular(tileRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -8,
          ),
        ],
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
    final fg = selected ? p.text : p.muted;
    final iconColor = selected ? SentryColors.crimson : p.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: SentryMotion.of(context, SentryMotion.short),
          curve: SentryMotion.emphasized,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? p.card : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? p.line : Colors.transparent,
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: p.isDark ? 0.22 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: iconColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _FooterLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.zero),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return p.muted.withValues(alpha: 0.5);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed)) {
            return SentryColors.crimson;
          }
          return p.muted;
        }),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: SentryTheme.sansFontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      child: Text(label),
    );
  }
}
