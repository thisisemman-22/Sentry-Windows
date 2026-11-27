import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_envelope.dart';
import '../../../shared/models/audit_models.dart';
import '../../../shared/models/auth_models.dart';
import '../../../shared/models/participant_models.dart';
import '../../../shared/models/spec_2026_models.dart';
import '../data/desktop_ops_repository.dart';

class DesktopOpsState {
  final SystemHealthDto systemHealth;
  final GeneralPasswordConfigDto? generalPassword;
  final Map<String, String> userAccountStatuses; // userCode -> active|suspended|first_login_required
  final List<VehicleApprovalRequestDto> vehicleRequests;
  final List<RfidTagDto> rfidTags;
  final List<FaceEnrollmentHistoryEntry> faceHistory;
  final List<ParkingRuleDto> parkingRules;
  final List<ParkingRuleChangeDto> parkingRuleHistory;
  final List<GuestVisitRequestDto> guestVisitRequests;
  final List<GuestAccountDto> guestAccounts;
  final GuestGateVerificationResultDto? lastGuestVerification;
  final List<ExportHistoryEntryDto> exportHistory;
  final List<AnnouncementDto> announcements;
  final List<ProfileDto> guardAccounts;
  final BackendSystemSettingsDto? backendSettings;

  const DesktopOpsState({
    this.systemHealth = const SystemHealthDto.empty(),
    this.generalPassword,
    this.userAccountStatuses = const {},
    this.vehicleRequests = const [],
    this.rfidTags = const [],
    this.faceHistory = const [],
    this.parkingRules = const [],
    this.parkingRuleHistory = const [],
    this.guestVisitRequests = const [],
    this.guestAccounts = const [],
    this.lastGuestVerification,
    this.exportHistory = const [],
    this.announcements = const [],
    this.guardAccounts = const [],
    this.backendSettings,
  });

  DesktopOpsState copyWith({
    SystemHealthDto? systemHealth,
    GeneralPasswordConfigDto? generalPassword,
    Map<String, String>? userAccountStatuses,
    List<VehicleApprovalRequestDto>? vehicleRequests,
    List<RfidTagDto>? rfidTags,
    List<FaceEnrollmentHistoryEntry>? faceHistory,
    List<ParkingRuleDto>? parkingRules,
    List<ParkingRuleChangeDto>? parkingRuleHistory,
    List<GuestVisitRequestDto>? guestVisitRequests,
    List<GuestAccountDto>? guestAccounts,
    GuestGateVerificationResultDto? lastGuestVerification,
    bool clearLastGuestVerification = false,
    List<ExportHistoryEntryDto>? exportHistory,
    List<AnnouncementDto>? announcements,
    List<ProfileDto>? guardAccounts,
    BackendSystemSettingsDto? backendSettings,
  }) {
    return DesktopOpsState(
      systemHealth: systemHealth ?? this.systemHealth,
      generalPassword: generalPassword ?? this.generalPassword,
      userAccountStatuses: userAccountStatuses ?? this.userAccountStatuses,
      vehicleRequests: vehicleRequests ?? this.vehicleRequests,
      rfidTags: rfidTags ?? this.rfidTags,
      faceHistory: faceHistory ?? this.faceHistory,
      parkingRules: parkingRules ?? this.parkingRules,
      parkingRuleHistory: parkingRuleHistory ?? this.parkingRuleHistory,
      guestVisitRequests: guestVisitRequests ?? this.guestVisitRequests,
      guestAccounts: guestAccounts ?? this.guestAccounts,
      lastGuestVerification: clearLastGuestVerification
          ? null
          : (lastGuestVerification ?? this.lastGuestVerification),
      exportHistory: exportHistory ?? this.exportHistory,
      announcements: announcements ?? this.announcements,
      guardAccounts: guardAccounts ?? this.guardAccounts,
      backendSettings: backendSettings ?? this.backendSettings,
    );
  }
}

class DesktopOpsController extends StateNotifier<DesktopOpsState> {
  DataSourceMode dataSourceMode;
  final DesktopOpsRepository repository;
  final void Function(AuditLogDto log)? onAppendAudit;

