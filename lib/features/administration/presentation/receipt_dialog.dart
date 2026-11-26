import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../data/dto/phase4_admin_dtos.dart';

/// Modal receipt displaying all non-secret Phase 4 account registration fields
/// (never echoes `attestation.reference`, `user_id`, or `email`).
Future<void> showRegistrationReceiptDialog(
  BuildContext context, {
  required AdminRegistrationReceipt receipt,
  VoidCallback? onOpenActivationHelp,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReceiptDialog(
      receipt: receipt,
      onOpenActivationHelp: onOpenActivationHelp,
    ),
  );
}

class ReceiptDialog extends StatelessWidget {
  final AdminRegistrationReceipt receipt;
  final VoidCallback? onOpenActivationHelp;

  const ReceiptDialog({
    super.key,
    required this.receipt,
    this.onOpenActivationHelp,
  });

  PillTone _deliveryTone(ActivationCodeDelivery delivery) {
    switch (delivery) {
      case ActivationCodeDelivery.providerAccepted:
        return PillTone.ok;
      case ActivationCodeDelivery.notReported:
        return PillTone.info;
      case ActivationCodeDelivery.providerRejected:
      case ActivationCodeDelivery.outcomeUnknown:
      case ActivationCodeDelivery.notSent:
        return PillTone.warn;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(receipt.operationTitle),
          StatusPill(
            label: receipt.idempotentReplay ? 'Idempotent replay' : '202 Accepted',
            tone: receipt.idempotentReplay ? PillTone.info : PillTone.ok,
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Callout(
                tone: PillTone.warn,
                icon: Icons.bookmark_added_outlined,
                title: 'Save this Registration ID for this session',
                message:
                    'Receipts contain an opaque registration_id UUID (never user_id or email). Copy and keep it for OTP activation reissue or password-setup recovery.',
              ),
              if (receipt.idempotentReplay) ...[
                const SizedBox(height: 12),
                const Callout(
                  tone: PillTone.info,
                  icon: Icons.replay_rounded,
                  title: 'Idempotent replay',
                  message:
                      'This response replayed an earlier submission with the same Idempotency-Key. No duplicate account or new OTP code was created.',
                ),
              ],
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registration ID',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          receipt.registrationId,
                          key: const Key('receipt_registration_id_text'),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('receipt_copy_id_button'),
                    tooltip: 'Copy registration_id',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: receipt.registrationId),
                      );
                      showSentryToast(
                        context,
                        'Registration ID copied to clipboard.',
                        tone: PillTone.ok,
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (receipt.registrationStateAtCreation != null)
                KeyValueRow(
                  label: 'Registration state',
                  value: receipt.registrationStateAtCreation!,
                  mono: true,
                ),
              if (receipt.accountActiveAtCreation != null)
                KeyValueRow(
                  label: 'Account active',
                  value: receipt.accountActiveAtCreation! ? 'true' : 'false',
                  mono: true,
                ),
              if (receipt.activationRequired != null)
                KeyValueRow(
                  label: 'Activation required',
                  value: receipt.activationRequired! ? 'true' : 'false',
                  mono: true,
                ),
              if (receipt.expiresAtUtc != null)
                KeyValueRow(
                  label: 'Registration expires (PHT)',
                  value: ManilaTime.formatDateTime(receipt.expiresAtUtc),
                  mono: true,
                ),
              KeyValueRow(
                label: 'Delivery status',
                value:
                    '${receipt.activationCodeDelivery.displayTitle} (${receipt.activationCodeDelivery.wireValue})',
              ),
              KeyValueRow(
                label: 'Request ID',
                value: receipt.requestId,
                mono: true,
              ),
              const SizedBox(height: 12),
              Callout(
                tone: _deliveryTone(receipt.activationCodeDelivery),
                icon: Icons.mark_email_read_outlined,
                title: receipt.activationCodeDelivery.displayTitle,
                message: receipt.activationCodeDelivery.explanation,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (onOpenActivationHelp != null)
          OutlinedButton.icon(
            key: const Key('receipt_open_activation_help_button'),
            onPressed: () {
              Navigator.of(context).pop();
              onOpenActivationHelp!();
            },
            icon: const Icon(Icons.support_agent_rounded, size: 18),
            label: const Text('Open Activation Help'),
          ),
        FilledButton(
          key: const Key('receipt_close_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
