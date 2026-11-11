import '../../core/network/api_envelope.dart';

/// All 11 official SENTRY v1.0.0 Event Types from `contracts/events/v1/common.schema.json`.
enum SentryEventType {
  plateObservation('plate_observation'),
  faceObservation('face_observation'),
  rfidScan('rfid_scan'),
  accessDecision('access_decision'),
  entryConfirmation('entry_confirmation'),
  exitConfirmation('exit_confirmation'),
  parkingAssignment('parking_assignment'),
  occupancyObservation('occupancy_observation'),
  guardReview('guard_review'),
  deviceHeartbeat('device_heartbeat'),
  realtimeUpdate('realtime_update');

  final String wireName;
  const SentryEventType(this.wireName);

  static SentryEventType fromWire(String value) {
    return SentryEventType.values.firstWhere(
      (e) => e.wireName == value,
      orElse: () =>
          throw FormatException('Invalid event_type in envelope: $value'),
    );
  }
}

/// Common Event Envelope (`contracts/events/v1/common.schema.json` §5.3).
/// Enforces:
/// - `schema_version == "1.0.0"`
/// - Valid UUID `event_id`
/// - UTC `occurred_at` ending in `Z`
/// - Stable `producer_id`
class CommonEventEnvelope<T> {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final RegExp _stableIdRegex = RegExp(r'^[a-z0-9][a-z0-9_-]{2,63}$');

  final String schemaVersion;
  final String eventId;
  final SentryEventType eventType;
  final DateTime occurredAtUtc;
  final String producerId;
  final String? correlationId;
  final T data;

  CommonEventEnvelope({
    this.schemaVersion = '1.0.0',
    required this.eventId,
    required this.eventType,
    required this.occurredAtUtc,
    required this.producerId,
    required this.correlationId,
    required this.data,
  }) {
    if (schemaVersion != '1.0.0') {
      throw FormatException('Unsupported schema_version: $schemaVersion');
    }
    if (!_uuidRegex.hasMatch(eventId)) {
      throw FormatException('Invalid event_id UUID format: $eventId');
    }
    if (!_stableIdRegex.hasMatch(producerId)) {
      throw FormatException('Invalid producer_id stable_id: $producerId');
    }
    if (correlationId != null && !_uuidRegex.hasMatch(correlationId!)) {
      throw FormatException('Invalid correlation_id UUID: $correlationId');
    }
  }

  factory CommonEventEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> dataJson) dataParser,
  ) {
    final occurredRaw = json['occurred_at']?.toString() ?? '';
    if (!occurredRaw.endsWith('Z')) {
      throw FormatException(
        'occurred_at must be strict RFC 3339 UTC ending in Z: $occurredRaw',
      );
    }
    final eventType =
        SentryEventType.fromWire(json['event_type']?.toString() ?? '');
    final dataMap = json['data'];
    if (dataMap is! Map<String, dynamic>) {
      throw const FormatException('Event envelope data must be an object');
    }
    return CommonEventEnvelope<T>(
      schemaVersion: json['schema_version']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? '',
      eventType: eventType,
      occurredAtUtc: DateTime.parse(occurredRaw).toUtc(),
      producerId: json['producer_id']?.toString() ?? '',
      correlationId: json['correlation_id']?.toString(),
      data: dataParser(dataMap),
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T data) serializer) {
    return {
      'schema_version': schemaVersion,
      'event_id': eventId,
      'event_type': eventType.wireName,
      'occurred_at': ManilaTime.toUtcIso(occurredAtUtc),
      'producer_id': producerId,
      'correlation_id': correlationId,
      'data': serializer(data),
    };
  }
}

/// §7.1 `plate_observation` event payload (`plate_observation.schema.json`).
class PlateObservationData {
  final String gateId;
  final String laneId;
  final String direction; // 'entry' | 'exit'
  final String recognitionStatus; // 'recognized' | 'uncertain' | 'unreadable'
  final String? plateText;
  final double? detectionConfidence;
  final double? ocrConfidence;
  final String modelVersion;
  final String thresholdConfigVersion;
  final int? processingDurationMs;