  /// Current active General Password held in memory ONLY during Mock Test Mode.
  String _mockGeneralPassword = 'SENTRY-WELCOME-2026!';
  int _seq = 500;

  DesktopOpsController({
    required this.dataSourceMode,
    required this.repository,
    this.onAppendAudit,
  }) : super(
          dataSourceMode == DataSourceMode.real
              ? const DesktopOpsState()
              : _buildInitialMockState(),
        );

  static DesktopOpsState _buildInitialMockState() {
    final now = DateTime.now().toUtc();
    return DesktopOpsState(
      systemHealth: MockDesktopOpsData.initialHealth(now),
      generalPassword: GeneralPasswordConfigDto(
        maskedValue: '••••••••••••',
        defaultExpiryHours: 24,
        updatedAtUtc: now.subtract(const Duration(days: 7)),
        updatedByUserCode: 'A001',
      ),
      userAccountStatuses: const {
        'U001': 'active',
        'U002': 'active',
        'U003': 'active',
        'U004': 'active',
        'U005': 'active',
        'U006': 'active',
        'U007': 'active',
        'G001': 'active',
        'A001': 'active',
      },
      vehicleRequests: MockDesktopOpsData.initialVehicleRequests(now),
      rfidTags: MockDesktopOpsData.initialRfidTags(now),
      faceHistory: MockDesktopOpsData.initialFaceHistory(now),
      parkingRules: MockDesktopOpsData.initialParkingRules(now),
      guestVisitRequests: MockDesktopOpsData.initialGuestRequests(now),
      guestAccounts: MockDesktopOpsData.initialGuestAccounts(now),
      announcements: MockDesktopOpsData.initialAnnouncements(now),
      guardAccounts: MockDesktopOpsData.initialGuardAccounts(),
      backendSettings: MockDesktopOpsData.initialBackendSettings(),
    );
  }

  void enableDeveloperMockMode() {
    dataSourceMode = DataSourceMode.mock;
    if (state.backendSettings == null) {
      state = _buildInitialMockState();
    }
  }

  void resetToProductionRealMode() {
    dataSourceMode = DataSourceMode.real;
    state = const DesktopOpsState();
  }

  String _nextId(String prefix) => '$prefix-${++_seq}';

  void _recordAudit({
    required ProfileDto actor,
    required String action,
    required String resourceType,
    required String resourceId,
    required String summary,
  }) {
    onAppendAudit?.call(
      AuditLogDto(
        auditId: '99000000-0000-4000-8000-${_seq.toString().padLeft(12, '0')}',
        occurredAtUtc: DateTime.now().toUtc(),
        actorUserId: actor.userId,
        actorUserCode: actor.userCode,
        actorRole: actor.role.wireValue,
        action: action,
        resourceType: resourceType,
        resourceId: resourceId,
        requestId: _nextId('req'),
        summary: summary,
      ),
    );
  }

  ApiEnvelope<T> _forbidden<T>() => ApiEnvelope.failure(
        code: 'ACCESS_DENIED',
        message: 'Administrator privileges are required for this action.',
        httpStatus: 403,
      );

  // --- System Health & Dead Letters ---

  Future<ApiEnvelope<DeadLetterItemDto>> retryDeadLetter(
    String id, {
    required ProfileDto actor,
  }) async {
    if (!actor.role.isAdmin) return _forbidden();
    if (dataSourceMode == DataSourceMode.real) {
      final res = await repository.retryDeadLetter(id);
      if (res.ok && res.data != null) {
        await refreshRealOpsSnapshot();
      }
      return res;
    }
    final letters = state.systemHealth.deadLetters;
    final idx = letters.indexWhere((d) => d.id == id);
    if (idx < 0) {
      return ApiEnvelope.failure(
        code: 'NOT_FOUND',
        message: 'Dead letter item $id not found.',
        httpStatus: 404,
      );
    }
    final resolved = letters[idx].copyWith(
      status: 'resolved',
      attempts: letters[idx].attempts + 1,
    );
    final updated = List<DeadLetterItemDto>.from(letters)..[idx] = resolved;
    final remainingFailed = updated.any((d) => d.status == 'failed');
    state = state.copyWith(
      systemHealth: state.systemHealth.copyWith(
        overallStatus: remainingFailed ? 'degraded' : 'healthy',
        updatedAtUtc: DateTime.now().toUtc(),
        deadLetters: updated,
      ),
    );
    _recordAudit(
      actor: actor,
      action: 'dead_letter_retried',
      resourceType: 'notification_delivery',
      resourceId: id,
      summary: 'Retried dead-letter delivery $id (${resolved.recipient}).',
    );
    return ApiEnvelope.success(resolved);
  }

