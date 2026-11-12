import '../../core/network/api_envelope.dart';
import 'event_envelope.dart';

/// Six Separate State Dimensions for a Gate Encounter (`AttemptDto`):
/// 1. Observation persistence (`observation_received`)
/// 2. Attempt processing (`identity_verification_pending` | `authorization_allowed` | `authorization_denied` | `guard_review_required` | `expired` | `cancelled` | `completed`)
/// 3. Decision outcome (`allowed` | `denied` | `review_required`)
/// 4. Gate actuation (`claimed`)
/// 5. Passage confirmation (`physical_passage_confirmed`)
/// 6. Committed Visit (`active` -> `closed`) & Parking Assignment (`held` -> `assigned` -> `released`)
///
/// Extended per Patrick Carpio's Backend Confirmation #1 (`GET /api/v1/access-attempts/{correlation_id}`):
/// Includes `plateText`, `ocrConfidence`, `detectionConfidence`, `rfidUid`,
/// `faceRecognitionStatus`, and `faceSimilarityScore` (calibrated cosine similarity in `[-1, 1]`).
class AttemptDto {
  final String correlationId;
  final String gateId;
  final String laneId;
  final String direction; // 'entry' | 'exit'
  final String vehicleType; // 'car' | 'motorcycle'
  final String
      state; // 'observation_received'|'identity_verification_pending'|'authorization_allowed'|'authorization_denied'|'guard_review_required'|'expired'|'cancelled'|'completed'
  final int attemptVersion;
  final DateTime startedAtUtc;
  final DateTime expiresAtUtc; // 60s attempt lifetime

  // Extended Telemetry (Patrick Carpio Confirmed Contract #1)
  final String? plateText;
  final String? plateRecognitionStatus; // 'recognized' | 'uncertain' | 'unreadable'
  final double? detectionConfidence;
  final double? ocrConfidence;
  final String? plateModelVersion;

  final String? rfidUid;
  final String? rfidReaderModel;
  final String? rfidFirmwareVersion;

  final String
      faceRecognitionStatus; // 'matched'|'unknown'|'uncertain'|'no_face'|'multiple_faces'|'pending'|'not_required'
  final double? faceSimilarityScore; // [-1, 1] raw cosine similarity
  final int faceCount;
  final String? faceTriggerEventId;
  final String? faceModelVersion;

  // Resolved User & Vehicle
  final String? userId;
  final String? userCode;
  final String? vehicleId;
  final String? vehicleCode;

  // Latest Immutable Access Decision
  final AccessDecisionData? latestDecision;

  // Gate Actuation & Passage Confirmation States (Separate from Decision!)
  final bool gateActuationClaimed;
  final DateTime? gateClaimedAtUtc;
  final bool passageConfirmed;
  final String? passageConfirmationSource;
  final DateTime? passageConfirmedAtUtc;

  // Space Hold / Assignment & Committed Visit (visitId is null until passageConfirmed!)
  final String? assignmentId;
  final String? spaceId;
  final String? spaceCode;
  final String? lotCode;
  final String? assignmentStatus; // 'held' | 'assigned' | 'released'
  final DateTime? holdExpiresAtUtc;
  final String? committedVisitId; // Only populated after passage confirmation!

  const AttemptDto({
    required this.correlationId,
    required this.gateId,
    required this.laneId,
    required this.direction,
    required this.vehicleType,
    required this.state,
    required this.attemptVersion,
    required this.startedAtUtc,
    required this.expiresAtUtc,
    this.plateText,
    this.plateRecognitionStatus,
    this.detectionConfidence,
    this.ocrConfidence,
    this.plateModelVersion,
    this.rfidUid,
    this.rfidReaderModel,
    this.rfidFirmwareVersion,
    required this.faceRecognitionStatus,
    this.faceSimilarityScore,
    this.faceCount = 1,
    this.faceTriggerEventId,
    this.faceModelVersion,
    this.userId,
    this.userCode,
    this.vehicleId,
    this.vehicleCode,
    this.latestDecision,
    this.gateActuationClaimed = false,
    this.gateClaimedAtUtc,
    this.passageConfirmed = false,
    this.passageConfirmationSource,
    this.passageConfirmedAtUtc,
    this.assignmentId,
    this.spaceId,
    this.spaceCode,
    this.lotCode,
    this.assignmentStatus,
    this.holdExpiresAtUtc,
    this.committedVisitId,
  });

  /// Formatted raw cosine similarity score per Patrick Carpio's Confirmation #1.
  /// CRITICAL: Never format `faceSimilarityScore` as a percentage!
  String get formattedFaceCosineSimilarity {
    if (direction == 'exit' || faceRecognitionStatus == 'not_required') {
      return 'Not Required on Exit';
    }
    if (faceSimilarityScore == null) {
      return 'Pending / No Embedding';
    }
    return '${faceSimilarityScore!.toStringAsFixed(2)} cosine similarity (cosine_similarity)';
  }

