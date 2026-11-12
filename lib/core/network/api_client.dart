import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../shared/models/auth_models.dart';
import '../config/app_config.dart';
import 'api_envelope.dart';
import 'secure_session_store.dart';

/// Shared HTTP client wrapper for SENTRY Desktop (`campus_parking_desktop`).
/// Enforces:
/// - `baseUrl` from [AppConfig.apiBaseUrl] (`http://127.0.0.1:8000` default)
/// - `connectTimeout: 3s` and `receiveTimeout: 5s`
/// - Bearer token injection from [SecureSessionStore] on every authenticated request
/// - Automatic `Idempotency-Key: <uuid_v4>` header on all mutation requests (`POST`, `PATCH`, `PUT`, `DELETE`)
/// - Automatic single-attempt token refresh on `401` via `POST /api/v1/auth/refresh`; if refresh fails,
///   clears [SecureSessionStore] and triggers [onSessionExpired]
/// - Fail-closed behavior in `DATA_SOURCE=real` mode (never falls back to mock success)
class ApiClient {
  final AppConfig config;
  final SecureSessionStore sessionStore;
  final Dio _dio;
  final Uuid _uuid = const Uuid();
  final void Function(String reason)? onSessionExpired;
  bool _isRefreshing = false;

  Dio get dio => _dio;

