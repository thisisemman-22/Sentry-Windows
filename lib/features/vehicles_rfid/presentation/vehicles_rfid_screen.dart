import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/auth_models.dart';
import '../../../shared/models/participant_models.dart';
import '../../../shared/models/spec_2026_models.dart';

/// Section 4: `Vehicles & RFID` (Administrator Only)
/// - Sub-tab 0: Registered Vehicles (Add approved vehicle, Edit type/plate, Remove)
/// - Sub-tab 1: User Vehicle Requests Queue (Approve / Reject with required reason)
/// - Sub-tab 2: RFID Tags Inventory (Register, Assign, Deactivate, Replace)
class VehiclesRfidScreen extends ConsumerStatefulWidget {
  const VehiclesRfidScreen({super.key});

  @override
  ConsumerState<VehiclesRfidScreen> createState() => _VehiclesRfidScreenState();
}

class _VehiclesRfidScreenState extends ConsumerState<VehiclesRfidScreen> {
  int _subTab = 0;
  String _reqFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null || !profile.role.isAdmin) {
      return const RoleRestrictedPanel(featureName: 'Vehicles & RFID');
    }

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Vehicles & RFID',
          subtitle:
              'Only vehicles with approved status are eligible at campus gates.',
          actions: [
            SegmentTabs(
              keyPrefix: 'vehicles_rfid_subtab',
              labels: const [
                'Vehicles',
                'Vehicle Requests',
                'RFID Tags',
              ],
              icons: const [
                Icons.directions_car_outlined,
                Icons.rule_folder_outlined,
                Icons.nfc_rounded,
              ],
              selected: _subTab,
              onChanged: (i) => setState(() => _subTab = i),
            ),
          ],
        ),
        const SizedBox(height: 20),

        SmoothSwitcher(
          switchKey: _subTab,
          child: switch (_subTab) {
            0 => _buildVehiclesTab(context, profile),
            1 => _buildRequestsTab(context, profile),
            _ => _buildRfidTab(context, profile),
          },
        ),
      ],
    );
  }

  Widget _buildVehiclesTab(BuildContext context, ProfileDto actor) {
    final p = SentryPalette.of(context);
    final sys = ref.watch(sentryScenarioProvider);
    final vehicles = <({ParticipantUserDto owner, ParticipantVehicleDto v})>[
      for (final u in sys.participantDirectory)
        for (final v in u.vehicles) (owner: u, v: v),
    ];

    return SentryCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Approved campus fleet (${vehicles.length})',
            subtitle:
                'Cars require a plate number; motorcycles require an RFID tag.',
            trailing: FilledButton.icon(
              key: const Key('vehicles_add_btn'),
              onPressed: sys.participantDirectory.isEmpty
                  ? null
                  : () => _openAddVehicleDialog(actor, sys.participantDirectory),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Vehicle'),
            ),
          ),
          const SizedBox(height: 16),
          if (vehicles.isEmpty)
            const EmptyState(
              icon: Icons.directions_car_outlined,
              title: 'No vehicles loaded',
              message:
                  'Approved campus vehicles appear here once synced with FastAPI.',
            )
          else
            for (var i = 0; i < vehicles.length; i++) ...[
              if (i > 0) Divider(color: p.line, height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlateBadge(
                          plateText: vehicles[i].v.plateNumberDisplay,
                          rfidUid: vehicles[i].v.rfidUid,
                          isCompact: true,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${vehicles[i].v.vehicleCode} · ${vehicles[i].owner.fullName} (${vehicles[i].owner.userCode})',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${vehicles[i].v.vehicleType} · status: ${vehicles[i].v.approvalStatus}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(
                          label: vehicles[i].v.isGateEligible
                              ? 'Gate Eligible'
                              : vehicles[i].v.approvalStatus,
                          tone: vehicles[i].v.isGateEligible
                              ? PillTone.ok
                              : PillTone.warn,
                        ),
                        OutlinedButton(
                          key: Key('edit_vehicle_${vehicles[i].v.vehicleCode}'),
                          onPressed: () => _openEditVehicleDialog(
                            actor,
                            vehicles[i].owner,
                            vehicles[i].v,
                          ),
                          child: const Text('Edit'),
                        ),
                        OutlinedButton(
                          key:
                              Key('remove_vehicle_${vehicles[i].v.vehicleCode}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SentryColors.crimson,
                          ),
                          onPressed: () {
                            ref
                                .read(sentryScenarioProvider.notifier)
                                .editOrRemoveParticipantVehicle(
                                  actor: actor,
                                  userCode: vehicles[i].owner.userCode,
                                  vehicleCode: vehicles[i].v.vehicleCode,
                                  remove: true,
                                );
                          },
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildRequestsTab(BuildContext context, ProfileDto actor) {
    final p = SentryPalette.of(context);
    final ops = ref.watch(desktopOpsControllerProvider);
    final requests = ops.vehicleRequests.where((r) {
      if (_reqFilter == 'all') return true;
      return r.status == _reqFilter;
    }).toList();

    return SentryCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const SectionHeader(
                title: 'User vehicle requests',
                subtitle: 'Approve eligible vehicles or reject with a reason.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in const ['all', 'pending', 'approved', 'rejected'])
                    ChoiceChip(
                      label: Text(f),
                      selected: _reqFilter == f,
                      onSelected: (_) => setState(() => _reqFilter = f),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (requests.isEmpty)
            const EmptyState(
              icon: Icons.rule_folder_outlined,
              title: 'No vehicle requests',
              message: 'No user vehicle submissions match this filter.',
            )
          else
            for (var i = 0; i < requests.length; i++) ...[
              if (i > 0) Divider(color: p.line, height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${requests[i].userFullName} (${requests[i].userCode} · ${requests[i].userRole})',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${requests[i].vehicleType} · Plate: ${requests[i].plateNumber ?? 'None'} · RFID: ${requests[i].rfidUid ?? 'None'}',
                          style: SentryTheme.mono(fontSize: 12.5, color: p.muted),
                        ),
                        if (requests[i].rejectionReason != null)
                          Text(
                            'Reason: ${requests[i].rejectionReason}',
                            style: TextStyle(fontSize: 12, color: p.errText),
                          ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        StatusPill(
                          label: requests[i].status,
                          tone: requests[i].status == 'approved'
                              ? PillTone.ok
                              : requests[i].status == 'rejected'
                                  ? PillTone.err
                                  : PillTone.warn,
                        ),
                        if (requests[i].status == 'pending') ...[
                          FilledButton(
                            key: Key(
                                'approve_vehicle_req_${requests[i].requestId}'),
                            onPressed: () {
                              ref
                                  .read(desktopOpsControllerProvider.notifier)
                                  .reviewVehicleRequest(
                                    requestId: requests[i].requestId,
                                    approve: true,
                                    actor: actor,
                                  );
                            },
                            child: const Text('Approve'),
                          ),
                          OutlinedButton(
                            key: Key(
                                'reject_vehicle_req_${requests[i].requestId}'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SentryColors.crimson,
                            ),
                            onPressed: () =>
                                _openRejectRequestDialog(actor, requests[i]),
                            child: const Text('Reject'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildRfidTab(BuildContext context, ProfileDto actor) {
    final p = SentryPalette.of(context);
    final ops = ref.watch(desktopOpsControllerProvider);

    return SentryCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'RFID tag inventory (${ops.rfidTags.length})',
            subtitle:
                'Register tags, assign to users/vehicles, deactivate, or replace.',
            trailing: FilledButton.icon(
              key: const Key('rfid_register_tag_btn'),
              onPressed: () => _openRegisterTagDialog(actor),
              icon: const Icon(Icons.nfc_rounded, size: 18),
              label: const Text('Register RFID Tag'),
            ),
          ),
          const SizedBox(height: 16),
          if (ops.rfidTags.isEmpty)
            const EmptyState(
              icon: Icons.nfc_rounded,
              title: 'No RFID tags loaded',
              message: 'Registered RFID tags appear here once loaded.',
            )
          else
            for (var i = 0; i < ops.rfidTags.length; i++) ...[
              if (i > 0) Divider(color: p.line, height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ops.rfidTags[i].rfidUid,
                          style: SentryTheme.mono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                        Text(
                          ops.rfidTags[i].assignedUserCode != null
                              ? 'Assigned: ${ops.rfidTags[i].assignedUserCode} (${ops.rfidTags[i].assignedVehicleCode ?? '—'})'
                              : 'Unassigned',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        StatusPill(
                          label: ops.rfidTags[i].status,
                          tone: ops.rfidTags[i].status == 'active'
                              ? PillTone.ok
                              : ops.rfidTags[i].status == 'deactivated'
                                  ? PillTone.err
                                  : PillTone.neutral,
                        ),
                        if (ops.rfidTags[i].status != 'deactivated' &&
                            ops.rfidTags[i].status != 'replaced') ...[
                          OutlinedButton(
                            onPressed: () {
                              ref
                                  .read(desktopOpsControllerProvider.notifier)
                                  .updateRfidTag(
                                    tagId: ops.rfidTags[i].tagId,
                                    status: 'deactivated',
                                    actor: actor,
                                  );
                            },
                            child: const Text('Deactivate'),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _openReplaceTagDialog(actor, ops.rfidTags[i]),
                            child: const Text('Replace'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  void _openAddVehicleDialog(
    ProfileDto actor,
    List<ParticipantUserDto> users,
  ) {
    String selectedUserCode = users.first.userCode;
    String vType = 'car';
    final plateCtrl = TextEditingController();
    final rfidCtrl = TextEditingController();
    String? err;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Add vehicle (approved immediately)'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedUserCode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'User'),
                  items: [
                    for (final u in users)
                      DropdownMenuItem(
                        value: u.userCode,
                        child: Text('${u.fullName} (${u.userCode})'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedUserCode = v);
                  },
                ),
                const SizedBox(height: 12),
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
                  key: const Key('add_vehicle_plate_field'),
                  controller: plateCtrl,
                  decoration: InputDecoration(
                    labelText: vType == 'car'
                        ? 'License plate *'
                        : 'License plate (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('add_vehicle_rfid_field'),
                  controller: rfidCtrl,
                  decoration: InputDecoration(
                    labelText: vType == 'motorcycle'
                        ? 'RFID tag UID * (required for motorcycle)'
                        : 'RFID tag UID (optional)',
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
              key: const Key('add_vehicle_submit_btn'),
              onPressed: () {
                if (vType == 'car' && plateCtrl.text.trim().isEmpty) {
                  setModalState(() => err = 'License plate is required for cars.');
                  return;
                }
                if (vType == 'motorcycle' && rfidCtrl.text.trim().isEmpty) {
                  setModalState(
                      () => err = 'RFID tag UID is required for motorcycles.');
                  return;
                }
                final owner =
                    users.firstWhere((u) => u.userCode == selectedUserCode);
                ref
                    .read(sentryScenarioProvider.notifier)
                    .registerParticipantVehicle(
                      actor: actor,
                      userCode: selectedUserCode,
                      vehicleCode:
                          'V${(owner.vehicles.length + 20).toString().padLeft(3, '0')}',
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
              child: const Text('Save vehicle'),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditVehicleDialog(
    ProfileDto actor,
    ParticipantUserDto owner,
    ParticipantVehicleDto vehicle,
  ) {
    String vType = vehicle.vehicleType;
    final plateCtrl =
        TextEditingController(text: vehicle.plateNumberDisplay ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Edit ${vehicle.vehicleCode} (type & plate only)'),
          content: SizedBox(
            width: 400,
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
                  decoration: const InputDecoration(labelText: 'License plate'),
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
                    .editOrRemoveParticipantVehicle(
                      actor: actor,
                      userCode: owner.userCode,
                      vehicleCode: vehicle.vehicleCode,
                      newVehicleType: vType,
                      newPlateDisplay: plateCtrl.text,
                    );
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ).whenComplete(plateCtrl.dispose);
  }

  void _openRejectRequestDialog(
    ProfileDto actor,
    VehicleApprovalRequestDto req,
  ) {
    final reasonCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Reject vehicle request ${req.requestId}'),
          content: SizedBox(
            width: 420,
            child: TextField(
              key: const Key('vehicle_reject_reason_field'),
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Required rejection reason',
                hintText: 'Explain why the request cannot be approved…',
              ),
              onChanged: (_) => setModalState(() {}),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('vehicle_confirm_reject_btn'),
              onPressed: reasonCtrl.text.trim().isEmpty
                  ? null
                  : () async {
                      await ref
                          .read(desktopOpsControllerProvider.notifier)
                          .reviewVehicleRequest(
                            requestId: req.requestId,
                            approve: false,
                            rejectionReason: reasonCtrl.text,
                            actor: actor,
                          );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
              child: const Text('Confirm reject'),
            ),
          ],
        ),
      ),
    ).whenComplete(reasonCtrl.dispose);
  }

  void _openRegisterTagDialog(ProfileDto actor) {
    final uidCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final vehCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register RFID Tag'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: uidCtrl,
                decoration:
                    const InputDecoration(labelText: 'RFID UID (e.g. 04AA1122)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(
                    labelText: 'Assign to User Code (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vehCtrl,
                decoration: const InputDecoration(
                    labelText: 'Assign to Vehicle Code (optional)'),
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
              if (uidCtrl.text.trim().isEmpty) return;
              ref.read(desktopOpsControllerProvider.notifier).registerRfidTag(
                    uid: uidCtrl.text,
                    userCode: userCtrl.text.trim().isEmpty ? null : userCtrl.text,
                    vehicleCode:
                        vehCtrl.text.trim().isEmpty ? null : vehCtrl.text,
                    actor: actor,
                  );
              Navigator.of(ctx).pop();
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  void _openReplaceTagDialog(ProfileDto actor, RfidTagDto oldTag) {
    final newUidCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Replace tag ${oldTag.rfidUid}'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: newUidCtrl,
            decoration: const InputDecoration(labelText: 'New RFID UID'),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (newUidCtrl.text.trim().isEmpty) return;
              ref.read(desktopOpsControllerProvider.notifier).updateRfidTag(
                    tagId: oldTag.tagId,
                    status: 'replaced',
                    replacedByUid: newUidCtrl.text,
                    actor: actor,
                  );
              Navigator.of(ctx).pop();
            },
            child: const Text('Replace tag'),
          ),
        ],
      ),
    ).whenComplete(newUidCtrl.dispose);
  }
}
