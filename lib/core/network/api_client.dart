import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import 'api_envelope.dart';
import 'secure_session_store.dart';

/// Shared HTTP client wrapper for SENTRY Desktop (`campus_parking_desktop`).
/// Enforces:
/// - Bearer token injection from [SecureSessionStore]
/// - Automatic `Idempotency-Key` header on state-changing `POST`/`PATCH` requests
/// - Fail-closed behavior in `DATA_SOURCE=real` mode (never falls back to mock success)
class ApiClient {
  final AppConfig config;
  final SecureSessionStore sessionStore;
  final Dio _dio;
  final Uuid _uuid = const Uuid();
  final void Function(String reason)? onSessionExpired;

  ApiClient({
    required this.config,
    required this.sessionStore,
    Dio? dio,
    this.onSessionExpired,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: config.apiBaseUrl,
                connectTimeout:
                    Duration(milliseconds: config.requestTimeoutMs),
                receiveTimeout:
                    Duration(milliseconds: config.requestTimeoutMs),
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
          if (session != null && session.accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          final method = options.method.toUpperCase();
          if ((method == 'POST' || method == 'PATCH' || method == 'PUT') &&
              !options.headers.containsKey('Idempotency-Key')) {
            options.headers['Idempotency-Key'] = _uuid.v4();
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          final status = err.response?.statusCode;
          if (status == 401) {
            await sessionStore.clearSession();
            onSessionExpired?.call(
              'Session expired or unauthorized (HTTP 401). Please sign in again.',
            );
          }
          handler.next(err);
        },
      ),
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
      final response =
          await _dio.get<Map<String, dynamic>>(path, queryParameters: queryParameters);
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
    Map<String, dynamic>? body,
    String? idempotencyKey,
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
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: idempotencyKey != null
            ? Options(headers: {'Idempotency-Key': idempotencyKey})
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
    Map<String, dynamic>? body,
    String? idempotencyKey,
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
      final response = await _dio.patch<Map<String, dynamic>>(
        path,
        data: body,
        options: idempotencyKey != null
            ? Options(headers: {'Idempotency-Key': idempotencyKey})
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
      code: status == 401
          ? ErrorCatalog.unauthorized
          : status == 403
              ? ErrorCatalog.accessDenied
              : status == 409
                  ? ErrorCatalog.staleVersion
                  : ErrorCatalog.serviceUnavailable,
      message:
          'FastAPI endpoint unreachable or failed (${e.message ?? 'Network error'}). Fail-closed mode active.',
      httpStatus: status,
    );
  }
}
