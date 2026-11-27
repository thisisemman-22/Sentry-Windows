import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/auth_models.dart';
import '../../../shared/models/participant_models.dart';
import '../../../shared/models/spec_2026_models.dart';
import '../../administration/presentation/administration_screen.dart';
import '../../administration/state/register_form_controller.dart';

/// Section 3 & 5: `Users` (Administrator Only)
/// - Sub-tab 0: Directory with Role/Status filters, General Password control
///   (masked + audited Show/Change), quick Reset Password (enforcing second-Admin
///   rule `targetUserId != currentAdminId`), and full User Detail sheet
///   (Edit, Suspend/Reactivate, Vehicles + inline Add Vehicle, RFID, Face, Recent visits).
/// - Sub-tab 1: Register User Unified Form (Student/Faculty/Staff/Guard/Admin,
///   car/motorcycle rules, RA 10173 consent + General First-Login Password assignment).
/// - Sub-tab 2: Desktop-Only Face Enrollment (`not_enrolled | enrolled | withdrawn`,
///   RA 10173 consent, webcam/upload, enrollment history, zero stored images).
/// - Sub-tab 3: Phase 4 OTP Onboarding & Activation Help.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _search = '';
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  bool _confirmGeneralPwd = true;
  String? _selectedFaceUserCode;
  String? _lastPhase4ReceiptId;

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final authState = ref.watch(authControllerProvider);
    final profile = authState.profile;
    if (profile == null || !profile.role.isAdmin) {
      return const RoleRestrictedPanel(
        featureName: 'Users & Biometric Enrollment',
      );
    }

    final subTab = ref.watch(usersSubTabProvider);
    final sysState = ref.watch(sentryScenarioProvider);
    final opsState = ref.watch(desktopOpsControllerProvider);

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Users',
          subtitle:
              'Search accounts, reset forgotten passwords, register members, and manage RA 10173 face enrollment.',
          actions: [
            SegmentTabs(
              keyPrefix: 'users_subtab',
              labels: const [
                'Directory',
                'Register User',
                'Face Enrollment',
                'OTP & Activation',
              ],
              icons: const [
                Icons.people_outline_rounded,
                Icons.person_add_alt_1_outlined,
                Icons.face_retouching_natural_outlined,
                Icons.support_agent_rounded,
              ],
              selected: subTab,
              onChanged: (i) =>
                  ref.read(usersSubTabProvider.notifier).state = i,
            ),
          ],
        ),
        const SizedBox(height: 20),

        SmoothSwitcher(
          switchKey: subTab,
          child: switch (subTab) {
            0 => _buildDirectoryTab(context, p, profile, sysState, opsState),
            1 => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SentryCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: CheckboxListTile(
                        key: const Key('confirm_general_password_checkbox'),
                        value: _confirmGeneralPwd,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Assign current General First-Login Password on save (24h expiry, forced change on first sign-in)',
                        ),
                        onChanged: (v) =>
                            setState(() => _confirmGeneralPwd = v == true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AdministrationScreen(
                    embeddedSubTab: 3,
                    onProceedToFacialEnrollmentWithCode: (code) {
                      setState(() => _selectedFaceUserCode = code);
                      ref.read(usersSubTabProvider.notifier).state = 2;
                    },
                    onOpenFaceEnrollmentTab: () =>
                        ref.read(usersSubTabProvider.notifier).state = 2,
                    onOpenActivationHelpTab: () =>
                        ref.read(usersSubTabProvider.notifier).state = 3,
                    onOpenPhase4Tab: () =>
                        ref.read(usersSubTabProvider.notifier).state = 3,
                  ),
                ],
              ),
            2 => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdministrationScreen(
                    embeddedSubTab: 2,
                    initialEnrollmentUserCode: _selectedFaceUserCode,
                    onOpenFaceEnrollmentTab: () =>
                        ref.read(usersSubTabProvider.notifier).state = 2,
                  ),
                  if (opsState.faceHistory.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _FaceHistoryCard(history: opsState.faceHistory),
                  ],
                ],
              ),
            _ => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdministrationScreen(
                    embeddedSubTab: 0,
                    onPhase4ReceiptRecorded: (regId) {
                      setState(() => _lastPhase4ReceiptId = regId);
                    },
                    onOpenActivationHelpTab: () {
                      ref
                          .read(registerFormControllerProvider.notifier)
                          .setFlow(AdminRegistrationFlow.reclaimStudentOrGuard);
                    },
                  ),
                  const SizedBox(height: 18),
                  AdministrationScreen(
                    embeddedSubTab: 1,
                    externalPhase4ReceiptId: _lastPhase4ReceiptId,
                    onOpenPhase4Tab: () {},
                  ),
                ],
              ),
          },
        ),
      ],
    );
  }

  Widget _buildDirectoryTab(
    BuildContext context,
    SentryPalette p,
    ProfileDto actor,
    dynamic sysState,
    dynamic opsState,
  ) {
    final opsCtrl = ref.read(desktopOpsControllerProvider.notifier);
    final dir = (sysState.participantDirectory as List<ParticipantUserDto>);

    // Build combined directory (participants + operator accounts A001/G001 for visibility & second-Admin rule checks).
    final allRows = <ParticipantUserDto>[
      ...dir,
      if (ref.read(appConfigProvider).isMock)
        ParticipantUserDto(
          userId: actor.userId,
          userCode: actor.userCode,
          fullName: actor.fullName,
          email: actor.email ?? actor.username,
          roleCode: actor.role.wireValue,
          status: 'active',
          faceTemplateId: '',
          faceEnrolled: false,
          vehicles: const [],
        ),
    ];

    final filtered = allRows.where((u) {
      final effectiveStatus = opsCtrl.userStatusFor(u);
      if (_roleFilter != 'all' && u.roleCode != _roleFilter) return false;
      if (_statusFilter != 'all' && effectiveStatus != _statusFilter) {
        return false;
      }
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toUpperCase();
        if (!u.fullName.toUpperCase().contains(q) &&
            !u.userCode.toUpperCase().contains(q) &&
            !u.email.toUpperCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    final GeneralPasswordConfigDto? gp = opsState.generalPassword;
    final revealed = gp?.revealedValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // General Password Control Bar
        SentryCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.crimsonTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.key_outlined,
                      size: 18,
                      color: p.crimson,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'General First-Login Password',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        revealed ?? gp?.maskedValue ?? '••••••••••••',
                        key: const Key('general_password_display_text'),
                        style: SentryTheme.mono(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: revealed != null ? p.crimson : p.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const InfoHint(
                    'Temporary password assigned on account creation or reset (24h expiry). Showing clears on hide.',
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('general_password_show_btn'),
                    onPressed: () async {
                      if (revealed != null) {
                        opsCtrl.hideGeneralPassword();
                      } else {
                        await opsCtrl.revealGeneralPassword(actor: actor);
                      }
                    },
                    icon: Icon(
                      revealed != null
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                    ),
                    label: Text(revealed != null ? 'Hide' : 'Show'),
                  ),
                  FilledButton(
                    key: const Key('general_password_change_btn'),
                    onPressed: () => _openChangeGeneralPasswordDialog(actor),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Directory Card
        SentryCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      key: const Key('users_search_field'),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, size: 19),
                        hintText: 'Search name, university ID, email…',
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      key: const Key('users_role_filter'),
                      initialValue: _roleFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All roles')),
                        DropdownMenuItem(value: 'student', child: Text('Student')),
                        DropdownMenuItem(value: 'faculty', child: Text('Faculty')),
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                        DropdownMenuItem(value: 'guard', child: Text('Guard')),
                        DropdownMenuItem(
                            value: 'administrator', child: Text('Administrator')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _roleFilter = v);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      key: const Key('users_status_filter'),
                      initialValue: _statusFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All statuses')),
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'suspended', child: Text('Suspended')),
                        DropdownMenuItem(
                            value: 'first_login_required',
                            child: Text('First login required')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _statusFilter = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                const EmptyState(
                  showBrandLogo: true,
                  icon: Icons.people_outline_rounded,
                  title: 'No registered users loaded',
                  message:
                      'User accounts appear here once synced with FastAPI.',
                )
              else
                for (var i = 0; i < filtered.length; i++) ...[
                  if (i > 0) Divider(color: p.line, height: 1),
                  Builder(builder: (context) {
                    final u = filtered[i];
                    final status = opsCtrl.userStatusFor(u);
                    final isSelf = u.userId == actor.userId;
                    return SentryRowTile(
                      key: Key('user_row_${u.userCode}'),
                      leading: MonogramAvatar(
                        name: u.fullName,
                        highlight: u.roleCode == 'administrator',
                      ),
                      title: u.fullName,
                      subtitle: '${u.roleCode} · ${u.email}',
                      badges: [
                        StatusPill(
                          label: u.userCode,
                          tone: PillTone.neutral,
                          monospace: true,
                        ),
                        StatusPill(
                          label: status == 'first_login_required'
                              ? 'First login required'
                              : status,
                          tone: status == 'active'
                              ? PillTone.ok
                              : status == 'suspended'
                                  ? PillTone.err
                                  : PillTone.warn,
                        ),
                      ],
                      actions: [
                        Tooltip(
                          message: isSelf
                              ? 'A second Administrator must reset another Admin account'
                              : 'Reset forgotten password to General Password',
                          child: OutlinedButton(
                            key: Key('reset_user_pwd_${u.userCode}'),
                            onPressed: isSelf
                                ? null
                                : () => _confirmResetPassword(
                                      context,
                                      actor,
                                      u,
                                    ),
                            child: const Text('Reset Password'),
                          ),
                        ),
                      ],
                      onTap: () => _openUserDetailSheet(context, actor, u),
                    );
                  }),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmResetPassword(
    BuildContext context,
    ProfileDto actor,
    ParticipantUserDto user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset password for ${user.userCode}?'),
        content: const Text(
          'Reset to the general password? Active sessions will be signed out.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_reset_to_general_pwd_btn'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset password'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final res = await ref
        .read(desktopOpsControllerProvider.notifier)
        .resetUserPasswordToGeneral(
          targetUserId: user.userId,
          targetUserCode: user.userCode,
          actor: actor,
        );
    if (!context.mounted) return;
    showSentryToast(
      context,
      res.ok
          ? 'Reset ${user.userCode} to General Password (sessions signed out).'
          : (res.error?.message ?? 'Reset failed.'),
      tone: res.ok ? PillTone.ok : PillTone.err,
    );
  }

  void _openChangeGeneralPasswordDialog(ProfileDto actor) {
    final ctrl = TextEditingController();
    String? err;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Change General First-Login Password'),
          content: SizedBox(
            width: 420,
            child: TextField(
              key: const Key('general_password_new_field'),
              controller: ctrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New General Password (min 12 chars)',
                errorText: err,
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('general_password_save_btn'),
              onPressed: () async {
                final res = await ref
                    .read(desktopOpsControllerProvider.notifier)
                    .changeGeneralPassword(
                      newPassword: ctrl.text,
                      actor: actor,
                    );
                if (!ctx.mounted) return;
                if (!res.ok) {
                  setModalState(() => err = res.error?.message);
                  return;
                }
                Navigator.of(ctx).pop();
                if (mounted) {
                  showSentryToast(
                    this.context,
                    'Updated General First-Login Password (audited).',
                    tone: PillTone.ok,
                  );
                }
              },
              child: const Text('Confirm change'),
            ),
          ],
        ),
      ),
    );
  }

  void _openUserDetailSheet(
    BuildContext context,
    ProfileDto actor,
    ParticipantUserDto user,
  ) {
    showDetailsSheet<void>(
      context,
      frosted: true,
      title: '${user.fullName} · ${user.userCode}',
      subtitle: '${user.email} · ${user.roleCode}',
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final sys = ref.watch(sentryScenarioProvider);
          final ops = ref.watch(desktopOpsControllerProvider);
          final opsCtrl = ref.read(desktopOpsControllerProvider.notifier);
          final freshUser = sys.participantDirectory
                  .where((u) => u.userCode == user.userCode)
                  .firstOrNull ??
              user;
          final status = opsCtrl.userStatusFor(freshUser);
          final isSuspended = status == 'suspended';
          final tags = ops.rfidTags
              .where((t) => t.assignedUserCode == freshUser.userCode)
              .toList();
          final recentVisits = sys.visits
              .where((v) => v.userCode == freshUser.userCode)
              .take(5)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    label: status,
                    tone: status == 'active'
                        ? PillTone.ok
                        : status == 'suspended'
                            ? PillTone.err
                            : PillTone.warn,
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openEditUserDialog(actor, freshUser),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                  if (freshUser.userId != actor.userId)
                    OutlinedButton(
                      key: Key('toggle_user_suspend_${freshUser.userCode}'),
                      onPressed: () {
                        opsCtrl.setUserSuspended(
                          userCode: freshUser.userCode,
                          suspend: !isSuspended,
                          actor: actor,
                        );
                      },
                      child: Text(isSuspended ? 'Reactivate' : 'Suspend'),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SectionHeader(
                title: 'Vehicles (${freshUser.vehicles.length})',
                trailing: OutlinedButton.icon(
                  key: const Key('user_detail_add_vehicle_btn'),
                  onPressed: () => _openQuickAddVehicle(actor, freshUser),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Vehicle'),
                ),
              ),
              const SizedBox(height: 8),
              if (freshUser.vehicles.isEmpty)
                Text('No registered vehicles.',
                    style: Theme.of(context).textTheme.bodySmall)
              else
                for (final v in freshUser.vehicles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        PlateBadge(
                          plateText: v.plateNumberDisplay,
                          rfidUid: v.rfidUid,
                          isCompact: true,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${v.vehicleCode} · ${v.vehicleType}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        StatusPill(
                          label: v.approvalStatus,
                          tone: v.isGateEligible ? PillTone.ok : PillTone.warn,
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'RFID Tags & Face Enrollment'),
              const SizedBox(height: 8),
              KeyValueRow(
                label: 'Face Enrollment',
                value: freshUser.faceEnrolled ? 'enrolled' : 'not_enrolled',
                mono: true,
              ),
              KeyValueRow(
                label: 'RFID Tags',
                value: tags.isEmpty
                    ? 'None assigned'
                    : tags.map((t) => '${t.rfidUid} (${t.status})').join(', '),
                mono: true,
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Recent Entries & Exits'),
              const SizedBox(height: 8),
              if (recentVisits.isEmpty)
                Text('No recorded campus stays yet.',
                    style: Theme.of(context).textTheme.bodySmall)
              else
                for (final v in recentVisits)
                  KeyValueRow(
                    label: '${v.vehicleCode} · ${v.spaceCode ?? '—'}',
                    value: v.isActive
                        ? 'Inside · ${ManilaTime.formatTimeOnly(v.enteredAtUtc)}'
                        : 'Exited · ${ManilaTime.formatTimeOnly(v.exitedAtUtc)}',
                    mono: true,
                  ),
            ],
          );
        },
      ),
    );
  }

  void _openEditUserDialog(ProfileDto actor, ParticipantUserDto user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    String role = user.roleCode;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Edit ${user.userCode}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'faculty', child: Text('Faculty')),
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(value: 'guard', child: Text('Guard')),
                    DropdownMenuItem(
                        value: 'administrator', child: Text('Administrator')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => role = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(sentryScenarioProvider.notifier)
                    .updateParticipantProfile(
                      actor: actor,
                      userCode: user.userCode,
                      fullName: nameCtrl.text,
                      roleCode: role,
                    );
                Navigator.of(ctx).pop();
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _openQuickAddVehicle(ProfileDto actor, ParticipantUserDto user) {
    final plateCtrl = TextEditingController();
    final rfidCtrl = TextEditingController();
    String vType = 'car';
    String? err;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Add approved vehicle to ${user.userCode}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: vType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Vehicle type'),
                  items: const [
                    DropdownMenuItem(value: 'car', child: Text('Car')),
                    DropdownMenuItem(
                        value: 'motorcycle', child: Text('Motorcycle')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => vType = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: plateCtrl,
                  decoration: InputDecoration(
                    labelText: vType == 'car'
                        ? 'Plate number *'
                        : 'Plate number (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rfidCtrl,
                  decoration: InputDecoration(
                    labelText: vType == 'motorcycle'
                        ? 'RFID Tag UID * (required for motorcycle)'
                        : 'RFID Tag UID (optional)',
                  ),
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err!, style: const TextStyle(color: SentryColors.crimson)),
                ],
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (vType == 'car' && plateCtrl.text.trim().isEmpty) {
                  setModalState(() => err = 'Plate number is required for cars.');
                  return;
                }
                if (vType == 'motorcycle' && rfidCtrl.text.trim().isEmpty) {
                  setModalState(
                      () => err = 'RFID Tag UID is required for motorcycles.');
                  return;
                }
                final count = user.vehicles.length + 10;
                ref
                    .read(sentryScenarioProvider.notifier)
                    .registerParticipantVehicle(
                      actor: actor,
                      userCode: user.userCode,
                      vehicleCode: 'V${count.toString().padLeft(3, '0')}',
                      vehicleType: vType,
                      plateDisplay: plateCtrl.text.trim().isEmpty
                          ? null
                          : plateCtrl.text.trim().toUpperCase(),
                      rfidUid: rfidCtrl.text.trim().isEmpty
                          ? null
                          : rfidCtrl.text.trim().toUpperCase(),
                    );
                Navigator.of(ctx).pop();
              },
              child: const Text('Approve & save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceHistoryCard extends StatelessWidget {
  final List<FaceEnrollmentHistoryEntry> history;
  const _FaceHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return SentryCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Enrollment history (metadata only)',
            subtitle:
                'Raw face images are never stored or previewed on Admin workstations.',
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < history.length; i++) ...[
            if (i > 0) Divider(color: p.line, height: 18),
            Row(
              children: [
                StatusPill(
                  label: history[i].action,
                  tone: history[i].action == 'withdrawn'
                      ? PillTone.err
                      : PillTone.info,
                  monospace: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${history[i].userCode} · ${history[i].consentVersion}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${history[i].actorUserCode} · ${ManilaTime.formatShort(history[i].occurredAtUtc)}',
                  style: SentryTheme.mono(fontSize: 12, color: p.muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
