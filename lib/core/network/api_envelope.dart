import 'package:intl/intl.dart';

/// Standard HTTP API Error Catalog (§6.1–6.2 of Integration Contracts).
class ErrorCatalog {
  ErrorCatalog._();

  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String sessionExpired = 'SESSION_EXPIRED';
  static const String forbidden = 'FORBIDDEN';
  static const String accessDenied = 'ACCESS_DENIED';
  static const String validationError = 'VALIDATION_ERROR';
  static const String validationFailed = 'VALIDATION_FAILED';
  static const String notFound = 'NOT_FOUND';
  static const String staleVersion = 'STALE_VERSION';
  static const String attemptExpired = 'ATTEMPT_EXPIRED';
  static const String decisionExpired = 'DECISION_EXPIRED';
  static const String laneBusy = 'LANE_BUSY';
  static const String passageStateConflict = 'PASSAGE_STATE_CONFLICT';
  static const String databaseConflict = 'DATABASE_CONFLICT';
  static const String duplicateActiveVisit = 'DUPLICATE_ACTIVE_VISIT';
  static const String activeVisitNotFound = 'ACTIVE_VISIT_NOT_FOUND';
  static const String unknownCredential = 'UNKNOWN_CREDENTIAL';
  static const String credentialRevoked = 'CREDENTIAL_REVOKED';
  static const String identityMismatch = 'IDENTITY_MISMATCH';
  static const String hardDenialOverrideForbidden =
      'HARD_DENIAL_OVERRIDE_FORBIDDEN';
  static const String rateLimited = 'RATE_LIMITED';
  static const String internalError = 'INTERNAL_ERROR';
  static const String configurationInvalid = 'CONFIGURATION_INVALID';
  static const String serviceUnavailable = 'SERVICE_UNAVAILABLE';
  static const String implementedButGated = 'IMPLEMENTED_BUT_GATED';

  /// Default error code mapping for HTTP status codes when the response body
  /// does not include an explicit `error.code`.
  static String defaultCodeForHttpStatus(int status) {
    switch (status) {
      case 401:
        return unauthorized;
      case 403:
        return forbidden;
      case 404:
        return notFound;
      case 409:
        return databaseConflict;
      case 410:
        return attemptExpired;
      case 422:
        return validationError;
      case 429:
        return rateLimited;
      case 500:
        return internalError;
      case 503:
      default:
        return serviceUnavailable;
    }
  }

  /// Hard security denial reason codes that MUST NEVER be overridden to `allowed`
  /// via guard review (`approve` action is strictly forbidden on these).
  static const Set<String> hardSecurityDenialReasons = {
    'UNKNOWN_CREDENTIAL',
    'CREDENTIAL_REVOKED',
    'IDENTITY_MISMATCH',
    'USER_INACTIVE',
    'VEHICLE_INACTIVE',
    'ACTIVE_VISIT_NOT_FOUND',
    'DUPLICATE_ACTIVE_VISIT',
    'GUARD_DENIED',
  };

  /// Reviewable uncertainty reason codes where a guard can submit `approve`
  /// (requesting backend re-evaluation while attempt has not expired).
  static const Set<String> reviewableUncertaintyReasons = {
    'IDENTITY_UNCERTAIN',
    'NO_COMPATIBLE_SPACE',
    'OCCUPANCY_CONFLICT',
    'CONFIGURATION_INVALID',
    'AMBIGUOUS_VEHICLE',
  };

  static bool isHardSecurityDenial(String reasonCode) =>
      hardSecurityDenialReasons.contains(reasonCode.toUpperCase());

  static bool isReviewableUncertainty(String reasonCode) =>
      reviewableUncertaintyReasons.contains(reasonCode.toUpperCase());
}

class ApiError {
  final String code;
  final String message;
  final int httpStatus;
  final Map<String, dynamic>? details;

  const ApiError({
    required this.code,
    required this.message,
    this.httpStatus = 400,
    this.details,
  });

  /// Extracts field-level error messages from `details` (e.g. on `409 DATABASE_CONFLICT`
  /// or `422 VALIDATION_ERROR`). Supports `details: {'field': 'plate_number', 'message': '...'}`
  /// or `details: {'field_errors': {'plate_number': '...'}}` or `details: {'plate_number': '...'}`.
  Map<String, String> get fieldErrors {
    final map = <String, String>{};
    if (details == null) return map;
    final field = details!['field']?.toString();
    if (field != null && field.isNotEmpty) {
      map[field] = details!['reason']?.toString() ??
          details!['message']?.toString() ??
          message;
    }
    final nested = details!['field_errors'] ?? details!['fields'];
    if (nested is Map) {
      nested.forEach((k, v) {
        if (k != null && v != null) {
          map[k.toString()] = v.toString();
        }
      });
    }
    return map;
  }

