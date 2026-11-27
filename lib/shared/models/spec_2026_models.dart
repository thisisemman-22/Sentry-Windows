import '../../core/network/api_envelope.dart';

/// Dead-letter delivery item surfaced on Dashboard System Health (`D`).
class DeadLetterItemDto {
  final String id;
  final String channel; // 'email' | 'push' | 'ws'
  final String recipient;
  final String eventType;
  final String errorMessage;
  final int attempts;
  final DateTime failedAtUtc;
  final String status; // 'failed' | 'resolved'

  const DeadLetterItemDto({
    required this.id,
    required this.channel,
    required this.recipient,
    required this.eventType,
    required this.errorMessage,
    required this.attempts,
    required this.failedAtUtc,
    this.status = 'failed',
  });

  DeadLetterItemDto copyWith({
    int? attempts,
    String? status,
  }) {
    return DeadLetterItemDto(
      id: id,
      channel: channel,
      recipient: recipient,
      eventType: eventType,
      errorMessage: errorMessage,
      attempts: attempts ?? this.attempts,
      failedAtUtc: failedAtUtc,
      status: status ?? this.status,
    );
  }

  factory DeadLetterItemDto.fromJson(Map<String, dynamic> json) {
    return DeadLetterItemDto(
      id: json['id']?.toString() ?? '',
      channel: json['channel']?.toString() ?? 'email',
      recipient: json['recipient']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? 'notification',
      errorMessage: json['error_message']?.toString() ?? 'Delivery failed',
      attempts: (json['attempts'] as num?)?.toInt() ?? 1,
      failedAtUtc:
          DateTime.tryParse(json['failed_at']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      status: json['status']?.toString() ?? 'failed',
    );
  }
}

/// System Health & Scheduler telemetry surfaced on Dashboard.
class SystemHealthDto {
  final String overallStatus; // 'healthy' | 'degraded'
  final String schedulerStatus; // 'running' | 'degraded'
  final DateTime? updatedAtUtc;
  final List<DeadLetterItemDto> deadLetters;

  const SystemHealthDto({
    required this.overallStatus,
    required this.schedulerStatus,
    this.updatedAtUtc,
    this.deadLetters = const [],
  });

  const SystemHealthDto.empty()
      : overallStatus = 'unknown',
        schedulerStatus = 'unknown',
        updatedAtUtc = null,
        deadLetters = const [];

  SystemHealthDto copyWith({
    String? overallStatus,
    String? schedulerStatus,
    DateTime? updatedAtUtc,
    List<DeadLetterItemDto>? deadLetters,
  }) {
    return SystemHealthDto(
      overallStatus: overallStatus ?? this.overallStatus,
      schedulerStatus: schedulerStatus ?? this.schedulerStatus,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      deadLetters: deadLetters ?? this.deadLetters,
    );
  }

  factory SystemHealthDto.fromJson(Map<String, dynamic> json) {
    final rawLetters = json['dead_letters'];
    return SystemHealthDto(
      overallStatus: json['overall_status']?.toString() ?? 'healthy',
      schedulerStatus: json['scheduler_status']?.toString() ?? 'running',
      updatedAtUtc:
          DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toUtc(),
      deadLetters: rawLetters is List
          ? rawLetters
              .whereType<Map<String, dynamic>>()
              .map(DeadLetterItemDto.fromJson)
              .toList()
          : const [],
    );
  }
}

/// Masked / Revealable General First-Login Password settings.
class GeneralPasswordConfigDto {
  final String maskedValue;
  final String? revealedValue;
  final int defaultExpiryHours;
  final DateTime updatedAtUtc;
  final String updatedByUserCode;

  const GeneralPasswordConfigDto({
    this.maskedValue = '••••••••••••',
    this.revealedValue,
    this.defaultExpiryHours = 24,
    required this.updatedAtUtc,
    this.updatedByUserCode = 'A001',
  });

