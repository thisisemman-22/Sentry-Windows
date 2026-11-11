import '../../core/network/api_envelope.dart';

/// Guard Review Queue Item (`GET /api/v1/guard-reviews`).
class GuardReviewQueueItem {
  final String reviewCaseId;
  final String correlationId;
  final String decisionId;
  final String gateId;
  final String laneId;
  final String direction; // 'entry' | 'exit'
  final String vehicleType; // 'car' | 'motorcycle'
  final String outcome; // 'review_required' | 'denied' | 'allowed'
  final String reasonCode;
  final String reasonMessage;
  final int currentAttemptVersion;
  final String attemptState;
  final DateTime createdAtUtc;
  final DateTime attemptExpiresAtUtc;
  final String? userId;
  final String? userCode;
  final String? vehicleId;
  final String? vehicleCode;
  final String? plateText;
  final double? ocrConfidence;
  final String? rfidUid;
  final String faceRecognitionStatus;
  final double? faceSimilarityScore;
  final List<String> evidenceEventIds;

  // Resolution fields if already reviewed
  final bool isResolved;
  final String? resolvedAction; // 'approve' | 'deny' | 'escalate'
  final String? resolvedByUserCode;
  final String? resolvedReason;
  final DateTime? resolvedAtUtc;
  final String? supersedingDecisionId;

  const GuardReviewQueueItem({
    required this.reviewCaseId,
    required this.correlationId,
    required this.decisionId,
    required this.gateId,
    required this.laneId,
    required this.direction,
    required this.vehicleType,
    required this.outcome,
    required this.reasonCode,
    required this.reasonMessage,
    required this.currentAttemptVersion,
    required this.attemptState,
    required this.createdAtUtc,
    required this.attemptExpiresAtUtc,
    this.userId,
    this.userCode,
    this.vehicleId,
    this.vehicleCode,
    this.plateText,
    this.ocrConfidence,
    this.rfidUid,
    required this.faceRecognitionStatus,
    this.faceSimilarityScore,
    required this.evidenceEventIds,
    this.isResolved = false,
    this.resolvedAction,
    this.resolvedByUserCode,
    this.resolvedReason,
    this.resolvedAtUtc,
    this.supersedingDecisionId,
  });

  bool get isHardSecurityDenial =>
      ErrorCatalog.isHardSecurityDenial(reasonCode);

  bool isAttemptExpired([DateTime? nowUtc]) {
    final check = (nowUtc ?? DateTime.now()).toUtc();
    return attemptState == 'expired' ||
        reasonCode == 'ATTEMPT_EXPIRED' ||
        !attemptExpiresAtUtc.isAfter(check);
  }

  /// Safety Rule: `approve` is ONLY allowed on reviewable uncertainties when the attempt is not expired!
  /// Hard security denials (`UNKNOWN_CREDENTIAL`, `CREDENTIAL_REVOKED`, `IDENTITY_MISMATCH`,
  /// `ACTIVE_VISIT_NOT_FOUND`, `DUPLICATE_ACTIVE_VISIT`) can NEVER be approved.
  bool canApprove([DateTime? nowUtc]) {
    if (isResolved) return false;
    if (isHardSecurityDenial) return false;
    if (isAttemptExpired(nowUtc)) return false;
    return ErrorCatalog.isReviewableUncertainty(reasonCode);
  }

  GuardReviewQueueItem copyWith({
    String? outcome,
    String? reasonCode,
    String? reasonMessage,
    int? currentAttemptVersion,
    String? attemptState,
    bool? isResolved,
    String? resolvedAction,
    String? resolvedByUserCode,
    String? resolvedReason,
    DateTime? resolvedAtUtc,
    String? supersedingDecisionId,
  }) {
    return GuardReviewQueueItem(
      reviewCaseId: reviewCaseId,
      correlationId: correlationId,
      decisionId: decisionId,
      gateId: gateId,
      laneId: laneId,
      direction: direction,
      vehicleType: vehicleType,
      outcome: outcome ?? this.outcome,
      reasonCode: reasonCode ?? this.reasonCode,
      reasonMessage: reasonMessage ?? this.reasonMessage,
      currentAttemptVersion:
          currentAttemptVersion ?? this.currentAttemptVersion,
      attemptState: attemptState ?? this.attemptState,
      createdAtUtc: createdAtUtc,
      attemptExpiresAtUtc: attemptExpiresAtUtc,
      userId: userId,
      userCode: userCode,
      vehicleId: vehicleId,
      vehicleCode: vehicleCode,
      plateText: plateText,
      ocrConfidence: ocrConfidence,
      rfidUid: rfidUid,
      faceRecognitionStatus: faceRecognitionStatus,
      faceSimilarityScore: faceSimilarityScore,
      evidenceEventIds: evidenceEventIds,
      isResolved: isResolved ?? this.isResolved,
      resolvedAction: resolvedAction ?? this.resolvedAction,
      resolvedByUserCode: resolvedByUserCode ?? this.resolvedByUserCode,
      resolvedReason: resolvedReason ?? this.resolvedReason,
      resolvedAtUtc: resolvedAtUtc ?? this.resolvedAtUtc,
      supersedingDecisionId:
          supersedingDecisionId ?? this.supersedingDecisionId,
    );
  }
}

/// Submission payload for `POST /api/v1/guard-reviews` (`§7.9`).
class GuardReviewSubmission {
  final String correlationId;
  final String decisionId;
  final String action; // 'approve' | 'deny' | 'escalate'
  final String reason; // 10..500 characters
  final int expectedAttemptVersion;

  GuardReviewSubmission({
    required this.correlationId,
    required this.decisionId,
    required this.action,
    required this.reason,
    required this.expectedAttemptVersion,
  }) {
    if (!const {'approve', 'deny', 'escalate'}.contains(action)) {
      throw FormatException('Invalid guard review action: $action');
    }
    if (reason.trim().length < 10 || reason.trim().length > 500) {
      throw FormatException(
        'Guard review explanation must be between 10 and 500 characters.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'correlation_id': correlationId,
        'decision_id': decisionId,
        'action': action,
        'reason': reason.trim(),
        'expected_attempt_version': expectedAttemptVersion,
      };
}