  // --- Users, Reset Forgotten Password & General Password ---

  String userStatusFor(ParticipantUserDto user) {
    return state.userAccountStatuses[user.userCode] ?? user.status;
  }

  void setUserSuspended({
    required String userCode,
    required bool suspend,
    required ProfileDto actor,
  }) {
    if (!actor.role.isAdmin) return;
    final nextMap = Map<String, String>.from(state.userAccountStatuses);
    nextMap[userCode] = suspend ? 'suspended' : 'active';
    state = state.copyWith(userAccountStatuses: nextMap);
    _recordAudit(
      actor: actor,
      action: suspend ? 'user_suspended' : 'user_reactivated',
      resourceType: 'user',
      resourceId: userCode,
      summary: '${suspend ? 'Suspended' : 'Reactivated'} user $userCode.',
    );
  }

  /// Resets forgotten password to the current General First-Login Password.
  /// Enforces `targetUserId != actor.userId` (second-Admin requirement).
  Future<ApiEnvelope<bool>> resetUserPasswordToGeneral({
    required String targetUserId,
    required String targetUserCode,
    required ProfileDto actor,
  }) async {
    if (!actor.role.isAdmin) return _forbidden();
    if (targetUserId == actor.userId || targetUserCode == actor.userCode) {
      return ApiEnvelope.failure(
        code: 'SELF_RESET_FORBIDDEN',
        message: 'A second Administrator must reset an Admin account password.',
        httpStatus: 403,
      );
    }
    if (dataSourceMode == DataSourceMode.real) {
      final res = await repository.resetUserPasswordToGeneral(
        targetUserId: targetUserId,
        actorUserId: actor.userId,
      );
      if (res.ok) {
        _recordAudit(
          actor: actor,
          action: 'password_reset_to_general',
          resourceType: 'user',
          resourceId: targetUserCode,
          summary:
              'Reset $targetUserCode to General Password (first login required).',
        );
      }
      return res;
    }
    final nextMap = Map<String, String>.from(state.userAccountStatuses);
    nextMap[targetUserCode] = 'first_login_required';
    state = state.copyWith(userAccountStatuses: nextMap);
    _recordAudit(
      actor: actor,
      action: 'password_reset_to_general',
      resourceType: 'user',
      resourceId: targetUserCode,
      summary:
          'Reset $targetUserCode to General Password (active sessions revoked, 24h expiry).',
    );
    return ApiEnvelope.success(true);
  }

  Future<ApiEnvelope<String>> revealGeneralPassword({
    required ProfileDto actor,
  }) async {
    if (!actor.role.isAdmin) return _forbidden();
    if (dataSourceMode == DataSourceMode.real) {
      final res = await repository.revealGeneralPassword();
      if (res.ok && res.data != null) {
        state = state.copyWith(
          generalPassword: (state.generalPassword ??
                  GeneralPasswordConfigDto(updatedAtUtc: DateTime.now().toUtc()))
              .copyWith(revealedValue: res.data),
        );
        _recordAudit(
          actor: actor,
          action: 'general_password_revealed',
          resourceType: 'system_setting',
          resourceId: 'general_first_login_password',
          summary: 'Admin ${actor.userCode} revealed the General Password.',
        );
      }
      return res;
    }
    final cfg = state.generalPassword ??
        GeneralPasswordConfigDto(updatedAtUtc: DateTime.now().toUtc());
    state = state.copyWith(
      generalPassword: cfg.copyWith(revealedValue: _mockGeneralPassword),
    );
    _recordAudit(
      actor: actor,
      action: 'general_password_revealed',
      resourceType: 'system_setting',
      resourceId: 'general_first_login_password',
      summary: 'Admin ${actor.userCode} revealed the General Password.',
    );
    return ApiEnvelope.success(_mockGeneralPassword);
  }

