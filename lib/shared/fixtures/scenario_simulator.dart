import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/roster_mode.dart';
import '../../core/network/api_envelope.dart';
import '../../core/network/ws_client.dart';
import '../models/attempt_models.dart';
import '../models/audit_models.dart';
import '../models/auth_models.dart';
import '../models/device_models.dart';
import '../models/event_envelope.dart';
import '../models/parking_models.dart';
import '../models/participant_models.dart';
import '../models/review_models.dart';
import '../models/visit_models.dart';
import 'synthetic_fixtures.dart';

/// Immutable snapshot of the complete SENTRY Command Center state.
class SentrySystemState {
  final RosterMode rosterMode;
  final Map<String, AttemptDto> activeLaneAttempts; // keyed by laneId
  final List<AttemptDto> attemptHistory;
  final List<VisitDto> visits;
  final List<SpaceDto> spaces;
  final List<GuardReviewQueueItem> reviewQueue;
  final List<DeviceDto> devices;
  final List<AuditLogDto> auditLogs;
  final List<ParticipantUserDto> participantDirectory;
  final List<String> recentActivityFeed;
  final WsStreamState wsState;
  final String? lastActionBanner;

  const SentrySystemState({
    required this.rosterMode,
    required this.activeLaneAttempts,
    required this.attemptHistory,
    required this.visits,
    required this.spaces,
    required this.reviewQueue,
    required this.devices,
    required this.auditLogs,
    required this.participantDirectory,
    required this.recentActivityFeed,
    required this.wsState,
    this.lastActionBanner,
  });

  DashboardDto computeDashboardKpis() {
    final activeVisits = visits.where((v) => v.isActive).length;
    final entriesToday = visits.length;
    final exitsToday = visits.where((v) => !v.isActive).length;
    final activeHolds = spaces.where((s) => s.allocationStatus == 'held').length;
    final pendingReviews = reviewQueue.where((r) => !r.isResolved).length;
    final totalSpaces = spaces.length;
    final trulyAvail =
        spaces.where((s) => s.isTrulyAvailableForAllocation).length;
    final occSpaces =
        spaces.where((s) => !s.isUnknownOrStale && s.physicalStatus == 'occupied').length;
    final unkSpaces = spaces.where((s) => s.isUnknownOrStale).length;
    final onlineDevs =
        devices.where((d) => d.effectiveStatus() == 'online').length;

    return DashboardDto(
      activeVisitsCount: activeVisits,
      entriesTodayCount: entriesToday,
      exitsTodayCount: exitsToday,
      activeHoldsAwaitingPassageCount: activeHolds,
      pendingGuardReviewsCount: pendingReviews,
      totalCampusSpaces: totalSpaces,
      trulyAvailableSpaces: trulyAvail,
      occupiedSpaces: occSpaces,
      heldSpaces: activeHolds,
      unknownOrStaleSpaces: unkSpaces,
      onlineDevicesCount: onlineDevs,
      totalDevicesCount: devices.length,
    );
  }

  List<LotSummaryDto> computeLotSummaries() {
    return [
      LotSummaryDto.fromSpaces(
        lotCode: 'A',
        lotName: 'Lot A · STEER Hub & CET',
        nearestLandmark: 'STEER Hub & CET Forecourt',
        spaces: spaces,
      ),
      LotSummaryDto.fromSpaces(
        lotCode: 'B',
        lotName: 'Lot B · CEAFA Building',
        nearestLandmark: 'CEAFA North Canopy',
        spaces: spaces,
      ),
      LotSummaryDto.fromSpaces(
        lotCode: 'C',
        lotName: 'Lot C · Gymnasium & CICS',
        nearestLandmark: 'Gov. Feliciano Leviste Gymnasium',
        spaces: spaces,
      ),
      LotSummaryDto.fromSpaces(
        lotCode: 'D',
        lotName: 'Lot D · RGR Laboratory Annex',
        nearestLandmark: 'RGR Academic Annex',
        spaces: spaces,
      ),
    ];
  }

  SentrySystemState copyWith({
    RosterMode? rosterMode,
    Map<String, AttemptDto>? activeLaneAttempts,
    List<AttemptDto>? attemptHistory,
    List<VisitDto>? visits,
    List<SpaceDto>? spaces,
    List<GuardReviewQueueItem>? reviewQueue,
    List<DeviceDto>? devices,
    List<AuditLogDto>? auditLogs,
    List<ParticipantUserDto>? participantDirectory,
    List<String>? recentActivityFeed,
    WsStreamState? wsState,
    String? lastActionBanner,
  }) {
    return SentrySystemState(
      rosterMode: rosterMode ?? this.rosterMode,
      activeLaneAttempts: activeLaneAttempts ?? this.activeLaneAttempts,
      attemptHistory: attemptHistory ?? this.attemptHistory,
      visits: visits ?? this.visits,
      spaces: spaces ?? this.spaces,
      reviewQueue: reviewQueue ?? this.reviewQueue,
      devices: devices ?? this.devices,
      auditLogs: auditLogs ?? this.auditLogs,
      participantDirectory: participantDirectory ?? this.participantDirectory,
      recentActivityFeed: recentActivityFeed ?? this.recentActivityFeed,
      wsState: wsState ?? this.wsState,
      lastActionBanner: lastActionBanner,
    );
  }
}

/// Interactive Mock Repository & Scenario Simulator (`T01–T32`) enforcing all
/// 6 state separation invariants and Patrick Carpio's 3 confirmed extensions.
class SentryScenarioController extends StateNotifier<SentrySystemState> {
  final WsInvalidationCoordinator wsCoordinator;
  int _seqCounter = 104;

  SentryScenarioController({
    required RosterMode initialRosterMode,
    required this.wsCoordinator,
  }) : super(_buildInitialState(initialRosterMode));

