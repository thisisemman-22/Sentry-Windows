import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../shared/models/auth_models.dart';
import '../../../shared/models/spec_2026_models.dart';

/// Repository interface covering the 2026-11-27 Desktop operational modules:
/// System Health & Dead Letters, User/Password Reset Controls, Vehicles & RFID,
/// Parking Rules, Guests & Gate Pass Verification, Export History, Announcements,
/// Guard Accounts, and Read-Only Backend Settings.
abstract class DesktopOpsRepository {
  Future<ApiEnvelope<SystemHealthDto>> fetchSystemHealth();
  Future<ApiEnvelope<DeadLetterItemDto>> retryDeadLetter(String deadLetterId);

  Future<ApiEnvelope<bool>> resetUserPasswordToGeneral({
    required String targetUserId,
    required String actorUserId,
  });

  Future<ApiEnvelope<GeneralPasswordConfigDto>> fetchGeneralPasswordConfig();
  Future<ApiEnvelope<String>> revealGeneralPassword();
  Future<ApiEnvelope<GeneralPasswordConfigDto>> changeGeneralPassword(
    String newPassword,
  );

  Future<ApiEnvelope<bool>> reviewVehicleRequest({
    required String requestId,
    required bool approve,
    String? rejectionReason,
  });

  Future<ApiEnvelope<List<ParkingRuleDto>>> fetchParkingRules();
  Future<ApiEnvelope<ParkingRuleDto>> updateParkingRule({
    required String ruleKey,
    required String valueText,
  });

  Future<ApiEnvelope<List<GuestVisitRequestDto>>> fetchGuestVisitRequests();
  Future<ApiEnvelope<GuestVisitRequestDto>> reviewGuestVisitRequest({
    required String visitRequestId,
    required bool approve,
    String? rejectionReason,
  });

  Future<ApiEnvelope<GuestGateVerificationResultDto>> verifyGuestGatePass({
    required String passCode,
    required String laneId,
  });

  Future<ApiEnvelope<List<AnnouncementDto>>> fetchAnnouncements();
  Future<ApiEnvelope<AnnouncementDto>> saveAnnouncement(AnnouncementDto item);
  Future<ApiEnvelope<bool>> deleteAnnouncement(String announcementId);

  Future<ApiEnvelope<BackendSystemSettingsDto>> fetchBackendSettings();
}

/// Production (`DATA_SOURCE=real`) HTTP repository wired via [ApiClient].
/// Pending backend routes carry explicit `// TODO(API)` endpoint notes and fail
/// closed cleanly without returning mock data.
class RealDesktopOpsRepository implements DesktopOpsRepository {
  final ApiClient apiClient;

  const RealDesktopOpsRepository({required this.apiClient});

