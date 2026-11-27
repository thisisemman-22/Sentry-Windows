import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/ui/sentry_ui.dart';

/// Admin-only read-only `Settings` screen showing backend authentication,
/// JWT key status, CORS, OpenAPI contract version, and DB connectivity.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final profile = ref.watch(authControllerProvider).profile;
    final isAdmin = profile?.role.isAdmin ?? false;
    if (!isAdmin) {
      return const ScreenScaffold(
        children: [
          PageIntro(
            title: 'Settings',
            subtitle: 'Read-only FastAPI configuration and database telemetry.',
          ),
          SizedBox(height: 18),
          RoleRestrictedPanel(
            featureName: 'Backend System Settings',
            minimumRole: 'administrator',
          ),
        ],
      );
    }

    final ops = ref.watch(desktopOpsControllerProvider);
    final settings = ops.backendSettings;

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Settings',
          subtitle:
              'Read-only FastAPI session limits, JWT signing state, CORS origins, and database status.',
          actions: [
            OutlinedButton.icon(
              key: const Key('settings_refresh_btn'),
              onPressed: () {
                ref
                    .read(desktopOpsControllerProvider.notifier)
                    .refreshRealOpsSnapshot();
              },
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Sync Settings'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (settings == null)
          SentryCard(
            child: EmptyState(
              icon: Icons.settings_ethernet_outlined,
              title: 'Backend settings unavailable',
              message:
                  'Waiting for FastAPI system configuration telemetry in production mode.',
              action: OutlinedButton.icon(
                onPressed: () {
                  ref
                      .read(desktopOpsControllerProvider.notifier)
                      .refreshRealOpsSnapshot();
                },
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            ),
          )
        else ...[
          SentryCard(
            key: const Key('settings_auth_policy_card'),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'Authentication & lockout policy (Read-only)',
                  subtitle: 'Enforced by FastAPI backend authentication service.',
                ),
                const SizedBox(height: 12),
                KeyValueRow(
                  label: 'Access session TTL',
                  value: '${settings.accessSessionMinutes} minutes',
                  mono: true,
                ),
                KeyValueRow(
                  label: 'Refresh session TTL',
                  value: '${settings.refreshSessionHours} hours',
                  mono: true,
                ),
                KeyValueRow(
                  label: 'Lockout policy',
                  value:
                      '${settings.maxLoginAttempts} attempts -> ${settings.lockoutMinutes} min lockout',
                  mono: true,
                ),
                KeyValueRow(
                  label: 'General Password default expiry',
                  value: '${settings.generalPasswordExpiryHours} hours',
                  mono: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SentryCard(
            key: const Key('settings_runtime_card'),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'Contract, JWT & database status (Read-only)',
                  subtitle: 'Phase 4 OpenAPI server runtime inspection.',
                  trailing: StatusPill(
                    label: settings.databaseConnected
                        ? 'DB Connected (${settings.databaseLatencyMs} ms)'
                        : 'DB Disconnected',
                    tone: settings.databaseConnected
                        ? PillTone.ok
                        : PillTone.err,
                    monospace: true,
                  ),
                ),
                const SizedBox(height: 12),
                KeyValueRow(
                  label: 'Contract version',
                  value: settings.contractVersion,
                  mono: true,
                ),
                KeyValueRow(
                  label: 'JWT signing key',
                  value: settings.signingKeyStatus,
                  mono: true,
                ),
                KeyValueRow(
                  label: 'Allowed CORS origins',
                  value: settings.corsOrigins.isEmpty
                      ? 'None configured'
                      : settings.corsOrigins.join(' · '),
                  mono: true,
                ),
                const SizedBox(height: 8),
                Text(
                  'Configuration is managed exclusively on the FastAPI server environment.',
                  style: SentryTheme.mono(fontSize: 12, color: p.muted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