  GeneralPasswordConfigDto copyWith({
    String? maskedValue,
    String? revealedValue,
    bool clearRevealed = false,
    int? defaultExpiryHours,
    DateTime? updatedAtUtc,
    String? updatedByUserCode,
  }) {
    return GeneralPasswordConfigDto(
      maskedValue: maskedValue ?? this.maskedValue,
      revealedValue:
          clearRevealed ? null : (revealedValue ?? this.revealedValue),
      defaultExpiryHours: defaultExpiryHours ?? this.defaultExpiryHours,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      updatedByUserCode: updatedByUserCode ?? this.updatedByUserCode,
    );
  }
}

/// User-submitted vehicle approval request (`pending | approved | rejected`).
class VehicleApprovalRequestDto {
  final String requestId;
  final String userId;
  final String userCode;
  final String userFullName;
  final String userRole;
  final String vehicleType; // 'car' | 'motorcycle'
  final String? plateNumber;
  final String? rfidUid;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;
  final DateTime submittedAtUtc;

  const VehicleApprovalRequestDto({
    required this.requestId,
    required this.userId,
    required this.userCode,
    required this.userFullName,
    required this.userRole,
    required this.vehicleType,
    this.plateNumber,
    this.rfidUid,
    this.status = 'pending',
    this.rejectionReason,
    required this.submittedAtUtc,
  });

  VehicleApprovalRequestDto copyWith({
    String? status,
    String? rejectionReason,
  }) {
    return VehicleApprovalRequestDto(
      requestId: requestId,
      userId: userId,
      userCode: userCode,
      userFullName: userFullName,
      userRole: userRole,
      vehicleType: vehicleType,
      plateNumber: plateNumber,
      rfidUid: rfidUid,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAtUtc: submittedAtUtc,
    );
  }

