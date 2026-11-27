import 'package:intl/intl.dart';

/// Standard HTTP API Error Catalog (§6.1–6.2 of Integration Contracts).
class ErrorCatalog {
  ErrorCatalog._();

  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String authenticationFailed = 'AUTHENTICATION_FAILED';
  static const String authenticationRequired = 'AUTHENTICATION_REQUIRED';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String sessionExpired = 'SESSION_EXPIRED';
  static const String forbidden = 'FORBIDDEN';
  static const String accessDenied = 'ACCESS_DENIED';
  static const String validationError = 'VALIDATION_ERROR';
  static const String validationFailed = 'VALIDATION_FAILED';
  static const String notFound = 'NOT_FOUND';
  static const String resourceNotFound = 'RESOURCE_NOT_FOUND';
  static const String methodNotAllowed = 'METHOD_NOT_ALLOWED';
  static const String registrationNotFound = 'REGISTRATION_NOT_FOUND';
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

  // Canonical Phase 4 account / auth codes (openapi.yaml 1.0.0-draft)
  static const String currentPasswordInvalid = 'CURRENT_PASSWORD_INVALID';
  static const String passwordPolicyRejected = 'PASSWORD_POLICY_REJECTED';
  static const String passwordChangeConflict = 'PASSWORD_CHANGE_CONFLICT';
  static const String passwordChangeLimited = 'PASSWORD_CHANGE_LIMITED';
  static const String passwordResetRejected = 'PASSWORD_RESET_REJECTED';
  static const String passwordResetLimited = 'PASSWORD_RESET_LIMITED';
  static const String activationRejected = 'ACTIVATION_REJECTED';
  static const String registrationInvalid = 'REGISTRATION_INVALID';
  static const String reclaimInvalid = 'RECLAIM_INVALID';
  static const String idempotencyKeyInvalid = 'IDEMPOTENCY_KEY_INVALID';
  static const String registrationConflict = 'REGISTRATION_CONFLICT';
  static const String idempotencyConflict = 'IDEMPOTENCY_CONFLICT';
  static const String reissueNotAllowed = 'REISSUE_NOT_ALLOWED';
  static const String recoveryNotAllowed = 'RECOVERY_NOT_ALLOWED';
  static const String deliveryInProgress = 'DELIVERY_IN_PROGRESS';
  static const String reissueExhausted = 'REISSUE_EXHAUSTED';
  static const String reclaimNotEligible = 'RECLAIM_NOT_ELIGIBLE';
  static const String reclaimLimitReached = 'RECLAIM_LIMIT_REACHED';
  static const String reissueLimited = 'REISSUE_LIMITED';
  static const String reclaimLimited = 'RECLAIM_LIMITED';

  /// Default error code mapping for HTTP status codes when the response body
  /// does not include an explicit `error.code`.
  static String defaultCodeForHttpStatus(int status) {
    switch (status) {
      case 401:
        return authenticationRequired;
      case 403:
        return accessDenied;
      case 404:
        return resourceNotFound;
      case 405:
        return methodNotAllowed;
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
    'UNMATCHED_PLATE',
    'LOT_B5_OVERFLOW_EXIT',
    'GUEST_PLATE_MISMATCH',
  };

  static bool isHardSecurityDenial(String reasonCode) =>
      hardSecurityDenialReasons.contains(reasonCode.toUpperCase());

  static bool isReviewableUncertainty(String reasonCode) =>
      reviewableUncertaintyReasons.contains(reasonCode.toUpperCase());
}

/// Structured Phase 4 field-level error detail (`openapi.yaml` component `ErrorDetail`).
class ErrorDetail {
  final String? field;
  final String code;
  final String message;

  const ErrorDetail({
    required this.field,
    required this.code,
    required this.message,
  });

  factory ErrorDetail.fromJson(Map<String, dynamic> json) {
    return ErrorDetail(
      field: json['field']?.toString(),
      code: json['code']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'field': field,
        'code': code,
        'message': message,
      };
}

class ApiError {
  final String code;
  final String message;
  final int httpStatus;
  final Map<String, dynamic>? details;
  final List<ErrorDetail> errorDetails;
  final int? retryAfterSeconds;

  const ApiError({
    required this.code,
    required this.message,
    this.httpStatus = 400,
    this.details,
    this.errorDetails = const [],
    this.retryAfterSeconds,
  });

  /// Extracts field-level error messages from `details` or `errorDetails`.
  Map<String, String> get fieldErrors {
    final map = <String, String>{};
    for (final d in errorDetails) {
      if (d.field != null && d.field!.isNotEmpty) {
        map[d.field!] = d.message;
      }
    }
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

  factory ApiError.fromJson(
    Map<String, dynamic> json, {
    int httpStatus = 400,
    int? retryAfterSeconds,
  }) {
    final status = (json['http_status'] as num?)?.toInt() ?? httpStatus;
    final rawDetails = json['details'];
    final Map<String, dynamic>? legacyDetails =
        rawDetails is Map<String, dynamic> ? rawDetails : null;
    final List<ErrorDetail> parsedList = rawDetails is List<dynamic>
        ? rawDetails
            .whereType<Map<String, dynamic>>()
            .map(ErrorDetail.fromJson)
            .toList()
        : const <ErrorDetail>[];
    return ApiError(
      code: json['code']?.toString() ??
          ErrorCatalog.defaultCodeForHttpStatus(status),
      message: json['message']?.toString() ?? 'An unexpected error occurred.',
      httpStatus: status,
      details: legacyDetails,
      errorDetails: parsedList,
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'http_status': httpStatus,
        if (errorDetails.isNotEmpty)
          'details': errorDetails.map((e) => e.toJson()).toList()
        else if (details != null)
          'details': details,
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
  final String contractVersion;
  final bool idempotentReplay;
  final String? nextCursor;
  final int? totalCount;

  const ApiMeta({
    required this.requestId,
    required this.timestampUtc,
    this.contractVersion = '1.0.0',
    this.idempotentReplay = false,
    this.nextCursor,
    this.totalCount,
  });

  factory ApiMeta.fromJson(Map<String, dynamic>? json, {String? headerRequestId}) {
    if (json == null) {
      return ApiMeta(
        requestId: headerRequestId ?? 'req-local-0000',
        timestampUtc: DateTime.now().toUtc(),
      );
    }
    return ApiMeta(
      requestId:
          json['request_id']?.toString() ?? headerRequestId ?? 'req-local-0000',
      timestampUtc: DateTime.tryParse(json['timestamp']?.toString() ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      contractVersion: json['contract_version']?.toString() ?? '1.0.0',
      idempotentReplay: json['idempotent_replay'] == true,
      nextCursor: json['next_cursor']?.toString(),
      totalCount: (json['total_count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'timestamp': ManilaTime.toUtcIso(timestampUtc),
        'contract_version': contractVersion,
        'idempotent_replay': idempotentReplay,
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
