import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../shared/models/audit_models.dart';
import '../../../shared/models/participant_models.dart';

/// Repository adapter for View 8 (`administration`) supporting:
/// - `GET /api/v1/admin/audit-logs` (Administrator Only)
/// - `P01–P06` `/api/v1/participants/...` (Administrator Only; `admission_evaluated: false`)
/// - `POST /api/v1/admin/users/register` (Manual User & Vehicle Registration with `Idempotency-Key`)
/// - `POST /api/v1/admin/users/{user_id}/face-enrollment` (RA 10173 Facial Enrollment)
/// - `GET /api/v1/admin/users/{user_id}/face-enrollment` (Enrollment Status — no raw photos)
/// - `DELETE /api/v1/admin/users/{user_id}/face-enrollment` (Withdraw consent / purge biometric embedding)
class AdministrationRepository {
  final ApiClient apiClient;

  const AdministrationRepository({required this.apiClient});

  Future<ApiEnvelope<List<AuditLogDto>>> fetchAuditLogsReal({
    int limit = 50,
    String? cursor,
  }) {
    return apiClient.get<List<AuditLogDto>>(
      '/api/v1/admin/audit-logs',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
      parser: (json) => (json as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(AuditLogDto.fromJson)
          .toList(),
    );
  }

  /// P01: List participant users (`GET /api/v1/participants`)
  Future<ApiEnvelope<List<ParticipantUserDto>>> fetchParticipantsReal() {
    return apiClient.get<List<ParticipantUserDto>>(
      '/api/v1/participants',
      parser: (json) => (json as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ParticipantUserDto.fromJson)
          .toList(),
    );
  }

  /// P02: Fetch participant user (`GET /api/v1/participants/{user_code}`)
  Future<ApiEnvelope<ParticipantUserDto>> fetchParticipantByCodeReal(
    String userCode,
  ) {
    return apiClient.get<ParticipantUserDto>(
      '/api/v1/participants/$userCode',
      parser: (json) =>
          ParticipantUserDto.fromJson(json as Map<String, dynamic>),
    );
  }

  /// P03: Create participant user (`POST /api/v1/participants`)
  Future<ApiEnvelope<ParticipantUserDto>> createParticipantReal(
    Map<String, dynamic> body,
  ) {
    return apiClient.post<ParticipantUserDto>(
      '/api/v1/participants',
      body: body,
      parser: (json) =>
          ParticipantUserDto.fromJson(json as Map<String, dynamic>),
    );
  }

  /// P04: Patch participant user (`PATCH /api/v1/participants/{user_code}`)
  Future<ApiEnvelope<ParticipantUserDto>> patchParticipantReal({
    required String userCode,
    required Map<String, dynamic> body,
  }) {
    return apiClient.patch<ParticipantUserDto>(
      '/api/v1/participants/$userCode',
      body: body,
      parser: (json) =>
          ParticipantUserDto.fromJson(json as Map<String, dynamic>),
    );
  }

  /// P05: Register vehicle for participant (`POST /api/v1/participants/{user_code}/vehicles`)
  Future<ApiEnvelope<ParticipantVehicleDto>> registerParticipantVehicleReal({
    required String userCode,
    required Map<String, dynamic> body,
  }) {
    return apiClient.post<ParticipantVehicleDto>(
      '/api/v1/participants/$userCode/vehicles',
      body: body,
      parser: (json) =>
          ParticipantVehicleDto.fromJson(json as Map<String, dynamic>),
    );
  }

  /// P06: Patch vehicle status/authorization (`PATCH /api/v1/participants/{user_code}/vehicles/{vehicle_code}`)
  Future<ApiEnvelope<ParticipantVehicleDto>> patchParticipantVehicleReal({
    required String userCode,
    required String vehicleCode,
    required Map<String, dynamic> body,
  }) {
    return apiClient.patch<ParticipantVehicleDto>(
      '/api/v1/participants/$userCode/vehicles/$vehicleCode',
      body: body,
      parser: (json) =>
          ParticipantVehicleDto.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Feature 1: Manual User & Vehicle Registration (`POST /api/v1/admin/users/register` with `Idempotency-Key`)
  Future<ApiEnvelope<ManualUserRegistrationResponse>> registerUserAndVehicleReal(
    ManualUserRegistrationRequest request, {
    String? idempotencyKey,
  }) {
    return apiClient.post<ManualUserRegistrationResponse>(
      '/api/v1/admin/users/register',
      body: request.toJson(),
      idempotencyKey: idempotencyKey,
      parser: (json) => ManualUserRegistrationResponse.fromJson(
        json as Map<String, dynamic>,
      ),
    );
  }

  /// Feature 2a: Fetch Facial Enrollment Status (`GET /api/v1/admin/users/{user_id}/face-enrollment`)
  Future<ApiEnvelope<FaceEnrollmentStatusDto>> fetchFaceEnrollmentReal(
    String userId,
  ) {
    return apiClient.get<FaceEnrollmentStatusDto>(
      '/api/v1/admin/users/$userId/face-enrollment',
      parser: (json) =>
          FaceEnrollmentStatusDto.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Feature 2b: Submit Facial Enrollment (`POST /api/v1/admin/users/{user_id}/face-enrollment`)
  Future<ApiEnvelope<FaceEnrollmentStatusDto>> submitFaceEnrollmentReal(
    FaceEnrollmentSubmissionRequest request, {
    String? idempotencyKey,
  }) {
    return apiClient.post<FaceEnrollmentStatusDto>(
      '/api/v1/admin/users/${request.userId}/face-enrollment',
      body: request.toJson(),
      idempotencyKey: idempotencyKey,
      parser: (json) =>
          FaceEnrollmentStatusDto.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Feature 2c: Revoke & Delete Facial Embedding (`DELETE /api/v1/admin/users/{user_id}/face-enrollment`)
  Future<ApiEnvelope<FaceEnrollmentStatusDto>> deleteFaceEnrollmentReal(
    String userId, {
    String? idempotencyKey,
  }) {
    return apiClient.delete<FaceEnrollmentStatusDto>(
      '/api/v1/admin/users/$userId/face-enrollment',
      idempotencyKey: idempotencyKey,
      parser: (json) =>
          FaceEnrollmentStatusDto.fromJson(json as Map<String, dynamic>),
    );
  }
}
