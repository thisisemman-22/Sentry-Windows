import '../../core/network/phase4_contract.dart';

/// Authentication and Role models for SENTRY Desktop (`guard` & `administrator`).
/// Aligned with Phase 4 OpenAPI 3.1.0 contract (`1.0.0-draft`, wire `1.0.0`).
enum UserRole {
  student,
  guard,
  administrator,
  faculty,
  staff;

  /// Strict OpenAPI role parser: throws [ContractViolation] on unknown values.
  static UserRole parseStrict(String value) {
    switch (value) {
      case 'student':
        return UserRole.student;
      case 'guard':
        return UserRole.guard;
      case 'administrator':
        return UserRole.administrator;
      case 'faculty':
        return UserRole.faculty;
      case 'staff':
        return UserRole.staff;
      default:
        throw ContractViolation('Unknown UserRole "$value".');
    }
  }

  static UserRole fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'administrator':
      case 'admin':
        return UserRole.administrator;
      case 'student':
        return UserRole.student;
      case 'faculty':
        return UserRole.faculty;
      case 'staff':
        return UserRole.staff;
      case 'guard':
      default:
        return UserRole.guard;
    }
  }

  String get wireValue {
    switch (this) {
      case UserRole.administrator:
        return 'administrator';
      case UserRole.student:
        return 'student';
      case UserRole.faculty:
        return 'faculty';
      case UserRole.staff:
        return 'staff';
      case UserRole.guard:
        return 'guard';
    }
  }

  String get displayBadge {
    switch (this) {
      case UserRole.administrator:
        return 'ADMINISTRATOR';
      case UserRole.student:
        return 'STUDENT';
      case UserRole.faculty:
        return 'FACULTY';
      case UserRole.staff:
        return 'STAFF';
      case UserRole.guard:
        return 'SECURITY GUARD';
    }
  }

  bool get isAdmin => this == UserRole.administrator;
  bool get isGuardOrAdmin =>
      this == UserRole.guard || this == UserRole.administrator;
  bool get isMobileOnly =>
      this == UserRole.student ||
      this == UserRole.faculty ||
      this == UserRole.staff;
}

/// Phase 4 Request DTO: `POST /api/v1/auth/login` (`additionalProperties: false`).
/// Never trims or normalizes `password`.
class LoginRequest {
  final String identifier;
  final String password;

  const LoginRequest({
    required this.identifier,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'password': password,
      };

  @override
  String toString() => 'LoginRequest(identifier: $identifier, password: [REDACTED])';
}

/// Phase 4 Request DTO: `POST /api/v1/auth/refresh`.
class RefreshRequest {
  final String refreshToken;

  const RefreshRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refresh_token': refreshToken};

  @override
  String toString() => 'RefreshRequest(refresh_token: [REDACTED])';
}

/// Phase 4 Request DTO: `POST /api/v1/auth/logout` (exact empty `{}`).
class LogoutRequest {
  const LogoutRequest();

  Map<String, dynamic> toJson() => const <String, dynamic>{};
}

/// Phase 4 Request DTO: `POST /api/v1/auth/password/change`.
class PasswordChangeRequest {
  final String currentPassword;
  final String newPassword;

  const PasswordChangeRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
        'current_password': currentPassword,
        'new_password': newPassword,
      };

  @override
  String toString() =>
      'PasswordChangeRequest(current_password: [REDACTED], new_password: [REDACTED])';
}

/// Phase 4 Request DTO: `POST /api/v1/auth/password-reset/request`.
class PasswordResetRequest {
  final String identifier;

  const PasswordResetRequest({required this.identifier});

  Map<String, dynamic> toJson() => {'identifier': identifier};
}

/// Phase 4 Request DTO: `POST /api/v1/auth/password-reset/verify`.
class PasswordResetVerifyRequest {
  final String identifier;
  final String otpCode;

  const PasswordResetVerifyRequest({
    required this.identifier,
    required this.otpCode,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'otp_code': otpCode,
      };

  @override
  String toString() =>
      'PasswordResetVerifyRequest(identifier: $identifier, otp_code: [REDACTED])';
}

/// Phase 4 Request DTO: `POST /api/v1/auth/password-reset/complete`.
class PasswordResetCompleteRequest {
  final String identifier;
  final String resetGrant;
  final String newPassword;