  void hideGeneralPassword() {
    final cfg = state.generalPassword;
    if (cfg == null) return;
    state = state.copyWith(
      generalPassword: cfg.copyWith(clearRevealed: true),
    );
  }

  Future<ApiEnvelope<GeneralPasswordConfigDto>> changeGeneralPassword({
    required String newPassword,
    required ProfileDto actor,
  }) async {
    if (!actor.role.isAdmin) return _forbidden();
    if (newPassword.runes.length < 12) {
      return ApiEnvelope.failure(
        code: 'PASSWORD_POLICY_REJECTED',
        message: 'General password must be at least 12 characters.',
        httpStatus: 400,
      );
    }
    if (dataSourceMode == DataSourceMode.real) {
      final res = await repository.changeGeneralPassword(newPassword);
      if (res.ok && res.data != null) {
        state = state.copyWith(generalPassword: res.data);
      }
      return res;
    }
    _mockGeneralPassword = newPassword;
    final nextCfg = (state.generalPassword ??
            GeneralPasswordConfigDto(updatedAtUtc: DateTime.now().toUtc()))
        .copyWith(
      clearRevealed: true,
      updatedAtUtc: DateTime.now().toUtc(),
      updatedByUserCode: actor.userCode,
    );
    state = state.copyWith(generalPassword: nextCfg);
    _recordAudit(
      actor: actor,
      action: 'general_password_changed',
      resourceType: 'system_setting',
      resourceId: 'general_first_login_password',
      summary: 'Admin ${actor.userCode} updated the General First-Login Password.',
    );
    return ApiEnvelope.success(nextCfg);
  }

  // --- Vehicles & RFID ---

  Future<ApiEnvelope<bool>> reviewVehicleRequest({
    required String requestId,
    required bool approve,
    String? rejectionReason,
    required ProfileDto actor,
  }) async {
    if (!actor.role.isAdmin) return _forbidden();
    if (!approve && (rejectionReason == null || rejectionReason.trim().isEmpty)) {
      return ApiEnvelope.failure(
        code: 'VALIDATION_ERROR',
        message: 'A rejection reason is required.',
        httpStatus: 422,
      );
    }
    if (dataSourceMode == DataSourceMode.real) {
      return repository.reviewVehicleRequest(
        requestId: requestId,
        approve: approve,
        rejectionReason: rejectionReason,
      );
    }
    final list = List<VehicleApprovalRequestDto>.from(state.vehicleRequests);
    final idx = list.indexWhere((r) => r.requestId == requestId);
    if (idx < 0) {
      return ApiEnvelope.failure(
        code: 'NOT_FOUND',
        message: 'Vehicle request $requestId not found.',
        httpStatus: 404,
      );
    }
    final next = list[idx].copyWith(
      status: approve ? 'approved' : 'rejected',
      rejectionReason: approve ? null : rejectionReason?.trim(),
    );
    list[idx] = next;
    state = state.copyWith(vehicleRequests: list);
    _recordAudit(
      actor: actor,
      action: approve ? 'vehicle_request_approved' : 'vehicle_request_rejected',
      resourceType: 'vehicle_request',
      resourceId: requestId,
      summary:
          '${approve ? 'Approved' : 'Rejected'} vehicle request $requestId (${next.userCode}).',
    );
    return ApiEnvelope.success(true);
  }

