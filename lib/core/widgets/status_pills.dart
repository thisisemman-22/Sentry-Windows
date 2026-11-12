import 'package:flutter/material.dart';
import '../theme/sentry_colors.dart';
import '../theme/sentry_theme.dart';

enum PillTone {
  ok,
  warn,
  err,
  info,
  neutral,
  crimson,
}

/// Semantic pill badge. Always pairs color with an icon + plain word so
/// status is never communicated by color alone (WCAG 1.4.1).
///
/// Factories translate backend enums into operator-friendly language:
/// - Decision outcome (`allowed` | `denied` | `review_required`)
/// - Attempt state machine (`observation_received` … `completed`)
/// - Physical bay status (`available` | `occupied` | `unknown`)
/// - Allocation bay status (`unassigned` | `held` | `assigned`)
/// - Device status (`online` | `degraded` | `offline`)
class StatusPill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final IconData? icon;
  final bool monospace;
  final String? tooltip;

  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.monospace = false,
    this.tooltip,
  });

  factory StatusPill.fromDecisionOutcome(String outcome) {
    switch (outcome.toLowerCase()) {
      case 'allowed':
        return const StatusPill(
          label: 'Allowed',
          tone: PillTone.ok,
          icon: Icons.check_circle_rounded,
          tooltip: 'Access decision: allowed',
        );
      case 'review_required':
      case 'needs_review':
        return const StatusPill(
          label: 'Review',
          tone: PillTone.warn,
          icon: Icons.visibility_rounded,
          tooltip: 'Access decision: review_required',
        );
      case 'idle':
        return const StatusPill(
          label: 'Idle',
          tone: PillTone.neutral,
          icon: Icons.sensors_rounded,
          tooltip: 'Gate lane idle',
        );
      case 'denied':
      default:
        return const StatusPill(
          label: 'Denied',
          tone: PillTone.err,
          icon: Icons.block_rounded,
          tooltip: 'Access decision: denied',
        );
    }
  }

  factory StatusPill.fromAttemptState(String state) {
    switch (state) {
      case 'observation_received':
        return const StatusPill(
          label: 'Vehicle detected',
          tone: PillTone.info,
          icon: Icons.sensors_rounded,
          tooltip: 'observation_received — no permission granted yet',
        );
      case 'identity_verification_pending':
        return const StatusPill(
          label: 'Verifying identity',
          tone: PillTone.info,
          icon: Icons.hourglass_top_rounded,
          tooltip: 'identity_verification_pending',
        );
      case 'authorization_allowed':
        return const StatusPill(
          label: 'Waiting to cross',
          tone: PillTone.warn,
          icon: Icons.timer_outlined,
          tooltip:
              'authorization_allowed — a bay is held until the guard confirms the vehicle crossed',
        );
      case 'guard_review_required':
        return const StatusPill(
          label: 'Review',
          tone: PillTone.warn,
          icon: Icons.visibility_rounded,
          tooltip: 'guard_review_required',
        );
      case 'authorization_denied':
        return const StatusPill(
          label: 'Denied',
          tone: PillTone.err,
          icon: Icons.block_rounded,
          tooltip: 'authorization_denied',
        );
      case 'expired':
        return const StatusPill(
          label: 'Expired',
          tone: PillTone.err,
          icon: Icons.timer_off_outlined,
          tooltip: 'expired — hold timed out before passage',
        );
      case 'cancelled':
        return const StatusPill(
          label: 'Cancelled',
          tone: PillTone.neutral,
          icon: Icons.cancel_outlined,
          tooltip: 'cancelled before passage',
        );
      case 'completed':
        return const StatusPill(
          label: 'Crossed gate',
          tone: PillTone.ok,
          icon: Icons.check_circle_rounded,
          tooltip: 'completed — passage confirmed, visit recorded',
        );
      default:
        return StatusPill(
          label: _humanize(state),
          tone: PillTone.neutral,
          tooltip: state,
        );
    }
  }

  factory StatusPill.fromPhysicalSpace(String physicalStatus,
      {bool isStale = false}) {
    if (isStale || physicalStatus == 'unknown') {
      return const StatusPill(
        label: 'Unknown',
        tone: PillTone.neutral,
        icon: Icons.videocam_off_outlined,
        tooltip:
            'Camera reading is unknown or stale — never counted as available',
      );
    }
    if (physicalStatus == 'available') {
      return const StatusPill(
        label: 'Empty',
        tone: PillTone.ok,
        icon: Icons.check_circle_outline_rounded,
        tooltip: 'Overhead camera sees this bay as empty',
      );
    }
    return const StatusPill(
      label: 'Occupied',
      tone: PillTone.crimson,
      icon: Icons.directions_car_rounded,
      tooltip: 'Overhead camera sees a vehicle in this bay',
    );
  }

  factory StatusPill.fromAllocationSpace(String allocationStatus) {
    switch (allocationStatus) {
      case 'unassigned':
        return const StatusPill(
          label: 'Open',
          tone: PillTone.ok,
          icon: Icons.lock_open_rounded,
          tooltip: 'Allocation: unassigned',
        );
      case 'held':
        return const StatusPill(
          label: 'Held',
          tone: PillTone.warn,
          icon: Icons.timer_outlined,
          tooltip:
              'Allocation: held for a vehicle at the gate (30s, before passage)',
        );
      case 'assigned':
      default:
        return const StatusPill(
          label: 'Assigned',
          tone: PillTone.crimson,
          icon: Icons.lock_rounded,
          tooltip: 'Allocation: assigned to an active visit',
        );
    }
  }

  factory StatusPill.fromDeviceStatus(String status) {
    switch (status) {
      case 'online':
        return const StatusPill(
          label: 'Online',
          tone: PillTone.ok,
          icon: Icons.wifi_rounded,
        );
      case 'degraded':
        return const StatusPill(
          label: 'Degraded',
          tone: PillTone.warn,
          icon: Icons.warning_amber_rounded,
          tooltip: 'Device is reporting but with reduced quality',
        );
      case 'offline':
      default:
        return const StatusPill(
          label: 'Offline',
          tone: PillTone.err,
          icon: Icons.wifi_off_rounded,
          tooltip: 'No heartbeat for more than 30 seconds',
        );
    }
  }

  static String _humanize(String raw) {
    final s = raw.replaceAll('_', ' ').trim();
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    Color bg;
    Color fg;

    switch (tone) {
      case PillTone.ok:
        bg = p.okTint;
        fg = p.okText;
        break;
      case PillTone.warn:
        bg = p.warnTint;
        fg = p.warnText;
        break;
      case PillTone.err:
        bg = p.errTint;
        fg = p.errText;
        break;
      case PillTone.info:
        bg = p.infoTint;
        fg = p.info;
        break;
      case PillTone.crimson:
        bg = p.crimsonTint;
        fg = p.crimsonHover;
        break;
      case PillTone.neutral:
        bg = p.subtle;
        fg = p.slate;
        break;
    }

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: monospace
                  ? SentryTheme.mono(fontSize: 12.5, color: fg)
                  : TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                      height: 1.2,
                      color: fg,
                      fontStyle: FontStyle.normal,
                    ),
            ),
          ),
        ],
      ),
    );

    if (tooltip == null) return pill;
    return Tooltip(message: tooltip!, child: pill);
  }
}