  static SentrySystemState _buildInitialState(RosterMode mode) {
    final now = DateTime.now().toUtc();
    final spaces = SentryFixtures.buildInitialSpaces(now);
    final devices = SentryFixtures.buildInitialDevices(now);
    final directory = SentryFixtures.buildParticipantDirectory(mode);

    final v001 = SentryFixtures.findVehicleByCode('V001')!;
    final v002 = SentryFixtures.findVehicleByCode('V002')!;
    final v003 = SentryFixtures.findVehicleByCode('V003')!;
    final v004 = SentryFixtures.findVehicleByCode('V004')!;
    final v005 = SentryFixtures.findVehicleByCode('V005')!;
    final v007 = SentryFixtures.findVehicleByCode('V007')!;
    final v008 = SentryFixtures.findVehicleByCode('V008')!;

    // Initial Active Lane Attempt on Car Entry Lane: U001 / V001 has ALLOWED decision + 30s held bay A-C03, awaiting passage!
    final carInDecision = AccessDecisionData(
      decisionId: '40000000-0000-4000-8000-000000000001',
      gateId: 'gate-north',
      laneId: 'lane-car-in',
      direction: 'entry',
      vehicleType: 'car',
      outcome: 'allowed',
      reasonCode: 'AUTHORIZED',
      reasonMessage:
          '3-way check passed: Plate OCR + ArcFace driver match verified. Bay A-C03 held for 30s.',
      userId: v001.ownerUserId,
      vehicleId: v001.vehicleId,
      visitId: null, // Strictly null before passage confirmation!
      assignmentId: '50000000-0000-4000-8000-000000000001',
      evidenceEventIds: const [
        '80000000-0000-4000-8000-000000000011',
        '80000000-0000-4000-8000-000000000012',
      ],
      expiresAtUtc: now.add(const Duration(seconds: 20)),
      supersedesDecisionId: null,
      attemptVersion: 1,
    );

    final initialCarInAttempt = AttemptDto(
      correlationId: '90000000-0000-4000-8000-000000000001',
      gateId: 'gate-north',
      laneId: 'lane-car-in',
      direction: 'entry',
      vehicleType: 'car',
      state: 'authorization_allowed',
      attemptVersion: 1,
      startedAtUtc: now.subtract(const Duration(seconds: 4)),
      expiresAtUtc: now.add(const Duration(seconds: 56)),
      plateText: v001.normalizedPlate(mode),
      plateRecognitionStatus: 'recognized',
      detectionConfidence: 0.99,
      ocrConfidence: 0.97,
      plateModelVersion: 'yolo-plate-v1.2',
      faceRecognitionStatus: 'matched',
      faceSimilarityScore: 0.84, // Calibrated cosine similarity
      faceCount: 1,
      faceTriggerEventId: '80000000-0000-4000-8000-000000000011',
      faceModelVersion: 'arcface-r100-v1.1',
      userId: v001.ownerUserId,
      userCode: 'U001',
      vehicleId: v001.vehicleId,
      vehicleCode: 'V001',
      latestDecision: carInDecision,
      gateActuationClaimed: true,
      gateClaimedAtUtc: now.subtract(const Duration(seconds: 2)),
      passageConfirmed: false, // Awaiting guard attestation or passage sensor!
      assignmentId: '50000000-0000-4000-8000-000000000001',
      spaceId: '30000000-0000-4000-8000-000000000103',
      spaceCode: 'A-C03',
      lotCode: 'A',
      assignmentStatus: 'held',
      holdExpiresAtUtc: now.add(const Duration(seconds: 26)),
      committedVisitId: null,
    );

    // Initial Motorcycle Entry Lane Attempt: U004 / V004 awaiting Guard Review (IDENTITY_UNCERTAIN)
    final motoInDecision = AccessDecisionData(
      decisionId: '40000000-0000-4000-8000-000000000004',
      gateId: 'gate-north',
      laneId: 'lane-moto-in',
      direction: 'entry',
      vehicleType: 'motorcycle',
      outcome: 'review_required',
      reasonCode: 'IDENTITY_UNCERTAIN',
      reasonMessage:
          'RFID 04D4E5F6 valid for V004, but helmet visor caused uncertain ArcFace similarity (0.52 cosine similarity).',
      userId: v004.ownerUserId,
      vehicleId: v004.vehicleId,
      visitId: null,
      assignmentId: null,
      evidenceEventIds: const [
        '80000000-0000-4000-8000-000000000041',
        '80000000-0000-4000-8000-000000000042',
      ],
      expiresAtUtc: null,
      supersedesDecisionId: null,
      attemptVersion: 1,
    );

    final initialMotoInAttempt = AttemptDto(
      correlationId: '90000000-0000-4000-8000-000000000004',
      gateId: 'gate-north',
      laneId: 'lane-moto-in',
      direction: 'entry',
      vehicleType: 'motorcycle',
      state: 'guard_review_required',
      attemptVersion: 1,
      startedAtUtc: now.subtract(const Duration(seconds: 12)),
      expiresAtUtc: now.add(const Duration(seconds: 48)),
      rfidUid: v004.rfidUid,
      rfidReaderModel: 'rc522',
      rfidFirmwareVersion: 'esp32-rc522-fw-v1.0.8',
      faceRecognitionStatus: 'uncertain',
      faceSimilarityScore: 0.52,
      faceCount: 1,
      faceTriggerEventId: '80000000-0000-4000-8000-000000000041',
      faceModelVersion: 'arcface-r100-v1.1',
      userId: v004.ownerUserId,
      userCode: 'U004',
      vehicleId: v004.vehicleId,
      vehicleCode: 'V004',
      latestDecision: motoInDecision,
      passageConfirmed: false,
    );

    // Initial Car Exit Lane Attempt: U003 / V003 ready to exit (Plate OCR only; Face Not Required on Exit!)
    final carOutDecision = AccessDecisionData(
      decisionId: '40000000-0000-4000-8000-000000000003',
      gateId: 'gate-north',
      laneId: 'lane-car-out',
      direction: 'exit',
      vehicleType: 'car',
      outcome: 'allowed',
      reasonCode: 'AUTHORIZED',
      reasonMessage:
          'Active campus visit VS03 verified for V003 via exit Plate OCR. Ready for departure confirmation.',
      userId: v003.ownerUserId,
      vehicleId: v003.vehicleId,
      visitId: '60000000-0000-4000-8000-000000000003',
      assignmentId: '50000000-0000-4000-8000-000000000003',
      evidenceEventIds: const ['80000000-0000-4000-8000-000000000031'],
      expiresAtUtc: now.add(const Duration(seconds: 20)),
      supersedesDecisionId: null,
      attemptVersion: 1,
    );

    final initialCarOutAttempt = AttemptDto(
      correlationId: '90000000-0000-4000-8000-000000000003',
      gateId: 'gate-north',
      laneId: 'lane-car-out',
      direction: 'exit',
      vehicleType: 'car',
      state: 'authorization_allowed',
      attemptVersion: 1,
      startedAtUtc: now.subtract(const Duration(seconds: 5)),
      expiresAtUtc: now.add(const Duration(seconds: 55)),
      plateText: v003.normalizedPlate(mode),
      plateRecognitionStatus: 'recognized',
      detectionConfidence: 0.98,
      ocrConfidence: 0.96,
      plateModelVersion: 'yolo-plate-v1.2',
      faceRecognitionStatus: 'not_required',
      faceSimilarityScore: null,
      userId: v003.ownerUserId,
      userCode: 'U003',
      vehicleId: v003.vehicleId,
      vehicleCode: 'V003',
      latestDecision: carOutDecision,
      gateActuationClaimed: true,
      gateClaimedAtUtc: now.subtract(const Duration(seconds: 2)),
      passageConfirmed: false,
      assignmentId: '50000000-0000-4000-8000-000000000003',
      spaceId: '30000000-0000-4000-8000-000000000102',
      spaceCode: 'A-C02',
      lotCode: 'A',
      assignmentStatus: 'assigned',
      committedVisitId: '60000000-0000-4000-8000-000000000003',
    );

    // Initial Moto Exit Lane Attempt: U002 / V002 RFID scan on exit
    final motoOutDecision = AccessDecisionData(
      decisionId: '40000000-0000-4000-8000-000000000002',
      gateId: 'gate-north',
      laneId: 'lane-moto-out',
      direction: 'exit',
      vehicleType: 'motorcycle',
      outcome: 'allowed',
      reasonCode: 'AUTHORIZED',
      reasonMessage:
          'Active motorcycle visit VS02 verified via ESP32 RFID scan (04A1B2C3). No plate/face required on exit.',
      userId: v002.ownerUserId,
      vehicleId: v002.vehicleId,
      visitId: '60000000-0000-4000-8000-000000000002',
      assignmentId: '50000000-0000-4000-8000-000000000002',
      evidenceEventIds: const ['80000000-0000-4000-8000-000000000021'],
      expiresAtUtc: now.add(const Duration(seconds: 20)),
      supersedesDecisionId: null,
      attemptVersion: 1,
    );

    final initialMotoOutAttempt = AttemptDto(
      correlationId: '90000000-0000-4000-8000-000000000002',
      gateId: 'gate-north',
      laneId: 'lane-moto-out',
      direction: 'exit',
      vehicleType: 'motorcycle',
      state: 'authorization_allowed',
      attemptVersion: 1,
      startedAtUtc: now.subtract(const Duration(seconds: 6)),
      expiresAtUtc: now.add(const Duration(seconds: 54)),
      rfidUid: v002.rfidUid,
      rfidReaderModel: 'rc522',
      rfidFirmwareVersion: 'esp32-rc522-fw-v1.0.8',
      faceRecognitionStatus: 'not_required',
      faceSimilarityScore: null,
      userId: v002.ownerUserId,
      userCode: 'U002',
      vehicleId: v002.vehicleId,
      vehicleCode: 'V002',
      latestDecision: motoOutDecision,
      gateActuationClaimed: true,
      passageConfirmed: false,
      assignmentId: '50000000-0000-4000-8000-000000000002',
      spaceId: '30000000-0000-4000-8000-000000000108',
      spaceCode: 'A-M02',
      lotCode: 'A',
      assignmentStatus: 'assigned',
      committedVisitId: '60000000-0000-4000-8000-000000000002',
    );

    // Historical Denied Attempt for U007's second car V008 while V007 is inside (T07 / T19)
    final v008CompetingDecision = AccessDecisionData(
      decisionId: '40000000-0000-4000-8000-000000000008',
      gateId: 'gate-north',
      laneId: 'lane-car-in',
      direction: 'entry',
      vehicleType: 'car',
      outcome: 'denied',
      reasonCode: 'DUPLICATE_ACTIVE_VISIT',
      reasonMessage:
          'User U007 already has an active campus visit with vehicle V007 (Bay B-C04). V007 must exit before V008 can enter.',
      userId: v008.ownerUserId,
      vehicleId: v008.vehicleId,
      visitId: null,
      assignmentId: null,
      evidenceEventIds: const ['80000000-0000-4000-8000-000000000081'],
      expiresAtUtc: null,
      attemptVersion: 1,
    );

    final v008DeniedAttempt = AttemptDto(
      correlationId: '90000000-0000-4000-8000-000000000008',
      gateId: 'gate-north',
      laneId: 'lane-car-in',
      direction: 'entry',
      vehicleType: 'car',
      state: 'authorization_denied',
      attemptVersion: 1,
      startedAtUtc: now.subtract(const Duration(minutes: 18)),
      expiresAtUtc: now.subtract(const Duration(minutes: 17)),
      plateText: v008.normalizedPlate(mode),
      plateRecognitionStatus: 'recognized',
      detectionConfidence: 0.99,
      ocrConfidence: 0.98,
      faceRecognitionStatus: 'matched',
      faceSimilarityScore: 0.86,
      userId: v008.ownerUserId,
      userCode: 'U007',
      vehicleId: v008.vehicleId,
      vehicleCode: 'V008',
      latestDecision: v008CompetingDecision,
    );

    // Confirmed Campus Visits (Active + Closed historical)
    final initialVisits = <VisitDto>[
      // Active Visit 1: U007 driving V007 parked at B-C04
      VisitDto(
        visitId: '60000000-0000-4000-8000-000000000007',
        visitCode: 'VS07',
        entryCorrelationId: '90000000-0000-4000-8000-000000000070',
        userId: v007.ownerUserId,
        userCode: 'U007',
        vehicleId: v007.vehicleId,
        vehicleCode: 'V007',
        vehicleType: 'car',
        status: 'active',
        entryGateId: 'gate-north',
        entryLaneId: 'lane-car-in',
        enteredAtUtc: now.subtract(const Duration(hours: 1, minutes: 42)),
        entryConfirmationSource: 'sensor',
        assignmentId: '50000000-0000-4000-8000-000000000007',
        lotCode: 'B',
        spaceId: '30000000-0000-4000-8000-000000000204',
        spaceCode: 'B-C04',
      ),
      // Active Visit 2: U003 driving V003 parked at A-C02
      VisitDto(
        visitId: '60000000-0000-4000-8000-000000000003',
        visitCode: 'VS03',
        entryCorrelationId: '90000000-0000-4000-8000-000000000030',
        userId: v003.ownerUserId,
        userCode: 'U003',
        vehicleId: v003.vehicleId,
        vehicleCode: 'V003',
        vehicleType: 'car',
        status: 'active',
        entryGateId: 'gate-north',
        entryLaneId: 'lane-car-in',
        enteredAtUtc: now.subtract(const Duration(hours: 2, minutes: 15)),
        entryConfirmationSource: 'sensor',
        assignmentId: '50000000-0000-4000-8000-000000000003',
        lotCode: 'A',
        spaceId: '30000000-0000-4000-8000-000000000102',
        spaceCode: 'A-C02',
      ),
      // Active Visit 3: U002 riding V002 parked at A-M02
      VisitDto(
        visitId: '60000000-0000-4000-8000-000000000002',
        visitCode: 'VS02',
        entryCorrelationId: '90000000-0000-4000-8000-000000000020',
        userId: v002.ownerUserId,
        userCode: 'U002',
        vehicleId: v002.vehicleId,
        vehicleCode: 'V002',
        vehicleType: 'motorcycle',
        status: 'active',
        entryGateId: 'gate-north',
        entryLaneId: 'lane-moto-in',
        enteredAtUtc: now.subtract(const Duration(minutes: 54)),
        entryConfirmationSource: 'guard_attestation',
        assignmentId: '50000000-0000-4000-8000-000000000002',
        lotCode: 'A',
        spaceId: '30000000-0000-4000-8000-000000000108',
        spaceCode: 'A-M02',
      ),
      // Historical Closed Visit 4: U007 driving V008 earlier today (completed exit!)
      // Demonstrates V007 and V008 have distinct, non-merged histories under U007!
      VisitDto(
        visitId: '60000000-0000-4000-8000-000000000008',
        visitCode: 'VS08-HIST',
        entryCorrelationId: '90000000-0000-4000-8000-000000000080',
        exitCorrelationId: '90000000-0000-4000-8000-000000000089',
        userId: v008.ownerUserId,
        userCode: 'U007',
        vehicleId: v008.vehicleId,
        vehicleCode: 'V008',
        vehicleType: 'car',
        status: 'closed',
        entryGateId: 'gate-north',
        entryLaneId: 'lane-car-in',
        enteredAtUtc: now.subtract(const Duration(hours: 5, minutes: 30)),
        entryConfirmationSource: 'sensor',
        exitGateId: 'gate-north',
        exitLaneId: 'lane-car-out',
        exitedAtUtc: now.subtract(const Duration(hours: 3, minutes: 10)),
        exitConfirmationSource: 'sensor',
        assignmentId: '50000000-0000-4000-8000-000000000008',
        lotCode: 'C',
        spaceId: '30000000-0000-4000-8000-000000000301',
        spaceCode: 'C-C01',
      ),
      // Historical Closed Visit 5: U005 driving V005 earlier today
      VisitDto(
        visitId: '60000000-0000-4000-8000-000000000005',
        visitCode: 'VS05-HIST',
        entryCorrelationId: '90000000-0000-4000-8000-000000000050',
        exitCorrelationId: '90000000-0000-4000-8000-000000000059',
        userId: v005.ownerUserId,
        userCode: 'U005',
        vehicleId: v005.vehicleId,
        vehicleCode: 'V005',
        vehicleType: 'car',
        status: 'closed',
        entryGateId: 'gate-north',
        entryLaneId: 'lane-car-in',
        enteredAtUtc: now.subtract(const Duration(hours: 4, minutes: 15)),
        entryConfirmationSource: 'sensor',
        exitGateId: 'gate-north',
        exitLaneId: 'lane-car-out',
        exitedAtUtc: now.subtract(const Duration(hours: 1, minutes: 05)),
        exitConfirmationSource: 'guard_attestation',
        assignmentId: '50000000-0000-4000-8000-000000000005',
        lotCode: 'D',
        spaceId: '30000000-0000-4000-8000-000000000401',
        spaceCode: 'D-C01',
      ),
    ];

    // Initial Guard Review Queue (Reviewable uncertainties + Hard denials for safety inspection)
    final reviewQueue = <GuardReviewQueueItem>[
      GuardReviewQueueItem(
        reviewCaseId: 'RV-101',
        correlationId: initialMotoInAttempt.correlationId,
        decisionId: motoInDecision.decisionId,
        gateId: 'gate-north',
        laneId: 'lane-moto-in',
        direction: 'entry',
        vehicleType: 'motorcycle',
        outcome: 'review_required',
        reasonCode: 'IDENTITY_UNCERTAIN',
        reasonMessage: motoInDecision.reasonMessage,
        currentAttemptVersion: 1,
        attemptState: 'guard_review_required',
        createdAtUtc: now.subtract(const Duration(seconds: 12)),
        attemptExpiresAtUtc: now.add(const Duration(minutes: 5)),
        userId: v004.ownerUserId,
        userCode: 'U004',
        vehicleId: v004.vehicleId,
        vehicleCode: 'V004',
        rfidUid: v004.rfidUid,
        faceRecognitionStatus: 'uncertain',
        faceSimilarityScore: 0.52,
        evidenceEventIds: motoInDecision.evidenceEventIds,
      ),
      GuardReviewQueueItem(
        reviewCaseId: 'RV-102',
        correlationId: '90000000-0000-4000-8000-000000000005',
        decisionId: '40000000-0000-4000-8000-000000000005',
        gateId: 'gate-north',
        laneId: 'lane-car-in',
        direction: 'entry',
        vehicleType: 'car',
        outcome: 'review_required',
        reasonCode: 'OCCUPANCY_CONFLICT',
        reasonMessage:
            'Preferred bay A-C05 reported physical_status=occupied by overhead camera while allocation_status=unassigned.',
        currentAttemptVersion: 1,
        attemptState: 'guard_review_required',
        createdAtUtc: now.subtract(const Duration(minutes: 2)),
        attemptExpiresAtUtc: now.add(const Duration(minutes: 4)),
        userId: v005.ownerUserId,
        userCode: 'U005',
        vehicleId: v005.vehicleId,
        vehicleCode: 'V005',
        plateText: v005.normalizedPlate(mode),
        ocrConfidence: 0.94,
        faceRecognitionStatus: 'matched',
        faceSimilarityScore: 0.79,
        evidenceEventIds: const ['80000000-0000-4000-8000-000000000051'],
      ),
      GuardReviewQueueItem(
        reviewCaseId: 'RV-103-HARD',
        correlationId: v008DeniedAttempt.correlationId,
        decisionId: v008CompetingDecision.decisionId,
        gateId: 'gate-north',
        laneId: 'lane-car-in',
        direction: 'entry',
        vehicleType: 'car',
        outcome: 'denied',
        reasonCode: 'DUPLICATE_ACTIVE_VISIT',
        reasonMessage: v008CompetingDecision.reasonMessage,
        currentAttemptVersion: 1,
        attemptState: 'authorization_denied',
        createdAtUtc: now.subtract(const Duration(minutes: 18)),
        attemptExpiresAtUtc: now.add(const Duration(minutes: 3)),
        userId: v008.ownerUserId,
        userCode: 'U007',
        vehicleId: v008.vehicleId,
        vehicleCode: 'V008',
        plateText: v008.normalizedPlate(mode),
        ocrConfidence: 0.98,
        faceRecognitionStatus: 'matched',
        faceSimilarityScore: 0.86,
        evidenceEventIds: v008CompetingDecision.evidenceEventIds,
      ),
      GuardReviewQueueItem(
        reviewCaseId: 'RV-104-HARD',
        correlationId: '90000000-0000-4000-8000-000000000099',
        decisionId: '40000000-0000-4000-8000-000000000099',
        gateId: 'gate-north',
        laneId: 'lane-car-in',
        direction: 'entry',
        vehicleType: 'car',
        outcome: 'denied',
        reasonCode: 'IDENTITY_MISMATCH',
        reasonMessage:
            'Plate UKQ247 belongs to U001 (V001), but ArcFace matched U003 (0.83 cosine similarity) with no multi-driver authorization.',
        currentAttemptVersion: 1,
        attemptState: 'authorization_denied',
        createdAtUtc: now.subtract(const Duration(minutes: 25)),
        attemptExpiresAtUtc: now.add(const Duration(minutes: 3)),
        userId: v001.ownerUserId,
        userCode: 'U001',
        vehicleId: v001.vehicleId,
        vehicleCode: 'V001',
        plateText: v001.normalizedPlate(mode),
        ocrConfidence: 0.97,
        faceRecognitionStatus: 'unknown',
        faceSimilarityScore: 0.21,
        evidenceEventIds: const ['80000000-0000-4000-8000-000000000091'],
      ),
    ];

    final initialAudits = <AuditLogDto>[
      AuditLogDto(
        auditId: 'AUD-9001',
        occurredAtUtc: now.subtract(const Duration(minutes: 54)),
        actorUserId: SentryFixtures.guardOperator.userId,
        actorUserCode: 'G001',
        actorRole: 'guard',
        action: 'passage_attested',
        resourceType: 'access_visit',
        resourceId: '60000000-0000-4000-8000-000000000002',
        requestId: 'req-attest-0092',
        summary:
            'Guard G001 confirmed motorcycle V002 physical crossing at Gate 1 entry lane (guard_attestation). Created active visit VS02.',
      ),
      AuditLogDto(
        auditId: 'AUD-9002',
        occurredAtUtc: now.subtract(const Duration(hours: 1, minutes: 5)),
        actorUserId: SentryFixtures.guardOperator.userId,
        actorUserCode: 'G001',
        actorRole: 'guard',
        action: 'passage_attested',
        resourceType: 'access_visit',
        resourceId: '60000000-0000-4000-8000-000000000005',
        requestId: 'req-attest-0088',
        summary:
            'Guard G001 confirmed car V005 physical exit at Gate 1 exit lane. Closed visit VS05-HIST and released bay D-C01.',
      ),
      AuditLogDto(
        auditId: 'AUD-9003',
        occurredAtUtc: now.subtract(const Duration(hours: 3)),
        actorUserId: SentryFixtures.adminOperator.userId,
        actorUserCode: 'A001',
        actorRole: 'administrator',
        action: 'vehicle_registered',
        resourceType: 'participant_vehicle',
        resourceId: '20000000-0000-4000-8000-000000000008',
        requestId: 'req-admin-0041',
        summary:
            'Administrator A001 verified secondary vehicle V008 under U007 (multi-vehicle single-visit constraint active).',
      ),
    ];

    return SentrySystemState(
      rosterMode: mode,
      activeLaneAttempts: {
        'lane-car-in': initialCarInAttempt,
        'lane-car-out': initialCarOutAttempt,
        'lane-moto-in': initialMotoInAttempt,
        'lane-moto-out': initialMotoOutAttempt,
      },
      attemptHistory: [
        initialCarInAttempt,
        initialMotoInAttempt,
        initialCarOutAttempt,
        initialMotoOutAttempt,
        v008DeniedAttempt,
      ],
      visits: initialVisits,
      spaces: spaces,
      reviewQueue: reviewQueue,
      devices: devices,
      auditLogs: initialAudits,
      participantDirectory: directory,
      recentActivityFeed: const [
        'GATE-NORTH/CAR-IN: V001 (U001) ALLOWED · Space A-C03 HELD (30s) · Awaiting physical passage confirmation',
        'GATE-NORTH/MOTO-IN: V004 (U004) REVIEW_REQUIRED (IDENTITY_UNCERTAIN · 0.52 cosine similarity)',
        'LOT A OVERHEAD CAM: Bay A-C05 reported OCCUPANCY_CONFLICT (physical=occupied, allocation=unassigned)',
        'GATE-NORTH/CAR-IN: V008 (U007) DENIED (DUPLICATE_ACTIVE_VISIT · V007 already active in B-C04)',
      ],
      wsState: WsStreamState(
        status: WsConnectionStatus.connected,
        lastStreamSequence: 104,
        lastSyncedAtUtc: now,
      ),
    );
  }

