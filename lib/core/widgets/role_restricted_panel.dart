import 'package:flutter/material.dart';
import '../theme/sentry_colors.dart';
import '../theme/sentry_theme.dart';

/// Clean 403 / Role-Gated panel rendered when a `guard` operator accesses an
/// `administrator`-only section (Audit Logs or `P01–P06` Registration Maintenance).
class RoleRestrictedPanel extends StatelessWidget {
  final String title;
  final String endpointPath;
  final String description;
  final String? lastSimulatedError;
  final VoidCallback? onSimulateForbiddenCall;

  const RoleRestrictedPanel({
    super.key,
    required this.title,
    required this.endpointPath,
    required this.description,
    this.lastSimulatedError,
    this.onSimulateForbiddenCall,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.errTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: p.errText,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'RESTRICTED ENDPOINT: $endpointPath · REQUIRES ROLE: ADMINISTRATOR',
                      style: SentryTheme.mono(
                        fontSize: 11,
                        color: p.errText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: p.slate,
              height: 1.5,
            ),
          ),
          if (onSimulateForbiddenCall != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onSimulateForbiddenCall,
              icon: const Icon(Icons.security_outlined, size: 16),
              label: const Text(
                'Test Calling Endpoint as Guard (Verify HTTP 403 ACCESS_DENIED)',
              ),
            ),
          ],
          if (lastSimulatedError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.errTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.err.withValues(alpha: 0.4)),
              ),
              child: Text(
                lastSimulatedError!,
                style: SentryTheme.mono(
                  fontSize: 11.5,
                  color: p.errText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