  const PasswordResetCompleteRequest({
    required this.identifier,
    required this.resetGrant,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'reset_grant': resetGrant,
        'new_password': newPassword,
      };

  @override
  String toString() =>
      'PasswordResetCompleteRequest(identifier: $identifier, reset_grant: [REDACTED], new_password: [REDACTED])';
}

/// Phase 4 Request DTO: `POST /api/v1/auth/activation/verify`.
class OtpVerificationRequest {
  final String identifier;
  final String otpCode;

  const OtpVerificationRequest({
    required this.identifier,
    required this.otpCode,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'otp_code': otpCode,
      };

  @override
  String toString() =>
      'OtpVerificationRequest(identifier: $identifier, otp_code: [REDACTED])';
}

/// Phase 4 Request DTO: `POST /api/v1/auth/activation/password`.
class PasswordSetupRequest {
  final String identifier;
  final String setupGrant;
  final String password;

  const PasswordSetupRequest({
    required this.identifier,
    required this.setupGrant,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'setup_grant': setupGrant,
        'password': password,
      };

  @override
  String toString() =>
      'PasswordSetupRequest(identifier: $identifier, setup_grant: [REDACTED], password: [REDACTED])';
}

/// Phase 4 Response DTO: `TokenPairData` (`login` & `refreshTokens`).
class TokenPairData {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime accessExpiresAtUtc;
  final DateTime refreshExpiresAtUtc;
  final bool firstLoginRequired;

  const TokenPairData({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.accessExpiresAtUtc,
    required this.refreshExpiresAtUtc,
    this.firstLoginRequired = false,
  });

  factory TokenPairData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'TokenPairData');
    assertExactKeys(
      map,
      requiredKeys: const {
        'access_token',
        'refresh_token',
        'token_type',
        'access_expires_at',
        'refresh_expires_at',
      },
      optionalKeys: const {'first_login_required'},
      schemaName: 'TokenPairData',
    );
    final accessToken = requireString(map, 'access_token', 'TokenPairData');
    final refreshToken = requireString(map, 'refresh_token', 'TokenPairData');
    final tokenType = requireString(map, 'token_type', 'TokenPairData');
    if (tokenType != 'bearer') {
      throw ContractViolation(
        'TokenPairData.token_type must equal "bearer", got "$tokenType".',
      );
    }
    final rawFirstLogin = map['first_login_required'];
    if (rawFirstLogin != null && rawFirstLogin is! bool) {
      throw const ContractViolation(
        'TokenPairData.first_login_required must be a boolean.',
      );
    }
    return TokenPairData(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      accessExpiresAtUtc:
          parseStrictUtcDateTime(map['access_expires_at'], 'TokenPairData.access_expires_at'),
      refreshExpiresAtUtc: parseStrictUtcDateTime(
        map['refresh_expires_at'],
        'TokenPairData.refresh_expires_at',
      ),
      firstLoginRequired: rawFirstLogin == true,
    );
  }

  @override
  String toString() =>
      'TokenPairData(token_type: $tokenType, access_token: [REDACTED], refresh_token: [REDACTED], access_expires_at: $accessExpiresAtUtc)';
}

/// Phase 4 Response DTO: `BuildingData`.
class BuildingData {
  final String id;
  final String code;
  final String name;

  const BuildingData({
    required this.id,
    required this.code,
    required this.name,
  });

  factory BuildingData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'BuildingData');
    assertExactKeys(
      map,
      requiredKeys: const {'id', 'code', 'name'},
      schemaName: 'BuildingData',
    );
    return BuildingData(
      id: requireUuid(map, 'id', 'BuildingData'),
      code: requireString(map, 'code', 'BuildingData'),
      name: requireString(map, 'name', 'BuildingData'),
    );
  }
}

/// Phase 4 Response DTO: `VehicleData` inside `ProfileData.authorized_vehicles`.
class ProfileVehicleData {
  final String id;
  final String displayCode;
  final String vehicleType; // 'car' | 'motorcycle'
  final String? normalizedPlate;

  const ProfileVehicleData({
    required this.id,
    required this.displayCode,
    required this.vehicleType,
    required this.normalizedPlate,
  });

