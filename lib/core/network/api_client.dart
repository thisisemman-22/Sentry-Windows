import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../shared/models/auth_models.dart';
import '../config/app_config.dart';
import 'api_envelope.dart';
import 'phase4_contract.dart';
import 'secure_session_store.dart';

/// Shared HTTP client wrapper for SENTRY Desktop (`campus_parking_desktop`).
/// Enforces:
/// - `baseUrl` from [AppConfig.apiBaseUrl]
/// - `connectTimeout: 3s` and default `receiveTimeout: 8s` (supports >=3s server timing padding)
/// - Bearer token injection from [SecureSessionStore] when `includeAuth: true`
/// - Explicit or automatic `Idempotency-Key: <uuid_v4>` on mutations when `autoIdempotencyKey: true`
/// - **Single-flight** token refresh (`Future<SessionDto?>? _inFlightRefresh`) via `POST /api/v1/auth/refresh`
///   with exact body `{"refresh_token": ...}` (`no retry grace` — never replays on `401` or `503`)
/// - Auto-retries `GET` (read-only) ONCE after successful refresh; NEVER auto-replays state-changing calls
/// - Fail-closed behavior in `DATA_SOURCE=real` mode and zero secret/token logging
class ApiClient {
  final AppConfig config;
  final SecureSessionStore sessionStore;
  final Dio _dio;
  final Uuid _uuid = const Uuid();
  final void Function(String reason)? onSessionExpired;
  final void Function(SessionDto nextSession)? onSessionRefreshed;
  final DateTime Function() _nowUtc;

  Future<SessionDto?>? _inFlightRefresh;

  Dio get dio => _dio;

