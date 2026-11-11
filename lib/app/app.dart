import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/motion/motion.dart';
import '../core/theme/sentry_theme.dart';
import '../core/widgets/sentry_interactive_logo.dart';
import '../features/authentication/presentation/login_screen.dart';
import 'desktop_shell.dart';
import 'providers.dart';

/// Root `MaterialApp` for SENTRY (`campus_parking_desktop`).
///
/// Pointer movement is written to [SentryPointer] (a plain `ValueNotifier`)
/// so the cursor-tracking shield logo animates without rebuilding the app.
class SentryDesktopApp extends ConsumerWidget {
  const SentryDesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authControllerProvider);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (e) => SentryPointer.position.value = e.position,
      onPointerMove: (e) => SentryPointer.position.value = e.position,
      child: MaterialApp(
        title: 'SENTRY · BatStateU TNEU Alangilan',
        debugShowCheckedModeBanner: false,
        theme: SentryTheme.light(),
        darkTheme: SentryTheme.dark(),
        themeMode: themeMode,
        themeAnimationDuration: const Duration(milliseconds: 420),
        themeAnimationCurve: SentryMotion.emphasized,
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 560),
          switchInCurve: SentryMotion.emphasized,
          switchOutCurve: SentryMotion.exit,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 0.985, end: 1.0).animate(anim),
              child: child,
            ),
          ),
          child: authState.isAuthenticated
              ? const DesktopShell(key: ValueKey('shell'))
              : const LoginScreen(key: ValueKey('login')),
        ),
      ),
    );
  }
}
