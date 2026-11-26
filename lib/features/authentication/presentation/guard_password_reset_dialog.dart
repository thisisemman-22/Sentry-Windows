import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/phase4_contract.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/auth_models.dart';

/// Signed-out Security Guard Forgot Password modal (`D-06`).
/// Step 1: `POST /api/v1/auth/password-reset/request` (always neutral `202`, >=3s padded)
/// Step 2: `POST /api/v1/auth/password-reset/verify` (6-digit OTP -> single-use grant in memory)
/// Step 3: `POST /api/v1/auth/password-reset/complete` (12–1024 chars -> `200`, revokes all sessions)
Future<void> showGuardPasswordResetDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _GuardPasswordResetDialog(),
  );
}

class _GuardPasswordResetDialog extends ConsumerStatefulWidget {
  const _GuardPasswordResetDialog();

  @override
  ConsumerState<_GuardPasswordResetDialog> createState() =>
      _GuardPasswordResetDialogState();
}

class _GuardPasswordResetDialogState
    extends ConsumerState<_GuardPasswordResetDialog> {
  final _identifierCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  int _step = 0; // 0 = request, 1 = verify OTP, 2 = complete password
  String? _inMemoryResetGrant;
  DateTime? _grantExpiresAtUtc;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _neutralNotice;
  String? _errorText;
  String? _requestId;
  int _retryAfterRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _inMemoryResetGrant = null;
    _cooldownTimer?.cancel();
    _identifierCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
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

  Future<void> _submitStep1Request() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty || identifier.length > 128) {
      setState(() => _errorText = 'Enter your University ID (1–128 chars).');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
      _requestId = null;
    });

    final isMock = ref.read(appConfigProvider).isMock;
    if (!isMock) {
      final res = await ref.read(authRepositoryProvider).requestPasswordReset(
            PasswordResetRequest(identifier: identifier),
          );
      if (!mounted) return;
      if (!res.ok) {
        final err = res.error;
        if (err?.httpStatus == 429 && (err?.retryAfterSeconds ?? 0) > 0) {
          _startCooldown(err!.retryAfterSeconds!);
        }
        setState(() {
          _submitting = false;
          _errorText = err != null
              ? Phase4ApiFailure.fromError(err, requestId: res.meta.requestId)
                  .userDisplayMessage
              : 'Service unavailable. Retry manually within allowed budgets.';
          _requestId = res.meta.requestId;
        });
        return;
      }
    }

    setState(() {
      _submitting = false;
      _neutralNotice =
          'Request accepted. If an eligible Security Guard account with a verified email matches, a 6-digit code was sent (60s cooldown between codes).';
      _step = 1;
    });
  }

  Future<void> _submitStep2Verify() async {
    final otp = _otpCtrl.text.trim();
    if (!isValidOtpCode(otp)) {
      setState(() => _errorText = 'Enter the 6-digit numeric reset code.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
      _requestId = null;
    });

    final isMock = ref.read(appConfigProvider).isMock;
    if (!isMock) {
      final res = await ref.read(authRepositoryProvider).verifyPasswordReset(
            PasswordResetVerifyRequest(
              identifier: _identifierCtrl.text.trim(),
              otpCode: otp,
            ),
          );
      if (!mounted) return;
      if (!res.ok || res.data == null) {
        final err = res.error;
        if (err?.httpStatus == 429 && (err?.retryAfterSeconds ?? 0) > 0) {
          _startCooldown(err!.retryAfterSeconds!);
        }
        setState(() {
          _submitting = false;
          _errorText = err != null
              ? Phase4ApiFailure.fromError(err, requestId: res.meta.requestId)
                  .userDisplayMessage
              : 'Service unavailable. You may resubmit the same code at most once by hand.';
          _requestId = res.meta.requestId;
        });
        return;
      }
      _otpCtrl.clear();
      setState(() {
        _submitting = false;
        _inMemoryResetGrant = res.data!.resetGrant;
        _grantExpiresAtUtc = res.data!.expiresAtUtc;
        _step = 2;
      });
      return;
    }

    _otpCtrl.clear();
    setState(() {
      _submitting = false;
      _inMemoryResetGrant = 'MOCK-RESET-GRANT-IN-MEMORY';
      _grantExpiresAtUtc =
          DateTime.now().toUtc().add(const Duration(minutes: 5));
      _step = 2;
    });
  }

  Future<void> _submitStep3Complete() async {
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;
    final policyErr = validatePasswordPolicy(newPass);
    if (policyErr != null) {
      setState(() => _errorText = policyErr);
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorText = 'Passwords do not match.');
      return;
    }
    final grant = _inMemoryResetGrant;
    if (grant == null) {
      setState(() {
        _step = 0;
        _errorText = 'Reset grant cleared. Please request a new reset code.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
      _requestId = null;
    });

    final isMock = ref.read(appConfigProvider).isMock;
    if (!isMock) {
      final res = await ref.read(authRepositoryProvider).completePasswordReset(
            PasswordResetCompleteRequest(
              identifier: _identifierCtrl.text.trim(),
              resetGrant: grant,
              newPassword: newPass,
            ),
          );
      if (!mounted) return;
      if (!res.ok) {
        final err = res.error;
        if (err?.httpStatus == 429 && (err?.retryAfterSeconds ?? 0) > 0) {
          _startCooldown(err!.retryAfterSeconds!);
        }
        setState(() {
          _submitting = false;
          _errorText = err != null
              ? Phase4ApiFailure.fromError(err, requestId: res.meta.requestId)
                  .userDisplayMessage
              : 'Outcome unknown. Try signing in with your new password before restarting.';
          _requestId = res.meta.requestId;
        });
        return;
      }
    }

    _inMemoryResetGrant = null;
    _newPassCtrl.clear();
    _confirmPassCtrl.clear();
    if (!mounted) return;
    ref.read(authControllerProvider.notifier).setLoginInfoBanner(
          'Password reset complete. Every active session was signed out; please sign in.',
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isBlockedByCooldown = _retryAfterRemaining > 0;
    return AlertDialog(
      title: const Text('Forgot password'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Callout(
                tone: PillTone.info,
                icon: Icons.lock_reset_rounded,
                title: 'Security Guards only',
                message:
                    'Password reset is available only to Security Guard accounts with a verified email. Administrators do not reset passwords here.',
              ),
              if (_neutralNotice != null) ...[
                const SizedBox(height: 12),
                Callout(
                  tone: PillTone.ok,
                  icon: Icons.mark_email_read_outlined,
                  title: 'Request submitted',
                  message: _neutralNotice!,
                ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Callout(
                  tone: PillTone.err,
                  icon: Icons.error_outline_rounded,
                  title: _requestId != null
                      ? 'Password reset notice (Request ID: $_requestId)'
                      : 'Password reset notice',
                  message: _errorText!,
                ),
              ],
              const SizedBox(height: 14),
              if (_step == 0)
                TextField(
                  key: const Key('reset_identifier_field'),
                  controller: _identifierCtrl,
                  decoration: const InputDecoration(
                    labelText: 'University ID',
                    hintText: 'Assigned guard identifier',
                  ),
                )
              else if (_step == 1) ...[
                TextField(
                  key: const Key('reset_otp_field'),
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-digit reset code',
                    hintText: '012345',
                    counterText: '',
                  ),
                ),
              ] else ...[
                if (_grantExpiresAtUtc != null) ...[
                  Text(
                    'Reset grant expires at ${ManilaTime.formatDateTime(_grantExpiresAtUtc)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  key: const Key('reset_new_password_field'),
                  controller: _newPassCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New password *',
                    helperText:
                        '12–1024 characters (<=4096 UTF-8 bytes). Spaces count; no trimming.',
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('reset_confirm_password_field'),
                  controller: _confirmPassCtrl,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password *',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('reset_submit_button'),
          onPressed: (_submitting || isBlockedByCooldown)
              ? null
              : switch (_step) {
                  0 => _submitStep1Request,
                  1 => _submitStep2Verify,
                  _ => _submitStep3Complete,
                },
          child: Text(
            isBlockedByCooldown
                ? 'Wait ${_retryAfterRemaining}s'
                : _submitting
                    ? 'Submitting…'
                    : switch (_step) {
                        0 => 'Request reset code',
                        1 => 'Verify code',
                        _ => 'Set new password',
                      },
          ),
        ),
      ],
    );
  }
}