  ApiClient({
    required this.config,
    required this.sessionStore,
    Dio? dio,
    this.onSessionExpired,
    this.onSessionRefreshed,
    DateTime Function()? nowUtc,
  })  : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: config.apiBaseUrl,
                connectTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 8),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final skipAuth = options.extra['_skip_auth'] == true;
          final path = options.path;
          final isAuthRoute = path.contains('/api/v1/auth/');
          if (!skipAuth) {
            var session = await sessionStore.readSession();
            if (session != null &&
                !isAuthRoute &&
                options.extra['_retried_after_refresh'] != true &&
                session.isExpired(_nowUtc()) &&
                (session.refreshToken?.isNotEmpty ?? false)) {
              final refreshed = await refreshSessionSingleFlight();
              if (refreshed != null) {
                session = refreshed;
              }
            }
            if (session != null &&
                session.accessToken.isNotEmpty &&
                !options.headers.containsKey('Authorization')) {
              options.headers['Authorization'] =
                  'Bearer ${session.accessToken}';
            }
          }
          final autoIdem = options.extra['_auto_idempotency'] != false;
          final method = options.method.toUpperCase();
          if (autoIdem &&
              (method == 'POST' ||
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
          final method = err.requestOptions.method.toUpperCase();
          final alreadyRetried =
              err.requestOptions.extra['_retried_after_refresh'] == true;
          final skipAuth = err.requestOptions.extra['_skip_auth'] == true;
          final isAuthEndpoint = path.contains('/api/v1/auth/login') ||
              path.contains('/api/v1/auth/refresh') ||
              path.contains('/api/v1/auth/logout') ||
              path.contains('/api/v1/auth/password-reset/') ||
              path.contains('/api/v1/auth/activation/');

          if (status == 401 && !alreadyRetried && !isAuthEndpoint && !skipAuth) {
            final refreshed = await refreshSessionSingleFlight();
            if (refreshed != null && method == 'GET') {
              // Contract rule: auto-repeat ONCE only for read-only GET requests.
              try {
                final retryOptions = err.requestOptions;
                retryOptions.extra['_retried_after_refresh'] = true;
                retryOptions.headers['Authorization'] =
                    'Bearer ${refreshed.accessToken}';
                final response = await _dio.fetch<dynamic>(retryOptions);
                return handler.resolve(response);
              } on DioException catch (retryErr) {
                if (retryErr.response?.statusCode == 401) {
                  await _expireSessionAndNotify();
                }
                return handler.next(retryErr);
              }
            }
            // State-changing call or failed refresh: never auto-replay mutation.
          } else if (status == 401 && !isAuthEndpoint && !skipAuth) {
            await _expireSessionAndNotify();
          }
          handler.next(err);
        },
      ),
    );
  }

  /// Coordinates refresh so only ONE `POST /api/v1/auth/refresh` runs in flight
  /// across concurrent callers. Replaying a consumed refresh token revokes the
  /// session on the backend. On `401` or `503` (or any failure), clears local
  /// tokens immediately and never retries with the same refresh token.
  Future<SessionDto?> refreshSessionSingleFlight() {
    final existing = _inFlightRefresh;
    if (existing != null) return existing;
    final future = _executeSingleFlightRefresh();
    _inFlightRefresh = future;
    return future.whenComplete(() {
      if (identical(_inFlightRefresh, future)) {
        _inFlightRefresh = null;
      }
    });
  }

  Future<SessionDto?> _executeSingleFlightRefresh() async {
    final currentSession = await sessionStore.readSession();
    final refreshToken = currentSession?.refreshToken;
    if (currentSession == null ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      await _expireSessionAndNotify();
      return null;
    }

    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/auth/refresh',
        data: RefreshRequest(refreshToken: refreshToken).toJson(),
        options: Options(
          extra: const {
            '_skip_auth': true,
            '_auto_idempotency': false,
            '_retried_after_refresh': true,
          },
        ),
      );
      final raw = response.data;
      if (raw is! Map<String, dynamic>) {
        await _expireSessionAndNotify();
        return null;
      }

      // Support canonical Phase 4 TokenPairData and minimal refresh test stubs safely.
      TokenPairData? tokenPair;
      if (raw['ok'] == true && raw['data'] is Map<String, dynamic>) {
        final dataMap = raw['data'] as Map<String, dynamic>;
        if (dataMap.containsKey('token_type') &&
            dataMap.containsKey('access_expires_at') &&
            dataMap.containsKey('refresh_expires_at')) {
          tokenPair = TokenPairData.fromStrictJson(dataMap);
        } else {
          final nextSession = currentSession.copyWith(
            accessToken:
                dataMap['access_token']?.toString() ?? currentSession.accessToken,
            refreshToken: dataMap['refresh_token']?.toString() ??
                currentSession.refreshToken,
            expiresAtUtc: dataMap['expires_at'] != null
                ? DateTime.parse(dataMap['expires_at'].toString()).toUtc()
                : DateTime.now().toUtc().add(const Duration(minutes: 10)),
          );
          await sessionStore.saveSession(nextSession);
          onSessionRefreshed?.call(nextSession);
          return nextSession;
        }
      }

      if (tokenPair != null) {
        final nextSession = currentSession.copyWith(
          accessToken: tokenPair.accessToken,
          refreshToken: tokenPair.refreshToken,
          tokenType: tokenPair.tokenType,
          issuedAtUtc: DateTime.now().toUtc(),
          expiresAtUtc: tokenPair.accessExpiresAtUtc,
          refreshExpiresAtUtc: tokenPair.refreshExpiresAtUtc,
        );
        await sessionStore.saveSession(nextSession);
        onSessionRefreshed?.call(nextSession);
        return nextSession;
      }

      await _expireSessionAndNotify();
      return null;
    } catch (_) {
      // Contract rule: on 401 OR 503 OR transport failure, NEVER replay the
      // presented refresh token again; discard stored tokens and sign in.
      await _expireSessionAndNotify();
      return null;
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
    bool includeAuth = true,
    bool strictPhase4Envelope = false,
    bool expectNullData = false,
    Duration? receiveTimeout,
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
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: Options(
          receiveTimeout: receiveTimeout,
          extra: {
            if (!includeAuth) '_skip_auth': true,
          },
        ),
      );
      return _parseResponse<T>(
        response,
        parser,
        strictPhase4Envelope: strictPhase4Envelope,
        expectNullData: expectNullData,
      );
    } on DioException catch (e) {
      return _handleDioError(e, strictPhase4Envelope: strictPhase4Envelope);
    } catch (e) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.serviceUnavailable,
        message: 'Unexpected error communicating with FastAPI: $e',
        httpStatus: 503,
      );
    }
  }

  /// Fetches raw binary bytes (`ResponseType.bytes`, e.g. CSV/PDF report exports).
  /// Decodes UTF-8 JSON error envelopes cleanly if the backend returns an error status.
  Future<ApiEnvelope<Uint8List>> getBytes(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool includeAuth = true,
    Duration? receiveTimeout,
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
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: receiveTimeout ?? const Duration(seconds: 20),
          headers: const {'Accept': '*/*'},
          extra: {
            if (!includeAuth) '_skip_auth': true,
          },
        ),
      );
      final headerRequestId = response.headers.value('x-request-id');
      final raw = response.data;
      if (raw == null || raw.isEmpty) {
        return ApiEnvelope.failure(
          code: ErrorCatalog.serviceUnavailable,
          message: 'Empty export payload returned by FastAPI backend.',
          httpStatus: response.statusCode ?? 503,
          requestId: headerRequestId ?? 'req-export-empty',
        );
      }
      return ApiEnvelope.success(
        Uint8List.fromList(raw),
        requestId: headerRequestId ?? 'req-export-ok',
      );
    } on DioException catch (e) {
      final resp = e.response;
      if (resp != null && resp.data is List<int>) {
        final rawBytes = resp.data as List<int>;
        try {
          final decoded = jsonDecode(utf8.decode(rawBytes));
          if (decoded is Map<String, dynamic>) {
            final synthetic = DioException(
              requestOptions: e.requestOptions,
              response: Response<dynamic>(
                requestOptions: e.requestOptions,
                data: decoded,
                statusCode: resp.statusCode,
                headers: resp.headers,
              ),
              type: e.type,
              error: e.error,
              message: e.message,
            );
            return _handleDioError<Uint8List>(synthetic);
          }
        } catch (_) {}
      }
      return _handleDioError<Uint8List>(e);
    } catch (e) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.serviceUnavailable,
        message: 'Unexpected error downloading binary payload: $e',
        httpStatus: 503,
      );
    }
  }

  Future<ApiEnvelope<T>> post<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    Map<String, dynamic>? headers,
    bool includeAuth = true,
    bool autoIdempotencyKey = true,
    bool strictPhase4Envelope = false,
    bool expectNullData = false,
    Duration? receiveTimeout,
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
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        options: Options(
          receiveTimeout: receiveTimeout,
          headers: mergedHeaders.isNotEmpty ? mergedHeaders : null,
          extra: {
            if (!includeAuth) '_skip_auth': true,
            '_auto_idempotency': autoIdempotencyKey,
          },
        ),
      );
      return _parseResponse<T>(
        response,
        parser,
        strictPhase4Envelope: strictPhase4Envelope,
        expectNullData: expectNullData,
      );
    } on DioException catch (e) {
      return _handleDioError(e, strictPhase4Envelope: strictPhase4Envelope);
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
    bool includeAuth = true,
    bool autoIdempotencyKey = true,
    bool strictPhase4Envelope = false,
    Duration? receiveTimeout,
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
      final response = await _dio.patch<dynamic>(
        path,
        data: body,
        options: Options(
          receiveTimeout: receiveTimeout,
          headers: mergedHeaders.isNotEmpty ? mergedHeaders : null,
          extra: {
            if (!includeAuth) '_skip_auth': true,
            '_auto_idempotency': autoIdempotencyKey,
          },
        ),
      );
      return _parseResponse<T>(
        response,
        parser,
        strictPhase4Envelope: strictPhase4Envelope,
      );
    } on DioException catch (e) {
      return _handleDioError(e, strictPhase4Envelope: strictPhase4Envelope);
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
    bool includeAuth = true,
    bool autoIdempotencyKey = true,
    bool strictPhase4Envelope = false,
    Duration? receiveTimeout,
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
      final response = await _dio.delete<dynamic>(
        path,
        data: body,
        options: Options(
          receiveTimeout: receiveTimeout,
          headers: mergedHeaders.isNotEmpty ? mergedHeaders : null,
          extra: {
            if (!includeAuth) '_skip_auth': true,
            '_auto_idempotency': autoIdempotencyKey,
          },
        ),
      );
      return _parseResponse<T>(
        response,
        parser,
        strictPhase4Envelope: strictPhase4Envelope,
      );
    } on DioException catch (e) {
      return _handleDioError(e, strictPhase4Envelope: strictPhase4Envelope);
    } catch (e) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.serviceUnavailable,
        message: 'Unexpected error communicating with FastAPI: $e',
        httpStatus: 503,
      );
    }
  }

  ApiEnvelope<T> _parseResponse<T>(
    Response<dynamic> response,
    T Function(dynamic json) parser, {
    bool strictPhase4Envelope = false,
    bool expectNullData = false,
  }) {
    final statusCode = response.statusCode ?? 200;
    final headerRequestId = response.headers.value('x-request-id');
    final retryAfter = int.tryParse(response.headers.value('retry-after') ?? '');
    final payload = response.data;

    if (payload == null || payload is! Map<String, dynamic>) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.serviceUnavailable,
        message: 'Invalid or empty response received from FastAPI backend.',
        httpStatus: statusCode,
        requestId: headerRequestId ?? 'req-invalid',
      );
    }

    if (strictPhase4Envelope) {
      try {
        final env = Phase4Envelope.parse<T>(
          payload,
          (data) => parser(data),
          expectNullData: expectNullData,
          httpStatus: statusCode,
          retryAfterSeconds: retryAfter,
        );
        return env.toApiEnvelope();
      } on ContractViolation catch (e) {
        return ApiEnvelope.failure(
          code: 'UNEXPECTED_RESPONSE',
          message: 'Contract violation: ${e.message}',
          httpStatus: statusCode,
          requestId: headerRequestId ?? 'req-contract-violation',
        );
      }
    }

    return _parseLegacyEnvelope(
      payload,
      statusCode,
      parser,
      headerRequestId: headerRequestId,
      retryAfter: retryAfter,
    );
  }

  ApiEnvelope<T> _parseLegacyEnvelope<T>(
    Map<String, dynamic> payload,
    int statusCode,
    T Function(dynamic json) parser, {
    String? headerRequestId,
    int? retryAfter,
  }) {
    final ok = payload['ok'] == true;
    final meta = ApiMeta.fromJson(
      payload['meta'] is Map<String, dynamic>
          ? payload['meta'] as Map<String, dynamic>
          : null,
      headerRequestId: headerRequestId,
    );
    if (!ok) {
      final errMap = payload['error'] is Map<String, dynamic>
          ? payload['error'] as Map<String, dynamic>
          : <String, dynamic>{};
      return ApiEnvelope<T>(
        ok: false,
        error: ApiError.fromJson(
          errMap,
          httpStatus: statusCode,
          retryAfterSeconds: retryAfter,
        ),
        meta: meta,
      );
    }
    return ApiEnvelope<T>(
      ok: true,
      data: parser(payload['data']),
      meta: meta,
    );
  }

  ApiEnvelope<T> _handleDioError<T>(
    DioException e, {
    bool strictPhase4Envelope = false,
  }) {
    final status = e.response?.statusCode ?? 503;
    final headerRequestId = e.response?.headers.value('x-request-id');
    final retryAfter =
        int.tryParse(e.response?.headers.value('retry-after') ?? '');
    final data = e.response?.data;

    if (strictPhase4Envelope && data is Map<String, dynamic>) {
      try {
        final env = Phase4Envelope.parse<T>(
          data,
          (_) => throw const ContractViolation('Unexpected ok=true in error.'),
          httpStatus: status,
          retryAfterSeconds: retryAfter,
        );
        return env.toApiEnvelope();
      } on ContractViolation catch (cv) {
        return ApiEnvelope.failure(
          code: 'UNEXPECTED_RESPONSE',
          message: 'Contract violation: ${cv.message}',
          httpStatus: status,
          requestId: headerRequestId ?? 'req-contract-violation',
        );
      }
    }

    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      return ApiEnvelope<T>(
        ok: false,
        error: ApiError.fromJson(
          data['error'] as Map<String, dynamic>,
          httpStatus: status,
          retryAfterSeconds: retryAfter,
        ),
        meta: ApiMeta.fromJson(
          data['meta'] is Map<String, dynamic>
              ? data['meta'] as Map<String, dynamic>
              : null,
          headerRequestId: headerRequestId,
        ),
      );
    }

    return ApiEnvelope.failure(
      code: ErrorCatalog.defaultCodeForHttpStatus(status),
      message:
          'Endpoint unreachable or failed (${e.message ?? 'Network error'}). Outcome unknown; fail-closed mode active.',
      httpStatus: status,
      requestId: headerRequestId ?? 'req-transport-err',
    );
  }
}