  factory ProfileVehicleData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'VehicleData');
    assertExactKeys(
      map,
      requiredKeys: const {
        'id',
        'display_code',
        'vehicle_type',
        'normalized_plate',
      },
      schemaName: 'VehicleData',
    );
    final vType = requireString(map, 'vehicle_type', 'VehicleData');
    if (vType != 'car' && vType != 'motorcycle') {
      throw ContractViolation('Unknown VehicleData.vehicle_type "$vType".');
    }
    return ProfileVehicleData(
      id: requireUuid(map, 'id', 'VehicleData'),
      displayCode: requireString(map, 'display_code', 'VehicleData'),
      vehicleType: vType,
      normalizedPlate: requireNullableString(map, 'normalized_plate', 'VehicleData'),
    );
  }
}

/// Phase 4 Response DTO: 7-field `ProfileData` allowlist (`GET /api/v1/me`)
/// plus optional `first_login_required`.
class ProfileData {
  final String id;
  final String displayCode;
  final String fullName;
  final UserRole role;
  final BuildingData? building;
  final String? email;
  final List<ProfileVehicleData> authorizedVehicles;
  final bool firstLoginRequired;

  const ProfileData({
    required this.id,
    required this.displayCode,
    required this.fullName,
    required this.role,
    required this.building,
    required this.email,
    required this.authorizedVehicles,
    this.firstLoginRequired = false,
  });

  factory ProfileData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'ProfileData');
    assertExactKeys(
      map,
      requiredKeys: const {
        'id',
        'display_code',
        'full_name',
        'role',
        'building',
        'email',
        'authorized_vehicles',
      },
      optionalKeys: const {'first_login_required'},
      schemaName: 'ProfileData',
    );
    final rawBuilding = map['building'];
    final BuildingData? building =
        rawBuilding == null ? null : BuildingData.fromStrictJson(rawBuilding);
    final rawVehicles = map['authorized_vehicles'];
    if (rawVehicles is! List<dynamic>) {
      throw const ContractViolation('ProfileData.authorized_vehicles must be an array.');
    }
    if (rawVehicles.length > 20) {
      throw const ContractViolation(
        'ProfileData.authorized_vehicles exceeds maxItems 20.',
      );
    }
    final rawFirstLogin = map['first_login_required'];
    if (rawFirstLogin != null && rawFirstLogin is! bool) {
      throw const ContractViolation(
        'ProfileData.first_login_required must be a boolean.',
      );
    }
    return ProfileData(
      id: requireUuid(map, 'id', 'ProfileData'),
      displayCode: requireString(map, 'display_code', 'ProfileData'),
      fullName: requireString(map, 'full_name', 'ProfileData'),
      role: UserRole.parseStrict(requireString(map, 'role', 'ProfileData')),
      building: building,
      email: requireNullableString(map, 'email', 'ProfileData'),
      authorizedVehicles:
          rawVehicles.map(ProfileVehicleData.fromStrictJson).toList(),
      firstLoginRequired: rawFirstLogin == true,
    );
  }
}

/// Phase 4 Response DTO: `PasswordResetAcceptedData`.
class PasswordResetAcceptedData {
  final String status;

  const PasswordResetAcceptedData({required this.status});

  factory PasswordResetAcceptedData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'PasswordResetAcceptedData');
    assertExactKeys(
      map,
      requiredKeys: const {'status'},
      schemaName: 'PasswordResetAcceptedData',
    );
    final status = requireString(map, 'status', 'PasswordResetAcceptedData');
    if (status != 'accepted') {
      throw ContractViolation(
        'PasswordResetAcceptedData.status must equal "accepted", got "$status".',
      );
    }
    return PasswordResetAcceptedData(status: status);
  }
}

/// Phase 4 Response DTO: `PasswordResetGrantData`.
class PasswordResetGrantData {
  final String resetGrant;
  final String grantType;
  final DateTime expiresAtUtc;

  const PasswordResetGrantData({
    required this.resetGrant,
    required this.grantType,
    required this.expiresAtUtc,
  });

  factory PasswordResetGrantData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'PasswordResetGrantData');
    assertExactKeys(
      map,
      requiredKeys: const {'reset_grant', 'grant_type', 'expires_at'},
      schemaName: 'PasswordResetGrantData',
    );
    final grantType = requireString(map, 'grant_type', 'PasswordResetGrantData');
    if (grantType != 'password_reset') {
      throw ContractViolation(
        'PasswordResetGrantData.grant_type must equal "password_reset", got "$grantType".',
      );
    }
    return PasswordResetGrantData(
      resetGrant: requireString(map, 'reset_grant', 'PasswordResetGrantData'),
      grantType: grantType,
      expiresAtUtc: parseStrictUtcDateTime(
        map['expires_at'],
        'PasswordResetGrantData.expires_at',
      ),
    );
  }

  @override
  String toString() =>
      'PasswordResetGrantData(grant_type: $grantType, reset_grant: [REDACTED], expires_at: $expiresAtUtc)';
}

