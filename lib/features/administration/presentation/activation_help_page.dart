import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/phase4_contract.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../data/dto/phase4_admin_dtos.dart';
import 'receipt_dialog.dart';

/// Administrator Activation Help view (`D-04`):
/// - Reissue OTP activation code (`POST /api/v1/admin/accounts/registrations/{registration_id}/otp/reissue`)
/// - Recover lost setup grant (`POST /api/v1/admin/accounts/registrations/{registration_id}/password-setup/recover`)
/// Uses opaque `registration_id` UUID ONLY (never `user_id` or `email`), requires explicit confirmation,
/// and never auto-chains or auto-retries on `503`.
class ActivationHelpPage extends ConsumerStatefulWidget {
  final String? initialRegistrationId;
  final VoidCallback? onSwitchToReclaim;

  const ActivationHelpPage({
    super.key,
    this.initialRegistrationId,
    this.onSwitchToReclaim,
  });

  @override
  ConsumerState<ActivationHelpPage> createState() => _ActivationHelpPageState();
}

class _ActivationHelpPageState extends ConsumerState<ActivationHelpPage> {
  late final TextEditingController _regIdCtrl;
  bool _submitting = false;
  String? _fieldError;
  String? _errorCode;
  String? _errorMessage;
  String? _requestId;
  AdminRegistrationReceipt? _lastReceipt;
  int _retryAfterRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _regIdCtrl = TextEditingController(text: widget.initialRegistrationId ?? '');
  }

  @override
  void didUpdateWidget(covariant ActivationHelpPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialRegistrationId;
    if (incoming != null &&
        incoming.isNotEmpty &&
        incoming != oldWidget.initialRegistrationId) {
      _regIdCtrl.text = incoming;
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _regIdCtrl.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _retryAfterRemaining = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_retryAfterRemaining <= 1) {
        timer.cancel();
        setState(() => _retryAfterRemaining = 0);
      } else {
        setState(() => _retryAfterRemaining--);
      }
    });
  }

  Future<bool> _confirmOperation({
    required String title,
    required String body,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(body),
        ),
        actions: [
          OutlinedButton(
            key: const Key('activation_help_confirm_cancel_button'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('activation_help_confirm_proceed_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & send'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _runReissue() async {
    final regId = _regIdCtrl.text.trim();
    if (!isValidCanonicalUuid(regId)) {
      setState(
        () => _fieldError = 'Enter a valid canonical registration_id UUID.',
      );
      return;
    }
    setState(() => _fieldError = null);

    final ok = await _confirmOperation(
      title: 'Reissue OTP activation code?',
      body:
          'This immediately invalidates any earlier OTP code for registration $regId and dispatches a fresh 6-digit code. Proceed?',
    );
    if (!ok || !mounted) return;

    setState(() {
      _submitting = true;
      _errorCode = null;
      _errorMessage = null;
      _requestId = null;
    });

    final res = await ref
        .read(adminRegistrationApiProvider)
        .reissueActivationCode(regId);
    if (!mounted) return;

    if (res.ok && res.data != null) {
      final receipt = AdminRegistrationReceipt.fromReissue(
        res.data!,
        requestId: res.meta.requestId,
      );
      setState(() {
        _submitting = false;
        _lastReceipt = receipt;
        _requestId = res.meta.requestId;
      });
      await showRegistrationReceiptDialog(context, receipt: receipt);
      return;
    }

    _handleError(res.error, res.meta.requestId);
  }

  Future<void> _runRecovery() async {
    final regId = _regIdCtrl.text.trim();
    if (!isValidCanonicalUuid(regId)) {
      setState(
        () => _fieldError = 'Enter a valid canonical registration_id UUID.',
      );
      return;
    }
    setState(() => _fieldError = null);

    final ok = await _confirmOperation(
      title: 'Recover password setup?',
      body:
          'Use this ONLY when the registrant already verified their OTP activation code but closed or lost their password-setup session. This revokes any previous setup grant and sends a fresh 6-digit OTP code. Proceed?',
    );
    if (!ok || !mounted) return;

    setState(() {
      _submitting = true;
      _errorCode = null;
      _errorMessage = null;
      _requestId = null;
    });

    final res =
        await ref.read(adminRegistrationApiProvider).recoverPasswordSetup(regId);
    if (!mounted) return;

    if (res.ok && res.data != null) {
      final receipt = AdminRegistrationReceipt.fromRecovery(
        res.data!,
        requestId: res.meta.requestId,
      );
      setState(() {
        _submitting = false;
        _lastReceipt = receipt;
        _requestId = res.meta.requestId;
      });
      await showRegistrationReceiptDialog(context, receipt: receipt);
      return;
    }

    _handleError(res.error, res.meta.requestId);
  }

  void _handleError(ApiError? err, String requestId) {
    if (err == null) {
      setState(() {
        _submitting = false;
        _errorCode = ErrorCatalog.serviceUnavailable;
        _errorMessage =
            'Outcome unknown — do NOT automatically retry. Confirm delivery state before trying again.';
        _requestId = requestId;
      });
      return;
    }

    if (err.httpStatus == 429 && (err.retryAfterSeconds ?? 0) > 0) {
      _startCooldown(err.retryAfterSeconds!);
    }

    final failure = Phase4ApiFailure.fromError(err, requestId: requestId);
    setState(() {
      _submitting = false;
      _errorCode = err.code;
      _errorMessage = failure.userDisplayMessage;
      _requestId = requestId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _retryAfterRemaining > 0;
    return SentryCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Activation help & OTP recovery',
            subtitle:
                'Reissue an expired OTP code or recover a lost password-setup grant using the receipt registration_id UUID.',
            hint:
                'Calls /otp/reissue or /password-setup/recover after explicit confirmation.',
          ),
          const SizedBox(height: 18),
          if (_errorMessage != null) ...[
            Callout(
              tone: PillTone.err,
              icon: Icons.error_outline_rounded,
              title: _requestId != null
                  ? '${_errorCode ?? 'Error'} · Request ID: $_requestId'
                  : (_errorCode ?? 'Error'),
              message: _errorMessage!,
              action: (_errorCode == ErrorCatalog.reissueNotAllowed &&
                      widget.onSwitchToReclaim != null)
                  ? OutlinedButton.icon(
                      onPressed: widget.onSwitchToReclaim,
                      icon: const Icon(Icons.replay_rounded, size: 17),
                      label: const Text('Open Expired Reclaim'),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
          ],
          if (_lastReceipt != null) ...[
            Callout(
              tone: PillTone.ok,
              icon: Icons.check_circle_outline_rounded,
              title: _lastReceipt!.operationTitle,
              message:
                  'Registration ID: ${_lastReceipt!.registrationId} · Delivery: ${_lastReceipt!.activationCodeDelivery.displayTitle} · Request ID: ${_lastReceipt!.requestId}',
              action: OutlinedButton(
                onPressed: () => showRegistrationReceiptDialog(
                  context,
                  receipt: _lastReceipt!,
                ),
                child: const Text('View receipt'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            key: const Key('activation_help_reg_id_field'),
            controller: _regIdCtrl,
            decoration: InputDecoration(
              labelText: 'Registration ID (UUID) *',
              hintText: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
              helperText:
                  'Obtained from the registration receipt (opaque UUID; user_id and email are never accepted).',
              errorText: _fieldError,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('reissue_activation_button'),
                onPressed: (_submitting || blocked) ? null : _runReissue,
                icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                label: Text(
                  blocked
                      ? 'Wait ${_retryAfterRemaining}s'
                      : (_submitting
                          ? 'Working…'
                          : 'Reissue OTP activation code'),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('recover_password_setup_button'),
                onPressed: (_submitting || blocked) ? null : _runRecovery,
                icon: const Icon(Icons.lock_reset_rounded, size: 18),
                label: Text(
                  blocked
                      ? 'Wait ${_retryAfterRemaining}s'
                      : 'Recover password setup',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Administrator Recovery Matrix',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          const _RecoveryMatrixRow(
            situation: 'Pending activation — expired or missed 6-digit OTP',
            endpoint: 'Reissue OTP activation code',
            rule:
                'Valid while pending_activation and before registration expiry. Replaces earlier OTP code (60s cooldown between reissues).',
          ),
          const _RecoveryMatrixRow(
            situation: 'Pending registration passed expires_at before verification',
            endpoint: 'Expired reclaim flow (Account registration tab)',
            rule:
                'Reissue returns 409 REISSUE_NOT_ALLOWED; submit an explicit reclaim request instead.',
          ),
          const _RecoveryMatrixRow(
            situation: 'OTP verified, setup_grant lost before password set',
            endpoint: 'Recover password setup',
            rule:
                'Revokes the unconsumed setup grant and sends a fresh 6-digit OTP code. Fails with 409 if account is already active.',
          ),
          const _RecoveryMatrixRow(
            situation: 'Active user forgot password later',
            endpoint: 'Self-service password reset',
            rule:
                'Security Guards use "Forgot password?" on the sign-in screen. Students, Faculty, and Staff must use the SENTRY Mobile Application.',
          ),
        ],
      ),
    );
  }
}

class _RecoveryMatrixRow extends StatelessWidget {
  final String situation;
  final String endpoint;
  final String rule;

  const _RecoveryMatrixRow({
    required this.situation,
    required this.endpoint,
    required this.rule,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                situation,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              StatusPill(label: endpoint, tone: PillTone.info),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            rule,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