  PlateObservationData({
    required this.gateId,
    required this.laneId,
    required this.direction,
    required this.recognitionStatus,
    this.plateText,
    this.detectionConfidence,
    this.ocrConfidence,
    required this.modelVersion,
    required this.thresholdConfigVersion,
    this.processingDurationMs,
  }) {
    if (!const {'entry', 'exit'}.contains(direction)) {
      throw FormatException('Invalid direction: $direction');
    }
    if (!const {'recognized', 'uncertain', 'unreadable'}
        .contains(recognitionStatus)) {
      throw FormatException('Invalid recognition_status: $recognitionStatus');
    }
    if (plateText != null &&
        !RegExp(r'^[A-Z0-9]{2,12}$').hasMatch(plateText!)) {
      throw FormatException(
          'Normalized plate_text must match ^[A-Z0-9]{2,12}\$: $plateText');
    }
  }

  factory PlateObservationData.fromJson(Map<String, dynamic> json) {
    return PlateObservationData(
      gateId: json['gate_id'] as String,
      laneId: json['lane_id'] as String,
      direction: json['direction'] as String,
      recognitionStatus: json['recognition_status'] as String,
      plateText: json['plate_text'] as String?,
      detectionConfidence: (json['detection_confidence'] as num?)?.toDouble(),
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble(),
      modelVersion: json['model_version'] as String,
      thresholdConfigVersion: json['threshold_config_version'] as String,
      processingDurationMs: (json['processing_duration_ms'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'gate_id': gateId,
        'lane_id': laneId,
        'direction': direction,
        'recognition_status': recognitionStatus,
        'plate_text': plateText,
        'detection_confidence': detectionConfidence,
        'ocr_confidence': ocrConfidence,
        'model_version': modelVersion,
        'threshold_config_version': thresholdConfigVersion,
        if (processingDurationMs != null)
          'processing_duration_ms': processingDurationMs,
      };
}

/// §7.2 `face_observation` event payload (`face_observation.schema.json`).
/// Note: `direction` is strictly `const: "entry"` (Face check is never used on exit).
/// `similarity_metric` is strictly `"cosine_similarity"` with `similarity_score` in `[-1, 1]`.
class FaceObservationData {
  final String gateId;
  final String laneId;
  final String direction; // strictly 'entry'
  final String triggerEventId;
  final String
      recognitionStatus; // 'matched'|'unknown'|'uncertain'|'no_face'|'multiple_faces'
  final String? userId;
  final String? faceTemplateId;
  final int faceCount;
  final String similarityMetric; // strictly 'cosine_similarity'
  final double? similarityScore; // [-1.0, 1.0]
  final String modelVersion;
  final String thresholdConfigVersion;
  final int? processingDurationMs;

  FaceObservationData({
    required this.gateId,
    required this.laneId,
    this.direction = 'entry',
    required this.triggerEventId,
    required this.recognitionStatus,
    this.userId,
    this.faceTemplateId,
    required this.faceCount,
    this.similarityMetric = 'cosine_similarity',
    this.similarityScore,
    required this.modelVersion,
    required this.thresholdConfigVersion,
    this.processingDurationMs,
  }) {
    if (direction != 'entry') {
      throw FormatException(
        'face_observation direction must be "entry" (received "$direction")',
      );
    }
    if (similarityMetric != 'cosine_similarity') {
      throw FormatException(
        'similarity_metric must be "cosine_similarity" (received "$similarityMetric")',
      );
    }
    if (similarityScore != null &&
        (similarityScore! < -1.0 || similarityScore! > 1.0)) {
      throw FormatException(
        'similarity_score must be in [-1, 1] (received $similarityScore)',
      );
    }
  }

  /// Formats `similarityScore` strictly as a calibrated cosine similarity metric
  /// per Patrick Carpio's Backend Confirmation #1 (NEVER as a percentage!).
  String get formattedCosineSimilarity {
    if (similarityScore == null) return 'N/A (no embedding)';
    return '${similarityScore!.toStringAsFixed(2)} cosine similarity ($similarityMetric)';
  }

  factory FaceObservationData.fromJson(Map<String, dynamic> json) {
    return FaceObservationData(
      gateId: json['gate_id'] as String,
      laneId: json['lane_id'] as String,
      direction: json['direction'] as String,
      triggerEventId: json['trigger_event_id'] as String,
      recognitionStatus: json['recognition_status'] as String,
      userId: json['user_id'] as String?,
      faceTemplateId: json['face_template_id'] as String?,
      faceCount: (json['face_count'] as num).toInt(),
      similarityMetric: json['similarity_metric'] as String,
      similarityScore: (json['similarity_score'] as num?)?.toDouble(),
      modelVersion: json['model_version'] as String,
      thresholdConfigVersion: json['threshold_config_version'] as String,
      processingDurationMs: (json['processing_duration_ms'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'gate_id': gateId,
        'lane_id': laneId,
        'direction': direction,
        'trigger_event_id': triggerEventId,
        'recognition_status': recognitionStatus,
        'user_id': userId,
        'face_template_id': faceTemplateId,
        'face_count': faceCount,
        'similarity_metric': similarityMetric,
        'similarity_score': similarityScore,
        'model_version': modelVersion,
        'threshold_config_version': thresholdConfigVersion,
        if (processingDurationMs != null)
          'processing_duration_ms': processingDurationMs,
      };
}

/// §7.3 `rfid_scan` event payload (`rfid_scan.schema.json`).
class RfidScanData {
  final String gateId;
  final String laneId;
  final String direction; // 'entry' | 'exit'
  final String rfidUid; // 8, 14, or 20 uppercase hex chars
  final String readerModel;
  final String firmwareVersion;

  RfidScanData({
    required this.gateId,
    required this.laneId,
    required this.direction,
    required this.rfidUid,
    required this.readerModel,
    required this.firmwareVersion,
  }) {
    if (!RegExp(r'^(?:[0-9A-F]{8}|[0-9A-F]{14}|[0-9A-F]{20})$')
        .hasMatch(rfidUid)) {
      throw FormatException('Invalid rfid_uid hex format: $rfidUid');
    }
  }

  factory RfidScanData.fromJson(Map<String, dynamic> json) {
    return RfidScanData(
      gateId: json['gate_id'] as String,
      laneId: json['lane_id'] as String,
      direction: json['direction'] as String,
      rfidUid: json['rfid_uid'] as String,
      readerModel: json['reader_model'] as String,
      firmwareVersion: json['firmware_version'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'gate_id': gateId,
        'lane_id': laneId,
        'direction': direction,
        'rfid_uid': rfidUid,
        'reader_model': readerModel,
        'firmware_version': firmwareVersion,
      };
}

/// §7.4 `access_decision` event payload (`access_decision.schema.json`).
class AccessDecisionData {
  final String decisionId;
  final String gateId;
  final String laneId;
  final String direction; // 'entry' | 'exit'
  final String vehicleType; // 'car' | 'motorcycle'
  final String outcome; // 'allowed' | 'denied' | 'review_required'
  final String reasonCode;
  final String reasonMessage;
  final String? userId;
  final String? vehicleId;
  final String? visitId; // null on entry decision (before passage confirmation!)
  final String? assignmentId;
  final List<String> evidenceEventIds;
  final DateTime? expiresAtUtc; // 20s default for 'allowed', null for others
  final String? supersedesDecisionId;
  final int attemptVersion;
  final String policyVersion;

  AccessDecisionData({
    required this.decisionId,
    required this.gateId,
    required this.laneId,
    required this.direction,
    required this.vehicleType,
    required this.outcome,
    required this.reasonCode,
    required this.reasonMessage,
    this.userId,
    this.vehicleId,
    this.visitId,
    this.assignmentId,
    required this.evidenceEventIds,
    this.expiresAtUtc,
    this.supersedesDecisionId,
    required this.attemptVersion,
    this.policyVersion = 'sentry-policy-v1.0',
  }) {
    if (!const {'allowed', 'denied', 'review_required'}.contains(outcome)) {
      throw FormatException('Invalid decision outcome: $outcome');
    }
    if (evidenceEventIds.isEmpty || evidenceEventIds.length > 8) {
      throw FormatException(
        'evidence_event_ids must contain 1..8 items (got ${evidenceEventIds.length})',
      );
    }
  }

  bool isExpired([DateTime? nowUtc]) {
    if (expiresAtUtc == null) return false;
    final check = (nowUtc ?? DateTime.now()).toUtc();
    return !expiresAtUtc!.isAfter(check);
  }

  factory AccessDecisionData.fromJson(Map<String, dynamic> json) {
    return AccessDecisionData(
      decisionId: json['decision_id'] as String,
      gateId: json['gate_id'] as String,
      laneId: json['lane_id'] as String,
      direction: json['direction'] as String,
      vehicleType: json['vehicle_type'] as String,
      outcome: json['outcome'] as String,
      reasonCode: json['reason_code'] as String,
      reasonMessage: json['reason_message'] as String,
      userId: json['user_id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      visitId: json['visit_id'] as String?,
      assignmentId: json['assignment_id'] as String?,
      evidenceEventIds: (json['evidence_event_ids'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      expiresAtUtc: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'].toString()).toUtc()
          : null,
      supersedesDecisionId: json['supersedes_decision_id'] as String?,
      attemptVersion: (json['attempt_version'] as num).toInt(),
      policyVersion: json['policy_version'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'decision_id': decisionId,
        'gate_id': gateId,
        'lane_id': laneId,
        'direction': direction,
        'vehicle_type': vehicleType,
        'outcome': outcome,
        'reason_code': reasonCode,
        'reason_message': reasonMessage,
        'user_id': userId,
        'vehicle_id': vehicleId,
        'visit_id': visitId,
        'assignment_id': assignmentId,
        'evidence_event_ids': evidenceEventIds,
        'expires_at': expiresAtUtc != null
            ? ManilaTime.toUtcIso(expiresAtUtc!)
            : null,
        'supersedes_decision_id': supersedesDecisionId,
        'attempt_version': attemptVersion,
        'policy_version': policyVersion,
      };
}

/// §7.5 `entry_confirmation` event payload (`entry_confirmation.schema.json`).
class EntryConfirmationData {
  final String decisionId;
  final String gateId;
  final String laneId;
  final DateTime confirmedAtUtc;
  final String confirmationSource; // 'sensor' | 'guard_attestation' | 'mock_sensor'
  final String passageReference;
  final String? notes;

  EntryConfirmationData({
    required this.decisionId,
    required this.gateId,
    required this.laneId,
    required this.confirmedAtUtc,
    required this.confirmationSource,
    required this.passageReference,
    this.notes,
  }) {
    if (!const {'sensor', 'guard_attestation', 'mock_sensor'}
        .contains(confirmationSource)) {
      throw FormatException(
        'Invalid confirmation_source: $confirmationSource',
      );
    }
    if (notes != null && (notes!.length < 10 || notes!.length > 500)) {
      throw FormatException('notes must be 10..500 characters');
    }
  }

  factory EntryConfirmationData.fromJson(Map<String, dynamic> json) {
    return EntryConfirmationData(
      decisionId: json['decision_id'] as String,
      gateId: json['gate_id'] as String,
      laneId: json['lane_id'] as String,
      confirmedAtUtc: DateTime.parse(json['confirmed_at'] as String).toUtc(),
      confirmationSource: json['confirmation_source'] as String,
      passageReference: json['passage_reference'] as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'decision_id': decisionId,
        'gate_id': gateId,
        'lane_id': laneId,
        'confirmed_at': ManilaTime.toUtcIso(confirmedAtUtc),
        'confirmation_source': confirmationSource,
        'passage_reference': passageReference,
        if (notes != null) 'notes': notes,
      };
}

/// §7.6 `exit_confirmation` event payload (`exit_confirmation.schema.json`).
class ExitConfirmationData {
  final String decisionId;
  final String visitId;
  final String gateId;
  final String laneId;
  final DateTime confirmedAtUtc;
  final String confirmationSource; // 'sensor' | 'guard_attestation' | 'mock_sensor'
  final String passageReference;
  final String? notes;

  ExitConfirmationData({
    required this.decisionId,
    required this.visitId,
    required this.gateId,
    required this.laneId,
    required this.confirmedAtUtc,
    required this.confirmationSource,
    required this.passageReference,
    this.notes,
  }) {
    if (!const {'sensor', 'guard_attestation', 'mock_sensor'}
        .contains(confirmationSource)) {
      throw FormatException(
        'Invalid confirmation_source: $confirmationSource',
      );
    }
    if (notes != null && (notes!.length < 10 || notes!.length > 500)) {
      throw FormatException('notes must be 10..500 characters');
    }
  }

  factory ExitConfirmationData.fromJson(Map<String, dynamic> json) {
    return ExitConfirmationData(
      decisionId: json['decision_id'] as String,
      visitId: json['visit_id'] as String,
      gateId: json['gate_id'] as String,
      laneId: json['lane_id'] as String,
      confirmedAtUtc: DateTime.parse(json['confirmed_at'] as String).toUtc(),
      confirmationSource: json['confirmation_source'] as String,
      passageReference: json['passage_reference'] as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'decision_id': decisionId,
        'visit_id': visitId,
        'gate_id': gateId,
        'lane_id': laneId,
        'confirmed_at': ManilaTime.toUtcIso(confirmedAtUtc),
        'confirmation_source': confirmationSource,
        'passage_reference': passageReference,
        if (notes != null) 'notes': notes,
      };
}

/// §7.7 `parking_assignment` event payload (`parking_assignment.schema.json`).
/// Invariant: When `status == "held"`, `visitId` MUST be `null`!
/// Only after `entry_confirmation` does `status` become `"assigned"` with a non-null `visitId`.
class ParkingAssignmentData {
  final String assignmentId;
  final String userId;
  final String vehicleId;
  final String? visitId;
  final String buildingCode;
  final String lotCode; // 'A' | 'B' | 'C' | 'D'
  final String spaceId;
  final String spaceCode;
  final String status; // 'held' | 'assigned' | 'released'
  final DateTime createdAtUtc;
  final DateTime? expiresAtUtc;
  final DateTime? releasedAtUtc;
  final int version;

  ParkingAssignmentData({
    required this.assignmentId,
    required this.userId,
    required this.vehicleId,
    required this.visitId,
    required this.buildingCode,
    required this.lotCode,
    required this.spaceId,
    required this.spaceCode,
    required this.status,
    required this.createdAtUtc,
    this.expiresAtUtc,
    this.releasedAtUtc,
    required this.version,
  }) {
    if (!const {'held', 'assigned', 'released'}.contains(status)) {
      throw FormatException('Invalid parking_assignment status: $status');
    }
    if (status == 'held' && visitId != null) {
      throw FormatException(
        'State Separation Invariant Violation: held parking_assignment must have visit_id == null',
      );
    }
  }

  factory ParkingAssignmentData.fromJson(Map<String, dynamic> json) {
    return ParkingAssignmentData(
      assignmentId: json['assignment_id'] as String,
      userId: json['user_id'] as String,
      vehicleId: json['vehicle_id'] as String,
      visitId: json['visit_id'] as String?,
      buildingCode: json['building_code'] as String,
      lotCode: json['lot_code'] as String,
      spaceId: json['space_id'] as String,
      spaceCode: json['space_code'] as String,
      status: json['status'] as String,
      createdAtUtc: DateTime.parse(json['created_at'] as String).toUtc(),
      expiresAtUtc: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String).toUtc()
          : null,
      releasedAtUtc: json['released_at'] != null
          ? DateTime.parse(json['released_at'] as String).toUtc()
          : null,
      version: (json['version'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'assignment_id': assignmentId,
        'user_id': userId,
        'vehicle_id': vehicleId,
        'visit_id': visitId,
        'building_code': buildingCode,
        'lot_code': lotCode,
        'space_id': spaceId,
        'space_code': spaceCode,
        'status': status,
        'created_at': ManilaTime.toUtcIso(createdAtUtc),
        'expires_at':
            expiresAtUtc != null ? ManilaTime.toUtcIso(expiresAtUtc!) : null,
        'released_at':
            releasedAtUtc != null ? ManilaTime.toUtcIso(releasedAtUtc!) : null,
        'version': version,
      };
}

/// §7.8 `occupancy_observation` event payload (`occupancy_observation.schema.json`).
class OccupancyObservationData {
  final String lotCode;
  final String spaceId;
  final String physicalStatus; // 'available' | 'occupied' | 'unknown'
  final double? confidence;
  final String bootId;
  final int sequenceNumber;
  final String calibrationVersion;
  final String modelVersion;

  OccupancyObservationData({
    required this.lotCode,
    required this.spaceId,
    required this.physicalStatus,
    this.confidence,
    required this.bootId,
    required this.sequenceNumber,
    required this.calibrationVersion,
    required this.modelVersion,
  }) {
    if (!const {'available', 'occupied', 'unknown'}.contains(physicalStatus)) {
      throw FormatException('Invalid physical_status: $physicalStatus');
    }
  }

  factory OccupancyObservationData.fromJson(Map<String, dynamic> json) {
    return OccupancyObservationData(
      lotCode: json['lot_code'] as String,
      spaceId: json['space_id'] as String,
      physicalStatus: json['physical_status'] as String,
      confidence: (json['confidence'] as num?)?.toDouble(),
      bootId: json['boot_id'] as String,
      sequenceNumber: (json['sequence_number'] as num).toInt(),
      calibrationVersion: json['calibration_version'] as String,
      modelVersion: json['model_version'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'lot_code': lotCode,
        'space_id': spaceId,
        'physical_status': physicalStatus,
        'confidence': confidence,
        'boot_id': bootId,
        'sequence_number': sequenceNumber,
        'calibration_version': calibrationVersion,
        'model_version': modelVersion,
      };
}

/// §7.9 `guard_review` event payload (`guard_review.schema.json`).
class GuardReviewEventData {
  final String reviewId;
  final String decisionId;
  final String actorUserId;
  final String action; // 'approve' | 'deny' | 'escalate'
  final String reason; // 10..500 chars
  final int expectedAttemptVersion;

  GuardReviewEventData({
    required this.reviewId,
    required this.decisionId,
    required this.actorUserId,
    required this.action,
    required this.reason,
    required this.expectedAttemptVersion,
  }) {
    if (!const {'approve', 'deny', 'escalate'}.contains(action)) {
      throw FormatException('Invalid guard_review action: $action');
    }
    if (reason.trim().length < 10 || reason.trim().length > 500) {
      throw FormatException(
        'guard_review reason must be between 10 and 500 characters',
      );
    }
    if (expectedAttemptVersion < 1) {
      throw FormatException('expected_attempt_version must be >= 1');
    }
  }

  factory GuardReviewEventData.fromJson(Map<String, dynamic> json) {
    return GuardReviewEventData(
      reviewId: json['review_id'] as String,
      decisionId: json['decision_id'] as String,
      actorUserId: json['actor_user_id'] as String,
      action: json['action'] as String,
      reason: json['reason'] as String,
      expectedAttemptVersion: (json['expected_attempt_version'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'review_id': reviewId,
        'decision_id': decisionId,
        'actor_user_id': actorUserId,
        'action': action,
        'reason': reason,
        'expected_attempt_version': expectedAttemptVersion,
      };
}

/// §7.10 `device_heartbeat` event payload (`device_heartbeat.schema.json`).
class DeviceHeartbeatData {
  final String status; // 'online' | 'degraded'
  final String bootId;
  final int sequenceNumber;
  final int uptimeSeconds;
  final String softwareVersion;
  final List<String> capabilities;
  final String? lastErrorCode;

  DeviceHeartbeatData({
    required this.status,
    required this.bootId,
    required this.sequenceNumber,
    required this.uptimeSeconds,
    required this.softwareVersion,
    required this.capabilities,
    this.lastErrorCode,
  }) {
    if (!const {'online', 'degraded'}.contains(status)) {
      throw FormatException('Invalid device_heartbeat status: $status');
    }
  }

  factory DeviceHeartbeatData.fromJson(Map<String, dynamic> json) {
    return DeviceHeartbeatData(
      status: json['status'] as String,
      bootId: json['boot_id'] as String,
      sequenceNumber: (json['sequence_number'] as num).toInt(),
      uptimeSeconds: (json['uptime_seconds'] as num).toInt(),
      softwareVersion: json['software_version'] as String,
      capabilities: (json['capabilities'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      lastErrorCode: json['last_error_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'boot_id': bootId,
        'sequence_number': sequenceNumber,
        'uptime_seconds': uptimeSeconds,
        'software_version': softwareVersion,
        'capabilities': capabilities,
        if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      };
}

/// §7.11 `realtime_update` event payload (`realtime_update.schema.json`).
class RealtimeUpdateData {
  final String resourceType;
  final String resourceId;
  final int resourceVersion;
  final int streamSequence;
  final bool refreshRequired; // const true
  final bool resyncRequired;

  RealtimeUpdateData({
    required this.resourceType,
    required this.resourceId,
    required this.resourceVersion,
    required this.streamSequence,
    this.refreshRequired = true,
    required this.resyncRequired,
  }) {
    if (!const {
      'access_attempt',
      'access_visit',
      'parking_assignment',
      'parking_space',
      'guard_review',
      'device',
    }.contains(resourceType)) {
      throw FormatException('Invalid realtime_update resource_type: $resourceType');
    }
    if (!refreshRequired) {
      throw const FormatException('refresh_required must be true');
    }
  }

  factory RealtimeUpdateData.fromJson(Map<String, dynamic> json) {
    return RealtimeUpdateData(
      resourceType: json['resource_type'] as String,
      resourceId: json['resource_id'] as String,
      resourceVersion: (json['resource_version'] as num).toInt(),
      streamSequence: (json['stream_sequence'] as num).toInt(),
      refreshRequired: json['refresh_required'] == true,
      resyncRequired: json['resync_required'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'resource_type': resourceType,
        'resource_id': resourceId,
        'resource_version': resourceVersion,
        'stream_sequence': streamSequence,
        'refresh_required': refreshRequired,
        'resync_required': resyncRequired,
      };
}
