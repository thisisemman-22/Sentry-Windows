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

  factory ParticipantVehicleDto.fromJson(Map<String, dynamic> json) {
    return ParticipantVehicleDto(
      vehicleId: json['vehicle_id']?.toString() ?? '',
      vehicleCode: json['vehicle_code']?.toString() ?? '',
      userCode: json['user_code']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? 'car',
      plateNumberDisplay: json['plate_number_display']?.toString() ??
          json['plate_number']?.toString(),
      normalizedPlateNumber: json['normalized_plate_number']?.toString(),
      rfidUid: json['rfid_uid']?.toString(),
      vehicleStatus: json['vehicle_status']?.toString() ?? 'active',
      authorizationStatus:
          json['authorization_status']?.toString() ?? 'authorized',
      isPrimaryVehicle: json['is_primary_vehicle'] != false,
      notes: json['notes']?.toString(),
      updatedAtUtc: DateTime.tryParse(json['updated_at']?.toString() ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
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
  final String userCode; // U001..U007 or newly registered U008+
  final String fullName;
  final String email;
  final String roleCode; // 'student' | 'guard' | 'administrator'
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
    this.roleCode = 'student',
    this.status = 'active',
    this.buildingCode,
    required this.faceTemplateId,
    this.faceEnrolled = true,
    this.admissionEvaluated = false,
    required this.vehicles,
  });

  ParticipantUserDto copyWith({
    String? fullName,
    String? roleCode,
    String? status,
    String? buildingCode,
    String? faceTemplateId,
    bool? faceEnrolled,
    List<ParticipantVehicleDto>? vehicles,
  }) {
    return ParticipantUserDto(
      userId: userId,
      userCode: userCode,
      fullName: fullName ?? this.fullName,
      email: email,
      roleCode: roleCode ?? this.roleCode,
      status: status ?? this.status,
      buildingCode: buildingCode ?? this.buildingCode,
      faceTemplateId: faceTemplateId ?? this.faceTemplateId,
      faceEnrolled: faceEnrolled ?? this.faceEnrolled,
      admissionEvaluated: admissionEvaluated,
      vehicles: vehicles ?? this.vehicles,
    );
  }

  factory ParticipantUserDto.fromJson(Map<String, dynamic> json) {
    final rawVehicles = json['vehicles'];
    return ParticipantUserDto(
      userId: json['user_id']?.toString() ?? '',
      userCode: json['user_code']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      roleCode: json['role_code']?.toString() ?? 'student',
      status: json['status']?.toString() ?? 'active',
      buildingCode: json['building_code']?.toString(),
      faceTemplateId: json['face_template_id']?.toString() ?? '',
      faceEnrolled: json['face_enrolled'] == true,
      admissionEvaluated: json['admission_evaluated'] == true,
      vehicles: rawVehicles is List
          ? rawVehicles
              .whereType<Map<String, dynamic>>()
              .map(ParticipantVehicleDto.fromJson)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_code': userCode,
        'full_name': fullName,
        'email': email,
        'role_code': roleCode,
        'status': status,
        'building_code': buildingCode,
        'face_template_id': faceTemplateId,
        'face_enrolled': faceEnrolled,
        'admission_evaluated': admissionEvaluated,
        'vehicles': vehicles.map((v) => v.toJson()).toList(),
      };
}

/// Request payload for `POST /api/v1/admin/users/register` (with `Idempotency-Key`).
class ManualUserRegistrationRequest {
  final String fullName;
  final String? userCode; // optional/auto-generated or matching ^U[0-9]{3,8}$
  final String email;
  final String roleCode; // 'student' | 'guard' | 'administrator'
  final String?
      buildingCode; // 'CET'|'REGISTRAR'|'STEERHUB'|'FITNESS CENTER'|'CEAFA'|'CICS'|'RGR' or null
  final bool includeVehicle;
  final String? vehicleType; // 'car' | 'motorcycle'
  final String? plateNumber; // auto-uppercased, normalized on submit
  final String? rfidUid; // optional hex string for motorcycles

  const ManualUserRegistrationRequest({
    required this.fullName,
    this.userCode,
    required this.email,
    this.roleCode = 'student',
    this.buildingCode,
    this.includeVehicle = true,
    this.vehicleType = 'car',
    this.plateNumber,
    this.rfidUid,
  });

  /// Normalizes a license plate (auto-uppercased, stripping spaces and hyphens).
  static String normalizePlate(String raw) {
    return raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Client-side field validation before submitting to `POST /api/v1/admin/users/register`.
  /// Returns a map of field-name -> error message (empty if valid).
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (fullName.trim().length < 2) {
      errors['full_name'] = 'Full name must be at least 2 characters.';
    }
    final code = userCode?.trim() ?? '';
    if (code.isNotEmpty && !RegExp(r'^U[0-9]{3,8}$').hasMatch(code)) {
      errors['user_code'] =
          'User code must match ^U[0-9]{3,8}\$ (e.g. U008) or be left blank to auto-generate.';
    }
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmedEmail)) {
      errors['email'] = 'Enter a valid campus or institutional email address.';
    }
    if (!const {'student', 'guard', 'administrator'}.contains(roleCode)) {
      errors['role_code'] = 'Role must be student, guard, or administrator.';
    }
    if (roleCode == 'student' && !includeVehicle) {
      errors['vehicle'] =
          'A primary vehicle is required when registering a Student for campus parking access.';
    }
    if (includeVehicle) {
      final vType = vehicleType ?? 'car';
      final rawPlate = plateNumber?.trim() ?? '';
      final normPlate = normalizePlate(rawPlate);
      final rawRfid = rfidUid?.trim().toUpperCase() ?? '';
      if (vType == 'car') {
        if (normPlate.length < 2 || normPlate.length > 12) {
          errors['plate_number'] =
              'License plate is required for cars (2–12 alphanumeric characters).';
        }
      } else if (vType == 'motorcycle') {
        if (normPlate.isNotEmpty &&
            (normPlate.length < 2 || normPlate.length > 12)) {
          errors['plate_number'] =
              'Normalized plate must be 2–12 alphanumeric characters.';
        }
        if (rawRfid.isNotEmpty &&
            !RegExp(r'^(?:[0-9A-F]{8}|[0-9A-F]{14}|[0-9A-F]{20})$')
                .hasMatch(rawRfid)) {
          errors['rfid_uid'] =
              'RFID UID must be 8, 14, or 20 uppercase hexadecimal characters (e.g. 04A1B2C3).';
        }
      }
    }
    return errors;
  }

  Map<String, dynamic> toJson() {
    final rawPlate = plateNumber?.trim();
    final normPlate =
        (rawPlate != null && rawPlate.isNotEmpty) ? normalizePlate(rawPlate) : null;
    final cleanRfid = rfidUid?.trim().toUpperCase();
    return {
      'full_name': fullName.trim(),
      if (userCode != null && userCode!.trim().isNotEmpty)
        'user_code': userCode!.trim().toUpperCase(),
      'email': email.trim().toLowerCase(),
      'role_code': roleCode,
      'building_code': buildingCode,
      if (includeVehicle)
        'vehicle': {
          'vehicle_type': vehicleType ?? 'car',
          'plate_number': rawPlate?.toUpperCase(),
          'normalized_plate_number': normPlate,
          if (cleanRfid != null && cleanRfid.isNotEmpty) 'rfid_uid': cleanRfid,
        },
    };
  }
}

