import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../shared/models/auth_models.dart';

/// Repository port & adapter for View 1 (`authentication`) + shared account ops
/// aligned with the canonical Phase 4 OpenAPI 3.1.0 contract (`1.0.0-draft`):
/// - `POST /api/v1/auth/login` (`login`)
/// - `POST /api/v1/auth/refresh` (`refreshTokens`)
/// - `POST /api/v1/auth/logout` (`logoutCurrentSession`)
/// - `GET /api/v1/me` (`getOwnProfile`)
/// - `POST /api/v1/auth/password/change` (`changePassword`)
/// - `POST /api/v1/auth/password-reset/request` (`requestPasswordReset`)
/// - `POST /api/v1/auth/password-reset/verify` (`verifyPasswordReset`)
/// - `POST /api/v1/auth/password-reset/complete` (`completePasswordReset`)
/// - `POST /api/v1/auth/activation/verify` (`verifyActivationCode`)
/// - `POST /api/v1/auth/activation/password` (`setActivationPassword`)
class AuthRepository {
  final ApiClient apiClient;

  const AuthRepository({required this.apiClient});

  Future<ApiEnvelope<TokenPairData>> login(LoginRequest request) {
    return apiClient.post<TokenPairData>(
      '/api/v1/auth/login',
      body: request.toJson(),
      includeAuth: false,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      parser: TokenPairData.fromStrictJson,
    );
  }

  Future<ApiEnvelope<TokenPairData>> refreshTokens(RefreshRequest request) {
    return apiClient.post<TokenPairData>(
      '/api/v1/auth/refresh',
      body: request.toJson(),
      includeAuth: false,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      parser: TokenPairData.fromStrictJson,
    );
  }

  Future<ApiEnvelope<bool>> logoutCurrentSession() {
    return apiClient.post<bool>(
      '/api/v1/auth/logout',
      body: const LogoutRequest().toJson(),
      includeAuth: true,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      expectNullData: true,
      parser: (_) => true,
    );
  }

  Future<ApiEnvelope<ProfileData>> getOwnProfile() {
    return apiClient.get<ProfileData>(
      '/api/v1/me',
      includeAuth: true,
      strictPhase4Envelope: true,
      parser: ProfileData.fromStrictJson,
    );
  }

  Future<ApiEnvelope<bool>> changePassword(PasswordChangeRequest request) {
    return apiClient.post<bool>(
      '/api/v1/auth/password/change',
      body: request.toJson(),
      includeAuth: true,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      expectNullData: true,
      parser: (_) => true,
    );
  }

  Future<ApiEnvelope<PasswordResetAcceptedData>> requestPasswordReset(
    PasswordResetRequest request,
  ) {
    return apiClient.post<PasswordResetAcceptedData>(
      '/api/v1/auth/password-reset/request',
      body: request.toJson(),
      includeAuth: false,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      // Padded to >= 3s by backend
      receiveTimeout: const Duration(seconds: 10),
      parser: PasswordResetAcceptedData.fromStrictJson,
    );
  }

  Future<ApiEnvelope<PasswordResetGrantData>> verifyPasswordReset(
    PasswordResetVerifyRequest request,
  ) {
    return apiClient.post<PasswordResetGrantData>(
      '/api/v1/auth/password-reset/verify',
      body: request.toJson(),
      includeAuth: false,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      receiveTimeout: const Duration(seconds: 8),
      parser: PasswordResetGrantData.fromStrictJson,
    );
  }

  Future<ApiEnvelope<bool>> completePasswordReset(
    PasswordResetCompleteRequest request,
  ) {
    return apiClient.post<bool>(
      '/api/v1/auth/password-reset/complete',
      body: request.toJson(),
      includeAuth: false,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      expectNullData: true,
      parser: (_) => true,
    );
  }

  Future<ApiEnvelope<SetupGrantData>> verifyActivationCode(
    OtpVerificationRequest request,
  ) {
    return apiClient.post<SetupGrantData>(
      '/api/v1/auth/activation/verify',
      body: request.toJson(),
      includeAuth: false,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      parser: SetupGrantData.fromStrictJson,
    );
  }

  Future<ApiEnvelope<ActivationData>> setActivationPassword(
    PasswordSetupRequest request,
  ) {
    return apiClient.post<ActivationData>(
      '/api/v1/auth/activation/password',
      body: request.toJson(),
      includeAuth: false,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      parser: ActivationData.fromStrictJson,
    );
  }

  // Compatibility alias for existing callers if needed.
  Future<ApiEnvelope<bool>> logoutReal() => logoutCurrentSession();
}