  ApiClient({
    required this.config,
    required this.sessionStore,
    Dio? dio,
    this.onSessionExpired,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: config.apiBaseUrl,
                connectTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 5),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = await sessionStore.readSession();
          if (session != null &&
              session.accessToken.isNotEmpty &&
              !options.headers.containsKey('Authorization')) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          final method = options.method.toUpperCase();
          if ((method == 'POST' ||
                  method == 'PATCH' ||
                  method == 'PUT' ||
                  method == 'DELETE') &&
              !options.headers.containsKey('Idempotency-Key')) {
            options.headers['Idempotency-Key'] = _uuid.v4();
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          final status = err.response?.statusCode;
          final path = err.requestOptions.path;
          final alreadyRetried =
              err.requestOptions.extra['_retried_after_refresh'] == true;
          final isAuthEndpoint = path.contains('/api/v1/auth/login') ||
              path.contains('/api/v1/auth/refresh');

          if (status == 401 && !alreadyRetried && !isAuthEndpoint) {
            final refreshed = await _attemptSingleTokenRefresh();
            if (refreshed != null) {
              try {
                final retryOptions = err.requestOptions;
                retryOptions.extra['_retried_after_refresh'] = true;
                retryOptions.headers['Authorization'] =
                    'Bearer ${refreshed.accessToken}';
                final response = await _dio.fetch<dynamic>(retryOptions);
                return handler.resolve(response);
              } on DioException catch (retryErr) {
                await _expireSessionAndNotify();
                return handler.next(retryErr);
              }
            } else {
              await _expireSessionAndNotify();
            }
          } else if (status == 401 && !path.contains('/api/v1/auth/login')) {
            await _expireSessionAndNotify();
          }
          handler.next(err);
        },
      ),
    );
  }

  Future<SessionDto?> _attemptSingleTokenRefresh() async {
    if (_isRefreshing) return null;
    final currentSession = await sessionStore.readSession();
    if (currentSession == null) return null;

    _isRefreshing = true;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {
          'session_id': currentSession.sessionId,
          'refresh_token':
              currentSession.refreshToken ?? currentSession.accessToken,
        },
        options: Options(
          extra: const {'_retried_after_refresh': true},
          headers: {
            'Authorization': 'Bearer ${currentSession.accessToken}',
            'Idempotency-Key': _uuid.v4(),
          },
        ),
      );
      final payload = response.data;
      if (payload != null &&
          payload['ok'] == true &&
          payload['data'] is Map<String, dynamic>) {
        final data = payload['data'] as Map<String, dynamic>;
        final SessionDto nextSession;
        if (data['profile'] is Map<String, dynamic>) {
          nextSession = SessionDto.fromJson(data);
        } else {
          nextSession = currentSession.copyWith(
            accessToken:
                data['access_token']?.toString() ?? currentSession.accessToken,
            refreshToken: data['refresh_token']?.toString() ??
                currentSession.refreshToken,
            expiresAtUtc: data['expires_at'] != null
                ? DateTime.parse(data['expires_at'].toString()).toUtc()
                : DateTime.now().toUtc().add(const Duration(hours: 8)),
          );
        }
        await sessionStore.saveSession(nextSession);
        return nextSession;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _expireSessionAndNotify() async {
    await sessionStore.clearSession();
    onSessionExpired?.call(
      'Session expired or unauthorized (HTTP 401). Please sign in again.',
    );
  }

  Future<ApiEnvelope<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) parser,
  }) async {
    final configError = config.validateForRealMode();
    if (configError != null) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.configurationInvalid,
        message: configError,
        httpStatus: 500,
      );
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return _parseEnvelope(response.data, response.statusCode ?? 200, parser);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.serviceUnavailable,
        message: 'Unexpected error communicating with FastAPI: $e',
        httpStatus: 503,
      );
    }
  }

  Future<ApiEnvelope<T>> post<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    Map<String, dynamic>? headers,
    required T Function(dynamic json) parser,
  }) async {
    final configError = config.validateForRealMode();
    if (configError != null) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.configurationInvalid,
        message: configError,
        httpStatus: 500,
      );
    }
    try {
      final mergedHeaders = <String, dynamic>{
        if (headers != null) ...headers,
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      };
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: mergedHeaders.isNotEmpty
            ? Options(headers: mergedHeaders)
            : null,
      );
      return _parseEnvelope(response.data, response.statusCode ?? 200, parser);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.serviceUnavailable,
        message: 'Unexpected error communicating with FastAPI: $e',
        httpStatus: 503,
      );
    }
  }

  Future<ApiEnvelope<T>> patch<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    Map<String, dynamic>? headers,
    required T Function(dynamic json) parser,
  }) async {
    final configError = config.validateForRealMode();
    if (configError != null) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.configurationInvalid,
        message: configError,
        httpStatus: 500,
      );
    }
    try {
      final mergedHeaders = <String, dynamic>{
        if (headers != null) ...headers,
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      };
      final response = await _dio.patch<Map<String, dynamic>>(
        path,
        data: body,
        options: mergedHeaders.isNotEmpty
            ? Options(headers: mergedHeaders)
            : null,
      );
      return _parseEnvelope(response.data, response.statusCode ?? 200, parser);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.serviceUnavailable,
        message: 'Unexpected error communicating with FastAPI: $e',
        httpStatus: 503,
      );
    }
  }

  Future<ApiEnvelope<T>> delete<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    Map<String, dynamic>? headers,
    required T Function(dynamic json) parser,
  }) async {
    final configError = config.validateForRealMode();
    if (configError != null) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.configurationInvalid,
        message: configError,
        httpStatus: 500,
      );
    }
    try {
      final mergedHeaders = <String, dynamic>{
        if (headers != null) ...headers,
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      };
      final response = await _dio.delete<Map<String, dynamic>>(
        path,
        data: body,
        options: mergedHeaders.isNotEmpty
            ? Options(headers: mergedHeaders)
            : null,
      );
      return _parseEnvelope(response.data, response.statusCode ?? 200, parser);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.serviceUnavailable,
        message: 'Unexpected error communicating with FastAPI: $e',
        httpStatus: 503,
      );
    }
  }

  ApiEnvelope<T> _parseEnvelope<T>(
    Map<String, dynamic>? payload,
    int statusCode,
    T Function(dynamic json) parser,
  ) {
    if (payload == null) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.serviceUnavailable,
        message: 'Empty response received from FastAPI backend.',
        httpStatus: statusCode,
      );
    }
    final ok = payload['ok'] == true;
    final meta = ApiMeta.fromJson(
      payload['meta'] is Map<String, dynamic>
          ? payload['meta'] as Map<String, dynamic>
          : null,
    );
    if (!ok) {
      final errMap = payload['error'] is Map<String, dynamic>
          ? payload['error'] as Map<String, dynamic>
          : <String, dynamic>{};
      return ApiEnvelope<T>(
        ok: false,
        error: ApiError.fromJson(errMap, httpStatus: statusCode),
        meta: meta,
      );
    }
    return ApiEnvelope<T>(
      ok: true,
      data: parser(payload['data']),
      meta: meta,
    );
  }

  ApiEnvelope<T> _handleDioError<T>(DioException e) {
    final status = e.response?.statusCode ?? 503;
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      return ApiEnvelope<T>(
        ok: false,
        error: ApiError.fromJson(
          data['error'] as Map<String, dynamic>,
          httpStatus: status,
        ),
        meta: ApiMeta.fromJson(
          data['meta'] is Map<String, dynamic>
              ? data['meta'] as Map<String, dynamic>
              : null,
        ),
      );
    }
    return ApiEnvelope.failure(
      code: ErrorCatalog.defaultCodeForHttpStatus(status),
      message:
          'FastAPI endpoint unreachable or failed (${e.message ?? 'Network error'}). Fail-closed mode active.',
      httpStatus: status,
    );
  }
}