/// Response payload from `POST /api/v1/admin/users/register` (`201 Created`).
class ManualUserRegistrationResponse {
  final String userId;
  final String userCode;
  final String fullName;
  final String email;
  final String roleCode;
  final String? buildingCode;
  final String? vehicleId;
  final String? vehicleCode;
  final String? plateNumberDisplay;
  final String? normalizedPlateNumber;
  final DateTime createdAtUtc;

  const ManualUserRegistrationResponse({
    required this.userId,
    required this.userCode,
    required this.fullName,
    required this.email,
    required this.roleCode,
    this.buildingCode,
    this.vehicleId,
    this.vehicleCode,
    this.plateNumberDisplay,
    this.normalizedPlateNumber,
    required this.createdAtUtc,
  });

  factory ManualUserRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return ManualUserRegistrationResponse(
      userId: json['user_id']?.toString() ?? '',
      userCode: json['user_code']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      roleCode: json['role_code']?.toString() ?? 'student',
      buildingCode: json['building_code']?.toString(),
      vehicleId: json['vehicle_id']?.toString(),
      vehicleCode: json['vehicle_code']?.toString(),
      plateNumberDisplay: json['plate_number_display']?.toString(),
      normalizedPlateNumber: json['normalized_plate_number']?.toString(),
      createdAtUtc: DateTime.tryParse(json['created_at']?.toString() ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_code': userCode,
        'full_name': fullName,
        'email': email,
        'role_code': roleCode,
        'building_code': buildingCode,
        'vehicle_id': vehicleId,
        'vehicle_code': vehicleCode,
        'plate_number_display': plateNumberDisplay,
        'normalized_plate_number': normalizedPlateNumber,
        'created_at': ManilaTime.toUtcIso(createdAtUtc),
      };
}

/// RA 10173-compliant Facial Recognition Enrollment status DTO
/// (`GET / POST / DELETE /api/v1/admin/users/{user_id}/face-enrollment`).
/// Privacy Rule: Never stores or returns raw face photos after upload—only
/// numerical embedding template metadata.
class FaceEnrollmentStatusDto {
  final String userId;
  final String userCode;
  final String status; // 'not_enrolled' | 'enrolled' | 'needs_re_enrollment'
  final String? faceTemplateId;
  final String modelVersion;
  final String? artifactReference;
  final DateTime? enrolledAtUtc;
  final DateTime? retentionExpiresAtUtc;
  final String consentVersion;
  final int frameCount;