  void registerRfidTag({
    required String uid,
    String? vehicleCode,
    String? userCode,
    required ProfileDto actor,
  }) {
    if (!actor.role.isAdmin || dataSourceMode == DataSourceMode.real) return;
    final normUid = uid.trim().toUpperCase();
    final hasAssignment = vehicleCode != null && vehicleCode.trim().isNotEmpty;
    final tag = RfidTagDto(
      tagId: _nextId('TAG'),
      rfidUid: normUid,
      status: hasAssignment ? 'active' : 'unassigned',
      assignedVehicleCode: hasAssignment ? vehicleCode.trim().toUpperCase() : null,
      assignedUserCode: userCode?.trim().toUpperCase(),
      registeredAtUtc: DateTime.now().toUtc(),
    );
    state = state.copyWith(rfidTags: [tag, ...state.rfidTags]);
    _recordAudit(
      actor: actor,
      action: 'rfid_tag_registered',
      resourceType: 'rfid_tag',
      resourceId: normUid,
      summary: 'Registered RFID tag $normUid.',
    );
  }

  void updateRfidTag({
    required String tagId,
    String? status,
    String? assignedVehicleCode,
    String? assignedUserCode,
    String? replacedByUid,
    required ProfileDto actor,
  }) {
    if (!actor.role.isAdmin || dataSourceMode == DataSourceMode.real) return;
    final list = List<RfidTagDto>.from(state.rfidTags);
    final idx = list.indexWhere((t) => t.tagId == tagId);
    if (idx < 0) return;
    final updated = list[idx].copyWith(
      status: status,
      assignedVehicleCode: assignedVehicleCode,
      assignedUserCode: assignedUserCode,
      replacedByUid: replacedByUid,
    );
    list[idx] = updated;
    if (replacedByUid != null && replacedByUid.trim().isNotEmpty) {
      list.insert(
        0,
        RfidTagDto(
          tagId: _nextId('TAG'),
          rfidUid: replacedByUid.trim().toUpperCase(),
          status: updated.assignedVehicleCode != null ? 'active' : 'unassigned',
          assignedVehicleCode: updated.assignedVehicleCode,
          assignedUserCode: updated.assignedUserCode,
          registeredAtUtc: DateTime.now().toUtc(),
        ),
      );
    }
    state = state.copyWith(rfidTags: list);
    _recordAudit(
      actor: actor,
      action: 'rfid_tag_updated',
      resourceType: 'rfid_tag',
      resourceId: updated.rfidUid,
      summary: 'Updated RFID tag ${updated.rfidUid} -> ${updated.status}.',
    );
  }

  void recordFaceHistory({
    required String userCode,
    required String action,
    required ProfileDto actor,
    String consentVersion = 'RA10173-BSU-2026.1',
  }) {
    if (!actor.role.isAdmin || dataSourceMode == DataSourceMode.real) return;
    final entry = FaceEnrollmentHistoryEntry(
      entryId: _nextId('FE'),
      userCode: userCode,
      action: action,
      consentVersion: consentVersion,
      actorUserCode: actor.userCode,
      occurredAtUtc: DateTime.now().toUtc(),
    );
    state = state.copyWith(faceHistory: [entry, ...state.faceHistory]);
  }

  // --- Parking Rules ---

  Future<ApiEnvelope<ParkingRuleDto>> updateParkingRule({
    required String ruleKey,
    required String valueText,
    required ProfileDto actor,
  }) async {
    if (!actor.role.isAdmin) return _forbidden();
    if (dataSourceMode == DataSourceMode.real) {
      return repository.updateParkingRule(ruleKey: ruleKey, valueText: valueText);
    }
    final rules = List<ParkingRuleDto>.from(state.parkingRules);
    final idx = rules.indexWhere((r) => r.ruleKey == ruleKey);
    if (idx < 0) {
      return ApiEnvelope.failure(
        code: 'NOT_FOUND',
        message: 'Rule $ruleKey not found.',
        httpStatus: 404,
      );
    }
    final prev = rules[idx];
    final next = prev.copyWith(
      valueText: valueText.trim(),
      updatedAtUtc: DateTime.now().toUtc(),
      updatedByUserCode: actor.userCode,
    );
    rules[idx] = next;
    final change = ParkingRuleChangeDto(
      changeId: _nextId('RC'),
      ruleKey: ruleKey,
      ruleTitle: prev.title,
      previousValue: prev.valueText,
      newValue: next.valueText,
      actorUserCode: actor.userCode,
      changedAtUtc: DateTime.now().toUtc(),
    );
    state = state.copyWith(
      parkingRules: rules,
      parkingRuleHistory: [change, ...state.parkingRuleHistory],
    );
    _recordAudit(
      actor: actor,
      action: 'parking_rule_updated',
      resourceType: 'parking_rule',
      resourceId: ruleKey,
      summary: 'Updated ${prev.title}: ${prev.valueText} -> ${next.valueText}.',
    );
    return ApiEnvelope.success(next);
  }

