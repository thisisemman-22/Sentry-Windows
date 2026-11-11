import '../../core/network/api_envelope.dart';

/// Source-verified `ParticipantVehicle` DTO for `P01–P06` (`/api/v1/participants/...`).
class ParticipantVehicleDto {
  final String vehicleId;
  final String vehicleCode;
  final String userCode;
  final String vehicleType; // 'car' | 'motorcycle'
  final String? plateNumberDisplay;
  final String? normalizedPlateNumber;
  final String? rfidUid;
  final String vehicleStatus; // 'active' | 'inactive' | 'revoked'
  final String authorizationStatus; // 'authorized' | 'suspended' | 'revoked'
  final bool isPrimaryVehicle;
  final String? notes;
  final DateTime updatedAtUtc;

  const ParticipantVehicleDto({
    required this.vehicleId,
    required this.vehicleCode,
    required this.userCode,
    required this.vehicleType,
    this.plateNumberDisplay,
    this.normalizedPlateNumber,
    this.rfidUid,
    this.vehicleStatus = 'active',
    this.authorizationStatus = 'authorized',
    this.isPrimaryVehicle = true,
    this.notes,
    required this.updatedAtUtc,
  });

  ParticipantVehicleDto copyWith({
    String? vehicleType,
    String? plateNumberDisplay,
    String? normalizedPlateNumber,
    String? rfidUid,
    String? vehicleStatus,
    String? authorizationStatus,
    bool? isPrimaryVehicle,
    String? notes,
    DateTime? updatedAtUtc,
  }) {
    return ParticipantVehicleDto(
      vehicleId: vehicleId,
      vehicleCode: vehicleCode,
      userCode: userCode,
      vehicleType: vehicleType ?? this.vehicleType,
      plateNumberDisplay: plateNumberDisplay ?? this.plateNumberDisplay,
      normalizedPlateNumber:
          normalizedPlateNumber ?? this.normalizedPlateNumber,
      rfidUid: rfidUid ?? this.rfidUid,
      vehicleStatus: vehicleStatus ?? this.vehicleStatus,
      authorizationStatus: authorizationStatus ?? this.authorizationStatus,
      isPrimaryVehicle: isPrimaryVehicle ?? this.isPrimaryVehicle,
      notes: notes ?? this.notes,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  Map<String, dynamic> toJson() => {
        'vehicle_id': vehicleId,
        'vehicle_code': vehicleCode,
        'user_code': userCode,
        'vehicle_type': vehicleType,
        'plate_number_display': plateNumberDisplay,
        'normalized_plate_number': normalizedPlateNumber,
        'rfid_uid': rfidUid,
        'vehicle_status': vehicleStatus,
        'authorization_status': authorizationStatus,
        'is_primary_vehicle': isPrimaryVehicle,
        'notes': notes,
        'updated_at': ManilaTime.toUtcIso(updatedAtUtc),
      };
}

/// Source-verified `ParticipantUser` DTO for `P01–P06` (`/api/v1/participants/...`).
/// Includes `admissionEvaluated: false` (since `P01–P06` are registration maintenance only,
/// never live gate admission evaluation).
class ParticipantUserDto {
  final String userId;
  final String userCode; // U001..U007
  final String fullName;
  final String email;
  final String status; // 'active' | 'inactive'
  final String? buildingCode; // null by default in strict contract fixtures
  final String faceTemplateId;
  final bool faceEnrolled;
  final bool admissionEvaluated; // strictly false on P01-P06 registration routes
  final List<ParticipantVehicleDto> vehicles;

  const ParticipantUserDto({
    required this.userId,
    required this.userCode,
    required this.fullName,
    required this.email,
    this.status = 'active',
    this.buildingCode,
    required this.faceTemplateId,
    this.faceEnrolled = true,
    this.admissionEvaluated = false,
    required this.vehicles,
  });

  ParticipantUserDto copyWith({
    String? fullName,
    String? status,
    String? buildingCode,
    List<ParticipantVehicleDto>? vehicles,
  }) {
    return ParticipantUserDto(
      userId: userId,
      userCode: userCode,
      fullName: fullName ?? this.fullName,
      email: email,
      status: status ?? this.status,
      buildingCode: buildingCode ?? this.buildingCode,
      faceTemplateId: faceTemplateId,
      faceEnrolled: faceEnrolled,
      admissionEvaluated: admissionEvaluated,
      vehicles: vehicles ?? this.vehicles,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_code': userCode,
        'full_name': fullName,
        'email': email,
        'status': status,
        'building_code': buildingCode,
        'face_template_id': faceTemplateId,
        'face_enrolled': faceEnrolled,
        'admission_evaluated': admissionEvaluated,
        'vehicles': vehicles.map((v) => v.toJson()).toList(),
      };
}
