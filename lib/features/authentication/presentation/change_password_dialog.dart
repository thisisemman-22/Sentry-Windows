import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/phase4_contract.dart';
import '../../../core/widgets/ui/sentry_ui.dart';

/// Opens the Own Profile modal displaying all 7 canonical `ProfileData` fields.
Future<void> showOwnProfileDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final profile = ref.watch(authControllerProvider).profile;
        if (profile == null) return const SizedBox.shrink();
        return AlertDialog(
          title: const Text('Account profile'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KeyValueRow(
                    label: 'Display code',
                    value: profile.userCode,
                    mono: true,
                  ),
                  KeyValueRow(label: 'Full name', value: profile.fullName),
                  KeyValueRow(
                    label: 'Role',
                    value: profile.role.wireValue,
                    mono: true,
                  ),
                  KeyValueRow(
                    label: 'Email',
                    value: profile.email ?? profile.username,
                  ),
                  KeyValueRow(
                    label: 'Building',
                    value: profile.building != null
                        ? '${profile.building!.code} · ${profile.building!.name}'
                        : 'Unassigned (${profile.assignedStation})',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Authorized vehicles (${profile.authorizedVehicles.length}/20)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  if (profile.authorizedVehicles.isEmpty)
                    Text(
                      'No authorized vehicles attached to this account.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    for (final v in profile.authorizedVehicles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${v.displayCode} (${v.vehicleType}) · Plate: ${v.normalizedPlate ?? 'None'}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              key: const Key('profile_change_password_button'),
              onPressed: () {
                Navigator.of(ctx).pop();
                showChangePasswordDialog(context);
              },
              icon: const Icon(Icons.password_rounded, size: 17),
              label: const Text('Change password'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
}

/// Authenticated password change modal (`POST /api/v1/auth/password/change`).
/// Available to BOTH signed-in Security Guards and Administrators.
Future<void> showChangePasswordDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _currentFieldError;
  String? _newFieldError;
  String? _generalError;
  String? _requestId;
  int _retryAfterRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
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

  Future<void> _submit() async {
    final currentPwd = _currentCtrl.text;
    final newPwd = _newCtrl.text;
    final confirmPwd = _confirmCtrl.text;

    if (currentPwd.isEmpty) {
      setState(() => _currentFieldError = 'Enter your current password.');
      return;
    }
    final policyErr = validatePasswordPolicy(newPwd);
    if (policyErr != null) {
      setState(() {
        _currentFieldError = null;
        _newFieldError = policyErr;
      });
      return;
    }
    if (newPwd != confirmPwd) {
      setState(() {
        _currentFieldError = null;
        _newFieldError = 'New password confirmation does not match.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _currentFieldError = null;
      _newFieldError = null;
      _generalError = null;
      _requestId = null;
    });

    final res = await ref.read(authControllerProvider.notifier).changePassword(
          currentPassword: currentPwd,
          newPassword: newPwd,
        );
    if (!mounted) return;

    if (res.ok) {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      Navigator.of(context).pop();
      return;
    }

    final err = res.error;
    if (err == null) {
      setState(() {
        _submitting = false;
        _generalError =
            '503 SERVICE_UNAVAILABLE: Outcome unknown — do not replay. Try signing in with the new password first.';
        _requestId = res.meta.requestId;
      });
      return;
    }

    if (err.code == ErrorCatalog.passwordChangeConflict) {
      Navigator.of(context).pop();
      return;
    }

    if (err.httpStatus == 429 && (err.retryAfterSeconds ?? 0) > 0) {
      _startCooldown(err.retryAfterSeconds!);
    }

    final failure = Phase4ApiFailure.fromError(
      err,
      requestId: res.meta.requestId,
    );

    setState(() {
      _submitting = false;
      _requestId = res.meta.requestId;
      if (err.code == ErrorCatalog.currentPasswordInvalid) {
        _currentFieldError = failure.userDisplayMessage;
      } else if (err.code == ErrorCatalog.passwordPolicyRejected) {
        _newFieldError = failure.userDisplayMessage;
      } else {
        _generalError = failure.userDisplayMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _retryAfterRemaining > 0;
    return AlertDialog(
      title: const Text('Change password'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Callout(
                tone: PillTone.warn,
                icon: Icons.info_outline_rounded,
                title: 'All sessions will sign out',
                message:
                    'Changing your password revokes every active session on all devices. You will need to sign in again.',
              ),
              if (_generalError != null) ...[
                const SizedBox(height: 12),
                Callout(
                  tone: PillTone.err,
                  icon: Icons.error_outline_rounded,
                  title: _requestId != null
                      ? 'Password change notice (Request ID: $_requestId)'
                      : 'Password change notice',
                  message: _generalError!,
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                key: const Key('change_pwd_current_field'),
                controller: _currentCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Current password *',
                  errorText: _currentFieldError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('change_pwd_new_field'),
                controller: _newCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'New password *',
                  helperText:
                      '12–1024 Unicode code points, <=4096 UTF-8 bytes, no composition rules, spaces preserved (never trimmed).',
                  helperMaxLines: 2,
                  errorText: _newFieldError,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('change_pwd_confirm_field'),
                controller: _confirmCtrl,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password *',
                ),
              ),
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
          key: const Key('change_pwd_submit_button'),
          onPressed: (_submitting || blocked) ? null : _submit,
          child: Text(
            blocked
                ? 'Wait ${_retryAfterRemaining}s'
                : (_submitting ? 'Updating…' : 'Update password'),
          ),
        ),
      ],
    );
  }
}
