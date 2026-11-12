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
    final config = ref.watch(appConfigProvider);
    final configError = config.validateForRealMode();

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
          child: configError != null
              ? _RealModeConfigErrorScreen(
                  key: const ValueKey('real_config_error_screen'),
                  errorMessage: configError,
                  apiBaseUrl: config.apiBaseUrl,
                  wsBaseUrl: config.wsBaseUrl,
                )
              : authState.isAuthenticated
                  ? const DesktopShell(key: ValueKey('shell'))
                  : const LoginScreen(key: ValueKey('login')),
        ),
      ),
    );
  }
}

class _RealModeConfigErrorScreen extends StatelessWidget {
  final String errorMessage;
  final String apiBaseUrl;
  final String wsBaseUrl;

  const _RealModeConfigErrorScreen({
    super.key,
    required this.errorMessage,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.gpp_bad_outlined,
                          color: theme.colorScheme.error,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Fail-Closed Startup Error (DATA_SOURCE=real)',
                            style: SentryTheme.display(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      errorMessage,
                      key: const Key('real_mode_config_error_text'),
                      style: SentryTheme.mono(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'SENTRY is configured with DATA_SOURCE=real and strictly refuses to fall back to mock/synthetic data when backend URLs are missing or invalid.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'API_BASE_URL: "${apiBaseUrl.isEmpty ? '<empty>' : apiBaseUrl}"\n'
                      'WS_BASE_URL:  "${wsBaseUrl.isEmpty ? '<empty>' : wsBaseUrl}"',
                      style: SentryTheme.mono(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