  factory VehicleApprovalRequestDto.fromJson(Map<String, dynamic> json) {
    return VehicleApprovalRequestDto(
      requestId: json['request_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userCode: json['user_code']?.toString() ?? '',
      userFullName: json['user_full_name']?.toString() ?? '',
      userRole: json['user_role']?.toString() ?? 'student',
      vehicleType: json['vehicle_type']?.toString() ?? 'car',
      plateNumber: json['plate_number']?.toString(),
      rfidUid: json['rfid_uid']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      submittedAtUtc:
          DateTime.tryParse(json['submitted_at']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

/// RFID inventory tag entry (`active | unassigned | deactivated | replaced`).
class RfidTagDto {
  final String tagId;
  final String rfidUid;
  final String status; // 'active' | 'unassigned' | 'deactivated' | 'replaced'
  final String? assignedVehicleCode;
  final String? assignedUserCode;
  final String? replacedByUid;
  final DateTime registeredAtUtc;

  const RfidTagDto({
    required this.tagId,
    required this.rfidUid,
    required this.status,
    this.assignedVehicleCode,
    this.assignedUserCode,
    this.replacedByUid,
    required this.registeredAtUtc,
  });

  RfidTagDto copyWith({
    String? status,
    String? assignedVehicleCode,
    String? assignedUserCode,
    bool clearAssignment = false,
    String? replacedByUid,
  }) {
    return RfidTagDto(
      tagId: tagId,
      rfidUid: rfidUid,
      status: status ?? this.status,
      assignedVehicleCode: clearAssignment
          ? null
          : (assignedVehicleCode ?? this.assignedVehicleCode),
      assignedUserCode:
          clearAssignment ? null : (assignedUserCode ?? this.assignedUserCode),
      replacedByUid: replacedByUid ?? this.replacedByUid,
      registeredAtUtc: registeredAtUtc,
    );
  }

  factory RfidTagDto.fromJson(Map<String, dynamic> json) {
    return RfidTagDto(
      tagId: json['tag_id']?.toString() ?? '',
      rfidUid: json['rfid_uid']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      assignedVehicleCode: json['assigned_vehicle_code']?.toString(),
      assignedUserCode: json['assigned_user_code']?.toString(),
      replacedByUid: json['replaced_by_uid']?.toString(),
      registeredAtUtc:
          DateTime.tryParse(json['registered_at']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

/// Biometric enrollment lifecycle audit entry (metadata only, zero images).
class FaceEnrollmentHistoryEntry {
  final String entryId;
  final String userCode;
  final String
      action; // 'consent_recorded' | 'enrolled' | 're_enrolled' | 'withdrawn' | 'cancelled'
  final String consentVersion;
  final String actorUserCode;
  final DateTime occurredAtUtc;

  const FaceEnrollmentHistoryEntry({
    required this.entryId,
    required this.userCode,
    required this.action,
    required this.consentVersion,
    required this.actorUserCode,
    required this.occurredAtUtc,
  });
}

/// Configurable campus parking rule + change log.
class ParkingRuleDto {
  final String ruleKey;
  final String title;
  final String description;
  final String valueText;
  final DateTime updatedAtUtc;
  final String updatedByUserCode;

  const ParkingRuleDto({
    required this.ruleKey,
    required this.title,
    required this.description,
    required this.valueText,
    required this.updatedAtUtc,
    required this.updatedByUserCode,
  });

  ParkingRuleDto copyWith({
    String? valueText,
    DateTime? updatedAtUtc,
    String? updatedByUserCode,
  }) {
    return ParkingRuleDto(
      ruleKey: ruleKey,
      title: title,
      description: description,
      valueText: valueText ?? this.valueText,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      updatedByUserCode: updatedByUserCode ?? this.updatedByUserCode,
    );
  }

  factory ParkingRuleDto.fromJson(Map<String, dynamic> json) {
    return ParkingRuleDto(
      ruleKey: json['rule_key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      valueText: json['value_text']?.toString() ?? '',
      updatedAtUtc:
          DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      updatedByUserCode: json['updated_by_user_code']?.toString() ?? 'A001',
    );
  }
}

class ParkingRuleChangeDto {
  final String changeId;
  final String ruleKey;
  final String ruleTitle;
  final String previousValue;
  final String newValue;
  final String actorUserCode;
  final DateTime changedAtUtc;

  const ParkingRuleChangeDto({
    required this.changeId,
    required this.ruleKey,
    required this.ruleTitle,
    required this.previousValue,
    required this.newValue,
    required this.actorUserCode,
    required this.changedAtUtc,
  });
}

/// Admin Guest Visit Request DTO.
///
/// SECURITY RULE: Intentionally omits any guest `BSUAL-XXXX` pass code!
/// The 4-digit pass code is generated exclusively on the guest's mobile app
/// after approval and verified only by Security Guards at the gate.
class GuestVisitRequestDto {
  final String visitRequestId;
  final String guestAccountId;
  final String guestFullName;
  final String guestEmail;
  final String hostName;
  final String hostDepartment;
  final String purpose;
  final DateTime visitDateUtc;
  final DateTime windowStartUtc;
  final DateTime windowEndUtc;
  final String vehicleType;
  final String plateNumber;
  final String status; // 'pending' | 'approved' | 'rejected' | 'cancelled' | 'expired'
  final String? rejectionReason;
  final bool isCurrentlyInside;
  final DateTime? checkedInAtUtc;

  const GuestVisitRequestDto({
    required this.visitRequestId,
    required this.guestAccountId,
    required this.guestFullName,
    required this.guestEmail,
    required this.hostName,
    required this.hostDepartment,
    required this.purpose,
    required this.visitDateUtc,
    required this.windowStartUtc,
    required this.windowEndUtc,
    required this.vehicleType,
    required this.plateNumber,
    required this.status,
    this.rejectionReason,
    this.isCurrentlyInside = false,
    this.checkedInAtUtc,
  });

  bool isOverdue([DateTime? nowUtc]) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    return isCurrentlyInside && now.isAfter(windowEndUtc);
  }

  GuestVisitRequestDto copyWith({
    String? status,
    String? rejectionReason,
    bool? isCurrentlyInside,
  }) {
    return GuestVisitRequestDto(
      visitRequestId: visitRequestId,
      guestAccountId: guestAccountId,
      guestFullName: guestFullName,
      guestEmail: guestEmail,
      hostName: hostName,
      hostDepartment: hostDepartment,
      purpose: purpose,
      visitDateUtc: visitDateUtc,
      windowStartUtc: windowStartUtc,
      windowEndUtc: windowEndUtc,
      vehicleType: vehicleType,
      plateNumber: plateNumber,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isCurrentlyInside: isCurrentlyInside ?? this.isCurrentlyInside,
      checkedInAtUtc: checkedInAtUtc,
    );
  }

  factory GuestVisitRequestDto.fromJson(Map<String, dynamic> json) {
    final start =
        DateTime.tryParse(json['window_start']?.toString() ?? '')?.toUtc() ??
            DateTime.now().toUtc();
    return GuestVisitRequestDto(
      visitRequestId: json['visit_request_id']?.toString() ?? '',
      guestAccountId: json['guest_account_id']?.toString() ?? '',
      guestFullName: json['guest_full_name']?.toString() ?? '',
      guestEmail: json['guest_email']?.toString() ?? '',
      hostName: json['host_name']?.toString() ?? '',
      hostDepartment: json['host_department']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      visitDateUtc:
          DateTime.tryParse(json['visit_date']?.toString() ?? '')?.toUtc() ??
              start,
      windowStartUtc: start,
      windowEndUtc:
          DateTime.tryParse(json['window_end']?.toString() ?? '')?.toUtc() ??
              start.add(const Duration(hours: 4)),
      vehicleType: json['vehicle_type']?.toString() ?? 'car',
      plateNumber: json['plate_number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      isCurrentlyInside: json['is_currently_inside'] == true,
      checkedInAtUtc:
          DateTime.tryParse(json['checked_in_at']?.toString() ?? '')?.toUtc(),
    );
  }
}

class GuestAccountDto {
  final String guestAccountId;
  final String fullName;
  final String email;
  final String phone;
  final String status; // 'active' | 'suspended' | 'first_login_required'
  final DateTime createdAtUtc;

  const GuestAccountDto({
    required this.guestAccountId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.status = 'active',
    required this.createdAtUtc,
  });

  GuestAccountDto copyWith({String? status}) {
    return GuestAccountDto(
      guestAccountId: guestAccountId,
      fullName: fullName,
      email: email,
      phone: phone,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
    );
  }

  factory GuestAccountDto.fromJson(Map<String, dynamic> json) {
    return GuestAccountDto(
      guestAccountId: json['guest_account_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      createdAtUtc:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

class GuestGateVerificationResultDto {
  final String passCode;
  final bool verified;
  final String? guestFullName;
  final String? plateNumber;
  final String? hostName;
  final String? windowLabel;
  final String message;

  const GuestGateVerificationResultDto({
    required this.passCode,
    required this.verified,
    this.guestFullName,
    this.plateNumber,
    this.hostName,
    this.windowLabel,
    required this.message,
  });

  factory GuestGateVerificationResultDto.fromJson(Map<String, dynamic> json) {
    return GuestGateVerificationResultDto(
      passCode: json['pass_code']?.toString() ?? '',
      verified: json['verified'] == true,
      guestFullName: json['guest_full_name']?.toString(),
      plateNumber: json['plate_number']?.toString(),
      hostName: json['host_name']?.toString(),
      windowLabel: json['window_label']?.toString(),
      message: json['message']?.toString() ?? 'Verification processed.',
    );
  }
}

/// Normalizes typed or pasted guest pass codes (`bsual 1234`, `BSUAL-1234`, `1234`)
/// into the exact 4-digit string, returning `null` when invalid.
String? normalizeGuestPassDigits(String raw) {
  var normalized = raw.toUpperCase().replaceAll(RegExp(r'[\s\-–—_]+'), '');
  if (normalized.startsWith('BSUAL')) {
    normalized = normalized.substring(5);
  }
  if (!RegExp(r'^[0-9]{4}$').hasMatch(normalized)) {
    return null;
  }
  return normalized;
}

/// Normalizes typed or pasted guest pass codes into canonical `BSUAL-XXXX` format.
String? normalizeGuestPassCode(String raw) {
  final digits = normalizeGuestPassDigits(raw);
  return digits == null ? null : 'BSUAL-$digits';
}

/// Pre-confirmation Guest Check lookup result showing Guest Name, Visit Date
/// & Time Window, and Vehicle (type & plate) so Guards can match physical ID.
class GuestPassLookupDto {
  final String passCode;
  final String visitRequestId;
  final String guestFullName;
  final DateTime visitDateUtc;
  final DateTime windowStartUtc;
  final DateTime windowEndUtc;
  final String windowLabel;
  final String vehicleType;
  final String plateNumber;
  final String hostName;
  final String purpose;
  final bool alreadyConfirmed;

  const GuestPassLookupDto({
    required this.passCode,
    required this.visitRequestId,
    required this.guestFullName,
    required this.visitDateUtc,
    required this.windowStartUtc,
    required this.windowEndUtc,
    required this.windowLabel,
    required this.vehicleType,
    required this.plateNumber,
    required this.hostName,
    required this.purpose,
    this.alreadyConfirmed = false,
  });

  factory GuestPassLookupDto.fromJson(Map<String, dynamic> json) {
    final start =
        DateTime.tryParse(json['window_start']?.toString() ?? '')?.toUtc() ??
            DateTime.now().toUtc();
    return GuestPassLookupDto(
      passCode: json['pass_code']?.toString() ?? '',
      visitRequestId: json['visit_request_id']?.toString() ?? '',
      guestFullName: json['guest_full_name']?.toString() ?? 'Campus Guest',
      visitDateUtc:
          DateTime.tryParse(json['visit_date']?.toString() ?? '')?.toUtc() ??
              start,
      windowStartUtc: start,
      windowEndUtc:
          DateTime.tryParse(json['window_end']?.toString() ?? '')?.toUtc() ??
              start.add(const Duration(hours: 4)),
      windowLabel: json['window_label']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? 'car',
      plateNumber: json['plate_number']?.toString() ?? 'UNSPECIFIED',
      hostName: json['host_name']?.toString() ?? 'Host Department',
      purpose: json['purpose']?.toString() ?? 'Approved campus visit',
      alreadyConfirmed: json['already_confirmed'] == true,
    );
  }
}

/// Guard Manual Entry log for Guest Motorcycles & Guests on Foot.
class ManualGuestEntryDto {
  final String entryId;
  final String entryCategory; // 'guest_motorcycle' | 'guest_on_foot'
  final String guestFullName;
  final String? passCode;
  final String? plateOrDescription;
  final String? purposeAndIdCheck;
  final String notes;
  final String recordedByUserCode;
  final DateTime recordedAtUtc;

  const ManualGuestEntryDto({
    required this.entryId,
    required this.entryCategory,
    required this.guestFullName,
    this.passCode,
    this.plateOrDescription,
    this.purposeAndIdCheck,
    required this.notes,
    required this.recordedByUserCode,
    required this.recordedAtUtc,
  });

  bool get isMotorcycle => entryCategory == 'guest_motorcycle';

  factory ManualGuestEntryDto.fromJson(Map<String, dynamic> json) {
    return ManualGuestEntryDto(
      entryId: json['entry_id']?.toString() ?? '',
      entryCategory: json['entry_category']?.toString() ?? 'guest_motorcycle',
      guestFullName: json['guest_full_name']?.toString() ?? '',
      passCode: json['pass_code']?.toString(),
      plateOrDescription: json['plate_or_description']?.toString(),
      purposeAndIdCheck: json['purpose_and_id_check']?.toString(),
      notes: json['notes']?.toString() ?? '',
      recordedByUserCode: json['recorded_by_user_code']?.toString() ?? 'G001',
      recordedAtUtc:
          DateTime.tryParse(json['recorded_at']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'entry_id': entryId,
        'entry_category': entryCategory,
        'guest_full_name': guestFullName,
        if (passCode != null && passCode!.isNotEmpty) 'pass_code': passCode,
        if (plateOrDescription != null && plateOrDescription!.isNotEmpty)
          'plate_or_description': plateOrDescription,
        if (purposeAndIdCheck != null && purposeAndIdCheck!.isNotEmpty)
          'purpose_and_id_check': purposeAndIdCheck,
        'notes': notes,
        'recorded_by_user_code': recordedByUserCode,
        'recorded_at': ManilaTime.toUtcIso(recordedAtUtc),
      };
}

/// 6 Report Presets per 2026-11-27 Desktop Spec.
enum ReportPreset {
  occupancy('occupancy', 'Occupancy', false),
  entriesExits('entries_exits', 'Entries & Exits', false),
  vehicles('vehicles', 'Vehicles', true),
  users('users', 'Users', true),
  guests('guests', 'Guests', true),
  reviewCases('review_cases', 'Review Cases', false);

  final String wireValue;
  final String label;
  final bool adminOnly;
  const ReportPreset(this.wireValue, this.label, this.adminOnly);
}

class ExportHistoryEntryDto {
  final String exportId;
  final String presetLabel;
  final String format; // 'csv' | 'pdf'
  final String filterSummary;
  final String exportedByUserCode;
  final DateTime exportedAtUtc;

  const ExportHistoryEntryDto({
    required this.exportId,
    required this.presetLabel,
    required this.format,
    required this.filterSummary,
    required this.exportedByUserCode,
    required this.exportedAtUtc,
  });
}

class AnnouncementDto {
  final String announcementId;
  final String title;
  final String body;
  final List<String> audienceRoles; // 'student' | 'faculty' | 'staff'
  final bool pinned;
  final bool isActive;
  final DateTime publishedAtUtc;
  final String authorUserCode;

  const AnnouncementDto({
    required this.announcementId,
    required this.title,
    required this.body,
    this.audienceRoles = const ['student', 'faculty', 'staff'],
    this.pinned = false,
    this.isActive = true,
    required this.publishedAtUtc,
    this.authorUserCode = 'A001',
  });

  AnnouncementDto copyWith({
    String? title,
    String? body,
    List<String>? audienceRoles,
    bool? pinned,
    bool? isActive,
  }) {
    return AnnouncementDto(
      announcementId: announcementId,
      title: title ?? this.title,
      body: body ?? this.body,
      audienceRoles: audienceRoles ?? this.audienceRoles,
      pinned: pinned ?? this.pinned,
      isActive: isActive ?? this.isActive,
      publishedAtUtc: publishedAtUtc,
      authorUserCode: authorUserCode,
    );
  }

  factory AnnouncementDto.fromJson(Map<String, dynamic> json) {
    final aud = json['audience_roles'];
    return AnnouncementDto(
      announcementId: json['announcement_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      audienceRoles: aud is List
          ? aud.map((e) => e.toString()).toList()
          : const ['student', 'faculty', 'staff'],
      pinned: json['pinned'] == true,
      isActive: json['is_active'] != false,
      publishedAtUtc:
          DateTime.tryParse(json['published_at']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      authorUserCode: json['author_user_code']?.toString() ?? 'A001',
    );
  }
}

class BackendSystemSettingsDto {
  final int accessSessionMinutes;
  final int refreshSessionHours;
  final int maxLoginAttempts;
  final int lockoutMinutes;
  final String contractVersion;
  final String signingKeyStatus;
  final List<String> corsOrigins;
  final bool databaseConnected;
  final int databaseLatencyMs;
  final int generalPasswordExpiryHours;

  const BackendSystemSettingsDto({
    required this.accessSessionMinutes,
    required this.refreshSessionHours,
    required this.maxLoginAttempts,
    required this.lockoutMinutes,
    required this.contractVersion,
    required this.signingKeyStatus,
    required this.corsOrigins,
    required this.databaseConnected,
    required this.databaseLatencyMs,
    required this.generalPasswordExpiryHours,
  });

  factory BackendSystemSettingsDto.fromJson(Map<String, dynamic> json) {
    final cors = json['cors_origins'];
    return BackendSystemSettingsDto(
      accessSessionMinutes:
          (json['access_session_minutes'] as num?)?.toInt() ?? 15,
      refreshSessionHours:
          (json['refresh_session_hours'] as num?)?.toInt() ?? 168,
      maxLoginAttempts: (json['max_login_attempts'] as num?)?.toInt() ?? 5,
      lockoutMinutes: (json['lockout_minutes'] as num?)?.toInt() ?? 15,
      contractVersion: json['contract_version']?.toString() ?? '1.0.0',
      signingKeyStatus:
          json['signing_key_status']?.toString() ?? 'Active (RS256)',
      corsOrigins: cors is List ? cors.map((e) => e.toString()).toList() : [],
      databaseConnected: json['database_connected'] == true,
      databaseLatencyMs: (json['database_latency_ms'] as num?)?.toInt() ?? 0,
      generalPasswordExpiryHours:
          (json['general_password_expiry_hours'] as num?)?.toInt() ?? 24,
    );
  }
}

/// Helper to mask PII in reports and previews (e.g. `ja***@sentry.test`).
String maskIdentifierForReport(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '—';
  final atIdx = trimmed.indexOf('@');
  if (atIdx > 1) {
    final local = trimmed.substring(0, atIdx);
    final domain = trimmed.substring(atIdx);
    final keep = local.length >= 2 ? local.substring(0, 2) : local.substring(0, 1);
    return '$keep***$domain';
  }
  if (trimmed.length <= 3) return '${trimmed[0]}**';
  return '${trimmed.substring(0, 2)}***${trimmed.substring(trimmed.length - 1)}';
}

String formatPhtDate(DateTime utc) {
  final pht = ManilaTime.toManila(utc);
  return '${pht.year.toString().padLeft(4, '0')}-${pht.month.toString().padLeft(2, '0')}-${pht.day.toString().padLeft(2, '0')}';
}
