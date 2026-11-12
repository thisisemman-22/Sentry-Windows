import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../shared/models/auth_models.dart';

/// Repository port & adapter for View 1 (`authentication`).
/// Supports both `DATA_SOURCE=mock` and strict `DATA_SOURCE=real`:
/// - `POST /api/v1/auth/login`
/// - `POST /api/v1/auth/refresh`
/// - `POST /api/v1/auth/logout`
/// - `GET /api/v1/me`
class AuthRepository {
  final ApiClient apiClient;

  const AuthRepository({required this.apiClient});

  Future<ApiEnvelope<SessionDto>> loginReal(LoginRequest request) {
    return apiClient.post<SessionDto>(
      '/api/v1/auth/login',
      body: request.toJson(),
      parser: (json) => SessionDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<ApiEnvelope<SessionDto>> refreshReal({
    required String sessionId,
    required String refreshToken,
  }) {
    return apiClient.post<SessionDto>(
      '/api/v1/auth/refresh',
      body: {
        'session_id': sessionId,
        'refresh_token': refreshToken,
      },
      parser: (json) => SessionDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<ApiEnvelope<bool>> logoutReal() {
    return apiClient.post<bool>(
      '/api/v1/auth/logout',
      body: const {},
      parser: (_) => true,
    );
  }

  Future<ApiEnvelope<ProfileDto>> fetchMeReal() {
    return apiClient.get<ProfileDto>(
      '/api/v1/me',
      parser: (json) => ProfileDto.fromJson(json as Map<String, dynamic>),
    );
  }
}