  @override
  Future<ApiEnvelope<SystemHealthDto>> fetchSystemHealth() {
    // TODO(API): confirm GET /api/v1/admin/system-health endpoint path
    return apiClient.get<SystemHealthDto>(
      '/api/v1/admin/system-health',
      parser: (json) => SystemHealthDto.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<ApiEnvelope<DeadLetterItemDto>> retryDeadLetter(String deadLetterId) {
    // TODO(API): confirm POST /api/v1/admin/dead-letters/{id}/retry endpoint
    return apiClient.post<DeadLetterItemDto>(
      '/api/v1/admin/dead-letters/$deadLetterId/retry',
      body: const {},
      parser: (json) =>
          DeadLetterItemDto.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<ApiEnvelope<bool>> resetUserPasswordToGeneral({
    required String targetUserId,
    required String actorUserId,
  }) {
    // TODO(API): confirm POST /api/v1/admin/users/{id}/reset-password endpoint
    return apiClient.post<bool>(
      '/api/v1/admin/users/$targetUserId/reset-password',
      body: {'actor_user_id': actorUserId},
      parser: (_) => true,
    );
  }

  @override
  Future<ApiEnvelope<GeneralPasswordConfigDto>> fetchGeneralPasswordConfig() {
    // TODO(API): confirm GET /api/v1/admin/settings/general-password metadata route
    return apiClient.get<GeneralPasswordConfigDto>(
      '/api/v1/admin/settings/general-password',
      parser: (json) {
        final m = json as Map<String, dynamic>;
        return GeneralPasswordConfigDto(
          maskedValue: m['masked_value']?.toString() ?? '••••••••••••',
          defaultExpiryHours:
              (m['default_expiry_hours'] as num?)?.toInt() ?? 24,
          updatedAtUtc: DateTime.tryParse(m['updated_at']?.toString() ?? '')
                  ?.toUtc() ??
              DateTime.now().toUtc(),
          updatedByUserCode: m['updated_by_user_code']?.toString() ?? 'ADMIN',
        );
      },
    );
  }

  @override
  Future<ApiEnvelope<String>> revealGeneralPassword() {
    // TODO(API): confirm POST /api/v1/admin/settings/general-password/reveal
    return apiClient.post<String>(
      '/api/v1/admin/settings/general-password/reveal',
      body: const {},
      parser: (json) =>
          (json as Map<String, dynamic>)['general_password']?.toString() ?? '',
    );
  }

  @override
  Future<ApiEnvelope<GeneralPasswordConfigDto>> changeGeneralPassword(
    String newPassword,
  ) {
    // TODO(API): confirm PUT /api/v1/admin/settings/general-password
    return apiClient.post<GeneralPasswordConfigDto>(
      '/api/v1/admin/settings/general-password',
      body: {'new_password': newPassword},
      parser: (json) {
        final m = json as Map<String, dynamic>;
        return GeneralPasswordConfigDto(
          maskedValue: m['masked_value']?.toString() ?? '••••••••••••',
          defaultExpiryHours:
              (m['default_expiry_hours'] as num?)?.toInt() ?? 24,
          updatedAtUtc: DateTime.now().toUtc(),
          updatedByUserCode: m['updated_by_user_code']?.toString() ?? 'ADMIN',
        );
      },
    );
  }

  @override
  Future<ApiEnvelope<bool>> reviewVehicleRequest({
    required String requestId,
    required bool approve,
    String? rejectionReason,
  }) {
    // TODO(API): confirm POST /api/v1/admin/vehicle-requests/{id}/decision
    return apiClient.post<bool>(
      '/api/v1/admin/vehicle-requests/$requestId/decision',
      body: {
        'decision': approve ? 'approved' : 'rejected',
        if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
          'rejection_reason': rejectionReason.trim(),
      },
      parser: (_) => true,
    );
  }

  @override
  Future<ApiEnvelope<List<ParkingRuleDto>>> fetchParkingRules() {
    // TODO(API): confirm GET /api/v1/parking-rules endpoint
    return apiClient.get<List<ParkingRuleDto>>(
      '/api/v1/parking-rules',
      parser: (json) {
        final list = (json is Map<String, dynamic> ? json['items'] : json)
                as List<dynamic>? ??
            const [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(ParkingRuleDto.fromJson)
            .toList();
      },
    );
  }

  @override
  Future<ApiEnvelope<ParkingRuleDto>> updateParkingRule({
    required String ruleKey,
    required String valueText,
  }) {
    // TODO(API): confirm PATCH /api/v1/admin/parking-rules/{rule_key}
    return apiClient.patch<ParkingRuleDto>(
      '/api/v1/admin/parking-rules/$ruleKey',
      body: {'value_text': valueText},
      parser: (json) => ParkingRuleDto.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<ApiEnvelope<List<GuestVisitRequestDto>>> fetchGuestVisitRequests() {
    // TODO(API): confirm GET /api/v1/admin/guests/visit-requests endpoint
    return apiClient.get<List<GuestVisitRequestDto>>(
      '/api/v1/admin/guests/visit-requests',
      parser: (json) {
        final list = (json is Map<String, dynamic> ? json['items'] : json)
                as List<dynamic>? ??
            const [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(GuestVisitRequestDto.fromJson)
            .toList();
      },
    );
  }

  @override
  Future<ApiEnvelope<GuestVisitRequestDto>> reviewGuestVisitRequest({
    required String visitRequestId,
    required bool approve,
    String? rejectionReason,
  }) {
    // TODO(API): confirm POST /api/v1/admin/guests/visit-requests/{id}/decision
    return apiClient.post<GuestVisitRequestDto>(
      '/api/v1/admin/guests/visit-requests/$visitRequestId/decision',
      body: {
        'decision': approve ? 'approved' : 'rejected',
        if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
          'rejection_reason': rejectionReason.trim(),
      },
      parser: (json) =>
          GuestVisitRequestDto.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<ApiEnvelope<GuestGateVerificationResultDto>> verifyGuestGatePass({
    required String passCode,
    required String laneId,
  }) {
    // TODO(API): confirm POST /api/v1/gate/guest-passes/verify
    return apiClient.post<GuestGateVerificationResultDto>(
      '/api/v1/gate/guest-passes/verify',
      body: {
        'pass_code': passCode,
        'lane_id': laneId,
      },
      parser: (json) =>
          GuestGateVerificationResultDto.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<ApiEnvelope<List<AnnouncementDto>>> fetchAnnouncements() {
    // TODO(API): confirm GET /api/v1/admin/announcements
    return apiClient.get<List<AnnouncementDto>>(
      '/api/v1/admin/announcements',
      parser: (json) {
        final list = (json is Map<String, dynamic> ? json['items'] : json)
                as List<dynamic>? ??
            const [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(AnnouncementDto.fromJson)
            .toList();
      },
    );
  }

  @override
  Future<ApiEnvelope<AnnouncementDto>> saveAnnouncement(AnnouncementDto item) {
    // TODO(API): confirm POST /api/v1/admin/announcements
    return apiClient.post<AnnouncementDto>(
      '/api/v1/admin/announcements',
      body: {
        'announcement_id': item.announcementId,
        'title': item.title,
        'body': item.body,
        'audience_roles': item.audienceRoles,
        'pinned': item.pinned,
      },
      parser: (json) => AnnouncementDto.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<ApiEnvelope<bool>> deleteAnnouncement(String announcementId) {
    // TODO(API): confirm DELETE /api/v1/admin/announcements/{id}
    return apiClient.delete<bool>(
      '/api/v1/admin/announcements/$announcementId',
      parser: (_) => true,
    );
  }

  @override
  Future<ApiEnvelope<BackendSystemSettingsDto>> fetchBackendSettings() {
    // TODO(API): confirm GET /api/v1/admin/settings/system
    return apiClient.get<BackendSystemSettingsDto>(
      '/api/v1/admin/settings/system',
      parser: (json) =>
          BackendSystemSettingsDto.fromJson(json as Map<String, dynamic>),
    );
  }
}

/// Offline Developer Test Mode fixtures & simulation data (strictly gated
/// behind `devModeUnlockedProvider`).
class MockDesktopOpsData {
  MockDesktopOpsData._();

  static SystemHealthDto initialHealth(DateTime now) => SystemHealthDto(
        overallStatus: 'degraded',
        schedulerStatus: 'running',
        updatedAtUtc: now.subtract(const Duration(seconds: 12)),
        deadLetters: [
          DeadLetterItemDto(
            id: 'DLQ-101',
            channel: 'email',
            recipient: 'guest.juan@example.test',
            eventType: 'guest_visit_approved',
            errorMessage: 'SMTP gateway timeout after 30s',
            attempts: 2,
            failedAtUtc: now.subtract(const Duration(minutes: 9)),
            status: 'failed',
          ),
          DeadLetterItemDto(
            id: 'DLQ-102',
            channel: 'push',
            recipient: 'U004 (FCM token)',
            eventType: 'guard_review_notice',
            errorMessage: 'Transient upstream 503',
            attempts: 1,
            failedAtUtc: now.subtract(const Duration(minutes: 4)),
            status: 'failed',
          ),
        ],
      );

  static List<VehicleApprovalRequestDto> initialVehicleRequests(DateTime now) =>
      [
        VehicleApprovalRequestDto(
          requestId: 'VR-001',
          userId: '10000000-0000-4000-8000-000000000002',
          userCode: 'U002',
          userFullName: 'Maximus Catacutan',
          userRole: 'student',
          vehicleType: 'car',
          plateNumber: 'NGA 4021',
          status: 'pending',
          submittedAtUtc: now.subtract(const Duration(hours: 2)),
        ),
        VehicleApprovalRequestDto(
          requestId: 'VR-002',
          userId: '10000000-0000-4000-8000-000000000004',
          userCode: 'U004',
          userFullName: 'Leila Navarro',
          userRole: 'faculty',
          vehicleType: 'motorcycle',
          plateNumber: 'MCO 918',
          rfidUid: '0491C2E4',
          status: 'pending',
          submittedAtUtc: now.subtract(const Duration(minutes: 42)),
        ),
      ];

  static List<RfidTagDto> initialRfidTags(DateTime now) => [
        RfidTagDto(
          tagId: 'TAG-01',
          rfidUid: '04D4E5F6',
          status: 'active',
          assignedVehicleCode: 'V004',
          assignedUserCode: 'U004',
          registeredAtUtc: now.subtract(const Duration(days: 14)),
        ),
        RfidTagDto(
          tagId: 'TAG-02',
          rfidUid: '04B1A9C2',
          status: 'active',
          assignedVehicleCode: 'V008',
          assignedUserCode: 'U007',
          registeredAtUtc: now.subtract(const Duration(days: 8)),
        ),
        RfidTagDto(
          tagId: 'TAG-03',
          rfidUid: '04FF102A',
          status: 'unassigned',
          registeredAtUtc: now.subtract(const Duration(days: 2)),
        ),
      ];

  static List<FaceEnrollmentHistoryEntry> initialFaceHistory(DateTime now) => [
        FaceEnrollmentHistoryEntry(
          entryId: 'FE-001',
          userCode: 'U001',
          action: 'enrolled',
          consentVersion: 'RA10173-BSU-2026.1',
          actorUserCode: 'A001',
          occurredAtUtc: now.subtract(const Duration(days: 10)),
        ),
        FaceEnrollmentHistoryEntry(
          entryId: 'FE-002',
          userCode: 'U004',
          action: 're_enrolled',
          consentVersion: 'RA10173-BSU-2026.1',
          actorUserCode: 'A001',
          occurredAtUtc: now.subtract(const Duration(days: 3)),
        ),
      ];

  static List<ParkingRuleDto> initialParkingRules(DateTime now) => [
        ParkingRuleDto(
          ruleKey: 'space_hold_ttl_sec',
          title: 'Pre-passage Space Hold TTL',
          description: 'Duration a bay stays held after Gate 1 ALLOW verdict.',
          valueText: '30 seconds',
          updatedAtUtc: now.subtract(const Duration(days: 5)),
          updatedByUserCode: 'A001',
        ),
        ParkingRuleDto(
          ruleKey: 'decision_ttl_sec',
          title: 'Gate Decision Expiration',
          description: 'Time window before gate attestation expires.',
          valueText: '20 seconds',
          updatedAtUtc: now.subtract(const Duration(days: 5)),
          updatedByUserCode: 'A001',
        ),
        ParkingRuleDto(
          ruleKey: 'single_active_visit',
          title: 'One Active Visit Per Owner',
          description:
              'Blocks simultaneous campus entry for second vehicle of same owner (U007 rule).',
          valueText: 'Enabled (Strict)',
          updatedAtUtc: now.subtract(const Duration(days: 12)),
          updatedByUserCode: 'A001',
        ),
      ];

  static List<GuestVisitRequestDto> initialGuestRequests(DateTime now) {
    final todayStart = DateTime.utc(now.year, now.month, now.day, 1);
    return [
      GuestVisitRequestDto(
        visitRequestId: 'GV-201',
        guestAccountId: 'GA-101',
        guestFullName: 'Engr. Carlo Mendoza',
        guestEmail: 'c.mendoza@industry.example',
        hostName: 'Dean, CEAFA',
        hostDepartment: 'CEAFA',
        purpose: 'ABET Accreditation Panel Visit',
        visitDateUtc: todayStart,
        windowStartUtc: now.subtract(const Duration(hours: 1)),
        windowEndUtc: now.add(const Duration(hours: 4)),
        vehicleType: 'car',
        plateNumber: 'VSA 771',
        status: 'pending',
      ),
      GuestVisitRequestDto(
        visitRequestId: 'GV-202',
        guestAccountId: 'GA-102',
        guestFullName: 'Atty. Patricia Reyes',
        guestEmail: 'p.reyes@legal.example',
        hostName: 'Campus Registrar',
        hostDepartment: 'REGISTRAR',
        purpose: 'Records Compliance Inspection',
        visitDateUtc: todayStart,
        windowStartUtc: now.subtract(const Duration(hours: 5)),
        windowEndUtc: now.subtract(const Duration(hours: 1)),
        vehicleType: 'car',
        plateNumber: 'DAB 509',
        status: 'approved',
        isCurrentlyInside: true, // Overdue guest car still inside past window!
        checkedInAtUtc: now.subtract(const Duration(hours: 4, minutes: 30)),
      ),
      GuestVisitRequestDto(
        visitRequestId: 'GV-203',
        guestAccountId: 'GA-103',
        guestFullName: 'Dr. Tomas Aquino',
        guestEmail: 't.aquino@partner.example',
        hostName: 'CICS Department',
        hostDepartment: 'CICS',
        purpose: 'Capstone Colloquium Judge',
        visitDateUtc: todayStart.add(const Duration(days: 1)),
        windowStartUtc: now.add(const Duration(hours: 12)),
        windowEndUtc: now.add(const Duration(hours: 18)),
        vehicleType: 'car',
        plateNumber: 'NBB 118',
        status: 'approved',
      ),
    ];
  }

  static List<GuestAccountDto> initialGuestAccounts(DateTime now) => [
        GuestAccountDto(
          guestAccountId: 'GA-101',
          fullName: 'Engr. Carlo Mendoza',
          email: 'c.mendoza@industry.example',
          phone: '+63 917 555 0141',
          status: 'active',
          createdAtUtc: now.subtract(const Duration(days: 3)),
        ),
        GuestAccountDto(
          guestAccountId: 'GA-102',
          fullName: 'Atty. Patricia Reyes',
          email: 'p.reyes@legal.example',
          phone: '+63 918 555 0192',
          status: 'active',
          createdAtUtc: now.subtract(const Duration(days: 7)),
        ),
      ];

  static List<AnnouncementDto> initialAnnouncements(DateTime now) => [
        AnnouncementDto(
          announcementId: 'ANN-01',
          title: 'Lot B3 CEAFA 1 Gate Calibration Notice',
          body:
              'Automated overhead cameras at Lot B3 are live. Use designated bays L1–L9 and R1–R10; R10 is reserved for PWD.',
          audienceRoles: const ['student', 'faculty', 'staff'],
          pinned: true,
          isActive: true,
          publishedAtUtc: now.subtract(const Duration(hours: 6)),
        ),
      ];

  static List<ProfileDto> initialGuardAccounts() => [
        const ProfileDto(
          userId: '10000000-0000-4000-8000-000000000101',
          userCode: 'G001',
          username: 'guard01@sentry.test',
          fullName: 'Harper Guard (Gate 1 Duty)',
          role: UserRole.guard,
          assignedStation: 'Gate 1 North Command Booth',
          isActive: true,
          email: 'guard01@sentry.test',
        ),
        const ProfileDto(
          userId: '10000000-0000-4000-8000-000000000102',
          userCode: 'G002',
          username: 'guard02@sentry.test',
          fullName: 'Mateo Cruz (Gate 2 South)',
          role: UserRole.guard,
          assignedStation: 'Gate 2 Exit Booth',
          isActive: true,
          email: 'guard02@sentry.test',
        ),
      ];

  static BackendSystemSettingsDto initialBackendSettings() =>
      const BackendSystemSettingsDto(
        accessSessionMinutes: 15,
        refreshSessionHours: 168,
        maxLoginAttempts: 5,
        lockoutMinutes: 15,
        contractVersion: '1.0.0',
        signingKeyStatus: 'RS256 Active (kid: sentry-2026-q4)',
        corsOrigins: [
          'https://sentry.batstate-u.edu.ph',
          'http://127.0.0.1:8000',
        ],
        databaseConnected: true,
        databaseLatencyMs: 6,
        generalPasswordExpiryHours: 24,
      );
}