  const FaceEnrollmentStatusDto({
    required this.userId,
    required this.userCode,
    required this.status,
    this.faceTemplateId,
    this.modelVersion = 'arcface-r100-v1.1',
    this.artifactReference,
    this.enrolledAtUtc,
    this.retentionExpiresAtUtc,
    this.consentVersion = 'RA10173-BSU-2026.1',
    this.frameCount = 0,
  });

  bool get isEnrolled => status == 'enrolled';

  factory FaceEnrollmentStatusDto.fromJson(Map<String, dynamic> json) {
    return FaceEnrollmentStatusDto(
      userId: json['user_id']?.toString() ?? '',
      userCode: json['user_code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'not_enrolled',
      faceTemplateId: json['face_template_id']?.toString(),
      modelVersion: json['model_version']?.toString() ?? 'arcface-r100-v1.1',
      artifactReference: json['artifact_reference']?.toString(),
      enrolledAtUtc: json['enrolled_at'] != null
          ? DateTime.tryParse(json['enrolled_at'].toString())?.toUtc()
          : null,
      retentionExpiresAtUtc: json['retention_expires_at'] != null
          ? DateTime.tryParse(json['retention_expires_at'].toString())?.toUtc()
          : null,
      consentVersion:
          json['consent_version']?.toString() ?? 'RA10173-BSU-2026.1',
      frameCount: (json['frame_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_code': userCode,
        'status': status,
        'face_template_id': faceTemplateId,
        'model_version': modelVersion,
        'artifact_reference': artifactReference,
        'enrolled_at':
            enrolledAtUtc != null ? ManilaTime.toUtcIso(enrolledAtUtc!) : null,
        'retention_expires_at': retentionExpiresAtUtc != null
            ? ManilaTime.toUtcIso(retentionExpiresAtUtc!)
            : null,
        'consent_version': consentVersion,
        'frame_count': frameCount,
      };
}

/// Request payload for `POST /api/v1/admin/users/{user_id}/face-enrollment`.
class FaceEnrollmentSubmissionRequest {
  final String userId;
  final String userCode;
  final bool consentAccepted;
  final String consentVersion;
  final List<String> framesBase64;
  final List<String> frameNames;

  const FaceEnrollmentSubmissionRequest({
    required this.userId,
    required this.userCode,
    required this.consentAccepted,
    this.consentVersion = 'RA10173-BSU-2026.1',
    required this.framesBase64,
    this.frameNames = const [],
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_code': userCode,
        'consent_accepted': consentAccepted,
        'consent_version': consentVersion,
        'frames': framesBase64,
        'frame_names': frameNames,
      };
}
