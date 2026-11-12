import '../../core/network/api_envelope.dart';

/// Confirmed Campus Visit DTO (`GET /api/v1/access-visits` — Patrick Carpio Confirmation #2).
/// Invariant: A `VisitDto` ONLY exists after physical passage confirmation (`entry_confirmation`).
/// An `allowed` entry decision alone NEVER creates an `active` visit!
class VisitDto {
  final String visitId;
  final String visitCode; // e.g. 'VS01'
  final String entryCorrelationId;
  final String? exitCorrelationId;
  final String userId;
  final String userCode;
  final String vehicleId;
  final String vehicleCode;
  final String vehicleType; // 'car' | 'motorcycle'
  final String status; // 'active' | 'closed'
  final String entryGateId;
  final String entryLaneId;
  final DateTime enteredAtUtc;
  final String entryConfirmationSource;
  final String? exitGateId;
  final String? exitLaneId;
  final DateTime? exitedAtUtc;
  final String? exitConfirmationSource;
  final String? assignmentId;
  final String? lotCode;
  final String? spaceId;
  final String? spaceCode;

  const VisitDto({
    required this.visitId,
    required this.visitCode,
    required this.entryCorrelationId,
    this.exitCorrelationId,
    required this.userId,
    required this.userCode,
    required this.vehicleId,
    required this.vehicleCode,
    required this.vehicleType,
    required this.status,
    required this.entryGateId,
    required this.entryLaneId,
    required this.enteredAtUtc,
    required this.entryConfirmationSource,
    this.exitGateId,
    this.exitLaneId,
    this.exitedAtUtc,
    this.exitConfirmationSource,
    this.assignmentId,
    this.lotCode,
    this.spaceId,
    this.spaceCode,
  });

  bool get isActive => status == 'active';

  Duration duration([DateTime? nowUtc]) {
    final end = exitedAtUtc ?? (nowUtc ?? DateTime.now()).toUtc();
    return end.difference(enteredAtUtc);
  }

  VisitDto copyWith({
    String? status,
    String? exitCorrelationId,
    String? exitGateId,
    String? exitLaneId,
    DateTime? exitedAtUtc,
    String? exitConfirmationSource,
  }) {
    return VisitDto(
      visitId: visitId,
      visitCode: visitCode,
      entryCorrelationId: entryCorrelationId,
      exitCorrelationId: exitCorrelationId ?? this.exitCorrelationId,
      userId: userId,
      userCode: userCode,
      vehicleId: vehicleId,
      vehicleCode: vehicleCode,
      vehicleType: vehicleType,
      status: status ?? this.status,
      entryGateId: entryGateId,
      entryLaneId: entryLaneId,
      enteredAtUtc: enteredAtUtc,
      entryConfirmationSource: entryConfirmationSource,
      exitGateId: exitGateId ?? this.exitGateId,
      exitLaneId: exitLaneId ?? this.exitLaneId,
      exitedAtUtc: exitedAtUtc ?? this.exitedAtUtc,
      exitConfirmationSource:
          exitConfirmationSource ?? this.exitConfirmationSource,
      assignmentId: assignmentId,
      lotCode: lotCode,
      spaceId: spaceId,
      spaceCode: spaceCode,
    );
  }

  factory VisitDto.fromJson(Map<String, dynamic> json) {
    return VisitDto(
      visitId: json['visit_id']?.toString() ?? '',
      visitCode: json['visit_code']?.toString() ?? 'VS00',
      entryCorrelationId: json['entry_correlation_id']?.toString() ?? '',
      exitCorrelationId: json['exit_correlation_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      userCode: json['user_code']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString() ?? '',
      vehicleCode: json['vehicle_code']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? 'car',
      status: json['status']?.toString() ?? 'active',
      entryGateId: json['entry_gate_id']?.toString() ?? 'gate-north',
      entryLaneId: json['entry_lane_id']?.toString() ?? 'lane-car-in',
      enteredAtUtc: DateTime.tryParse(json['entered_at']?.toString() ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      entryConfirmationSource:
          json['entry_confirmation_source']?.toString() ?? 'sensor',
      exitGateId: json['exit_gate_id']?.toString(),
      exitLaneId: json['exit_lane_id']?.toString(),
      exitedAtUtc: json['exited_at'] != null
          ? DateTime.tryParse(json['exited_at'].toString())?.toUtc()
          : null,
      exitConfirmationSource: json['exit_confirmation_source']?.toString(),
      assignmentId: json['assignment_id']?.toString(),
      lotCode: json['lot_code']?.toString(),
      spaceId: json['space_id']?.toString(),
      spaceCode: json['space_code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'visit_id': visitId,
        'visit_code': visitCode,
        'entry_correlation_id': entryCorrelationId,
        'exit_correlation_id': exitCorrelationId,
        'user_id': userId,
        'user_code': userCode,
        'vehicle_id': vehicleId,
        'vehicle_code': vehicleCode,
        'vehicle_type': vehicleType,
        'status': status,
        'entry_gate_id': entryGateId,
        'entry_lane_id': entryLaneId,
        'entered_at': ManilaTime.toUtcIso(enteredAtUtc),
        'entry_confirmation_source': entryConfirmationSource,
        'exit_gate_id': exitGateId,
        'exit_lane_id': exitLaneId,
        'exited_at':
            exitedAtUtc != null ? ManilaTime.toUtcIso(exitedAtUtc!) : null,
        'exit_confirmation_source': exitConfirmationSource,
        'assignment_id': assignmentId,
        'lot_code': lotCode,
        'space_id': spaceId,
        'space_code': spaceCode,
      };
}

/// Request payload for `POST /api/v1/passages/entries` and `POST /api/v1/passages/exits`
/// (Patrick Carpio's Confirmed Contract #3: Guard "Confirm Vehicle Crossed" Fallback Button).
class PassageConfirmationRequest {
  final String correlationId;
  final String decisionId;
  final String? visitId; // Required on exit confirmation
  final String gateId;
  final String laneId;
  final String direction; // 'entry' | 'exit'
  final String confirmationSource; // 'guard_attestation' | 'sensor' | 'mock_sensor'
  final String passageReference;
  final String notes; // Required 10..500 chars for guard_attestation

  PassageConfirmationRequest({
    required this.correlationId,
    required this.decisionId,
    this.visitId,
    required this.gateId,
    required this.laneId,
    required this.direction,
    this.confirmationSource = 'guard_attestation',
    required this.passageReference,
    required this.notes,
  }) {
    if (notes.trim().length < 10 || notes.trim().length > 500) {
      throw FormatException(
        'Guard passage attestation notes must be between 10 and 500 characters.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'correlation_id': correlationId,
        'decision_id': decisionId,
        if (visitId != null) 'visit_id': visitId,
        'gate_id': gateId,
        'lane_id': laneId,
        'direction': direction,
        'confirmation_source': confirmationSource,
        'passage_reference': passageReference,
        'notes': notes.trim(),
      };
}
