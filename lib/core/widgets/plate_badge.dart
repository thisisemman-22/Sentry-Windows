import 'package:flutter/material.dart';
import '../theme/sentry_colors.dart';
import '../theme/sentry_theme.dart';

/// License Plate Badge Widget (`PlateBadge`) matching §4.2:
/// - `height: 26px`, `padding: EdgeInsets.symmetric(horizontal: 9)`
/// - `borderRadius: BorderRadius.circular(6)`
/// - background `--subtle`, `1px solid --line`, bold uppercase monospace text with `letterSpacing: 0.8`.
class PlateBadge extends StatelessWidget {
  final String? plateText;
  final String? rfidUid;
  final bool isCompact;

  const PlateBadge({
    super.key,
    this.plateText,
    this.rfidUid,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final isRfidOnly =
        (plateText == null || plateText!.trim().isEmpty) && rfidUid != null;
    final display = (plateText != null && plateText!.trim().isNotEmpty)
        ? plateText!.toUpperCase()
        : (rfidUid != null ? 'RFID:$rfidUid' : 'UNREADABLE');

    final isUnreadable = display == 'UNREADABLE';

    return Container(
      height: isCompact ? 23 : 26,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 7 : 9),
      decoration: BoxDecoration(
        color: isUnreadable
            ? p.errTint
            : isRfidOnly
                ? p.infoTint
                : p.subtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isUnreadable
              ? p.err.withValues(alpha: 0.45)
              : isRfidOnly
                  ? p.info.withValues(alpha: 0.45)
                  : p.line,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRfidOnly ? Icons.contactless_outlined : Icons.directions_car_filled_outlined,
            size: 12,
            color: isUnreadable
                ? p.errText
                : isRfidOnly
                    ? p.info
                    : p.crimson,
          ),
          const SizedBox(width: 5),
          Text(
            display,
            style: SentryTheme.mono(
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isUnreadable ? p.errText : p.text,
            ),
          ),
        ],
      ),
    );
  }
}
