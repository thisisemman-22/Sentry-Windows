import 'dart:convert';
import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/config/roster_mode.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/role_restricted_panel.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/auth_models.dart';
import '../../../shared/models/participant_models.dart';

/// In-memory staged face frame prior to ArcFace embedding extraction.
/// Discarded immediately from memory once enrollment is submitted.
class _StagedFaceFrame {
  final String fileName;
  final String sourceLabel; // 'File upload' | 'Webcam capture'
  final Uint8List? previewBytes;
  final String base64Payload;
  final DateTime capturedAtUtc;

  const _StagedFaceFrame({
    required this.fileName,
    required this.sourceLabel,
    this.previewBytes,
    required this.base64Payload,
    required this.capturedAtUtc,
  });
}

/// View 8: `Administration` — operator session, registered drivers/vehicles (`P01–P06`),
/// manual user & vehicle registration (`POST /api/v1/admin/users/register`),
/// RA 10173-compliant facial recognition enrollment (`/api/v1/admin/users/{user_id}/face-enrollment`),
/// and the system security audit trail.
class AdministrationScreen extends ConsumerStatefulWidget {
  const AdministrationScreen({super.key});

  @override
  ConsumerState<AdministrationScreen> createState() =>
      _AdministrationScreenState();
}

class _AdministrationScreenState extends ConsumerState<AdministrationScreen> {
  // 0 = Drivers & vehicles, 1 = Manual registration, 2 = Facial enrollment, 3 = Audit log
  int _adminSubTab = 0;
  String? _guardForbiddenTestResult;

  // --- Feature 1: Manual User & Vehicle Registration State ---
  final _fullNameCtrl = TextEditingController();
  final _userCodeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _plateNumberCtrl = TextEditingController();
  final _rfidUidCtrl = TextEditingController();
  String _selectedRoleCode = 'student';
  String? _selectedBuildingCode = 'CICS';
  bool _includeVehicle = true;
  String _selectedVehicleType = 'car';
  bool _isSubmittingRegistration = false;
  Map<String, String> _regFieldErrors = const {};
  String? _regGeneralError;
  ManualUserRegistrationResponse? _lastCreatedRegistration;

  // --- Feature 2: Facial Recognition Enrollment State (RA 10173 Compliant) ---
  String? _selectedEnrollmentUserCode;
  String _enrollmentUserSearchQuery = '';
  bool _ra10173ConsentAccepted = false;
  final List<_StagedFaceFrame> _stagedFaceFrames = [];
  bool _isSubmittingEnrollment = false;
  bool _isRevokingEnrollment = false;
  String? _enrollmentErrorBanner;
  String? _enrollmentSuccessBanner;
  FaceEnrollmentStatusDto? _realFetchedEnrollment;

  @override
  void dispose() {
    _stagedFaceFrames.clear();
    _fullNameCtrl.dispose();
    _userCodeCtrl.dispose();
    _emailCtrl.dispose();
    _plateNumberCtrl.dispose();
    _rfidUidCtrl.dispose();
    super.dispose();
  }

