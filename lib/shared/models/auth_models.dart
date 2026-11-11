/// Authentication and Role models for SENTRY Desktop (`guard` & `administrator`).
enum UserRole {
  guard,
  administrator,
  student;

  static UserRole fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'administrator':
      case 'admin':
        return UserRole.administrator;
      case 'student':
        return UserRole.student;
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
      case UserRole.guard:
        return 'SECURITY GUARD';
    }
  }

  bool get isAdmin => this == UserRole.administrator;
  bool get isGuardOrAdmin =>
      this == UserRole.guard || this == UserRole.administrator;
}

class LoginRequest {
  final String username;
  final String password;
  final String clientId;

  const LoginRequest({
    required this.username,
    required this.password,
    this.clientId = 'desktop-guard-01',
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'client_id': clientId,
      };
}

class ProfileDto {
  final String userId;
  final String userCode;
  final String username;
  final String fullName;
  final UserRole role;
  final String assignedStation;
  final bool isActive;

  const ProfileDto({
    required this.userId,
    required this.userCode,
    required this.username,
    required this.fullName,
    required this.role,
    required this.assignedStation,
    this.isActive = true,
  });

  factory ProfileDto.fromJson(Map<String, dynamic> json) {
    return ProfileDto(
      userId: json['user_id']?.toString() ?? '',
      userCode: json['user_code']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: UserRole.fromString(json['role']?.toString() ?? 'guard'),
      assignedStation:
          json['assigned_station']?.toString() ?? 'Gate 1 Guardhouse',
      isActive: json['is_active'] != false,
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
      };
}

class SessionDto {
  final String sessionId;
  final String accessToken;
  final DateTime issuedAtUtc;
  final DateTime expiresAtUtc;
  final ProfileDto profile;

  const SessionDto({
    required this.sessionId,
    required this.accessToken,
    required this.issuedAtUtc,
    required this.expiresAtUtc,
    required this.profile,
  });

  bool isExpired([DateTime? nowUtc]) {
    final check = (nowUtc ?? DateTime.now()).toUtc();
    return !expiresAtUtc.isAfter(check);
  }

  factory SessionDto.fromJson(Map<String, dynamic> json) {
    return SessionDto(
      sessionId: json['session_id']?.toString() ?? '',
      accessToken: json['access_token']?.toString() ?? '',
      issuedAtUtc:
          DateTime.parse(json['issued_at'].toString()).toUtc(),
      expiresAtUtc:
          DateTime.parse(json['expires_at'].toString()).toUtc(),
      profile: ProfileDto.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'access_token': accessToken,
        'issued_at': '${issuedAtUtc.toIso8601String().replaceAll(RegExp(r'Z$'), '')}Z',
        'expires_at': '${expiresAtUtc.toIso8601String().replaceAll(RegExp(r'Z$'), '')}Z',
        'profile': profile.toJson(),
      };
}