/// Phase 4 Response DTO: `SetupGrantData`.
class SetupGrantData {
  final String setupGrant;
  final String grantType;
  final DateTime expiresAtUtc;

  const SetupGrantData({
    required this.setupGrant,
    required this.grantType,
    required this.expiresAtUtc,
  });

  factory SetupGrantData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'SetupGrantData');
    assertExactKeys(
      map,
      requiredKeys: const {'setup_grant', 'grant_type', 'expires_at'},
      schemaName: 'SetupGrantData',
    );
    final grantType = requireString(map, 'grant_type', 'SetupGrantData');
    if (grantType != 'password_setup') {
      throw ContractViolation(
        'SetupGrantData.grant_type must equal "password_setup", got "$grantType".',
      );
    }
    return SetupGrantData(
      setupGrant: requireString(map, 'setup_grant', 'SetupGrantData'),
      grantType: grantType,
      expiresAtUtc: parseStrictUtcDateTime(
        map['expires_at'],
        'SetupGrantData.expires_at',
      ),
    );
  }

  @override
  String toString() =>
      'SetupGrantData(grant_type: $grantType, setup_grant: [REDACTED], expires_at: $expiresAtUtc)';
}

/// Phase 4 Response DTO: `ActivationData`.
class ActivationData {
  final String status;

  const ActivationData({required this.status});

  factory ActivationData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'ActivationData');
    assertExactKeys(
      map,
      requiredKeys: const {'status'},
      schemaName: 'ActivationData',
    );
    final status = requireString(map, 'status', 'ActivationData');
    if (status != 'activated') {
      throw ContractViolation(
        'ActivationData.status must equal "activated", got "$status".',
      );
    }
    return ActivationData(status: status);
  }
}

/// App-level authenticated operator profile wrapper compatible with both
/// Phase 4 `ProfileData` (`GET /api/v1/me`) and local mock fixtures.
class ProfileDto {
  final String userId;
  final String userCode;
  final String username;
  final String fullName;
  final UserRole role;
  final String assignedStation;
  final bool isActive;
  final String? email;
  final BuildingData? building;
  final List<ProfileVehicleData> authorizedVehicles;
  final bool firstLoginRequired;

  const ProfileDto({
    required this.userId,
    required this.userCode,
    required this.username,
    required this.fullName,
    required this.role,
    required this.assignedStation,
    this.isActive = true,
    this.email,
    this.building,
    this.authorizedVehicles = const [],
    this.firstLoginRequired = false,
  });

  ProfileDto copyWith({
    String? fullName,
    String? assignedStation,
    bool? isActive,
    String? email,
    bool? firstLoginRequired,
  }) {
    return ProfileDto(
      userId: userId,
      userCode: userCode,
      username: username,
      fullName: fullName ?? this.fullName,
      role: role,
      assignedStation: assignedStation ?? this.assignedStation,
      isActive: isActive ?? this.isActive,
      email: email ?? this.email,
      building: building,
      authorizedVehicles: authorizedVehicles,
      firstLoginRequired: firstLoginRequired ?? this.firstLoginRequired,
    );
  }

  factory ProfileDto.fromProfileData(
    ProfileData data, {
    bool forceFirstLogin = false,
  }) {
    return ProfileDto(
      userId: data.id,
      userCode: data.displayCode,
      username: data.email ?? data.displayCode,
      fullName: data.fullName,
      role: data.role,
      assignedStation: data.building?.name ??
          (data.role.isAdmin ? 'ICT Command Center' : 'Campus Security Desk'),
      isActive: true,
      email: data.email,
      building: data.building,
      authorizedVehicles: data.authorizedVehicles,
      firstLoginRequired: data.firstLoginRequired || forceFirstLogin,
    );
  }