  // --- Guests & Gate Pass Verification ---

  Future<ApiEnvelope<GuestVisitRequestDto>> reviewGuestVisitRequest({
    required String visitRequestId,
    required bool approve,
    String? rejectionReason,
    required ProfileDto actor,
  }) async {
    if (!actor.role.isAdmin) return _forbidden();
    final trimmedReason = rejectionReason?.trim() ?? '';
    if (!approve && trimmedReason.isEmpty) {
      return ApiEnvelope.failure(
        code: 'VALIDATION_ERROR',
        message: 'A rejection reason is required before declining a guest visit.',
        httpStatus: 422,
      );
    }
    if (dataSourceMode == DataSourceMode.real) {
      return repository.reviewGuestVisitRequest(
        visitRequestId: visitRequestId,
        approve: approve,
        rejectionReason: trimmedReason,
      );
    }
    final requests = List<GuestVisitRequestDto>.from(state.guestVisitRequests);
    final idx = requests.indexWhere((r) => r.visitRequestId == visitRequestId);
    if (idx < 0) {
      return ApiEnvelope.failure(
        code: 'NOT_FOUND',
        message: 'Visit request $visitRequestId not found.',
        httpStatus: 404,
      );
    }
    final next = requests[idx].copyWith(
      status: approve ? 'approved' : 'rejected',
      rejectionReason: approve ? null : trimmedReason,
    );
    requests[idx] = next;
    state = state.copyWith(guestVisitRequests: requests);
    _recordAudit(
      actor: actor,
      action: approve ? 'guest_visit_approved' : 'guest_visit_rejected',
      resourceType: 'guest_visit',
      resourceId: visitRequestId,
      summary: approve
          ? 'Approved guest visit $visitRequestId (${next.guestFullName}). Pass code stays guest-private.'
          : 'Rejected guest visit $visitRequestId (${next.guestFullName}): $trimmedReason',
    );
    return ApiEnvelope.success(next);
  }

  void toggleGuestAccountSuspend({
    required String guestAccountId,
    required bool suspend,
    required ProfileDto actor,
  }) {
    if (!actor.role.isAdmin || dataSourceMode == DataSourceMode.real) return;
    final list = List<GuestAccountDto>.from(state.guestAccounts);
    final idx = list.indexWhere((g) => g.guestAccountId == guestAccountId);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(status: suspend ? 'suspended' : 'active');
    state = state.copyWith(guestAccounts: list);
    _recordAudit(
      actor: actor,
      action: suspend ? 'guest_suspended' : 'guest_reactivated',
      resourceType: 'guest_account',
      resourceId: guestAccountId,
      summary: '${suspend ? 'Suspended' : 'Reactivated'} guest account ${list[idx].fullName}.',
    );
  }

  void resetGuestAccountPassword({
    required String guestAccountId,
    required ProfileDto actor,
  }) {
    if (!actor.role.isAdmin || dataSourceMode == DataSourceMode.real) return;
    final list = List<GuestAccountDto>.from(state.guestAccounts);
    final idx = list.indexWhere((g) => g.guestAccountId == guestAccountId);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(status: 'first_login_required');
    state = state.copyWith(guestAccounts: list);
    _recordAudit(
      actor: actor,
      action: 'guest_password_reset',
      resourceType: 'guest_account',
      resourceId: guestAccountId,
      summary:
          'Reset guest ${list[idx].fullName} to General Password (first login required).',
    );
  }

