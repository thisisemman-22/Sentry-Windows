import 'package:flutter/material.dart';
import '../network/api_envelope.dart';
import '../network/ws_client.dart';
import '../theme/sentry_colors.dart';
import '../theme/sentry_theme.dart';

/// Top Telemetry & Freshness Ribbon (`FreshnessBanner`) showing:
/// - Live synced vs. Stale/Offline WebSocket state (`§7.11`)
/// - Sequence number & deduplication counter
/// - One-click "Simulate Lag / Offline (`T18`)" and "Reconnect & Full Resync" buttons
class FreshnessBanner extends StatelessWidget {
  final WsStreamState wsState;
  final VoidCallback onToggleSimulateOffline;
  final VoidCallback onForceFullResync;

  const FreshnessBanner({
    super.key,
    required this.wsState,
    required this.onToggleSimulateOffline,
    required this.onForceFullResync,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final isHealthy = wsState.isHealthy;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isHealthy ? p.okTint : p.warnTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isHealthy ? p.ok : p.warn).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHealthy ? Icons.bolt_rounded : Icons.sync_problem_rounded,
            size: 15,
            color: isHealthy ? p.okText : p.warnText,
          ),
          const SizedBox(width: 6),
          Text(
            isHealthy
                ? 'LIVE CAMERAS & GATE SYNCED'
                : 'TELEMETRY STALE · RESYNC REQUIRED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isHealthy ? p.okText : p.warnText,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'SEQ #${wsState.lastStreamSequence} · ${ManilaTime.formatTimeOnly(wsState.lastSyncedAtUtc)}',
            style: SentryTheme.mono(
              fontSize: 10.5,
              color: isHealthy ? p.okText : p.warnText,
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap:
                isHealthy ? onToggleSimulateOffline : onForceFullResync,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: p.card.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: p.line),
              ),
              child: Text(
                isHealthy ? 'Simulate Lag (T18)' : 'Reconnect & Resync',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