  /// Computes which of the 6 distinct stages (1..6) this attempt has reached.
  int get currentStageNumber {
    if (passageConfirmed && committedVisitId != null) {
      return 6; // Stage 6: Active Visit Committed & Space Assigned (or Closed/Released on exit)
    }
    if (passageConfirmed) {
      return 5; // Stage 5: Physical Passage Confirmed
    }
    if (gateActuationClaimed) {
      return 4; // Stage 4: Gate Actuation Claimed
    }
    if (latestDecision != null) {
      return 3; // Stage 3: Access Decision Issued (+ 30s Space Hold if allowed entry)
    }
    if (state != 'observation_received') {
      return 2; // Stage 2: Identity Verification Processing
    }
    return 1; // Stage 1: Observation Received
  }

  /// True when the 30-second parking space hold has elapsed before passage confirmation.
  bool isHoldExpired([DateTime? nowUtc]) {
    if (holdExpiresAtUtc == null) return false;
    final checkTime = (nowUtc ?? DateTime.now()).toUtc();
    return !checkTime.isBefore(holdExpiresAtUtc!);
  }

  /// True when the gate attempt lifetime has elapsed or state is `expired`.
  bool isAttemptExpired([DateTime? nowUtc]) {
    if (state == 'expired') return true;
    final checkTime = (nowUtc ?? DateTime.now()).toUtc();
    return !checkTime.isBefore(expiresAtUtc);
  }

  /// True when the guard can click "Confirm Vehicle Crossed Gate" (`guard_attestation`).
  /// Enforces that neither the 20s decision nor the 30s space hold nor the 60s attempt
  /// has expired prior to physical passage confirmation.
  bool canConfirmPassage([DateTime? nowUtc]) {
    final checkTime = (nowUtc ?? DateTime.now()).toUtc();
    if (passageConfirmed) return false;
    if (state == 'expired' || state == 'cancelled' || state == 'completed') {
      return false;
    }
    if (isAttemptExpired(checkTime)) return false;
    if (direction == 'entry' &&
        (isHoldExpired(checkTime) ||
            assignmentStatus == 'released' ||
            assignmentStatus == 'expired')) {
      return false;
    }
    final decision = latestDecision;
    if (decision == null || decision.outcome != 'allowed') return false;
    return !decision.isExpired(checkTime);
  }

  /// True when the guard can cancel the attempt before passage confirmation.
  bool get canCancelBeforePassage =>
      !passageConfirmed &&
      state != 'expired' &&
      state != 'cancelled' &&
      state != 'completed';

  AttemptDto copyWith({
    String? state,
    int? attemptVersion,
    DateTime? expiresAtUtc,
    String? plateText,
    String? plateRecognitionStatus,
    double? detectionConfidence,
    double? ocrConfidence,
    String? rfidUid,
    String? faceRecognitionStatus,
    double? faceSimilarityScore,
    String? userId,
    String? userCode,
    String? vehicleId,
    String? vehicleCode,
    AccessDecisionData? latestDecision,
    bool? gateActuationClaimed,
    DateTime? gateClaimedAtUtc,
    bool? passageConfirmed,
    String? passageConfirmationSource,
    DateTime? passageConfirmedAtUtc,
    String? assignmentId,
    String? spaceId,
    String? spaceCode,
    String? lotCode,
    String? assignmentStatus,
    DateTime? holdExpiresAtUtc,
    String? committedVisitId,
  }) {
    return AttemptDto(
      correlationId: correlationId,
      gateId: gateId,
      laneId: laneId,
      direction: direction,
      vehicleType: vehicleType,
      state: state ?? this.state,
      attemptVersion: attemptVersion ?? this.attemptVersion,
      startedAtUtc: startedAtUtc,
      expiresAtUtc: expiresAtUtc ?? this.expiresAtUtc,
      plateText: plateText ?? this.plateText,
      plateRecognitionStatus:
          plateRecognitionStatus ?? this.plateRecognitionStatus,
      detectionConfidence: detectionConfidence ?? this.detectionConfidence,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      plateModelVersion: plateModelVersion,
      rfidUid: rfidUid ?? this.rfidUid,
      rfidReaderModel: rfidReaderModel,
      rfidFirmwareVersion: rfidFirmwareVersion,
      faceRecognitionStatus:
          faceRecognitionStatus ?? this.faceRecognitionStatus,
      faceSimilarityScore: faceSimilarityScore ?? this.faceSimilarityScore,
      faceCount: faceCount,
      faceTriggerEventId: faceTriggerEventId,
      faceModelVersion: faceModelVersion,
      userId: userId ?? this.userId,
      userCode: userCode ?? this.userCode,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleCode: vehicleCode ?? this.vehicleCode,
      latestDecision: latestDecision ?? this.latestDecision,
      gateActuationClaimed: gateActuationClaimed ?? this.gateActuationClaimed,
      gateClaimedAtUtc: gateClaimedAtUtc ?? this.gateClaimedAtUtc,
      passageConfirmed: passageConfirmed ?? this.passageConfirmed,
      passageConfirmationSource:
          passageConfirmationSource ?? this.passageConfirmationSource,
      passageConfirmedAtUtc:
          passageConfirmedAtUtc ?? this.passageConfirmedAtUtc,
      assignmentId: assignmentId ?? this.assignmentId,
      spaceId: spaceId ?? this.spaceId,
      spaceCode: spaceCode ?? this.spaceCode,
      lotCode: lotCode ?? this.lotCode,
      assignmentStatus: assignmentStatus ?? this.assignmentStatus,
      holdExpiresAtUtc: holdExpiresAtUtc ?? this.holdExpiresAtUtc,
      committedVisitId: committedVisitId ?? this.committedVisitId,
    );
  }