  /// Security Guard / Operator 4-digit `BSUAL-XXXX` gate pass verification.
  Future<ApiEnvelope<GuestGateVerificationResultDto>> verifyGuestGatePass({
    required String digits4,
    required String laneId,
    required ProfileDto actor,
  }) async {
    final clean = digits4.trim();
    if (!RegExp(r'^[0-9]{4}$').hasMatch(clean)) {
      return ApiEnvelope.failure(
        code: 'INVALID_PASS_CODE',
        message: 'Enter the exact 4 digits shown after BSUAL- on the guest app.',
        httpStatus: 422,
      );
    }
    final fullCode = 'BSUAL-$clean';
    if (dataSourceMode == DataSourceMode.real) {
      final res = await repository.verifyGuestGatePass(
        passCode: fullCode,
        laneId: laneId,
      );
      if (res.ok && res.data != null) {
        state = state.copyWith(lastGuestVerification: res.data);
      }
      return res;
    }
    final approvedGuest = state.guestVisitRequests
        .where((g) => g.status == 'approved')
        .firstOrNull;
    final result = GuestGateVerificationResultDto(
      passCode: fullCode,
      verified: true,
      guestFullName: approvedGuest?.guestFullName ?? 'Verified Campus Guest',
      plateNumber: approvedGuest?.plateNumber ?? 'GUEST-01',
      hostName: approvedGuest?.hostName ?? 'Host Department',
      windowLabel: 'Valid today',
      message: 'Verified $fullCode and linked to $laneId gate camera.',
    );
    state = state.copyWith(lastGuestVerification: result);
    _recordAudit(
      actor: actor,
      action: 'guest_gate_pass_verified',
      resourceType: 'guest_pass',
      resourceId: fullCode,
      summary: 'Guard ${actor.userCode} verified $fullCode at $laneId.',
    );
    return ApiEnvelope.success(result);
  }

  // --- Export History ---

  void recordReportExport({
    required String presetLabel,
    required String format,
    required String filterSummary,
    required ProfileDto actor,
  }) {
    final entry = ExportHistoryEntryDto(
      exportId: _nextId('EXP'),
      presetLabel: presetLabel,
      format: format.toUpperCase(),
      filterSummary: filterSummary,
      exportedByUserCode: actor.userCode,
      exportedAtUtc: DateTime.now().toUtc(),
    );
    state = state.copyWith(exportHistory: [entry, ...state.exportHistory]);
    _recordAudit(
      actor: actor,
      action: 'report_exported',
      resourceType: 'report',
      resourceId: entry.exportId,
      summary: 'Exported $presetLabel (${entry.format}) [$filterSummary].',
    );
  }

  // --- Announcements ---

  Future<ApiEnvelope<AnnouncementDto>> saveAnnouncement({
    AnnouncementDto? existing,
    required String title,
    required String body,
    required List<String> audienceRoles,
    bool pinned = false,
    required ProfileDto actor,
  }) async {
    if (!actor.role.isAdmin) return _forbidden();
    final dto = AnnouncementDto(
      announcementId: existing?.announcementId ?? _nextId('ANN'),
      title: title.trim(),
      body: body.trim(),
      audienceRoles: audienceRoles.isEmpty
          ? const ['student', 'faculty', 'staff']
          : audienceRoles,
      pinned: pinned,
      isActive: true,
      publishedAtUtc: existing?.publishedAtUtc ?? DateTime.now().toUtc(),
      authorUserCode: actor.userCode,
    );
    if (dataSourceMode == DataSourceMode.real) {
      final res = await repository.saveAnnouncement(dto);
      if (res.ok && res.data != null) {
        final list = [
          res.data!,
          ...state.announcements
              .where((a) => a.announcementId != dto.announcementId),
        ];
        state = state.copyWith(announcements: list);
      }
      return res;
    }
    final list = [
      dto,
      ...state.announcements
          .where((a) => a.announcementId != dto.announcementId),
    ];
    state = state.copyWith(announcements: list);
    _recordAudit(
      actor: actor,
      action: existing == null ? 'announcement_created' : 'announcement_updated',
      resourceType: 'announcement',
      resourceId: dto.announcementId,
      summary: '${existing == null ? 'Published' : 'Updated'} "${dto.title}".',
    );
    return ApiEnvelope.success(dto);
  }