  String? fieldError(String fieldName) => fieldErrors[fieldName];

  factory ApiError.fromJson(Map<String, dynamic> json, {int httpStatus = 400}) {
    final status = (json['http_status'] as num?)?.toInt() ?? httpStatus;
    return ApiError(
      code: json['code']?.toString() ??
          ErrorCatalog.defaultCodeForHttpStatus(status),
      message: json['message']?.toString() ?? 'An unexpected error occurred.',
      httpStatus: status,
      details: json['details'] is Map<String, dynamic>
          ? json['details'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'http_status': httpStatus,
        if (details != null) 'details': details,
      };
}

/// Typed failure wrapper for `DATA_SOURCE=real` fail-closed error handling.
class ApiFailure implements Exception {
  final ApiError error;
  final ApiMeta? meta;

  const ApiFailure({
    required this.error,
    this.meta,
  });

  String get code => error.code;
  String get message => error.message;
  int get httpStatus => error.httpStatus;

  @override
  String toString() =>
      'ApiFailure(httpStatus: ${error.httpStatus}, code: ${error.code}, message: ${error.message})';
}

class ApiMeta {
  final String requestId;
  final DateTime timestampUtc;
  final String? nextCursor;
  final int? totalCount;

  const ApiMeta({
    required this.requestId,
    required this.timestampUtc,
    this.nextCursor,
    this.totalCount,
  });

  factory ApiMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ApiMeta(
        requestId: 'req-local-0000',
        timestampUtc: DateTime.now().toUtc(),
      );
    }
    return ApiMeta(
      requestId: json['request_id']?.toString() ?? 'req-local-0000',
      timestampUtc: DateTime.tryParse(json['timestamp']?.toString() ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      nextCursor: json['next_cursor']?.toString(),
      totalCount: (json['total_count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'timestamp': ManilaTime.toUtcIso(timestampUtc),
        if (nextCursor != null) 'next_cursor': nextCursor,
        if (totalCount != null) 'total_count': totalCount,
      };
}

/// Standard HTTP response envelope `{ok, data, error, meta}` (§6.1).
class ApiEnvelope<T> {
  final bool ok;
  final T? data;
  final ApiError? error;
  final ApiMeta meta;

  const ApiEnvelope({
    required this.ok,
    this.data,
    this.error,
    required this.meta,
  });

  factory ApiEnvelope.success(
    T data, {
    String requestId = 'req-mock-0001',
    String? nextCursor,
    int? totalCount,
  }) {
    return ApiEnvelope<T>(
      ok: true,
      data: data,
      meta: ApiMeta(
        requestId: requestId,
        timestampUtc: DateTime.now().toUtc(),
        nextCursor: nextCursor,
        totalCount: totalCount,
      ),
    );
  }

  factory ApiEnvelope.failure({
    required String code,
    required String message,
    int httpStatus = 400,
    Map<String, dynamic>? details,
    String requestId = 'req-mock-err',
  }) {
    return ApiEnvelope<T>(
      ok: false,
      error: ApiError(
        code: code,
        message: message,
        httpStatus: httpStatus,
        details: details,
      ),
      meta: ApiMeta(
        requestId: requestId,
        timestampUtc: DateTime.now().toUtc(),
      ),
    );
  }
}

/// Timezone formatting utility enforcing invariant #6:
/// - Wire/API timestamps are strict RFC 3339 UTC ending in `Z`.
/// - All UI displays format for `Asia/Manila` (`UTC+8`) without mutating the UTC DateTime.
class ManilaTime {
  ManilaTime._();

  static const Duration manilaOffset = Duration(hours: 8);

  static DateTime toManila(DateTime utcOrLocal) {
    final utc = utcOrLocal.toUtc();
    return utc.add(manilaOffset);
  }

  static String toUtcIso(DateTime dt) {
    final u = dt.toUtc();
    return '${u.toIso8601String().replaceAll(RegExp(r'Z$'), '')}Z';
  }

  static String formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final m = toManila(dt);
    return '${DateFormat('yyyy-MM-dd HH:mm:ss').format(m)} PHT';
  }

  static String formatTimeOnly(DateTime? dt) {
    if (dt == null) return '—';
    final m = toManila(dt);
    return '${DateFormat('HH:mm:ss').format(m)} UTC+8';
  }

  static String formatShort(DateTime? dt) {
    if (dt == null) return '—';
    final m = toManila(dt);
    return DateFormat('MMM d, HH:mm:ss').format(m);
  }

  static String formatDuration(Duration d) {
    if (d.isNegative) return '00s';
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s';
    }
    if (mins > 0) {
      return '${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s';
    }
    return '${secs.toString().padLeft(2, '0')}s';
  }
}
