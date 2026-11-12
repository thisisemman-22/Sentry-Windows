import '../../core/network/api_envelope.dart';

/// System Audit Log DTO (`GET /api/v1/admin/audit-logs` — Administrator Only).
class AuditLogDto {
  final String auditId;
  final DateTime occurredAtUtc;
  final String actorUserId;
  final String actorUserCode;
  final String actorRole;
  final String
      action; // 'configuration_review'|'passage_attested'|'guard_review_recorded'|'vehicle_registered'|'vehicle_updated'
  final String resourceType;
  final String resourceId;
  final String requestId;
  final String summary;

  const AuditLogDto({
    required this.auditId,
    required this.occurredAtUtc,
    required this.actorUserId,
    required this.actorUserCode,
    required this.actorRole,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    required this.requestId,
    required this.summary,
  });

  factory AuditLogDto.fromJson(Map<String, dynamic> json) {
    return AuditLogDto(
      auditId: json['audit_id']?.toString() ?? '',
      occurredAtUtc: DateTime.tryParse(json['occurred_at']?.toString() ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      actorUserId: json['actor_user_id']?.toString() ?? '',
      actorUserCode: json['actor_user_code']?.toString() ?? '',
      actorRole: json['actor_role']?.toString() ?? 'administrator',
      action: json['action']?.toString() ?? 'configuration_review',
      resourceType: json['resource_type']?.toString() ?? '',
      resourceId: json['resource_id']?.toString() ?? '',
      requestId: json['request_id']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'audit_id': auditId,
        'occurred_at': ManilaTime.toUtcIso(occurredAtUtc),
        'actor_user_id': actorUserId,
        'actor_user_code': actorUserCode,
        'actor_role': actorRole,
        'action': action,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'request_id': requestId,
        'summary': summary,
      };
}

/// Overview Command Dashboard KPI summary (`GET /api/v1/dashboard`).
class DashboardDto {
  final int activeVisitsCount; // Confirmed post-passage visits inside campus
  final int entriesTodayCount;
  final int exitsTodayCount;
  final int activeHoldsAwaitingPassageCount; // Pre-passage holds (NOT active visits!)
  final int pendingGuardReviewsCount;
  final int totalCampusSpaces;
  final int trulyAvailableSpaces;
  final int occupiedSpaces;
  final int heldSpaces;
  final int unknownOrStaleSpaces;
  final int onlineDevicesCount;
  final int totalDevicesCount;

  const DashboardDto({
    required this.activeVisitsCount,
    required this.entriesTodayCount,
    required this.exitsTodayCount,
    required this.activeHoldsAwaitingPassageCount,
    required this.pendingGuardReviewsCount,
    required this.totalCampusSpaces,
    required this.trulyAvailableSpaces,
    required this.occupiedSpaces,
    required this.heldSpaces,
    required this.unknownOrStaleSpaces,
    required this.onlineDevicesCount,
    required this.totalDevicesCount,
  });

  factory DashboardDto.fromJson(Map<String, dynamic> json) {
    return DashboardDto(
      activeVisitsCount: (json['active_visits_count'] as num?)?.toInt() ?? 0,
      entriesTodayCount: (json['entries_today_count'] as num?)?.toInt() ?? 0,
      exitsTodayCount: (json['exits_today_count'] as num?)?.toInt() ?? 0,
      activeHoldsAwaitingPassageCount:
          (json['active_holds_awaiting_passage_count'] as num?)?.toInt() ?? 0,
      pendingGuardReviewsCount:
          (json['pending_guard_reviews_count'] as num?)?.toInt() ?? 0,
      totalCampusSpaces: (json['total_campus_spaces'] as num?)?.toInt() ?? 32,
      trulyAvailableSpaces:
          (json['truly_available_spaces'] as num?)?.toInt() ?? 0,
      occupiedSpaces: (json['occupied_spaces'] as num?)?.toInt() ?? 0,
      heldSpaces: (json['held_spaces'] as num?)?.toInt() ?? 0,
      unknownOrStaleSpaces:
          (json['unknown_or_stale_spaces'] as num?)?.toInt() ?? 0,
      onlineDevicesCount: (json['online_devices_count'] as num?)?.toInt() ?? 0,
      totalDevicesCount: (json['total_devices_count'] as num?)?.toInt() ?? 7,
    );
  }
}
