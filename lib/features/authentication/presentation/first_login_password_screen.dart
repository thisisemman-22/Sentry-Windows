import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/sentry_interactive_logo.dart';
import '../../../core/widgets/ui/sentry_ui.dart';

/// Forced First-Login Password Change screen (`first_login_required: true`).
/// Blocks access to [DesktopShell] until the operator sets and confirms a new
/// personal password matching policy (`12–1024` code points, exact double entry).
class FirstLoginPasswordScreen extends ConsumerStatefulWidget {
  const FirstLoginPasswordScreen({super.key});

  @override
  ConsumerState<FirstLoginPasswordScreen> createState() =>
      _FirstLoginPasswordScreenState();
}

class _FirstLoginPasswordScreenState
    extends ConsumerState<FirstLoginPasswordScreen> {
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final res = await ref
        .read(authControllerProvider.notifier)
        .completeFirstLoginPassword(
          newPassword: _newPwdCtrl.text,
          confirmPassword: _confirmPwdCtrl.text,
        );
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _isSubmitting = false;
        _errorText = res.error?.message ?? 'Unable to update password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final profile = ref.watch(authControllerProvider).profile;

    final newPwd = _newPwdCtrl.text;
    final confirmPwd = _confirmPwdCtrl.text;
    final meetsLen = newPwd.runes.length >= 12;
    final matches = newPwd.isNotEmpty && newPwd == confirmPwd;

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.7),
                    radius: 1.0,
                    colors: [
                      SentryColors.crimson
                          .withValues(alpha: p.isDark ? 0.14 : 0.06),
                      p.bg.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SentryCard(
                  padding: const EdgeInsets.all(32),
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.crimsonTint,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const SentryInteractiveLogo(size: 34),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Set your personal password',
                                  style: SentryTheme.display(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: p.text,
                                  ),
                                ),
                                if (profile != null)
                                  Text(
                                    '${profile.fullName} · ${profile.role.isAdmin ? 'Administrator' : 'Guard'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: p.muted),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Replace the temporary password with your own before continuing.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: p.slate,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          StatusPill(
                            label: '12+ characters',
                            tone: meetsLen ? PillTone.ok : PillTone.neutral,
                          ),
                          StatusPill(
                            label: 'Passwords match',
                            tone: matches ? PillTone.ok : PillTone.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_errorText != null) ...[
                        Callout(
                          key: const Key('first_login_error_banner'),
                          tone: PillTone.err,
                          icon: Icons.error_outline_rounded,
                          title: 'Cannot save password',
                          message: _errorText!,
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'New password',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('first_login_new_password_field'),
                        controller: _newPwdCtrl,
                        obscureText: _obscureNew,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline_rounded,
                              size: 19),
                          hintText: 'Minimum 12 characters',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Confirm new password',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('first_login_confirm_password_field'),
                        controller: _confirmPwdCtrl,
                        obscureText: _obscureConfirm,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _isSubmitting ? null : _submit(),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.verified_user_outlined,
                              size: 19),
                          hintText: 'Re-enter new password',
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 46,
                        child: FilledButton(
                          key: const Key('first_login_submit_button'),
                          onPressed: _isSubmitting ? null : _submit,
                          child: Text(
                            _isSubmitting
                                ? 'Updating password…'
                                : 'Save password & continue',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        key: const Key('first_login_logout_button'),
                        onPressed: _isSubmitting
                            ? null
                            : () => ref
                                .read(authControllerProvider.notifier)
                                .signOut(),
                        child: const Text('Cancel & sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
