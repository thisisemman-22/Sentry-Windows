import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/phase4_contract.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/auth_models.dart';

/// Opens the signed-out Security Guard First-Time Activation modal (`D-07`).
/// Step 1: University ID + 6-digit OTP -> `POST /api/v1/auth/activation/verify`
/// Step 2: New password (12–1024 chars, never trimmed) -> `POST /api/v1/auth/activation/password`
Future<void> showGuardActivationDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _GuardActivationDialog(),
  );
}

class _GuardActivationDialog extends ConsumerStatefulWidget {
  const _GuardActivationDialog();

  @override
  ConsumerState<_GuardActivationDialog> createState() =>
      _GuardActivationDialogState();
}

class _GuardActivationDialogState
    extends ConsumerState<_GuardActivationDialog> {
  final _identifierCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  int _step = 0; // 0 = verify OTP, 1 = set first password
  String? _inMemorySetupGrant;
  DateTime? _grantExpiresAtUtc;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorText;
  String? _requestId;

  @override
  void dispose() {
    _inMemorySetupGrant = null;
    _identifierCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitStep1Verify() async {
    final identifier = _identifierCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    if (identifier.isEmpty || identifier.length > 128) {
      setState(() => _errorText = 'Enter your assigned University ID (1–128 chars).');
      return;
    }
    if (!isValidOtpCode(otp)) {
      setState(() => _errorText = 'Enter the 6-digit activation code from your email.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
      _requestId = null;
    });

    final isMock = ref.read(appConfigProvider).isMock;
    if (!isMock) {
      final res = await ref.read(authRepositoryProvider).verifyActivationCode(
            OtpVerificationRequest(identifier: identifier, otpCode: otp),
          );
      if (!mounted) return;
      if (!res.ok || res.data == null) {
        final err = res.error;
        final msg = (err?.code == ErrorCatalog.activationRejected ||
                err?.httpStatus == 400)
            ? 'Activation code invalid or expired. Please contact an administrator.'
            : (err != null
                ? Phase4ApiFailure.fromError(err, requestId: res.meta.requestId)
                    .userDisplayMessage
                : 'Service unavailable. Retry once by hand within 5 minutes.');
        setState(() {
          _submitting = false;
          _errorText = msg;
          _requestId = res.meta.requestId;
        });
        return;
      }
      _otpCtrl.clear();
      setState(() {
        _submitting = false;
        _inMemorySetupGrant = res.data!.setupGrant;
        _grantExpiresAtUtc = res.data!.expiresAtUtc;
        _step = 1;
      });
      return;
    }

    // Mock / Developer Test Mode behavior
    if (otp == '000000') {
      setState(() {
        _submitting = false;
        _errorText =
            'Activation code invalid or expired. Please contact an administrator.';
        _requestId = 'mock-activation-err-400';
      });
      return;
    }
    _otpCtrl.clear();
    setState(() {
      _submitting = false;
      _inMemorySetupGrant = 'MOCK-SETUP-GRANT-IN-MEMORY';
      _grantExpiresAtUtc = DateTime.now().toUtc().add(const Duration(minutes: 5));
      _step = 1;
    });
  }

  Future<void> _submitStep2Password() async {
    final newPass = _passwordCtrl.text;
    final confirmPass = _confirmCtrl.text;
    final policyErr = validatePasswordPolicy(newPass);
    if (policyErr != null) {
      setState(() => _errorText = policyErr);
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorText = 'Passwords do not match.');
      return;
    }
    final grant = _inMemorySetupGrant;
    if (grant == null) {
      setState(() {
        _step = 0;
        _errorText = 'Setup session lost; verify your activation code again.';
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
      final res = await ref.read(authRepositoryProvider).setActivationPassword(
            PasswordSetupRequest(
              identifier: _identifierCtrl.text.trim(),
              setupGrant: grant,
              password: newPass,
            ),
          );
      if (!mounted) return;
      if (!res.ok || res.data == null) {
        final err = res.error;
        final msg = err != null
            ? Phase4ApiFailure.fromError(err, requestId: res.meta.requestId)
                .userDisplayMessage
            : 'Outcome unknown. Try signing in first before retrying.';
        setState(() {
          _submitting = false;
          _errorText = msg;
          _requestId = res.meta.requestId;
        });
        return;
      }
    }

    _inMemorySetupGrant = null;
    _passwordCtrl.clear();
    _confirmCtrl.clear();
    if (!mounted) return;
    ref.read(authControllerProvider.notifier).setLoginInfoBanner(
          'Security Guard account activated. You can now sign in with your new password.',
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('First-time activation'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Callout(
                tone: PillTone.info,
                icon: Icons.shield_outlined,
                title: 'Security Guards only',
                message:
                    'Use the 6-digit activation code staged by an Administrator. No self-service resend is available.',
              ),
              const SizedBox(height: 14),
              if (_errorText != null) ...[
                Callout(
                  tone: PillTone.err,
                  icon: Icons.error_outline_rounded,
                  title: _requestId != null
                      ? 'Activation notice (Request ID: $_requestId)'
                      : 'Activation notice',
                  message: _errorText!,
                ),
                const SizedBox(height: 14),
              ],
              if (_step == 0) ...[
                TextField(
                  key: const Key('activation_identifier_field'),
                  controller: _identifierCtrl,
                  decoration: const InputDecoration(
                    labelText: 'University ID',
                    hintText: 'Assigned guard identifier',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('activation_otp_field'),
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-digit activation code',
                    hintText: '012345',
                    counterText: '',
                  ),
                ),
              ] else ...[
                if (_grantExpiresAtUtc != null) ...[
                  Text(
                    'Setup grant expires at ${ManilaTime.formatDateTime(_grantExpiresAtUtc)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  key: const Key('activation_new_password_field'),
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Choose password *',
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
                  key: const Key('activation_confirm_password_field'),
                  controller: _confirmCtrl,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password *',
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
          key: const Key('activation_submit_button'),
          onPressed: _submitting
              ? null
              : (_step == 0 ? _submitStep1Verify : _submitStep2Password),
          child: Text(_submitting
              ? 'Processing…'
              : (_step == 0 ? 'Verify code' : 'Activate account')),
        ),
      ],
    );
  }
}