  void _openRegisterVehicleDialog(String userCode) {
    final codeCtrl = TextEditingController(text: 'V009');
    final plateCtrl = TextEditingController(text: 'BSU 2026');
    String selectedType = 'car';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Add vehicle for $userCode'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle code (e.g. V009)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'car', child: Text('Car')),
                        DropdownMenuItem(
                          value: 'motorcycle',
                          child: Text('Motorcycle'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedType = v);
                      },
                      decoration:
                          const InputDecoration(labelText: 'Vehicle type'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: plateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'License plate (e.g. BSU 2026)',
                      ),
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
                    final actor = ref.read(authControllerProvider).profile!;
                    ref
                        .read(sentryScenarioProvider.notifier)
                        .registerParticipantVehicle(
                          actor: actor,
                          userCode: userCode,
                          vehicleCode: codeCtrl.text.trim(),
                          vehicleType: selectedType,
                          plateDisplay: plateCtrl.text.trim(),
                        );
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Register vehicle'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      codeCtrl.dispose();
      plateCtrl.dispose();
    });
  }

  Future<void> _submitManualRegistration(ProfileDto actor) async {
    final effectiveIncludeVehicle =
        _selectedRoleCode == 'student' ? true : _includeVehicle;
    final effectiveBuilding =
        _selectedRoleCode == 'student' ? _selectedBuildingCode : _selectedBuildingCode;

    final request = ManualUserRegistrationRequest(
      fullName: _fullNameCtrl.text,
      userCode: _userCodeCtrl.text.trim().isEmpty ? null : _userCodeCtrl.text,
      email: _emailCtrl.text,
      roleCode: _selectedRoleCode,
      buildingCode: effectiveBuilding,
      includeVehicle: effectiveIncludeVehicle,
      vehicleType: _selectedVehicleType,
      plateNumber: _plateNumberCtrl.text.toUpperCase(),
      rfidUid: _rfidUidCtrl.text.toUpperCase(),
    );

    final clientErrors = request.validate();
    if (clientErrors.isNotEmpty) {
      setState(() {
        _regFieldErrors = clientErrors;
        _regGeneralError = null;
        _lastCreatedRegistration = null;
      });
      return;
    }

    setState(() {
      _isSubmittingRegistration = true;
      _regFieldErrors = const {};
      _regGeneralError = null;
      _lastCreatedRegistration = null;
    });

    final config = ref.read(appConfigProvider);
    ApiEnvelope<ManualUserRegistrationResponse> response;
    if (config.isReal) {
      response = await ref
          .read(administrationRepositoryProvider)
          .registerUserAndVehicleReal(request);
      if (!response.ok && response.error != null) {
        ref
            .read(sentryScenarioProvider.notifier)
            .recordRealApiFailure(response.error!);
      }
    } else {
      response = ref
          .read(sentryScenarioProvider.notifier)
          .registerUserAndVehicle(actor: actor, request: request);
    }

    if (!mounted) return;
    if (!response.ok || response.data == null) {
      final err = response.error;
      setState(() {
        _isSubmittingRegistration = false;
        _regFieldErrors = err?.fieldErrors ?? const {};
        _regGeneralError = err != null
            ? '${err.httpStatus} ${err.code}: ${err.message}'
            : 'Registration failed.';
      });
      return;
    }

    final created = response.data!;
    setState(() {
      _isSubmittingRegistration = false;
      _lastCreatedRegistration = created;
      _regFieldErrors = const {};
      _regGeneralError = null;
      _fullNameCtrl.clear();
      _userCodeCtrl.clear();
      _emailCtrl.clear();
      _plateNumberCtrl.clear();
      _rfidUidCtrl.clear();
    });
  }

  void _proceedToFacialEnrollmentForUser(String userCode) {
    setState(() {
      _selectedEnrollmentUserCode = userCode;
      _ra10173ConsentAccepted = false;
      _stagedFaceFrames.clear();
      _enrollmentErrorBanner = null;
      _enrollmentSuccessBanner = null;
      _adminSubTab = 2;
    });
  }

  Future<void> _pickFaceImagesFromDisk() async {
    if (!_ra10173ConsentAccepted) return;
    if (_stagedFaceFrames.length >= 5) {
      setState(() {
        _enrollmentErrorBanner =
            'Maximum of 5 face photos reached. Remove a photo before adding another.';
      });
      return;
    }

    try {
      const typeGroup = XTypeGroup(
        label: 'Face Photos (JPG, PNG)',
        extensions: <String>['jpg', 'jpeg', 'png'],
      );
      final files = await openFiles(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (files.isEmpty) return;

      final remainingSlots = 5 - _stagedFaceFrames.length;
      final selectedSlice = files.take(remainingSlots);
      final newFrames = <_StagedFaceFrame>[];
      for (final xfile in selectedSlice) {
        final bytes = await xfile.readAsBytes();
        newFrames.add(
          _StagedFaceFrame(
            fileName: xfile.name,
            sourceLabel: 'File upload',
            previewBytes: bytes,
            base64Payload: base64Encode(bytes),
            capturedAtUtc: DateTime.now().toUtc(),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _stagedFaceFrames.addAll(newFrames);
        _enrollmentErrorBanner = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enrollmentErrorBanner =
            'Could not open native file picker ($e). You can use "Capture from Webcam" to stage enrollment frames.';
      });
    }
  }

  static final Uint8List _kDevTestPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  Future<void> _captureFromWebcamFrame() async {
    if (!_ra10173ConsentAccepted) return;
    if (_stagedFaceFrames.length >= 5) {
      setState(() {
        _enrollmentErrorBanner =
            'Maximum of 5 face frames reached (1–5 photos allowed per enrollment).';
      });
      return;
    }

    final isMock = ref.read(appConfigProvider).isMock;
    final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');
    List<CameraDescription> cameras = const [];
    if (!isFlutterTest) {
      try {
        cameras = await availableCameras().timeout(
          const Duration(seconds: 2),
          onTimeout: () => const <CameraDescription>[],
        );
      } on CameraException {
        cameras = const [];
      } on PlatformException {
        cameras = const [];
      } on MissingPluginException {
        cameras = const [];
      } catch (_) {
        cameras = const [];
      }
    }

    if (!mounted) return;

    if (cameras.isNotEmpty) {
      final capturedBytes = await showDialog<Uint8List>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _WindowsWebcamCaptureDialog(cameras: cameras),
      );
      if (!mounted || capturedBytes == null) return;
      final frameNumber = _stagedFaceFrames.length + 1;
      final now = DateTime.now().toUtc();
      final userCode = _selectedEnrollmentUserCode ?? 'user';
      setState(() {
        _stagedFaceFrames.add(
          _StagedFaceFrame(
            fileName:
                '${userCode.toLowerCase()}_webcam_frame_0$frameNumber.jpg',
            sourceLabel: 'Webcam capture',
            previewBytes: capturedBytes,
            base64Payload: base64Encode(capturedBytes),
            capturedAtUtc: now,
          ),
        );
        _enrollmentErrorBanner = null;
      });
      return;
    }

    // No physical Windows webcam detected.
    // In production mode (DATA_SOURCE=real), strictly fail closed and never
    // generate fake placeholder frames.
    if (!isMock) {
      setState(() {
        _enrollmentErrorBanner =
            "No webcam detected — use Upload Face Images to select photos from disk.";
      });
      return;
    }

    // In Developer Test Mode (DATA_SOURCE=mock) when running on a headless machine:
    final frameNumber = _stagedFaceFrames.length + 1;
    final now = DateTime.now().toUtc();
    final userCode = _selectedEnrollmentUserCode ?? 'user';
    setState(() {
      _stagedFaceFrames.add(
        _StagedFaceFrame(
          fileName:
              '${userCode.toLowerCase()}_webcam_frame_0$frameNumber.png',
          sourceLabel: 'Webcam capture (Dev Test Mode)',
          previewBytes: _kDevTestPngBytes,
          base64Payload: base64Encode(_kDevTestPngBytes),
          capturedAtUtc: now,
        ),
      );
      _enrollmentErrorBanner = null;
    });
  }

  Future<void> _submitFacialEnrollment(
    ProfileDto actor,
    ParticipantUserDto targetUser,
  ) async {
    if (!_ra10173ConsentAccepted || _stagedFaceFrames.isEmpty) return;

    setState(() {
      _isSubmittingEnrollment = true;
      _enrollmentErrorBanner = null;
      _enrollmentSuccessBanner = null;
    });

    final request = FaceEnrollmentSubmissionRequest(
      userId: targetUser.userId,
      userCode: targetUser.userCode,
      consentAccepted: _ra10173ConsentAccepted,
      consentVersion: 'RA10173-BSU-2026.1',
      framesBase64: _stagedFaceFrames.map((f) => f.base64Payload).toList(),
      frameNames: _stagedFaceFrames.map((f) => f.fileName).toList(),
    );

    final config = ref.read(appConfigProvider);
    ApiEnvelope<FaceEnrollmentStatusDto> response;
    if (config.isReal) {
      response = await ref
          .read(administrationRepositoryProvider)
          .submitFaceEnrollmentReal(request);
      if (!response.ok && response.error != null) {
        ref
            .read(sentryScenarioProvider.notifier)
            .recordRealApiFailure(response.error!);
      }
    } else {
      response = ref
          .read(sentryScenarioProvider.notifier)
          .submitFaceEnrollment(actor: actor, request: request);
    }

    if (!mounted) return;
    if (!response.ok || response.data == null) {
      final err = response.error;
      setState(() {
        _isSubmittingEnrollment = false;
        _enrollmentErrorBanner = err != null
            ? '${err.httpStatus} ${err.code}: ${err.message}'
            : 'Facial enrollment failed.';
      });
      return;
    }

    // Immediately purge raw staged frames from client memory per RA 10173 privacy rule!
    final enrolled = response.data!;
    setState(() {
      _isSubmittingEnrollment = false;
      _stagedFaceFrames.clear();
      _realFetchedEnrollment = enrolled;
      _enrollmentSuccessBanner =
          'Enrolled ArcFace template ${enrolled.faceTemplateId} for ${targetUser.fullName} (${targetUser.userCode}). Raw photos purged from memory.';
    });
  }

  Future<void> _confirmAndRevokeFaceEnrollment(
    ProfileDto actor,
    ParticipantUserDto targetUser,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke consent & delete biometric embedding?'),
        content: SizedBox(
          width: 440,
          child: Text(
            'This will immediately purge the encrypted ArcFace embedding for ${targetUser.fullName} (${targetUser.userCode}) under RA 10173 Data Privacy rights. Entry lane facial verification will require re-enrollment.',
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_revoke_face_enrollment_button'),
            style: FilledButton.styleFrom(
              backgroundColor: SentryColors.crimson,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete embedding'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || _isRevokingEnrollment) return;

    setState(() {
      _isRevokingEnrollment = true;
      _enrollmentErrorBanner = null;
    });

    final config = ref.read(appConfigProvider);
    ApiEnvelope<FaceEnrollmentStatusDto> response;
    if (config.isReal) {
      response = await ref
          .read(administrationRepositoryProvider)
          .deleteFaceEnrollmentReal(targetUser.userId);
      if (!response.ok && response.error != null) {
        ref
            .read(sentryScenarioProvider.notifier)
            .recordRealApiFailure(response.error!);
      }
    } else {
      response = ref.read(sentryScenarioProvider.notifier).deleteFaceEnrollment(
            actor: actor,
            userCodeOrId: targetUser.userCode,
          );
    }

    if (!mounted) return;
    if (!response.ok || response.data == null) {
      final err = response.error;
      setState(() {
        _isRevokingEnrollment = false;
        _enrollmentErrorBanner = err != null
            ? '${err.httpStatus} ${err.code}: ${err.message}'
            : 'Failed to revoke facial enrollment.';
      });
      return;
    }

    setState(() {
      _isRevokingEnrollment = false;
      _realFetchedEnrollment = response.data;
      _stagedFaceFrames.clear();
      _ra10173ConsentAccepted = false;
      _enrollmentErrorBanner = null;
      _enrollmentSuccessBanner =
          'Biometric embedding purged and status set to not_enrolled for ${targetUser.fullName} (${targetUser.userCode}).';
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final authState = ref.watch(authControllerProvider);
    final sysState = ref.watch(sentryScenarioProvider);
    final session = authState.session;
    if (session == null) return const SizedBox.shrink();
    final profile = session.profile;
    final isAdmin = profile.role.isAdmin;

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Administration',
          subtitle:
              'Operator profile, user & vehicle registration, RA 10173 facial enrollment, and the audit trail.',
          actions: [
            if (isAdmin)
              SegmentTabs(
                keyPrefix: 'admin_subtab',
                labels: [
                  'Drivers & vehicles (${sysState.participantDirectory.length})',
                  'Manual registration',
                  'Facial enrollment',
                  'Audit log (${sysState.auditLogs.length})',
                ],
                icons: const [
                  Icons.directions_car_outlined,
                  Icons.person_add_alt_1_outlined,
                  Icons.face_retouching_natural_outlined,
                  Icons.policy_outlined,
                ],
                selected: _adminSubTab,
                onChanged: (i) => setState(() => _adminSubTab = i),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // Fail-closed API error banner if DATA_SOURCE=real encountered a failure
        if (sysState.lastRealApiError != null) ...[
          Callout(
            tone: PillTone.err,
            icon: Icons.error_outline_rounded,
            title:
                'Real API Error (${sysState.lastRealApiError!.httpStatus} ${sysState.lastRealApiError!.code})',
            message: sysState.lastRealApiError!.message,
            action: OutlinedButton.icon(
              key: const Key('real_api_retry_button'),
              onPressed: () {
                ref
                    .read(sentryScenarioProvider.notifier)
                    .clearRealApiFailure();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 1. Operator Session Card
        Reveal(
          index: 1,
          child: SentryCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isAdmin ? p.text : SentryColors.crimson,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : Icons.shield_rounded,
                        color: isAdmin ? p.card : Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              Text(
                                profile.fullName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              StatusPill(
                                label: isAdmin ? 'Administrator' : 'Guard',
                                tone: isAdmin
                                    ? PillTone.ok
                                    : PillTone.crimson,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${profile.username} · ${profile.assignedStation} · Session valid until ${ManilaTime.formatTimeOnly(session.expiresAtUtc)}',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (ref.watch(appConfigProvider).isMock) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          final nextRoster =
                              sysState.rosterMode == RosterMode.classDemo
                                  ? RosterMode.contractSynthetic
                                  : RosterMode.classDemo;
                          ref
                              .read(sentryScenarioProvider.notifier)
                              .setRosterMode(nextRoster);
                        },
                        icon: const Icon(Icons.groups_2_outlined, size: 18),
                        label: Text(
                          sysState.rosterMode == RosterMode.classDemo
                              ? 'Roster: Class Demo'
                              : 'Roster: Synthetic',
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('simulate_ws_1008_expiry_button'),
                        onPressed: () {
                          ref
                              .read(authControllerProvider.notifier)
                              .expireSessionWith1008();
                        },
                        icon: const Icon(Icons.timer_off_outlined, size: 18),
                        label: const Text('Test session expiry'),
                      ),
                    ],
                    FilledButton.icon(
                      key: const Key('admin_logout_button'),
                      onPressed: () {
                        ref.read(authControllerProvider.notifier).signOut();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 2. Role-Gated Sections
        if (!isAdmin)
          Reveal(
            index: 2,
            child: RoleRestrictedPanel(
              title: 'Administrator access required',
              endpointPath:
                  'GET /api/v1/admin/audit-logs · POST /api/v1/admin/users/register · /api/v1/admin/users/{user_id}/face-enrollment',
              description:
                  'You are signed in as ${profile.fullName} (Guard). Registering users/vehicles, enrolling biometric templates, and reading the system audit log require an Administrator account.',
              lastSimulatedError: ref.watch(appConfigProvider).isMock
                  ? _guardForbiddenTestResult
                  : null,
              onSimulateForbiddenCall: ref.watch(appConfigProvider).isMock
                  ? () {
                      final res = ref
                          .read(sentryScenarioProvider.notifier)
                          .fetchAuditLogsForRole(UserRole.guard);
                      setState(() {
                        _guardForbiddenTestResult =
                            '${res.error?.code}: ${res.error?.message}';
                      });
                    }
                  : null,
            ),
          )
        else
          SmoothSwitcher(
            switchKey: _adminSubTab,
            child: switch (_adminSubTab) {
              0 => _buildParticipantsCard(context, p, profile),
              1 => _buildManualRegistrationCard(context, p, profile),
              2 => _buildFacialEnrollmentCard(context, p, profile),
              _ => _buildAuditLogsCard(context, p),
            },
          ),
      ],
    );
  }

  Widget _buildParticipantsCard(
    BuildContext context,
    SentryPalette p,
    ProfileDto profile,
  ) {
    final sysState = ref.watch(sentryScenarioProvider);
    return SentryCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Registered drivers & vehicles',
            subtitle:
                'Add vehicles, check facial enrollment status, or toggle authorization for campus participants.',
            hint:
                'Participant directory endpoints (/api/v1/participants/...) with admission_evaluated: false.',
            trailing: FilledButton.icon(
              key: const Key('open_manual_registration_tab_button'),
              onPressed: () => setState(() => _adminSubTab = 1),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Register new user'),
            ),
          ),
          const SizedBox(height: 20),
          if (sysState.participantDirectory.isEmpty)
            EmptyState(
              icon: Icons.badge_outlined,
              title: 'No registered participants loaded',
              message:
                  'Registered drivers and vehicles will appear here once synchronized with FastAPI.',
              action: OutlinedButton.icon(
                key: const Key('admin_participants_retry_button'),
                onPressed: () {
                  ref
                      .read(sentryScenarioProvider.notifier)
                      .refreshRealSnapshot();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            )
          else
            for (var i = 0; i < sysState.participantDirectory.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Builder(builder: (context) {
              final u = sysState.participantDirectory[i];
              final faceStatus = sysState.faceEnrollments[u.userCode];
              final isEnrolled = faceStatus?.isEnrolled ?? u.faceEnrolled;
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: p.subtle,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${u.fullName} (${u.userCode})',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                StatusPill(
                                  label: isEnrolled
                                      ? 'Face enrolled'
                                      : 'Face not enrolled',
                                  tone: isEnrolled
                                      ? PillTone.ok
                                      : PillTone.warn,
                                ),
                                if (u.buildingCode != null)
                                  StatusPill(
                                    label: u.buildingCode!,
                                    tone: PillTone.neutral,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              u.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              key: Key('manage_face_${u.userCode}'),
                              onPressed: () =>
                                  _proceedToFacialEnrollmentForUser(u.userCode),
                              icon: const Icon(
                                Icons.face_retouching_natural_outlined,
                                size: 17,
                              ),
                              label: const Text('Facial enrollment'),
                            ),
                            OutlinedButton.icon(
                              key: Key('p05_add_vehicle_${u.userCode}'),
                              onPressed: () =>
                                  _openRegisterVehicleDialog(u.userCode),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add vehicle'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (u.vehicles.isEmpty)
                      Text(
                        'No vehicles registered.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final v in u.vehicles)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: p.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: p.line),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    v.vehicleCode,
                                    style: SentryTheme.mono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: p.text,
                                    ),
                                  ),
                                  PlateBadge(
                                    plateText: v.plateNumberDisplay,
                                    rfidUid: v.rfidUid,
                                    isCompact: true,
                                  ),
                                  StatusPill(
                                    label: v.authorizationStatus == 'authorized'
                                        ? 'Authorized'
                                        : 'Revoked',
                                    tone: v.authorizationStatus == 'authorized'
                                        ? PillTone.ok
                                        : PillTone.err,
                                  ),
                                  TextButton(
                                    key: Key(
                                        'p06_toggle_${u.userCode}_${v.vehicleCode}'),
                                    onPressed: () {
                                      ref
                                          .read(sentryScenarioProvider.notifier)
                                          .toggleVehicleAuthorizationStatus(
                                            actor: profile,
                                            userCode: u.userCode,
                                            vehicleCode: v.vehicleCode,
                                          );
                                    },
                                    child: Text(
                                      v.authorizationStatus == 'authorized'
                                          ? 'Revoke'
                                          : 'Authorize',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Feature 1: Manual User & Vehicle Registration (`POST /api/v1/admin/users/register`).
  Widget _buildManualRegistrationCard(
    BuildContext context,
    SentryPalette p,
    ProfileDto actor,
  ) {
    final isStudent = _selectedRoleCode == 'student';
    final showVehicleSection = isStudent || _includeVehicle;

    return SentryCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Manual user & vehicle registration',
            subtitle:
                'Register a campus participant or staff member and link their primary vehicle.',
            hint:
                'Submits POST /api/v1/admin/users/register with an automatic Idempotency-Key UUID v4.',
          ),
          const SizedBox(height: 20),

          if (_lastCreatedRegistration != null) ...[
            Callout(
              tone: PillTone.ok,
              icon: Icons.check_circle_outline_rounded,
              title:
                  '201 Created · Registered ${_lastCreatedRegistration!.fullName} (${_lastCreatedRegistration!.userCode})',
              message:
                  'User ID: ${_lastCreatedRegistration!.userId}${_lastCreatedRegistration!.vehicleId != null ? ' · Vehicle ID: ${_lastCreatedRegistration!.vehicleId} (${_lastCreatedRegistration!.vehicleCode})' : ''}',
              action: FilledButton.icon(
                key: const Key('proceed_to_facial_enrollment_button'),
                onPressed: () => _proceedToFacialEnrollmentForUser(
                  _lastCreatedRegistration!.userCode,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                label: const Text('Proceed to Facial Enrollment →'),
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (_regGeneralError != null) ...[
            Callout(
              tone: PillTone.err,
              icon: Icons.error_outline_rounded,
              title: 'Registration conflict or validation error',
              message: _regGeneralError!,
            ),
            const SizedBox(height: 20),
          ],

          // Row 1: Full Name + User Code
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 680;
              final nameField = TextField(
                key: const Key('reg_full_name_field'),
                controller: _fullNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full name *',
                  hintText: 'e.g. Juan Dela Cruz',
                  errorText: _regFieldErrors['full_name'],
                ),
              );
              final codeField = TextField(
                key: const Key('reg_user_code_field'),
                controller: _userCodeCtrl,
                decoration: InputDecoration(
                  labelText: 'User code (optional · auto-generated)',
                  hintText: 'e.g. U008 (matches ^U[0-9]{3,8}\$)',
                  errorText: _regFieldErrors['user_code'],
                ),
              );
              if (!wide) {
                return Column(
                  children: [
                    nameField,
                    const SizedBox(height: 14),
                    codeField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: nameField),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: codeField),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Row 2: Email + Role + Building
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 680;
              final emailField = TextField(
                key: const Key('reg_email_field'),
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Institutional email *',
                  hintText: 'e.g. student008@sentry.test',
                  errorText: _regFieldErrors['email'],
                ),
              );
              final roleDropdown = DropdownButtonFormField<String>(
                key: const Key('reg_role_dropdown'),
                initialValue: _selectedRoleCode,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Role *',
                  errorText: _regFieldErrors['role_code'],
                ),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'guard', child: Text('Guard')),
                  DropdownMenuItem(
                    value: 'administrator',
                    child: Text('Administrator'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedRoleCode = v;
                    if (v == 'student') {
                      _includeVehicle = true;
                      _selectedBuildingCode ??= 'CICS';
                    } else {
                      _selectedBuildingCode = null;
                    }
                  });
                },
              );
              final buildingDropdown = DropdownButtonFormField<String?>(
                key: const Key('reg_building_dropdown'),
                initialValue: _selectedBuildingCode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Destination building',
                ),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None (Guard / Admin)'),
                  ),
                  DropdownMenuItem(value: 'CET', child: Text('CET')),
                  DropdownMenuItem(
                    value: 'REGISTRAR',
                    child: Text('REGISTRAR'),
                  ),
                  DropdownMenuItem(value: 'STEERHUB', child: Text('STEERHUB')),
                  DropdownMenuItem(
                    value: 'FITNESS CENTER',
                    child: Text('FITNESS CENTER'),
                  ),
                  DropdownMenuItem(value: 'CEAFA', child: Text('CEAFA')),
                  DropdownMenuItem(value: 'CICS', child: Text('CICS')),
                  DropdownMenuItem(value: 'RGR', child: Text('RGR')),
                ],
                onChanged: (v) => setState(() => _selectedBuildingCode = v),
              );

              if (!wide) {
                return Column(
                  children: [
                    emailField,
                    const SizedBox(height: 14),
                    roleDropdown,
                    const SizedBox(height: 14),
                    buildingDropdown,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: emailField),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: roleDropdown),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: buildingDropdown),
                ],
              );
            },
          ),
          const SizedBox(height: 22),

          // Vehicle Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: p.subtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Primary vehicle registration',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isStudent
                              ? 'Required for Student parking access. Plates are normalized (uppercase, stripped spaces/hyphens) on submit.'
                              : 'Optional for Guard or Administrator staff accounts.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (!isStudent)
                      Switch(
                        key: const Key('reg_include_vehicle_switch'),
                        value: _includeVehicle,
                        onChanged: (v) => setState(() => _includeVehicle = v),
                      ),
                  ],
                ),
                if (showVehicleSection) ...[
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 640;
                      final typeField = DropdownButtonFormField<String>(
                        key: const Key('reg_vehicle_type_dropdown'),
                        initialValue: _selectedVehicleType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle type *',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'car', child: Text('Car')),
                          DropdownMenuItem(
                            value: 'motorcycle',
                            child: Text('Motorcycle'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedVehicleType = v);
                          }
                        },
                      );
                      final plateField = TextField(
                        key: const Key('reg_plate_number_field'),
                        controller: _plateNumberCtrl,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (val) {
                          final upper = val.toUpperCase();
                          if (upper != val) {
                            _plateNumberCtrl.value =
                                _plateNumberCtrl.value.copyWith(
                              text: upper,
                              selection: TextSelection.collapsed(
                                offset: upper.length,
                              ),
                            );
                          }
                        },
                        decoration: InputDecoration(
                          labelText: _selectedVehicleType == 'car'
                              ? 'License plate * (auto-uppercased)'
                              : 'License plate (optional for motorcycle)',
                          hintText: 'e.g. UKQ 247 or ABC 1234',
                          errorText: _regFieldErrors['plate_number'],
                        ),
                      );
                      final rfidField = TextField(
                        key: const Key('reg_rfid_uid_field'),
                        controller: _rfidUidCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'RFID UID (hex · for motorcycles)',
                          hintText: 'e.g. 04A1B2C3',
                          errorText: _regFieldErrors['rfid_uid'],
                        ),
                      );
                      if (!wide) {
                        return Column(
                          children: [
                            typeField,
                            const SizedBox(height: 12),
                            plateField,
                            const SizedBox(height: 12),
                            rfidField,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: typeField),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: plateField),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: rfidField),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _fullNameCtrl.clear();
                    _userCodeCtrl.clear();
                    _emailCtrl.clear();
                    _plateNumberCtrl.clear();
                    _rfidUidCtrl.clear();
                    _regFieldErrors = const {};
                    _regGeneralError = null;
                  });
                },
                child: const Text('Clear form'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const Key('submit_manual_registration_button'),
                onPressed: _isSubmittingRegistration
                    ? null
                    : () => _submitManualRegistration(actor),
                icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                label: Text(
                  _isSubmittingRegistration
                      ? 'Registering…'
                      : 'Register user & vehicle',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Feature 2: Facial Recognition Enrollment (RA 10173 Compliant)
  /// (`GET / POST / DELETE /api/v1/admin/users/{user_id}/face-enrollment`).
  Widget _buildFacialEnrollmentCard(
    BuildContext context,
    SentryPalette p,
    ProfileDto actor,
  ) {
    final sysState = ref.watch(sentryScenarioProvider);
    final filteredUsers = sysState.participantDirectory.where((u) {
      final q = _enrollmentUserSearchQuery.trim().toUpperCase();
      if (q.isEmpty) return true;
      return u.userCode.toUpperCase().contains(q) ||
          u.fullName.toUpperCase().contains(q) ||
          u.email.toUpperCase().contains(q);
    }).toList();

    if (sysState.participantDirectory.isEmpty) {
      return const SentryCard(
        child: EmptyState(
          icon: Icons.face_retouching_natural_outlined,
          title: 'No registered users available',
          message:
              'Register a user in Manual Registration first or sync the participant directory.',
        ),
      );
    }

    final isMock = ref.watch(appConfigProvider).isMock;
    final selectedUser = _selectedEnrollmentUserCode != null
        ? sysState.participantDirectory
            .where((u) => u.userCode == _selectedEnrollmentUserCode)
            .firstOrNull
        : (isMock
            ? (sysState.participantDirectory
                    .where((u) => u.userCode == 'U001')
                    .firstOrNull ??
                sysState.participantDirectory.firstOrNull)
            : null);

    final enrollmentStatus = selectedUser != null
        ? (_realFetchedEnrollment?.userCode == selectedUser.userCode
            ? _realFetchedEnrollment!
            : (sysState.faceEnrollments[selectedUser.userCode] ??
                FaceEnrollmentStatusDto(
                  userId: selectedUser.userId,
                  userCode: selectedUser.userCode,
                  status: selectedUser.faceEnrolled ? 'enrolled' : 'not_enrolled',
                  faceTemplateId: selectedUser.faceEnrolled
                      ? selectedUser.faceTemplateId
                      : null,
                )))
        : null;

    final canSubmitEnrollment = _ra10173ConsentAccepted &&
        _stagedFaceFrames.isNotEmpty &&
        !_isSubmittingEnrollment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. User Selector Card
        SentryCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: '1. Select registered user for facial enrollment',
                subtitle:
                    'Choose a participant to inspect or update their ArcFace template.',
                trailing: SizedBox(
                  width: 280,
                  child: TextField(
                    key: const Key('face_enrollment_user_search_field'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      hintText: 'Search by name or U-code…',
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setState(() => _enrollmentUserSearchQuery = v),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filteredUsers.map((u) {
                  final isSelected =
                      selectedUser != null && u.userCode == selectedUser.userCode;
                  final status = sysState.faceEnrollments[u.userCode]?.status ??
                      (u.faceEnrolled ? 'enrolled' : 'not_enrolled');
                  return ChoiceChip(
                    key: Key('select_face_user_${u.userCode}'),
                    label: Text(
                      '${u.fullName} (${u.userCode}) · ${status == 'enrolled' ? 'Enrolled' : 'Not enrolled'}',
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedEnrollmentUserCode = u.userCode;
                        _realFetchedEnrollment = null;
                        _stagedFaceFrames.clear();
                        _enrollmentErrorBanner = null;
                        _enrollmentSuccessBanner = null;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (_enrollmentSuccessBanner != null) ...[
          Callout(
            tone: PillTone.ok,
            icon: Icons.check_circle_outline_rounded,
            title: 'Biometric enrollment updated',
            message: _enrollmentSuccessBanner!,
          ),
          const SizedBox(height: 18),
        ],

        if (_enrollmentErrorBanner != null) ...[
          Callout(
            tone: PillTone.err,
            icon: Icons.error_outline_rounded,
            title: 'Facial enrollment notice',
            message: _enrollmentErrorBanner!,
          ),
          const SizedBox(height: 18),
        ],

        if (selectedUser == null || enrollmentStatus == null)
          const SentryCard(
            child: EmptyState(
              icon: Icons.person_search_outlined,
              title: 'No user selected',
              message:
                  'Select a registered user above to inspect biometric status and capture facial templates.',
            ),
          )
        else
          // 2. Two-column layout: Enrollment Status Card + RA 10173 Consent & Capture Card
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final statusCard = _buildEnrollmentStatusCard(
                context,
                p,
                actor,
                selectedUser,
                enrollmentStatus,
              );
              final captureCard = _buildConsentAndCaptureCard(
                context,
                p,
                actor,
                selectedUser,
                canSubmitEnrollment,
              );
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  statusCard,
                  const SizedBox(height: 18),
                  captureCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: statusCard),
                const SizedBox(width: 18),
                Expanded(flex: 6, child: captureCard),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEnrollmentStatusCard(
    BuildContext context,
    SentryPalette p,
    ProfileDto actor,
    ParticipantUserDto selectedUser,
    FaceEnrollmentStatusDto statusDto,
  ) {
    final isEnrolled = statusDto.status == 'enrolled';
    final statusTone = switch (statusDto.status) {
      'enrolled' => PillTone.ok,
      'needs_re_enrollment' => PillTone.warn,
      _ => PillTone.neutral,
    };

    return SentryCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Enrollment status',
            subtitle: '${selectedUser.fullName} (${selectedUser.userCode})',
            hint:
                'GET /api/v1/admin/users/${selectedUser.userId}/face-enrollment — never stores or returns raw face photos.',
            trailing: StatusPill(
              key: const Key('face_enrollment_status_pill'),
              label: statusDto.status,
              tone: statusTone,
              monospace: true,
            ),
          ),
          const SizedBox(height: 16),
          KeyValueRow(
            label: 'User ID',
            value: selectedUser.userId,
            mono: true,
          ),
          KeyValueRow(
            label: 'Status',
            value: statusDto.status,
            mono: true,
          ),
          KeyValueRow(
            label: 'Face template ID',
            value: statusDto.faceTemplateId ?? 'None (not_enrolled)',
            mono: true,
          ),
          KeyValueRow(
            label: 'ArcFace model version',
            value: statusDto.modelVersion,
            mono: true,
          ),
          KeyValueRow(
            label: 'Encrypted artifact ref',
            value: statusDto.artifactReference ?? '—',
            mono: true,
          ),
          KeyValueRow(
            label: 'Enrolled at (Asia/Manila)',
            value: ManilaTime.formatDateTime(statusDto.enrolledAtUtc),
            mono: true,
          ),
          KeyValueRow(
            label: 'Retention expires at',
            value: ManilaTime.formatDateTime(statusDto.retentionExpiresAtUtc),
            mono: true,
          ),
          KeyValueRow(
            label: 'RA 10173 consent version',
            value: statusDto.consentVersion,
            mono: true,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const Key('revoke_face_enrollment_button'),
            onPressed: isEnrolled && !_isRevokingEnrollment
                ? () => _confirmAndRevokeFaceEnrollment(actor, selectedUser)
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: SentryColors.crimson,
            ),
            icon: const Icon(Icons.delete_forever_outlined, size: 18),
            label: Text(
              _isRevokingEnrollment
                  ? 'Deleting embedding…'
                  : 'Revoke & Delete Embedding',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentAndCaptureCard(
    BuildContext context,
    SentryPalette p,
    ProfileDto actor,
    ParticipantUserDto selectedUser,
    bool canSubmitEnrollment,
  ) {
    return SentryCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: '2. RA 10173 consent & image capture',
            subtitle:
                'Explicit consent is required before uploading or capturing face photos.',
          ),
          const SizedBox(height: 14),

          // Mandatory RA 10173 Consent Gate Checkbox
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.subtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _ra10173ConsentAccepted ? p.ok : p.line,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                key: const Key('ra10173_consent_checkbox'),
                value: _ra10173ConsentAccepted,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'User has signed explicit RA 10173 biometric enrollment consent',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Images are processed by ArcFace into encrypted numerical embeddings on the backend. Raw photos are discarded after embedding extraction.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                onChanged: (checked) {
                  setState(() {
                    _ra10173ConsentAccepted = checked == true;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Upload & Webcam Buttons (disabled until consent checkbox is checked!)
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                key: const Key('upload_face_images_button'),
                onPressed:
                    _ra10173ConsentAccepted ? _pickFaceImagesFromDisk : null,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Upload Face Images (1–5 photos)'),
              ),
              OutlinedButton.icon(
                key: const Key('capture_webcam_button'),
                onPressed:
                    _ra10173ConsentAccepted ? _captureFromWebcamFrame : null,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Capture from Webcam'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // In-memory thumbnail previews before submission
          if (_stagedFaceFrames.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: p.subtle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _ra10173ConsentAccepted
                    ? 'No frames staged yet. Upload 1–5 face photos (.jpg, .jpeg, .png) or capture a frame from the webcam.'
                    : 'Check the RA 10173 consent box above to unlock photo upload and webcam capture.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Staged in-memory frames (${_stagedFaceFrames.length}/5 · purged immediately after submit):',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < _stagedFaceFrames.length; i++)
                      Container(
                        width: 148,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: p.subtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 68,
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: p.card,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _stagedFaceFrames[i].previewBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        _stagedFaceFrames[i].previewBytes!,
                                        height: 68,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.face_retouching_natural_rounded,
                                          size: 28,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.face_retouching_natural_rounded,
                                      size: 28,
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _stagedFaceFrames[i].fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SentryTheme.mono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: p.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _stagedFaceFrames[i].sourceLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _stagedFaceFrames.removeAt(i);
                                    });
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: p.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('submit_face_enrollment_button'),
            onPressed: canSubmitEnrollment
                ? () => _submitFacialEnrollment(actor, selectedUser)
                : null,
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            label: Text(
              _isSubmittingEnrollment
                  ? 'Extracting ArcFace embedding…'
                  : 'Enroll ArcFace embedding (${_stagedFaceFrames.length} frame${_stagedFaceFrames.length == 1 ? '' : 's'})',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsCard(BuildContext context, SentryPalette p) {
    final sysState = ref.watch(sentryScenarioProvider);
    return SentryCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'System audit log',
            subtitle:
                'Chronological record of guard confirmations, reviews, user registrations, and biometric enrollments.',
            trailing: StatusPill(
              label: '${sysState.auditLogs.length} entries',
              tone: PillTone.ok,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < sysState.auditLogs.length; i++) ...[
            if (i > 0) Divider(color: p.line, height: 22),
            Builder(builder: (context) {
              final log = sysState.auditLogs[i];
              final timeLabel = Text(
                '${log.actorUserCode} · ${ManilaTime.formatShort(log.occurredAtUtc)}',
                style: SentryTheme.mono(fontSize: 12.5, color: p.muted),
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 640;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusPill(
                            label: log.action,
                            tone: PillTone.info,
                            monospace: true,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              log.summary,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: p.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (!isNarrow) ...[
                            const SizedBox(width: 14),
                            timeLabel,
                          ],
                        ],
                      ),
                      if (isNarrow) ...[
                        const SizedBox(height: 6),
                        timeLabel,
                      ],
                    ],
                  );
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Live Windows Webcam Preview & Frame Capture Dialog using `camera` / `camera_windows`.
class _WindowsWebcamCaptureDialog extends StatefulWidget {
  final List<CameraDescription> cameras;

  const _WindowsWebcamCaptureDialog({required this.cameras});

  @override
  State<_WindowsWebcamCaptureDialog> createState() =>
      _WindowsWebcamCaptureDialogState();
}

class _WindowsWebcamCaptureDialogState
    extends State<_WindowsWebcamCaptureDialog> {
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _initCamera(0);
  }

  Future<void> _initCamera(int index) async {
    final prev = _controller;
    setState(() {
      _isInitializing = true;
      _errorText = null;
      _selectedCameraIndex = index;
    });
    if (prev != null) {
      await prev.dispose();
    }

    final controller = CameraController(
      widget.cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorText =
            "Camera initialization failed (${e.code}): ${e.description ?? 'Unable to open Windows webcam.'}";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorText = 'Unable to open Windows webcam ($e).';
      });
    }
  }

  Future<void> _captureFrame() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isCapturing) return;
    setState(() {
      _isCapturing = true;
      _errorText = null;
    });
    try {
      final xfile = await ctrl.takePicture();
      final bytes = await xfile.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _errorText = 'Failed to capture frame from webcam ($e).';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final ctrl = _controller;
    return AlertDialog(
      title: const Text('Capture face photo from Windows webcam'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.cameras.length > 1) ...[
                DropdownButtonFormField<int>(
                  initialValue: _selectedCameraIndex,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select camera device',
                    isDense: true,
                  ),
                  items: [
                    for (var i = 0; i < widget.cameras.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          widget.cameras[i].name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isInitializing || _isCapturing
                      ? null
                      : (idx) {
                          if (idx != null) _initCamera(idx);
                        },
                ),
                const SizedBox(height: 12),
              ],
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.line),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: _isInitializing
                    ? const CircularProgressIndicator()
                    : _errorText != null
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _errorText!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          )
                        : (ctrl != null && ctrl.value.isInitialized)
                            ? CameraPreview(ctrl)
                            : const Text(
                                'Webcam preview unavailable',
                                style: TextStyle(color: Colors.white),
                              ),
              ),
              const SizedBox(height: 10),
              Text(
                'Center the participant\'s face in the frame. Raw image bytes are discarded immediately after ArcFace embedding extraction.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isCapturing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('confirm_webcam_capture_button'),
          onPressed: (!_isInitializing &&
                  _errorText == null &&
                  ctrl != null &&
                  ctrl.value.isInitialized &&
                  !_isCapturing)
              ? _captureFrame
              : null,
          icon: const Icon(Icons.camera_alt_rounded, size: 18),
          label: Text(_isCapturing ? 'Capturing…' : 'Capture Frame'),
        ),
      ],
    );
  }
}