  /// Switches between `RosterMode.classDemo` and `RosterMode.contractSynthetic`
  /// while preserving all relational UUIDs.
  void setRosterMode(RosterMode mode) {
    final updatedDirectory = SentryFixtures.buildParticipantDirectory(mode);
    final updatedLaneAttempts = <String, AttemptDto>{};
    state.activeLaneAttempts.forEach((laneId, attempt) {
      final vf = SentryFixtures.findVehicleByCode(attempt.vehicleCode);
      updatedLaneAttempts[laneId] = vf != null && attempt.vehicleType == 'car'
          ? attempt.copyWith(plateText: vf.normalizedPlate(mode))
          : attempt;
    });
    final updatedHistory = state.attemptHistory.map((attempt) {
      final vf = SentryFixtures.findVehicleByCode(attempt.vehicleCode);
      return vf != null && attempt.vehicleType == 'car'
          ? attempt.copyWith(plateText: vf.normalizedPlate(mode))
          : attempt;
    }).toList();

    state = state.copyWith(
      rosterMode: mode,
      participantDirectory: updatedDirectory,
      activeLaneAttempts: updatedLaneAttempts,
      attemptHistory: updatedHistory,
      lastActionBanner: 'Switched display roster to ${mode.label}.',
    );
  }

  /// Patrick Carpio's Confirmed Contract #3:
  /// Guard clicks "Confirm Vehicle Crossed Gate (`guard_attestation`)" on an `allowed` attempt.
  /// - Validates 10..500 character `notes`
  /// - Validates attempt has a non-expired `allowed` decision
  /// - Entry: transitions `held` space -> `assigned` and creates an `active` `VisitDto`
  /// - Exit: closes the `active` `VisitDto` and transitions `assigned` space -> `unassigned` (`released`)
  ApiEnvelope<VisitDto> confirmVehicleCrossedGate({
    required String laneId,
    required String notes,
    required ProfileDto actor,
  }) {
    final trimmed = notes.trim();
    if (trimmed.length < 10 || trimmed.length > 500) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.validationFailed,
        message:
            'Guard attestation notes must be between 10 and 500 characters (received ${trimmed.length}).',
        httpStatus: 422,
      );
    }

    final attempt = state.activeLaneAttempts[laneId];
    if (attempt == null) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.notFound,
        message: 'No active gate attempt found on lane $laneId.',
        httpStatus: 404,
      );
    }

    final decision = attempt.latestDecision;
    if (decision == null || decision.outcome != 'allowed') {
      return ApiEnvelope.failure(
        code: ErrorCatalog.validationFailed,
        message:
            'Cannot confirm passage: attempt ${attempt.correlationId} does not have an allowed decision.',
        httpStatus: 409,
      );
    }

    final now = DateTime.now().toUtc();
    if (decision.isExpired(now) || attempt.state == 'expired') {
      return ApiEnvelope.failure(
        code: ErrorCatalog.decisionExpired,
        message:
            'Decision ${decision.decisionId} has expired (20s validity window elapsed). Cannot confirm passage.',
        httpStatus: 409,
      );
    }

    if (attempt.direction == 'entry') {
      // Enforce U007 Multi-Vehicle Single-Visit Constraint before committing visit
      final existingActiveForUser = state.visits.any(
        (v) => v.isActive && v.userId == attempt.userId,
      );
      if (existingActiveForUser) {
        return ApiEnvelope.failure(
          code: ErrorCatalog.duplicateActiveVisit,
          message:
              'DUPLICATE_ACTIVE_VISIT: User ${attempt.userCode} already has an active campus visit.',
          httpStatus: 409,
        );
      }

      final newVisitId =
          '60000000-0000-4000-8000-${(_seqCounter++).toString().padLeft(12, '0')}';
      final newVisitCode = 'VS-${attempt.vehicleCode}';
      final createdVisit = VisitDto(
        visitId: newVisitId,
        visitCode: newVisitCode,
        entryCorrelationId: attempt.correlationId,
        userId: attempt.userId ?? '',
        userCode: attempt.userCode ?? 'U001',
        vehicleId: attempt.vehicleId ?? '',
        vehicleCode: attempt.vehicleCode ?? 'V001',
        vehicleType: attempt.vehicleType,
        status: 'active',
        entryGateId: attempt.gateId,
        entryLaneId: attempt.laneId,
        enteredAtUtc: now,
        entryConfirmationSource: 'guard_attestation',
        assignmentId: attempt.assignmentId,
        lotCode: attempt.lotCode,
        spaceId: attempt.spaceId,
        spaceCode: attempt.spaceCode,
      );

      final updatedAttempt = attempt.copyWith(
        state: 'completed',
        gateActuationClaimed: true,
        passageConfirmed: true,
        passageConfirmationSource: 'guard_attestation',
        passageConfirmedAtUtc: now,
        assignmentStatus: 'assigned',
        committedVisitId: newVisitId,
      );

      final updatedSpaces = state.spaces.map((s) {
        if (s.spaceCode == attempt.spaceCode || s.spaceId == attempt.spaceId) {
          return s.copyWith(
            physicalStatus: 'occupied',
            allocationStatus: 'assigned',
            visitId: newVisitId,
            assignedVehicleCode: attempt.vehicleCode,
            assignedUserCode: attempt.userCode,
          );
        }
        return s;
      }).toList();

      final newAudit = AuditLogDto(
        auditId: 'AUD-${_seqCounter++}',
        occurredAtUtc: now,
        actorUserId: actor.userId,
        actorUserCode: actor.userCode,
        actorRole: actor.role.wireValue,
        action: 'passage_attested',
        resourceType: 'access_visit',
        resourceId: newVisitId,
        requestId: 'req-attest-$_seqCounter',
        summary:
            'Guard ${actor.userCode} attested physical entry for ${attempt.vehicleCode} (${attempt.userCode}) at ${attempt.laneId}. Space ${attempt.spaceCode} transitioned HELD -> ASSIGNED. Notes: "$trimmed"',
      );

      _applyRealtimeTick(
        resourceType: 'access_visit',
        resourceId: newVisitId,
      );

      final updatedLanes =
          Map<String, AttemptDto>.from(state.activeLaneAttempts);
      updatedLanes[laneId] = updatedAttempt;

      final updatedHistory = [
        updatedAttempt,
        ...state.attemptHistory
            .where((a) => a.correlationId != updatedAttempt.correlationId),
      ];

      state = state.copyWith(
        activeLaneAttempts: updatedLanes,
        attemptHistory: updatedHistory,
        visits: [createdVisit, ...state.visits],
        spaces: updatedSpaces,
        auditLogs: [newAudit, ...state.auditLogs],
        recentActivityFeed: [
          'PASSAGE CONFIRMED (guard_attestation): ${attempt.vehicleCode} (${attempt.userCode}) crossed ${attempt.laneId} -> Active Visit $newVisitCode & Space ${attempt.spaceCode} ASSIGNED',
          ...state.recentActivityFeed.take(14),
        ],
        lastActionBanner:
            'Confirmed physical entry for ${attempt.vehicleCode}: Active Visit $newVisitCode created & Space ${attempt.spaceCode} transitioned HELD -> ASSIGNED.',
      );

      return ApiEnvelope.success(createdVisit);
    } else {
      // Exit confirmation: close active visit and release parking space
      VisitDto? closedVisit;
      final updatedVisits = state.visits.map((v) {
        if (v.isActive &&
            (v.visitId == attempt.committedVisitId ||
                v.vehicleCode == attempt.vehicleCode)) {
          closedVisit = v.copyWith(
            status: 'closed',
            exitCorrelationId: attempt.correlationId,
            exitGateId: attempt.gateId,
            exitLaneId: attempt.laneId,
            exitedAtUtc: now,
            exitConfirmationSource: 'guard_attestation',
          );
          return closedVisit!;
        }
        return v;
      }).toList();

      if (closedVisit == null) {
        return ApiEnvelope.failure(
          code: ErrorCatalog.activeVisitNotFound,
          message:
              'ACTIVE_VISIT_NOT_FOUND: No active campus visit found for ${attempt.vehicleCode}.',
          httpStatus: 409,
        );
      }

      final updatedAttempt = attempt.copyWith(
        state: 'completed',
        gateActuationClaimed: true,
        passageConfirmed: true,
        passageConfirmationSource: 'guard_attestation',
        passageConfirmedAtUtc: now,
        assignmentStatus: 'released',
        committedVisitId: closedVisit!.visitId,
      );

      final updatedSpaces = state.spaces.map((s) {
        if (s.spaceCode == closedVisit!.spaceCode ||
            s.assignedVehicleCode == attempt.vehicleCode) {
          return s.copyWith(
            physicalStatus: 'available',
            allocationStatus: 'unassigned',
            clearAssignment: true,
            clearVisit: true,
          );
        }
        return s;
      }).toList();

      final newAudit = AuditLogDto(
        auditId: 'AUD-${_seqCounter++}',
        occurredAtUtc: now,
        actorUserId: actor.userId,
        actorUserCode: actor.userCode,
        actorRole: actor.role.wireValue,
        action: 'passage_attested',
        resourceType: 'access_visit',
        resourceId: closedVisit!.visitId,
        requestId: 'req-exit-$_seqCounter',
        summary:
            'Guard ${actor.userCode} attested physical exit for ${attempt.vehicleCode} (${attempt.userCode}). Visit ${closedVisit!.visitCode} CLOSED & Bay ${closedVisit!.spaceCode} RELEASED. Notes: "$trimmed"',
      );

      _applyRealtimeTick(
        resourceType: 'access_visit',
        resourceId: closedVisit!.visitId,
      );

      final updatedLanes =
          Map<String, AttemptDto>.from(state.activeLaneAttempts);
      updatedLanes[laneId] = updatedAttempt;

      final updatedHistory = [
        updatedAttempt,
        ...state.attemptHistory
            .where((a) => a.correlationId != updatedAttempt.correlationId),
      ];

      state = state.copyWith(
        activeLaneAttempts: updatedLanes,
        attemptHistory: updatedHistory,
        visits: updatedVisits,
        spaces: updatedSpaces,
        auditLogs: [newAudit, ...state.auditLogs],
        recentActivityFeed: [
          'EXIT CONFIRMED (guard_attestation): ${attempt.vehicleCode} (${attempt.userCode}) departed -> Visit ${closedVisit!.visitCode} CLOSED & Bay ${closedVisit!.spaceCode} RELEASED',
          ...state.recentActivityFeed.take(14),
        ],
        lastActionBanner:
            'Confirmed physical exit for ${attempt.vehicleCode}: Visit ${closedVisit!.visitCode} closed & Space ${closedVisit!.spaceCode} released.',
      );

      return ApiEnvelope.success(closedVisit!);
    }
  }

  /// Cancels an active gate attempt before physical passage confirmation
  /// (`POST /api/v1/access-attempts/{correlation_id}/cancel`).
  /// Releases any 30s `held` space back to `unassigned`.
  ApiEnvelope<AttemptDto> cancelAttemptBeforePassage(String laneId) {
    final attempt = state.activeLaneAttempts[laneId];
    if (attempt == null || !attempt.canCancelBeforePassage) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.validationFailed,
        message: 'Attempt cannot be cancelled (already confirmed or closed).',
        httpStatus: 409,
      );
    }

    final updatedAttempt = attempt.copyWith(
      state: 'cancelled',
      assignmentStatus:
          attempt.assignmentStatus == 'held' ? 'released' : attempt.assignmentStatus,
    );

    final updatedSpaces = state.spaces.map((s) {
      if (attempt.assignmentStatus == 'held' &&
          s.spaceCode == attempt.spaceCode) {
        return s.copyWith(
          allocationStatus: 'unassigned',
          clearAssignment: true,
          clearVisit: true,
        );
      }
      return s;
    }).toList();

    final updatedLanes = Map<String, AttemptDto>.from(state.activeLaneAttempts);
    updatedLanes[laneId] = updatedAttempt;

    state = state.copyWith(
      activeLaneAttempts: updatedLanes,
      attemptHistory: [
        updatedAttempt,
        ...state.attemptHistory
            .where((a) => a.correlationId != updatedAttempt.correlationId),
      ],
      spaces: updatedSpaces,
      recentActivityFeed: [
        'ATTEMPT CANCELLED: ${attempt.vehicleCode ?? attempt.correlationId} cancelled before passage; held bay ${attempt.spaceCode ?? 'N/A'} released.',
        ...state.recentActivityFeed.take(14),
      ],
      lastActionBanner:
          'Cancelled attempt ${attempt.correlationId} before passage and released held space.',
    );

    return ApiEnvelope.success(updatedAttempt);
  }

  /// Submits a Guard Review (`POST /api/v1/guard-reviews` — View 4).
  /// Enforces:
  /// - 10..500 character `reason`
  /// - `expectedAttemptVersion == currentAttemptVersion` (returns `409 STALE_VERSION` on mismatch)
  /// - Hard security denials (`UNKNOWN_CREDENTIAL`, `CREDENTIAL_REVOKED`, `IDENTITY_MISMATCH`,
  ///   `DUPLICATE_ACTIVE_VISIT`, `ACTIVE_VISIT_NOT_FOUND`) CANNOT be approved!
  /// - Approving a reviewable uncertainty (`IDENTITY_UNCERTAIN`, `OCCUPANCY_CONFLICT`, etc.)
  ///   appends a new `access_decision` (`supersedes_decision_id` set, `attempt_version` incremented,
  ///   `outcome: allowed`, 30s space `held` with `visit_id: null`), and requires passage confirmation next!
  ApiEnvelope<GuardReviewQueueItem> submitGuardReview({
    required String reviewCaseId,
    required String action, // 'approve' | 'deny' | 'escalate'
    required String reason,
    required int expectedAttemptVersion,
    required ProfileDto actor,
  }) {
    final trimmed = reason.trim();
    if (trimmed.length < 10 || trimmed.length > 500) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.validationFailed,
        message: 'Guard review explanation must be 10–500 characters.',
        httpStatus: 422,
      );
    }

    final idx =
        state.reviewQueue.indexWhere((r) => r.reviewCaseId == reviewCaseId);
    if (idx < 0) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.notFound,
        message: 'Review case $reviewCaseId not found.',
        httpStatus: 404,
      );
    }

    final item = state.reviewQueue[idx];
    if (expectedAttemptVersion != item.currentAttemptVersion) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.staleVersion,
        message:
            '409 STALE_VERSION: Expected attempt_version $expectedAttemptVersion, but current version is ${item.currentAttemptVersion}. Refresh queue and retry.',
        httpStatus: 409,
        details: {
          'expected_attempt_version': expectedAttemptVersion,
          'current_attempt_version': item.currentAttemptVersion,
        },
      );
    }

    if (action == 'approve') {
      if (item.isHardSecurityDenial) {
        return ApiEnvelope.failure(
          code: ErrorCatalog.hardDenialOverrideForbidden,
          message:
              'Hard security denial (${item.reasonCode}) cannot be overridden to allowed via guard review. Only Deny or Escalate is permitted.',
          httpStatus: 409,
        );
      }
      if (item.isAttemptExpired()) {
        return ApiEnvelope.failure(
          code: ErrorCatalog.attemptExpired,
          message:
              'ATTEMPT_EXPIRED: Cannot approve an expired gate attempt.',
          httpStatus: 409,
        );
      }
    }

    final now = DateTime.now().toUtc();
    final nextVersion = item.currentAttemptVersion + 1;
    final newDecisionId =
        '40000000-0000-4000-8000-${(_seqCounter++).toString().padLeft(12, '0')}';

    // Find a compatible available bay if approving entry
    SpaceDto? heldBay;
    if (action == 'approve' && item.direction == 'entry') {
      final neededCompat =
          item.vehicleType == 'motorcycle' ? 'motorcycle_only' : 'car_only';
      for (final s in state.spaces) {
        if (s.compatibility == neededCompat &&
            s.isTrulyAvailableForAllocation) {
          heldBay = s;
          break;
        }
      }
    }

    final resolvedItem = item.copyWith(
      outcome: action == 'approve' ? 'allowed' : 'denied',
      reasonCode: action == 'approve' ? 'AUTHORIZED' : 'GUARD_DENIED',
      reasonMessage: action == 'approve'
          ? 'Approved via Guard Review (${actor.userCode}): Superseding decision $newDecisionId issued${heldBay != null ? ' with 30s hold on ${heldBay.spaceCode}' : ''}. Awaiting physical passage confirmation.'
          : 'Guard ${actor.userCode} recorded $action: $trimmed',
      currentAttemptVersion: nextVersion,
      attemptState: action == 'approve'
          ? 'authorization_allowed'
          : 'authorization_denied',
      isResolved: true,
      resolvedAction: action,
      resolvedByUserCode: actor.userCode,
      resolvedReason: trimmed,
      resolvedAtUtc: now,
      supersedingDecisionId: action == 'approve' ? newDecisionId : null,
    );

    final updatedQueue = List<GuardReviewQueueItem>.from(state.reviewQueue);
    updatedQueue[idx] = resolvedItem;

    // Update matching lane attempt if present
    final updatedLanes = Map<String, AttemptDto>.from(state.activeLaneAttempts);
    List<SpaceDto> updatedSpaces = state.spaces;

    if (action == 'approve') {
      final newDecision = AccessDecisionData(
        decisionId: newDecisionId,
        gateId: item.gateId,
        laneId: item.laneId,
        direction: item.direction,
        vehicleType: item.vehicleType,
        outcome: 'allowed',
        reasonCode: 'AUTHORIZED',
        reasonMessage: resolvedItem.reasonMessage,
        userId: item.userId,
        vehicleId: item.vehicleId,
        visitId: null, // Strictly null until passage confirmation!
        assignmentId: heldBay != null
            ? '50000000-0000-4000-8000-${_seqCounter.toString().padLeft(12, '0')}'
            : null,
        evidenceEventIds: item.evidenceEventIds,
        expiresAtUtc: now.add(const Duration(seconds: 20)),
        supersedesDecisionId: item.decisionId,
        attemptVersion: nextVersion,
      );

      if (heldBay != null) {
        updatedSpaces = state.spaces.map((s) {
          if (s.spaceId == heldBay!.spaceId) {
            return s.copyWith(
              allocationStatus: 'held',
              assignmentId: newDecision.assignmentId,
              visitId: null,
              assignedVehicleCode: item.vehicleCode,
              assignedUserCode: item.userCode,
              holdExpiresAtUtc: now.add(const Duration(seconds: 30)),
            );
          }
          return s;
        }).toList();
      }

      final existingLaneAttempt = updatedLanes[item.laneId];
      if (existingLaneAttempt != null &&
          existingLaneAttempt.correlationId == item.correlationId) {
        updatedLanes[item.laneId] = existingLaneAttempt.copyWith(
          state: 'authorization_allowed',
          attemptVersion: nextVersion,
          latestDecision: newDecision,
          gateActuationClaimed: true,
          gateClaimedAtUtc: now,
          assignmentId: newDecision.assignmentId,
          spaceId: heldBay?.spaceId,
          spaceCode: heldBay?.spaceCode,
          lotCode: heldBay?.lotCode,
          assignmentStatus: heldBay != null ? 'held' : null,
          holdExpiresAtUtc: now.add(const Duration(seconds: 30)),
          committedVisitId: null, // Still null until passage confirmed!
        );
      }
    } else {
      final existingLaneAttempt = updatedLanes[item.laneId];
      if (existingLaneAttempt != null &&
          existingLaneAttempt.correlationId == item.correlationId) {
        updatedLanes[item.laneId] = existingLaneAttempt.copyWith(
          state: 'authorization_denied',
          attemptVersion: nextVersion,
        );
      }
    }

    final newAudit = AuditLogDto(
      auditId: 'AUD-${_seqCounter++}',
      occurredAtUtc: now,
      actorUserId: actor.userId,
      actorUserCode: actor.userCode,
      actorRole: actor.role.wireValue,
      action: 'guard_review_recorded',
      resourceType: 'guard_review',
      resourceId: reviewCaseId,
      requestId: 'req-rv-$_seqCounter',
      summary:
          'Guard ${actor.userCode} submitted "$action" on case $reviewCaseId (v${item.currentAttemptVersion}->v$nextVersion): "$trimmed"',
    );

    _applyRealtimeTick(
      resourceType: 'guard_review',
      resourceId: reviewCaseId,
    );

    state = state.copyWith(
      reviewQueue: updatedQueue,
      activeLaneAttempts: updatedLanes,
      spaces: updatedSpaces,
      auditLogs: [newAudit, ...state.auditLogs],
      recentActivityFeed: [
        'GUARD REVIEW ($action): Case $reviewCaseId (${item.vehicleCode ?? 'Unknown'}) -> v$nextVersion ${action == 'approve' ? 'ALLOWED + 30s hold on ${heldBay?.spaceCode ?? 'bay'} (awaiting passage)' : 'DENIED/ESCALATED'}',
        ...state.recentActivityFeed.take(14),
      ],
      lastActionBanner:
          'Guard review ($action) recorded for $reviewCaseId (attempt_version incremented to v$nextVersion).',
    );

    return ApiEnvelope.success(resolvedItem);
  }

  /// Simulates bumping `currentAttemptVersion` on a review item so the operator
  /// can test `409 STALE_VERSION` conflict handling in View 4!
  void simulateConcurrentVersionBump(String reviewCaseId) {
    final updated = state.reviewQueue.map((r) {
      if (r.reviewCaseId == reviewCaseId) {
        return r.copyWith(currentAttemptVersion: r.currentAttemptVersion + 1);
      }
      return r;
    }).toList();
    state = state.copyWith(
      reviewQueue: updated,
      lastActionBanner:
          'Simulated concurrent backend update on $reviewCaseId: attempt_version incremented in background.',
    );
  }

  /// Triggers an interactive gate scenario (`T01`, `T02`, `T03`, `T04`, `T06`, `T07`, `T13`, `T16`, `T20`)
  /// for live defense demonstrations and automated scenario tests.
  void triggerScenario(String scenarioCode) {
    final now = DateTime.now().toUtc();
    final mode = state.rosterMode;
    final corrId =
        '90000000-0000-4000-8000-${(_seqCounter++).toString().padLeft(12, '0')}';
    final decId =
        '40000000-0000-4000-8000-${(_seqCounter++).toString().padLeft(12, '0')}';

    final updatedLanes = Map<String, AttemptDto>.from(state.activeLaneAttempts);
    final updatedQueue = List<GuardReviewQueueItem>.from(state.reviewQueue);
    List<SpaceDto> updatedSpaces = List<SpaceDto>.from(state.spaces);
    String feedMsg = '';

    switch (scenarioCode) {
      case 'T01': // Normal Car Entry (U001 / V001) -> Allowed + 30s Hold on A-C01
        final v001 = SentryFixtures.findVehicleByCode('V001')!;
        final decision = AccessDecisionData(
          decisionId: decId,
          gateId: 'gate-north',
          laneId: 'lane-car-in',
          direction: 'entry',
          vehicleType: 'car',
          outcome: 'allowed',
          reasonCode: 'AUTHORIZED',
          reasonMessage:
              'T01: Plate ${v001.normalizedPlate(mode)} + ArcFace matched U001 (0.85 cosine similarity). Bay A-C01 held for 30s.',
          userId: v001.ownerUserId,
          vehicleId: v001.vehicleId,
          visitId: null, // Strictly null before passage!
          assignmentId: '50000000-0000-4000-8000-000000000901',
          evidenceEventIds: const ['80000000-0000-4000-8000-000000000101'],
          expiresAtUtc: now.add(const Duration(seconds: 20)),
          attemptVersion: 1,
        );
        final attempt = AttemptDto(
          correlationId: corrId,
          gateId: 'gate-north',
          laneId: 'lane-car-in',
          direction: 'entry',
          vehicleType: 'car',
          state: 'authorization_allowed',
          attemptVersion: 1,
          startedAtUtc: now,
          expiresAtUtc: now.add(const Duration(seconds: 60)),
          plateText: v001.normalizedPlate(mode),
          plateRecognitionStatus: 'recognized',
          detectionConfidence: 0.99,
          ocrConfidence: 0.98,
          plateModelVersion: 'yolo-plate-v1.2',
          faceRecognitionStatus: 'matched',
          faceSimilarityScore: 0.85,
          userId: v001.ownerUserId,
          userCode: 'U001',
          vehicleId: v001.vehicleId,
          vehicleCode: 'V001',
          latestDecision: decision,
          gateActuationClaimed: true,
          gateClaimedAtUtc: now,
          passageConfirmed: false,
          assignmentId: decision.assignmentId,
          spaceId: '30000000-0000-4000-8000-000000000101',
          spaceCode: 'A-C01',
          lotCode: 'A',
          assignmentStatus: 'held',
          holdExpiresAtUtc: now.add(const Duration(seconds: 30)),
          committedVisitId: null,
        );
        updatedLanes['lane-car-in'] = attempt;
        updatedSpaces = updatedSpaces.map((s) {
          if (s.spaceCode == 'A-C01') {
            return s.copyWith(
              allocationStatus: 'held',
              assignmentId: decision.assignmentId,
              visitId: null,
              assignedVehicleCode: 'V001',
              assignedUserCode: 'U001',
              holdExpiresAtUtc: now.add(const Duration(seconds: 30)),
            );
          }
          return s;
        }).toList();
        feedMsg =
            'SCENARIO T01: Normal Car Entry (U001 / V001) -> ALLOWED + 30s Space Hold on A-C01 (visit_id=null until passage confirmed)';
        break;

      case 'T02': // Plate + Wrong Face Mismatch -> DENIED: IDENTITY_MISMATCH
        final v001 = SentryFixtures.findVehicleByCode('V001')!;
        final decision = AccessDecisionData(
          decisionId: decId,
          gateId: 'gate-north',
          laneId: 'lane-car-in',
          direction: 'entry',
          vehicleType: 'car',
          outcome: 'denied',
          reasonCode: 'IDENTITY_MISMATCH',
          reasonMessage:
              'T02: Plate ${v001.normalizedPlate(mode)} belongs to V001 (U001), but driver face did not match enrolled template (0.18 cosine similarity).',
          userId: v001.ownerUserId,
          vehicleId: v001.vehicleId,
          visitId: null,
          assignmentId: null,
          evidenceEventIds: const ['80000000-0000-4000-8000-000000000102'],
          expiresAtUtc: null,
          attemptVersion: 1,
        );
        final attempt = AttemptDto(
          correlationId: corrId,
          gateId: 'gate-north',
          laneId: 'lane-car-in',
          direction: 'entry',
          vehicleType: 'car',
          state: 'authorization_denied',
          attemptVersion: 1,
          startedAtUtc: now,
          expiresAtUtc: now.add(const Duration(seconds: 60)),
          plateText: v001.normalizedPlate(mode),
          plateRecognitionStatus: 'recognized',
          detectionConfidence: 0.98,
          ocrConfidence: 0.96,
          faceRecognitionStatus: 'unknown',
          faceSimilarityScore: 0.18,
          userId: v001.ownerUserId,
          userCode: 'U001',
          vehicleId: v001.vehicleId,
          vehicleCode: 'V001',
          latestDecision: decision,
        );
        updatedLanes['lane-car-in'] = attempt;
        feedMsg =
            'SCENARIO T02: Car Entry Plate + Wrong Face -> DENIED (IDENTITY_MISMATCH · 0.18 cosine similarity)';
        break;

      case 'T03': // Unknown Plate -> DENIED: UNKNOWN_CREDENTIAL
        final decision = AccessDecisionData(
          decisionId: decId,
          gateId: 'gate-north',
          laneId: 'lane-car-in',
          direction: 'entry',
          vehicleType: 'car',
          outcome: 'denied',
          reasonCode: 'UNKNOWN_CREDENTIAL',
          reasonMessage:
              'T03: Scanned license plate XYZ9999 is not registered in the SENTRY vehicle registry.',
          userId: null,
          vehicleId: null,
          visitId: null,
          assignmentId: null,
          evidenceEventIds: const ['80000000-0000-4000-8000-000000000103'],
          expiresAtUtc: null,
          attemptVersion: 1,
        );
        final attempt = AttemptDto(
          correlationId: corrId,
          gateId: 'gate-north',
          laneId: 'lane-car-in',
          direction: 'entry',
          vehicleType: 'car',
          state: 'authorization_denied',
          attemptVersion: 1,
          startedAtUtc: now,
          expiresAtUtc: now.add(const Duration(seconds: 60)),
          plateText: 'XYZ9999',
          plateRecognitionStatus: 'recognized',
          detectionConfidence: 0.97,
          ocrConfidence: 0.95,
          faceRecognitionStatus: 'unknown',
          faceSimilarityScore: 0.11,
          latestDecision: decision,
        );
        updatedLanes['lane-car-in'] = attempt;
        feedMsg =
            'SCENARIO T03: Unregistered Plate XYZ9999 -> Hard Denial (UNKNOWN_CREDENTIAL)';
        break;

      case 'T04': // Normal Motorcycle Entry (U006 / V006 RFID + Face) -> Allowed + 30s Hold on A-M01
        final v006 = SentryFixtures.findVehicleByCode('V006')!;
        final decision = AccessDecisionData(
          decisionId: decId,
          gateId: 'gate-north',
          laneId: 'lane-moto-in',
          direction: 'entry',
          vehicleType: 'motorcycle',
          outcome: 'allowed',
          reasonCode: 'AUTHORIZED',
          reasonMessage:
              'T04: ESP32 RFID ${v006.rfidUid} + ArcFace matched U006 (0.82 cosine similarity). Motorcycle bay A-M01 held for 30s.',
          userId: v006.ownerUserId,
          vehicleId: v006.vehicleId,
          visitId: null,
          assignmentId: '50000000-0000-4000-8000-000000000904',
          evidenceEventIds: const ['80000000-0000-4000-8000-000000000104'],
          expiresAtUtc: now.add(const Duration(seconds: 20)),
          attemptVersion: 1,
        );
        final attempt = AttemptDto(
          correlationId: corrId,
          gateId: 'gate-north',
          laneId: 'lane-moto-in',
          direction: 'entry',
          vehicleType: 'motorcycle',
          state: 'authorization_allowed',
          attemptVersion: 1,
          startedAtUtc: now,
          expiresAtUtc: now.add(const Duration(seconds: 60)),
          rfidUid: v006.rfidUid,
          rfidReaderModel: 'rc522',
          rfidFirmwareVersion: 'esp32-rc522-fw-v1.0.8',
          faceRecognitionStatus: 'matched',
          faceSimilarityScore: 0.82,
          userId: v006.ownerUserId,
          userCode: 'U006',
          vehicleId: v006.vehicleId,
          vehicleCode: 'V006',
          latestDecision: decision,
          gateActuationClaimed: true,
          gateClaimedAtUtc: now,
          passageConfirmed: false,
          assignmentId: decision.assignmentId,
          spaceId: '30000000-0000-4000-8000-000000000107',
          spaceCode: 'A-M01',
          lotCode: 'A',
          assignmentStatus: 'held',
          holdExpiresAtUtc: now.add(const Duration(seconds: 30)),
          committedVisitId: null,
        );
        updatedLanes['lane-moto-in'] = attempt;
        updatedSpaces = updatedSpaces.map((s) {
          if (s.spaceCode == 'A-M01') {
            return s.copyWith(
              allocationStatus: 'held',
              assignmentId: decision.assignmentId,
              visitId: null,
              assignedVehicleCode: 'V006',
              assignedUserCode: 'U006',
              holdExpiresAtUtc: now.add(const Duration(seconds: 30)),
            );
          }
          return s;
        }).toList();
        feedMsg =
            'SCENARIO T04: Motorcycle Entry (U006 / V006 RFID 04112233 + Face) -> ALLOWED + 30s Hold on A-M01';
        break;

      case 'T06': // Revoked Motorcycle RFID -> DENIED: CREDENTIAL_REVOKED
        final decision = AccessDecisionData(
          decisionId: decId,
          gateId: 'gate-north',
          laneId: 'lane-moto-in',
          direction: 'entry',
          vehicleType: 'motorcycle',
          outcome: 'denied',
          reasonCode: 'CREDENTIAL_REVOKED',
          reasonMessage:
              'T06: Motorcycle RFID UID 04DEAD99 has status=revoked in rfid_credentials.',
          userId: null,
          vehicleId: null,
          visitId: null,
          assignmentId: null,
          evidenceEventIds: const ['80000000-0000-4000-8000-000000000106'],
          expiresAtUtc: null,
          attemptVersion: 1,
        );
        final attempt = AttemptDto(
          correlationId: corrId,
          gateId: 'gate-north',
          laneId: 'lane-moto-in',
          direction: 'entry',
          vehicleType: 'motorcycle',
          state: 'authorization_denied',
          attemptVersion: 1,
          startedAtUtc: now,
          expiresAtUtc: now.add(const Duration(seconds: 60)),
          rfidUid: '04DEAD99',
          rfidReaderModel: 'rc522',
          rfidFirmwareVersion: 'esp32-rc522-fw-v1.0.8',
          faceRecognitionStatus: 'not_required',
          latestDecision: decision,
        );
        updatedLanes['lane-moto-in'] = attempt;
        feedMsg =
            'SCENARIO T06: Revoked Motorcycle RFID 04DEAD99 -> Hard Denial (CREDENTIAL_REVOKED)';
        break;

      case 'T07': // U007 Competing Second Car Entry (V007 inside -> V008 denied DUPLICATE_ACTIVE_VISIT)
        final v008 = SentryFixtures.findVehicleByCode('V008')!;
        final decision = AccessDecisionData(
          decisionId: decId,
          gateId: 'gate-north',
          laneId: 'lane-car-in',
          direction: 'entry',
          vehicleType: 'car',
          outcome: 'denied',
          reasonCode: 'DUPLICATE_ACTIVE_VISIT',
          reasonMessage:
              'T07: Multi-vehicle constraint (uq_access_visits_active_user): U007 already has an active campus visit with V007 in Bay B-C04. V007 must exit before V008 can enter.',
          userId: v008.ownerUserId,
          vehicleId: v008.vehicleId,
          visitId: null,
          assignmentId: null,
          evidenceEventIds: const ['80000000-0000-4000-8000-000000000107'],
          expiresAtUtc: null,
          attemptVersion: 1,
        );
        final attempt = AttemptDto(
          correlationId: corrId,
          gateId: 'gate-north',
          laneId: 'lane-car-in',
          direction: 'entry',
          vehicleType: 'car',
          state: 'authorization_denied',
          attemptVersion: 1,
          startedAtUtc: now,
          expiresAtUtc: now.add(const Duration(seconds: 60)),
          plateText: v008.normalizedPlate(mode),
          plateRecognitionStatus: 'recognized',
          detectionConfidence: 0.99,
          ocrConfidence: 0.98,
          faceRecognitionStatus: 'matched',
          faceSimilarityScore: 0.87,
          userId: v008.ownerUserId,
          userCode: 'U007',
          vehicleId: v008.vehicleId,
          vehicleCode: 'V008',
          latestDecision: decision,
        );
        updatedLanes['lane-car-in'] = attempt;
        feedMsg =
            'SCENARIO T07: U007 Second Car Entry (V008) while V007 is inside -> DENIED (DUPLICATE_ACTIVE_VISIT)';
        break;

      case 'T13': // Unreadable OCR / Uncertain Face -> REVIEW_REQUIRED: IDENTITY_UNCERTAIN
        final v005 = SentryFixtures.findVehicleByCode('V005')!;
        final decision = AccessDecisionData(
          decisionId: decId,
          gateId: 'gate-north',
          laneId: 'lane-car-in',
          direction: 'entry',
          vehicleType: 'car',
          outcome: 'review_required',
          reasonCode: 'IDENTITY_UNCERTAIN',
          reasonMessage:
              'T13: Rain glare caused low OCR confidence (0.58) and borderline ArcFace similarity (0.54 cosine similarity). Queued for Guard Review.',
          userId: v005.ownerUserId,
          vehicleId: v005.vehicleId,
          visitId: null,
          assignmentId: null,
          evidenceEventIds: const ['80000000-0000-4000-8000-000000000113'],
          expiresAtUtc: null,
          attemptVersion: 1,
        );
        final attempt = AttemptDto(
          correlationId: corrId,
          gateId: 'gate-north',
          laneId: 'lane-car-in',
          direction: 'entry',
          vehicleType: 'car',
          state: 'guard_review_required',
          attemptVersion: 1,
          startedAtUtc: now,
          expiresAtUtc: now.add(const Duration(minutes: 4)),
          plateText: v005.normalizedPlate(mode),
          plateRecognitionStatus: 'uncertain',
          detectionConfidence: 0.81,
          ocrConfidence: 0.58,
          faceRecognitionStatus: 'uncertain',
          faceSimilarityScore: 0.54,
          userId: v005.ownerUserId,
          userCode: 'U005',
          vehicleId: v005.vehicleId,
          vehicleCode: 'V005',
          latestDecision: decision,
        );
        updatedLanes['lane-car-in'] = attempt;
        updatedQueue.insert(
          0,
          GuardReviewQueueItem(
            reviewCaseId: 'RV-$_seqCounter',
            correlationId: corrId,
            decisionId: decId,
            gateId: 'gate-north',
            laneId: 'lane-car-in',
            direction: 'entry',
            vehicleType: 'car',
            outcome: 'review_required',
            reasonCode: 'IDENTITY_UNCERTAIN',
            reasonMessage: decision.reasonMessage,
            currentAttemptVersion: 1,
            attemptState: 'guard_review_required',
            createdAtUtc: now,
            attemptExpiresAtUtc: now.add(const Duration(minutes: 4)),
            userId: v005.ownerUserId,
            userCode: 'U005',
            vehicleId: v005.vehicleId,
            vehicleCode: 'V005',
            plateText: v005.normalizedPlate(mode),
            ocrConfidence: 0.58,
            faceRecognitionStatus: 'uncertain',
            faceSimilarityScore: 0.54,
            evidenceEventIds: decision.evidenceEventIds,
          ),
        );
        feedMsg =
            'SCENARIO T13: Uncertain OCR/Face on V005 (U005) -> REVIEW_REQUIRED queued in Guard Reviews';
        break;

      case 'T16': // 30s Space Hold Expires Without Passage -> ATTEMPT_EXPIRED
        final currentCarIn = updatedLanes['lane-car-in'];
        if (currentCarIn != null) {
          final expiredAttempt = currentCarIn.copyWith(
            state: 'expired',
            expiresAtUtc: now.subtract(const Duration(seconds: 1)),
            assignmentStatus: 'released',
            holdExpiresAtUtc: now.subtract(const Duration(seconds: 1)),
          );
          updatedLanes['lane-car-in'] = expiredAttempt;
          updatedSpaces = updatedSpaces.map((s) {
            if (s.spaceCode == currentCarIn.spaceCode &&
                s.allocationStatus == 'held') {
              return s.copyWith(
                allocationStatus: 'unassigned',
                clearAssignment: true,
                clearVisit: true,
              );
            }
            return s;
          }).toList();
          feedMsg =
              'SCENARIO T16: 30s Space Hold expired without passage confirmation -> Attempt EXPIRED & held bay released (no visit created)';
        }
        break;

      case 'T20': // Car Exit (U007 / V007 exits so V008 can later enter!)
        final v007 = SentryFixtures.findVehicleByCode('V007')!;
        final decision = AccessDecisionData(
          decisionId: decId,
          gateId: 'gate-north',
          laneId: 'lane-car-out',
          direction: 'exit',
          vehicleType: 'car',
          outcome: 'allowed',
          reasonCode: 'AUTHORIZED',
          reasonMessage:
              'T20: Exit Plate OCR verified active visit VS07 for V007 (U007). Face check not required on exit. Awaiting departure confirmation.',
          userId: v007.ownerUserId,
          vehicleId: v007.vehicleId,
          visitId: '60000000-0000-4000-8000-000000000007',
          assignmentId: '50000000-0000-4000-8000-000000000007',
          evidenceEventIds: const ['80000000-0000-4000-8000-000000000120'],
          expiresAtUtc: now.add(const Duration(seconds: 20)),
          attemptVersion: 1,
        );
        final attempt = AttemptDto(
          correlationId: corrId,
          gateId: 'gate-north',
          laneId: 'lane-car-out',
          direction: 'exit',
          vehicleType: 'car',
          state: 'authorization_allowed',
          attemptVersion: 1,
          startedAtUtc: now,
          expiresAtUtc: now.add(const Duration(seconds: 60)),
          plateText: v007.normalizedPlate(mode),
          plateRecognitionStatus: 'recognized',
          detectionConfidence: 0.99,
          ocrConfidence: 0.97,
          faceRecognitionStatus: 'not_required',
          faceSimilarityScore: null,
          userId: v007.ownerUserId,
          userCode: 'U007',
          vehicleId: v007.vehicleId,
          vehicleCode: 'V007',
          latestDecision: decision,
          gateActuationClaimed: true,
          gateClaimedAtUtc: now,
          passageConfirmed: false,
          assignmentId: '50000000-0000-4000-8000-000000000007',
          spaceId: '30000000-0000-4000-8000-000000000204',
          spaceCode: 'B-C04',
          lotCode: 'B',
          assignmentStatus: 'assigned',
          committedVisitId: '60000000-0000-4000-8000-000000000007',
        );
        updatedLanes['lane-car-out'] = attempt;
        feedMsg =
            'SCENARIO T20: V007 (U007) at Car Exit Lane -> ALLOWED (Plate OCR only; Face Not Required on Exit). Click "Confirm Vehicle Crossed" to close visit!';
        break;
    }

    _applyRealtimeTick(
      resourceType: 'access_attempt',
      resourceId: corrId,
    );

    final newAttempt = updatedLanes['lane-car-in'] ?? updatedLanes['lane-moto-in'];
    state = state.copyWith(
      activeLaneAttempts: updatedLanes,
      attemptHistory: newAttempt != null
          ? [
              newAttempt,
              ...state.attemptHistory
                  .where((a) => a.correlationId != newAttempt.correlationId),
            ]
          : state.attemptHistory,
      reviewQueue: updatedQueue,
      spaces: updatedSpaces,
      recentActivityFeed: [
        if (feedMsg.isNotEmpty) feedMsg,
        ...state.recentActivityFeed.take(14),
      ],
      lastActionBanner: feedMsg,
    );
  }

  /// Simulates device status change (`online` | `degraded` | `offline`) for View 7.
  /// Enforces Invariant: When an occupancy camera (`D05`) goes `offline`, all its
  /// mapped parking bays automatically become `isStale: true` / `physicalStatus: 'unknown'`!
  void setDeviceSimulatedStatus(String deviceCode, String nextStatus) {
    final now = DateTime.now().toUtc();
    String? affectedLot;
    final updatedDevices = state.devices.map((d) {
      if (d.deviceCode == deviceCode) {
        affectedLot = d.mappedLotCode;
        return d.copyWith(
          reportedStatus: nextStatus,
          sequenceNumber: d.sequenceNumber + 1,
          uptimeSeconds: d.uptimeSeconds + 10,
          lastReceivedAtUtc: nextStatus == 'offline'
              ? now.subtract(const Duration(seconds: 45))
              : now,
          lastErrorCode: nextStatus == 'degraded'
              ? 'CLOCK_SKEW_OR_HIGH_LATENCY'
              : nextStatus == 'offline'
                  ? 'HEARTBEAT_TIMEOUT_30S'
                  : null,
          clearError: nextStatus == 'online',
        );
      }
      return d;
    }).toList();

    List<SpaceDto> updatedSpaces = state.spaces;
    if (affectedLot != null) {
      final isOffline = nextStatus == 'offline';
      updatedSpaces = state.spaces.map((s) {
        if (s.lotCode == affectedLot) {
          return s.copyWith(
            isStale: isOffline,
            physicalStatus: isOffline
                ? 'unknown'
                : (s.allocationStatus == 'assigned' ? 'occupied' : 'available'),
          );
        }
        return s;
      }).toList();
    }

    _applyRealtimeTick(
      resourceType: 'device',
      resourceId: deviceCode,
    );

    state = state.copyWith(
      devices: updatedDevices,
      spaces: updatedSpaces,
      recentActivityFeed: [
        'DEVICE $deviceCode STATUS -> ${nextStatus.toUpperCase()}${affectedLot != null && nextStatus == 'offline' ? ' · Lot $affectedLot bays marked UNKNOWN / STALE (never available)' : ''}',
        ...state.recentActivityFeed.take(14),
      ],
      lastActionBanner:
          'Device $deviceCode transitioned to $nextStatus${affectedLot != null && nextStatus == 'offline' ? '; mapped Lot $affectedLot spaces marked unknown/stale.' : '.'}',
    );
  }

  /// Toggles a bay's physical camera observation in Mock Mode (View 5) so the operator
  /// can test `available` vs `occupied` vs `unknown` and Occupancy Conflict alerts.
  void cycleSpacePhysicalStatus(String spaceCode) {
    final now = DateTime.now().toUtc();
    final updatedSpaces = state.spaces.map((s) {
      if (s.spaceCode == spaceCode) {
        final nextPhys = s.physicalStatus == 'available'
            ? 'occupied'
            : s.physicalStatus == 'occupied'
                ? 'unknown'
                : 'available';
        return s.copyWith(
          physicalStatus: nextPhys,
          isStale: nextPhys == 'unknown',
          lastObservedAtUtc: now,
        );
      }
      return s;
    }).toList();

    state = state.copyWith(
      spaces: updatedSpaces,
      lastActionBanner: 'Updated overhead camera observation for bay $spaceCode.',
    );
  }

  /// Role-gated Admin endpoint check (`GET /api/v1/admin/audit-logs` & `P01–P06`).
  /// Returns `403 ACCESS_DENIED` if called by a `guard` principal!
  ApiEnvelope<List<AuditLogDto>> fetchAuditLogsForRole(UserRole role) {
    if (!role.isAdmin) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.accessDenied,
        message:
            'HTTP 403 FORBIDDEN (ACCESS_DENIED): Role "${role.wireValue}" is not permitted to access /api/v1/admin/audit-logs. Requires role "administrator".',
        httpStatus: 403,
      );
    }
    return ApiEnvelope.success(state.auditLogs);
  }

  /// Role-gated `P05` (`POST /api/v1/participants/{user_code}/vehicles`) registration helper.
  ApiEnvelope<ParticipantVehicleDto> registerParticipantVehicle({
    required ProfileDto actor,
    required String userCode,
    required String vehicleCode,
    required String vehicleType,
    String? plateDisplay,
    String? rfidUid,
  }) {
    if (!actor.role.isAdmin) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.accessDenied,
        message:
            'HTTP 403 FORBIDDEN (ACCESS_DENIED): Role "${actor.role.wireValue}" cannot modify participant vehicle registrations (P05). Requires "administrator".',
        httpStatus: 403,
      );
    }

    final now = DateTime.now().toUtc();
    final normalized =
        plateDisplay?.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final newVehicle = ParticipantVehicleDto(
      vehicleId:
          '20000000-0000-4000-8000-${(_seqCounter++).toString().padLeft(12, '0')}',
      vehicleCode: vehicleCode.toUpperCase(),
      userCode: userCode,
      vehicleType: vehicleType,
      plateNumberDisplay: plateDisplay,
      normalizedPlateNumber: normalized,
      rfidUid: rfidUid,
      vehicleStatus: 'active',
      authorizationStatus: 'authorized',
      isPrimaryVehicle: false,
      notes: 'Registered via P05 Admin Directory in Mock Mode.',
      updatedAtUtc: now,
    );

    final updatedDir = state.participantDirectory.map((u) {
      if (u.userCode == userCode) {
        return u.copyWith(vehicles: [...u.vehicles, newVehicle]);
      }
      return u;
    }).toList();

    final newAudit = AuditLogDto(
      auditId: 'AUD-${_seqCounter++}',
      occurredAtUtc: now,
      actorUserId: actor.userId,
      actorUserCode: actor.userCode,
      actorRole: actor.role.wireValue,
      action: 'vehicle_registered',
      resourceType: 'participant_vehicle',
      resourceId: newVehicle.vehicleId,
      requestId: 'req-p05-$_seqCounter',
      summary:
          'Admin ${actor.userCode} registered vehicle ${newVehicle.vehicleCode} ($vehicleType) under $userCode (admission_evaluated=false).',
    );

    state = state.copyWith(
      participantDirectory: updatedDir,
      auditLogs: [newAudit, ...state.auditLogs],
      lastActionBanner:
          'P05: Registered ${newVehicle.vehicleCode} under $userCode (admission_evaluated: false).',
    );

    return ApiEnvelope.success(newVehicle);
  }

  /// Role-gated `P06` (`PATCH /api/v1/participants/{user_code}/vehicles/{vehicle_code}`) helper.
  ApiEnvelope<ParticipantVehicleDto> toggleVehicleAuthorizationStatus({
    required ProfileDto actor,
    required String userCode,
    required String vehicleCode,
  }) {
    if (!actor.role.isAdmin) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.accessDenied,
        message:
            'HTTP 403 FORBIDDEN (ACCESS_DENIED): Role "${actor.role.wireValue}" cannot patch participant vehicles (P06).',
        httpStatus: 403,
      );
    }

    final now = DateTime.now().toUtc();
    ParticipantVehicleDto? patched;

    final updatedDir = state.participantDirectory.map((u) {
      if (u.userCode != userCode) return u;
      final updatedVehicles = u.vehicles.map((v) {
        if (v.vehicleCode == vehicleCode) {
          final nextAuth = v.authorizationStatus == 'authorized'
              ? 'suspended'
              : 'authorized';
          patched = v.copyWith(
            authorizationStatus: nextAuth,
            updatedAtUtc: now,
          );
          return patched!;
        }
        return v;
      }).toList();
      return u.copyWith(vehicles: updatedVehicles);
    }).toList();

    if (patched == null) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.notFound,
        message: 'Vehicle $vehicleCode under $userCode not found.',
        httpStatus: 404,
      );
    }

    final newAudit = AuditLogDto(
      auditId: 'AUD-${_seqCounter++}',
      occurredAtUtc: now,
      actorUserId: actor.userId,
      actorUserCode: actor.userCode,
      actorRole: actor.role.wireValue,
      action: 'vehicle_updated',
      resourceType: 'participant_vehicle',
      resourceId: patched!.vehicleId,
      requestId: 'req-p06-$_seqCounter',
      summary:
          'Admin ${actor.userCode} updated $vehicleCode authorization_status to ${patched!.authorizationStatus} via P06.',
    );

    state = state.copyWith(
      participantDirectory: updatedDir,
      auditLogs: [newAudit, ...state.auditLogs],
      lastActionBanner:
          'P06: Updated $vehicleCode authorization_status to ${patched!.authorizationStatus}.',
    );

    return ApiEnvelope.success(patched!);
  }

  /// Simulates WebSocket lag/disconnect (`T18`) or reconnect resync (`§7.11`).
  void toggleSimulatedOfflineLag() {
    if (state.wsState.isHealthy) {
      wsCoordinator.markOfflineOrStale(
        'Simulated WebSocket disconnect / telemetry lag (T18). Showing stale data warning.',
      );
      state = state.copyWith(
        wsState: wsCoordinator.state,
        lastActionBanner:
            'T18: Simulated WebSocket disconnect. Telemetry marked STALE · RESYNC REQUIRED.',
      );
    } else {
      wsCoordinator.reconnectAndResync();
      state = state.copyWith(
        wsState: wsCoordinator.state,
        lastActionBanner:
            'WebSocket reconnected and full snapshot resync completed.',
      );
    }
  }

  void forceFullSnapshotResync() {
    wsCoordinator.reconnectAndResync();
    state = state.copyWith(
      wsState: wsCoordinator.state,
      lastActionBanner: 'Executed full REST snapshot resync across all views.',
    );
  }

  void _applyRealtimeTick({
    required String resourceType,
    required String resourceId,
  }) {
    final nextSeq = wsCoordinator.state.lastStreamSequence + 1;
    final envelope = CommonEventEnvelope<RealtimeUpdateData>(
      eventId:
          '88000000-0000-4000-8000-${(_seqCounter++).toString().padLeft(12, '0')}',
      eventType: SentryEventType.realtimeUpdate,
      occurredAtUtc: DateTime.now().toUtc(),
      producerId: 'fastapi-backend-01',
      correlationId: null,
      data: RealtimeUpdateData(
        resourceType: resourceType,
        resourceId: resourceId,
        resourceVersion: 1,
        streamSequence: nextSeq,
        refreshRequired: true,
        resyncRequired: false,
      ),
    );
    wsCoordinator.handleRealtimeEnvelope(envelope);
    state = state.copyWith(wsState: wsCoordinator.state);
  }
}