  factory AttemptDto.fromJson(Map<String, dynamic> json) {
    return AttemptDto(
      correlationId: json['correlation_id']?.toString() ?? '',
      gateId: json['gate_id']?.toString() ?? 'gate-north',
      laneId: json['lane_id']?.toString() ?? 'lane-car-in',
      direction: json['direction']?.toString() ?? 'entry',
      vehicleType: json['vehicle_type']?.toString() ?? 'car',
      state: json['state']?.toString() ?? 'observation_received',
      attemptVersion: (json['attempt_version'] as num?)?.toInt() ?? 1,
      startedAtUtc: DateTime.tryParse(json['started_at']?.toString() ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      expiresAtUtc: DateTime.tryParse(json['expires_at']?.toString() ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(seconds: 60)),
      plateText: json['plate_text']?.toString(),
      plateRecognitionStatus: json['plate_recognition_status']?.toString(),
      detectionConfidence:
          (json['detection_confidence'] as num?)?.toDouble(),
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble(),
      plateModelVersion: json['plate_model_version']?.toString(),
      rfidUid: json['rfid_uid']?.toString(),
      rfidReaderModel: json['rfid_reader_model']?.toString(),
      rfidFirmwareVersion: json['rfid_firmware_version']?.toString(),
      faceRecognitionStatus:
          json['face_recognition_status']?.toString() ?? 'pending',
      faceSimilarityScore:
          (json['face_similarity_score'] as num?)?.toDouble(),
      faceCount: (json['face_count'] as num?)?.toInt() ?? 1,
      faceTriggerEventId: json['face_trigger_event_id']?.toString(),
      faceModelVersion: json['face_model_version']?.toString(),
      userId: json['user_id']?.toString(),
      userCode: json['user_code']?.toString(),
      vehicleId: json['vehicle_id']?.toString(),
      vehicleCode: json['vehicle_code']?.toString(),
      latestDecision: json['latest_decision'] is Map<String, dynamic>
          ? AccessDecisionData.fromJson(
              json['latest_decision'] as Map<String, dynamic>,
            )
          : null,
      gateActuationClaimed: json['gate_actuation_claimed'] == true,
      gateClaimedAtUtc: json['gate_claimed_at'] != null
          ? DateTime.tryParse(json['gate_claimed_at'].toString())?.toUtc()
          : null,
      passageConfirmed: json['passage_confirmed'] == true,
      passageConfirmationSource:
          json['passage_confirmation_source']?.toString(),
      passageConfirmedAtUtc: json['passage_confirmed_at'] != null
          ? DateTime.tryParse(json['passage_confirmed_at'].toString())?.toUtc()
          : null,
      assignmentId: json['assignment_id']?.toString(),
      spaceId: json['space_id']?.toString(),
      spaceCode: json['space_code']?.toString(),
      lotCode: json['lot_code']?.toString(),
      assignmentStatus: json['assignment_status']?.toString(),
      holdExpiresAtUtc: json['hold_expires_at'] != null
          ? DateTime.tryParse(json['hold_expires_at'].toString())?.toUtc()
          : null,
      committedVisitId: json['committed_visit_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'correlation_id': correlationId,
        'gate_id': gateId,
        'lane_id': laneId,
        'direction': direction,
        'vehicle_type': vehicleType,
        'state': state,
        'attempt_version': attemptVersion,
        'started_at': ManilaTime.toUtcIso(startedAtUtc),
        'expires_at': ManilaTime.toUtcIso(expiresAtUtc),
        'plate_text': plateText,
        'plate_recognition_status': plateRecognitionStatus,
        'detection_confidence': detectionConfidence,
        'ocr_confidence': ocrConfidence,
        'rfid_uid': rfidUid,
        'face_recognition_status': faceRecognitionStatus,
        'face_similarity_score': faceSimilarityScore,
        'user_id': userId,
        'user_code': userCode,
        'vehicle_id': vehicleId,
        'vehicle_code': vehicleCode,
        if (latestDecision != null) 'latest_decision': latestDecision!.toJson(),
        'gate_actuation_claimed': gateActuationClaimed,
        'passage_confirmed': passageConfirmed,
        'assignment_id': assignmentId,
        'space_id': spaceId,
        'space_code': spaceCode,
        'lot_code': lotCode,
        'assignment_status': assignmentStatus,
        'committed_visit_id': committedVisitId,
      };
}