  factory ProfileDto.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('display_code') && json.containsKey('id')) {
      return ProfileDto.fromProfileData(ProfileData.fromStrictJson(json));
    }
    return ProfileDto(
      userId: json['user_id']?.toString() ?? '',
      userCode: json['user_code']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: UserRole.fromString(json['role']?.toString() ?? 'guard'),
      assignedStation:
          json['assigned_station']?.toString() ?? 'Gate 1 Guardhouse',
      isActive: json['is_active'] != false,
      email: json['email']?.toString(),
      firstLoginRequired: json['first_login_required'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_code': userCode,
        'username': username,
        'full_name': fullName,
        'role': role.wireValue,
        'assigned_station': assignedStation,
        'is_active': isActive,
        if (email != null) 'email': email,
        if (firstLoginRequired) 'first_login_required': true,
      };
}

class SessionDto {
  final String sessionId;
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final DateTime issuedAtUtc;
  final DateTime expiresAtUtc;
  final DateTime? refreshExpiresAtUtc;
  final ProfileDto profile;

  const SessionDto({
    required this.sessionId,
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'bearer',
    required this.issuedAtUtc,
    required this.expiresAtUtc,
    this.refreshExpiresAtUtc,
    required this.profile,
  });

  bool get firstLoginRequired => profile.firstLoginRequired;

  factory SessionDto.fromTokenPairAndProfile(
    TokenPairData pair,
    ProfileData profile,
  ) {
    return SessionDto(
      sessionId: 'sess-${profile.id}',
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      tokenType: pair.tokenType,
      issuedAtUtc: DateTime.now().toUtc(),
      expiresAtUtc: pair.accessExpiresAtUtc,
      refreshExpiresAtUtc: pair.refreshExpiresAtUtc,
      profile: ProfileDto.fromProfileData(
        profile,
        forceFirstLogin: pair.firstLoginRequired,
      ),
    );
  }

  bool isExpired([DateTime? nowUtc]) {
    final check = (nowUtc ?? DateTime.now()).toUtc();
    return !expiresAtUtc.isAfter(check);
  }

  bool isRefreshExpired([DateTime? nowUtc]) {
    if (refreshExpiresAtUtc == null) return false;
    final check = (nowUtc ?? DateTime.now()).toUtc();
    return !refreshExpiresAtUtc!.isAfter(check);
  }

  SessionDto copyWith({
    String? sessionId,
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    DateTime? issuedAtUtc,
    DateTime? expiresAtUtc,
    DateTime? refreshExpiresAtUtc,
    ProfileDto? profile,
  }) {
    return SessionDto(
      sessionId: sessionId ?? this.sessionId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      issuedAtUtc: issuedAtUtc ?? this.issuedAtUtc,
      expiresAtUtc: expiresAtUtc ?? this.expiresAtUtc,
      refreshExpiresAtUtc: refreshExpiresAtUtc ?? this.refreshExpiresAtUtc,
      profile: profile ?? this.profile,
    );
  }

  factory SessionDto.fromJson(Map<String, dynamic> json) {
    return SessionDto(
      sessionId: json['session_id']?.toString() ?? '',
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString(),
      tokenType: json['token_type']?.toString() ?? 'bearer',
      issuedAtUtc: json['issued_at'] != null
          ? DateTime.parse(json['issued_at'].toString()).toUtc()
          : DateTime.now().toUtc(),
      expiresAtUtc: DateTime.parse(
        (json['access_expires_at'] ?? json['expires_at']).toString(),
      ).toUtc(),
      refreshExpiresAtUtc: json['refresh_expires_at'] != null
          ? DateTime.parse(json['refresh_expires_at'].toString()).toUtc()
          : null,
      profile: ProfileDto.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'access_token': accessToken,
        if (refreshToken != null) 'refresh_token': refreshToken,
        'token_type': tokenType,
        'issued_at':
            '${issuedAtUtc.toIso8601String().replaceAll(RegExp(r'Z$'), '')}Z',
        'expires_at':
            '${expiresAtUtc.toIso8601String().replaceAll(RegExp(r'Z$'), '')}Z',
        if (refreshExpiresAtUtc != null)
          'refresh_expires_at':
              '${refreshExpiresAtUtc!.toIso8601String().replaceAll(RegExp(r'Z$'), '')}Z',
        'profile': profile.toJson(),
      };

  @override
  String toString() =>
      'SessionDto(userCode: ${profile.userCode}, role: ${profile.role.wireValue}, access_token: [REDACTED], refresh_token: [REDACTED], expiresAtUtc: $expiresAtUtc)';
}