  Future<ApiEnvelope<bool>> deleteAnnouncement(
    String announcementId, {
    required ProfileDto actor,
  }) async {
    if (!actor.role.isAdmin) return _forbidden();
    if (dataSourceMode == DataSourceMode.real) {
      final res = await repository.deleteAnnouncement(announcementId);
      if (res.ok) {
        state = state.copyWith(
          announcements: state.announcements
              .where((a) => a.announcementId != announcementId)
              .toList(),
        );
      }
      return res;
    }
    state = state.copyWith(
      announcements: state.announcements
          .where((a) => a.announcementId != announcementId)
          .toList(),
    );
    _recordAudit(
      actor: actor,
      action: 'announcement_deleted',
      resourceType: 'announcement',
      resourceId: announcementId,
      summary: 'Removed announcement $announcementId.',
    );
    return ApiEnvelope.success(true);
  }

  // --- Guard Accounts (Admin Only) ---

  void addOrUpdateGuardAccount({
    String? existingUserId,
    required String userCode,
    required String fullName,
    required String email,
    required String assignedStation,
    bool isActive = true,
    required ProfileDto actor,
  }) {
    if (!actor.role.isAdmin || dataSourceMode == DataSourceMode.real) return;
    final list = List<ProfileDto>.from(state.guardAccounts);
    final idx = existingUserId == null
        ? -1
        : list.indexWhere((g) => g.userId == existingUserId);
    final profile = ProfileDto(
      userId: existingUserId ?? '10000000-0000-4000-8000-${_seq++}',
      userCode: userCode.trim().toUpperCase(),
      username: email.trim().toLowerCase(),
      fullName: fullName.trim(),
      role: UserRole.guard,
      assignedStation: assignedStation.trim(),
      isActive: isActive,
      email: email.trim().toLowerCase(),
    );
    if (idx >= 0) {
      list[idx] = profile;
    } else {
      list.add(profile);
    }
    state = state.copyWith(guardAccounts: list);
    _recordAudit(
      actor: actor,
      action: idx >= 0 ? 'guard_account_updated' : 'guard_account_created',
      resourceType: 'guard_account',
      resourceId: profile.userCode,
      summary:
          '${idx >= 0 ? 'Updated' : 'Created'} security guard ${profile.fullName} (${profile.userCode}).',
    );
  }

  void toggleGuardActive(
    String userId, {
    required ProfileDto actor,
  }) {
    if (!actor.role.isAdmin || dataSourceMode == DataSourceMode.real) return;
    final list = List<ProfileDto>.from(state.guardAccounts);
    final idx = list.indexWhere((g) => g.userId == userId);
    if (idx < 0) return;
    final current = list[idx];
    final next = current.copyWith(isActive: !current.isActive);
    list[idx] = next;
    state = state.copyWith(guardAccounts: list);
    _recordAudit(
      actor: actor,
      action: next.isActive ? 'guard_reactivated' : 'guard_deactivated',
      resourceType: 'guard_account',
      resourceId: next.userCode,
      summary:
          '${next.isActive ? 'Activated' : 'Deactivated'} security guard ${next.userCode}.',
    );
  }

  Future<void> refreshRealOpsSnapshot() async {
    if (dataSourceMode != DataSourceMode.real) return;
    final health = await repository.fetchSystemHealth();
    final rules = await repository.fetchParkingRules();
    final guests = await repository.fetchGuestVisitRequests();
    final anns = await repository.fetchAnnouncements();
    final settings = await repository.fetchBackendSettings();
    state = state.copyWith(
      systemHealth: health.ok && health.data != null ? health.data : null,
      parkingRules: rules.ok && rules.data != null ? rules.data : null,
      guestVisitRequests: guests.ok && guests.data != null ? guests.data : null,
      announcements: anns.ok && anns.data != null ? anns.data : null,
      backendSettings:
          settings.ok && settings.data != null ? settings.data : null,
    );
  }
}
