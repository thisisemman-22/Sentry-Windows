import 'package:campus_parking_desktop/core/config/roster_mode.dart';
import 'package:campus_parking_desktop/core/network/api_envelope.dart';
import 'package:campus_parking_desktop/core/network/ws_client.dart';
import 'package:campus_parking_desktop/shared/fixtures/scenario_simulator.dart';
import 'package:campus_parking_desktop/shared/fixtures/synthetic_fixtures.dart';
import 'package:campus_parking_desktop/shared/models/auth_models.dart';
import 'package:campus_parking_desktop/shared/models/event_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 2 & 13: Event Contracts & Schema Validation', () {
    test('CommonEventEnvelope enforces schema_version 1.0.0, UUIDs, and UTC Z timestamps', () {
      final json = {
        'schema_version': '1.0.0',
        'event_id': '80000000-0000-4000-8000-000000000011',
        'event_type': 'plate_observation',
        'occurred_at': '2026-11-11T04:44:00Z',
        'producer_id': 'plate-entry-01',
        'correlation_id': '90000000-0000-4000-8000-000000000001',
        'data': {
          'gate_id': 'gate-north',
          'lane_id': 'lane-car-in',
          'direction': 'entry',
          'recognition_status': 'recognized',
          'plate_text': 'UKQ247',
          'detection_confidence': 0.99,
          'ocr_confidence': 0.97,
          'model_version': 'yolo-plate-v1.2',
          'threshold_config_version': 'thresh-v1',
        },
      };

      final env = CommonEventEnvelope.fromJson(
        json,
        PlateObservationData.fromJson,
      );
      expect(env.schemaVersion, '1.0.0');
      expect(env.eventType, SentryEventType.plateObservation);
      expect(env.data.plateText, 'UKQ247');

      // Non-UTC timestamp (missing trailing Z) must fail validation
      final badTimestampJson = Map<String, dynamic>.from(json)
        ..['occurred_at'] = '2026-11-11T12:44:00+08:00';
      expect(
        () => CommonEventEnvelope.fromJson(
          badTimestampJson,
          PlateObservationData.fromJson,
        ),
        throwsFormatException,
      );
    });

    test('FaceObservationData enforces entry-only direction and raw cosine_similarity in [-1, 1]', () {
      final face = FaceObservationData(
        gateId: 'gate-north',
        laneId: 'lane-car-in',
        direction: 'entry',
        triggerEventId: '80000000-0000-4000-8000-000000000011',
        recognitionStatus: 'matched',
        userId: '10000000-0000-4000-8000-000000000001',
        faceTemplateId: '11000000-0000-4000-8000-000000000001',
        faceCount: 1,
        similarityMetric: 'cosine_similarity',
        similarityScore: 0.81,
        modelVersion: 'arcface-r100-v1.1',
        thresholdConfigVersion: 'thresh-v1',
      );

      // Must format as raw cosine similarity, NEVER as percentage
      expect(
        face.formattedCosineSimilarity,
        '0.81 cosine similarity (cosine_similarity)',
      );
      expect(face.formattedCosineSimilarity.contains('%'), isFalse);

      // Exit direction on face_observation is forbidden by schema
      expect(
        () => FaceObservationData(
          gateId: 'gate-north',
          laneId: 'lane-car-out',
          direction: 'exit',
          triggerEventId: '80000000-0000-4000-8000-000000000011',
          recognitionStatus: 'matched',
          faceCount: 1,
          similarityScore: 0.81,
          modelVersion: 'arcface-r100-v1.1',
          thresholdConfigVersion: 'thresh-v1',
        ),
        throwsFormatException,
      );
    });

    test('ParkingAssignmentData enforces visit_id == null when status == held', () {
      expect(
        () => ParkingAssignmentData(
          assignmentId: '50000000-0000-4000-8000-000000000001',
          userId: '10000000-0000-4000-8000-000000000001',
          vehicleId: '20000000-0000-4000-8000-000000000001',
          visitId: '60000000-0000-4000-8000-000000000001', // Illegal while held!
          buildingCode: 'CET',
          lotCode: 'A',
          spaceId: '30000000-0000-4000-8000-000000000103',
          spaceCode: 'A-C03',
          status: 'held',
          createdAtUtc: DateTime.now().toUtc(),
          version: 1,
        ),
        throwsFormatException,
      );
    });
  });

  group('Phase 6, 7, 8, 9, 10, 11, 12: Core Architectural & Safety Invariants', () {
    late WsInvalidationCoordinator wsCoord;
    late SentryScenarioController controller;

    setUp(() {
      wsCoord = WsInvalidationCoordinator();
      controller = SentryScenarioController(
        initialRosterMode: RosterMode.classDemo,
        wsCoordinator: wsCoord,
      );
    });

    tearDown(() {
      wsCoord.dispose();
    });

    test('State Separation: allowed decision holds space with visit_id == null; only passage confirmation creates active visit & assigned space', () {
      // Initial state on lane-car-in has U001 / V001 with an ALLOWED decision and held space A-C03
      final prePassageAttempt =
          controller.state.activeLaneAttempts['lane-car-in']!;
      expect(prePassageAttempt.latestDecision?.outcome, 'allowed');
      expect(prePassageAttempt.assignmentStatus, 'held');
      expect(prePassageAttempt.committedVisitId, isNull);
      expect(prePassageAttempt.passageConfirmed, isFalse);

      final heldSpaceBefore = controller.state.spaces
          .firstWhere((s) => s.spaceCode == 'A-C03');
      expect(heldSpaceBefore.allocationStatus, 'held');
      expect(heldSpaceBefore.visitId, isNull);

      // Confirm physical passage (Patrick Carpio Confirmed Contract #3)
      final res = controller.confirmVehicleCrossedGate(
        laneId: 'lane-car-in',
        notes: 'Witnessed car V001 physical crossing at Gate 1 entry lane.',
        actor: SentryFixtures.guardOperator,
      );

      expect(res.ok, isTrue);
      expect(res.data?.status, 'active');
      expect(res.data?.vehicleCode, 'V001');

      final postPassageAttempt =
          controller.state.activeLaneAttempts['lane-car-in']!;
      expect(postPassageAttempt.passageConfirmed, isTrue);
      expect(postPassageAttempt.assignmentStatus, 'assigned');
      expect(postPassageAttempt.committedVisitId, isNotNull);

      final assignedSpaceAfter = controller.state.spaces
          .firstWhere((s) => s.spaceCode == 'A-C03');
      expect(assignedSpaceAfter.allocationStatus, 'assigned');
      expect(assignedSpaceAfter.visitId, res.data?.visitId);
    });

    test('U007 Multi-Vehicle Constraint: V007 and V008 stay distinct, and second simultaneous entry is denied with DUPLICATE_ACTIVE_VISIT', () {
      final u007Vehicles = SentryFixtures.vehiclesForUser('U007');
      expect(u007Vehicles.map((v) => v.vehicleCode).toList(), ['V007', 'V008']);

      // Trigger T07 (V008 attempts entry while V007 has active visit VS07)
      controller.triggerScenario('T07');
      final attempt = controller.state.activeLaneAttempts['lane-car-in']!;
      expect(attempt.userCode, 'U007');
      expect(attempt.vehicleCode, 'V008');
      expect(attempt.latestDecision?.outcome, 'denied');
      expect(attempt.latestDecision?.reasonCode, 'DUPLICATE_ACTIVE_VISIT');
    });

    test('Guard Review Safety: approve is forbidden on hard security denials, 409 STALE_VERSION on outdated version, and approve on uncertainty requires passage confirmation next', () {
      // 1. Hard denial case RV-103-HARD (DUPLICATE_ACTIVE_VISIT) cannot be approved
      final hardDenialCase = controller.state.reviewQueue
          .firstWhere((r) => r.reviewCaseId == 'RV-103-HARD');
      expect(hardDenialCase.canApprove(), isFalse);

      final hardApproveAttempt = controller.submitGuardReview(
        reviewCaseId: 'RV-103-HARD',
        action: 'approve',
        reason: 'Trying to override a hard security denial.',
        expectedAttemptVersion: hardDenialCase.currentAttemptVersion,
        actor: SentryFixtures.guardOperator,
      );
      expect(hardApproveAttempt.ok, isFalse);
      expect(
        hardApproveAttempt.error?.code,
        ErrorCatalog.hardDenialOverrideForbidden,
      );

      // 2. Simulate concurrent version bump on RV-101 -> submitting v1 returns 409 STALE_VERSION
      controller.simulateConcurrentVersionBump('RV-101');
      final staleRes = controller.submitGuardReview(
        reviewCaseId: 'RV-101',
        action: 'approve',
        reason: 'Verified motorcycle rider U004 student ID at Gate 1.',
        expectedAttemptVersion: 1, // Outdated version (current is 2)
        actor: SentryFixtures.guardOperator,
      );
      expect(staleRes.ok, isFalse);
      expect(staleRes.error?.code, ErrorCatalog.staleVersion);
      expect(staleRes.error?.httpStatus, 409);

      // 3. Submit with synced expectedAttemptVersion == 2 -> succeeds, increments to v3, holds space, visit_id still null!
      final validApprove = controller.submitGuardReview(
        reviewCaseId: 'RV-101',
        action: 'approve',
        reason: 'Verified motorcycle rider U004 student ID at Gate 1.',
        expectedAttemptVersion: 2,
        actor: SentryFixtures.guardOperator,
      );
      expect(validApprove.ok, isTrue);
      expect(validApprove.data?.currentAttemptVersion, 3);
      expect(validApprove.data?.supersedingDecisionId, isNotNull);

      final motoAttempt = controller.state.activeLaneAttempts['lane-moto-in']!;
      expect(motoAttempt.state, 'authorization_allowed');
      expect(motoAttempt.committedVisitId, isNull); // Still awaiting passage!
    });

    test('Role Gating: Guard receives 403 ACCESS_DENIED on Admin Audit Logs and P05/P06 endpoints', () {
      final guardAuditRes =
          controller.fetchAuditLogsForRole(UserRole.guard);
      expect(guardAuditRes.ok, isFalse);
      expect(guardAuditRes.error?.httpStatus, 403);
      expect(guardAuditRes.error?.code, ErrorCatalog.accessDenied);

      final adminAuditRes =
          controller.fetchAuditLogsForRole(UserRole.administrator);
      expect(adminAuditRes.ok, isTrue);

      final guardP05Res = controller.registerParticipantVehicle(
        actor: SentryFixtures.guardOperator,
        userCode: 'U001',
        vehicleCode: 'V099',
        vehicleType: 'car',
        plateDisplay: 'TEST 999',
      );
      expect(guardP05Res.ok, isFalse);
      expect(guardP05Res.error?.httpStatus, 403);
    });

    test('Device Offline -> Unknown/Stale Space Propagation & WebSocket Sequence Gap Resync', () {
      // Mark D05 (Lot A overhead camera) offline -> Lot A spaces must become unknown/stale and NEVER available
      controller.setDeviceSimulatedStatus('D05', 'offline');
      final lotASpaces = controller.state.spaces
          .where((s) => s.lotCode == 'A')
          .toList();
      expect(lotASpaces.every((s) => s.isUnknownOrStale), isTrue);
      expect(
        lotASpaces.any((s) => s.isTrulyAvailableForAllocation),
        isFalse,
      );

      // WebSocket duplicate event_id deduplication & sequence gap resync
      final currentSeq = wsCoord.state.lastStreamSequence;
      final env1 = CommonEventEnvelope<RealtimeUpdateData>(
        eventId: '88000000-0000-4000-8000-000000009991',
        eventType: SentryEventType.realtimeUpdate,
        occurredAtUtc: DateTime.now().toUtc(),
        producerId: 'fastapi-backend-01',
        correlationId: null,
        data: RealtimeUpdateData(
          resourceType: 'device',
          resourceId: 'D05',
          resourceVersion: 2,
          streamSequence: currentSeq + 1,
          refreshRequired: true,
          resyncRequired: false,
        ),
      );
      expect(wsCoord.handleRealtimeEnvelope(env1), isTrue);
      // Sending exact same eventId again is ignored as duplicate
      expect(wsCoord.handleRealtimeEnvelope(env1), isFalse);
      expect(wsCoord.state.duplicateEventsIgnored, 1);

      // Sending a sequence gap (currentSeq + 10) triggers sequenceGapResyncCount increment
      final gapEnv = CommonEventEnvelope<RealtimeUpdateData>(
        eventId: '88000000-0000-4000-8000-000000009992',
        eventType: SentryEventType.realtimeUpdate,
        occurredAtUtc: DateTime.now().toUtc(),
        producerId: 'fastapi-backend-01',
        correlationId: null,
        data: RealtimeUpdateData(
          resourceType: 'parking_space',
          resourceId: 'A-C01',
          resourceVersion: 3,
          streamSequence: currentSeq + 10,
          refreshRequired: true,
          resyncRequired: false,
        ),
      );
      expect(wsCoord.handleRealtimeEnvelope(gapEnv), isTrue);
      expect(wsCoord.state.sequenceGapResyncCount, 1);
    });
  });
}
