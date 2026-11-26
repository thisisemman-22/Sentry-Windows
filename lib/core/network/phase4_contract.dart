import 'dart:convert';
import 'api_envelope.dart';

/// Raised when an API payload violates the canonical Phase 4 OpenAPI 3.1.0 contract
/// (`additionalProperties: false`, missing required keys, invalid enum/const,
/// bad `contract_version`, or malformed envelope shape).
class ContractViolation implements Exception {
  final String message;

  const ContractViolation(this.message);

  @override
  String toString() => 'ContractViolation: $message';
}

final RegExp _canonicalUuidRegex = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final RegExp _nilUuidRegex = RegExp(r'^0{8}-0{4}-0{4}-0{4}-0{12}$');
final RegExp _otpCodeRegex = RegExp(r'^[0-9]{6}$');
final RegExp _attestationRefRegex = RegExp(r'^[!-~](?:[ -~]{0,62}[!-~])?$');

bool isValidCanonicalUuid(String value) => _canonicalUuidRegex.hasMatch(value);

bool isValidIdempotencyKey(String value) =>
    _canonicalUuidRegex.hasMatch(value) && !_nilUuidRegex.hasMatch(value);

bool isValidOtpCode(String value) => _otpCodeRegex.hasMatch(value);

bool isValidAttestationReference(String value) =>
    value.isNotEmpty &&
    value.length <= 64 &&
    _attestationRefRegex.hasMatch(value);

/// Enforces server password policy without trimming or normalizing whitespace:
/// - **12 to 1024 Unicode code points** (`runes.length`)
/// - **At most 4096 UTF-8 bytes**
/// - **No composition rules**
String? validatePasswordPolicy(String password) {
  final codePoints = password.runes.length;
  if (codePoints < 12) {
    return 'Password must be at least 12 characters long (spaces count).';
  }
  if (codePoints > 1024) {
    return 'Password must be at most 1024 characters long.';
  }
  final utf8Bytes = utf8.encode(password).length;
  if (utf8Bytes > 4096) {
    return 'Password must be at most 4096 UTF-8 bytes.';
  }
  return null;
}

void assertExactKeys(
  Map<String, dynamic> map, {
  required Set<String> requiredKeys,
  Set<String> optionalKeys = const {},
  required String schemaName,
}) {
  for (final req in requiredKeys) {
    if (!map.containsKey(req)) {
      throw ContractViolation(
        '$schemaName missing required field "$req".',
      );
    }
  }
  final allowed = {...requiredKeys, ...optionalKeys};
  for (final key in map.keys) {
    if (!allowed.contains(key)) {
      throw ContractViolation(
        '$schemaName contains unknown field "$key" (additionalProperties: false).',
      );
    }
  }
}

Map<String, dynamic> requireJsonMap(Object? raw, String schemaName) {
  if (raw is! Map<String, dynamic>) {
    throw ContractViolation('$schemaName must be a JSON object.');
  }
  return raw;
}

String requireString(Map<String, dynamic> json, String key, String schemaName) {
  final val = json[key];
  if (val is! String) {
    throw ContractViolation('$schemaName.$key must be a string.');
  }
  return val;
}

String? requireNullableString(
  Map<String, dynamic> json,
  String key,
  String schemaName,
) {
  final val = json[key];
  if (val != null && val is! String) {
    throw ContractViolation('$schemaName.$key must be a string or null.');
  }
  return val as String?;
}

bool requireBool(Map<String, dynamic> json, String key, String schemaName) {
  final val = json[key];
  if (val is! bool) {
    throw ContractViolation('$schemaName.$key must be a boolean.');
  }
  return val;
}

String requireUuid(Map<String, dynamic> json, String key, String schemaName) {
  final val = requireString(json, key, schemaName);
  if (!isValidCanonicalUuid(val)) {
    throw ContractViolation('$schemaName.$key must be a valid UUID.');
  }
  return val;
}

DateTime parseStrictUtcDateTime(Object? raw, String fieldPath) {
  if (raw is! String || raw.trim().isEmpty) {
    throw ContractViolation('$fieldPath must be an RFC 3339 date-time string.');
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw ContractViolation('$fieldPath is not a valid date-time: "$raw".');
  }
  return parsed.toUtc();
}

/// Canonical Phase 4 response `meta` object (`openapi.yaml` component `Meta`).
class Phase4Meta {
  final String requestId;
  final DateTime timestampUtc;
  final String contractVersion;
  final bool idempotentReplay;

  const Phase4Meta({
    required this.requestId,
    required this.timestampUtc,
    required this.contractVersion,
    required this.idempotentReplay,
  });

  factory Phase4Meta.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'Meta');
    assertExactKeys(
      map,
      requiredKeys: const {
        'request_id',
        'timestamp',
        'contract_version',
        'idempotent_replay',
      },
      schemaName: 'Meta',
    );
    final requestId = requireUuid(map, 'request_id', 'Meta');
    final timestamp = parseStrictUtcDateTime(map['timestamp'], 'Meta.timestamp');
    final version = requireString(map, 'contract_version', 'Meta');
    if (version != '1.0.0') {
      throw ContractViolation(
        'Meta.contract_version must equal "1.0.0", got "$version".',
      );
    }
    final replay = requireBool(map, 'idempotent_replay', 'Meta');
    return Phase4Meta(
      requestId: requestId,
      timestampUtc: timestamp,
      contractVersion: version,
      idempotentReplay: replay,
    );
  }

  ApiMeta toApiMeta() => ApiMeta(
        requestId: requestId,
        timestampUtc: timestampUtc,
        contractVersion: contractVersion,
        idempotentReplay: idempotentReplay,
      );
}

ErrorDetail parseStrictErrorDetail(Object? raw) {
  final map = requireJsonMap(raw, 'ErrorDetail');
  assertExactKeys(
    map,
    requiredKeys: const {'field', 'code', 'message'},
    schemaName: 'ErrorDetail',
  );
  return ErrorDetail(
    field: requireNullableString(map, 'field', 'ErrorDetail'),
    code: requireString(map, 'code', 'ErrorDetail'),
    message: requireString(map, 'message', 'ErrorDetail'),
  );
}

ApiError parseStrictApiError(
  Object? raw, {
  required int httpStatus,
  int? retryAfterSeconds,
}) {
  final map = requireJsonMap(raw, 'ApiError');
  assertExactKeys(
    map,
    requiredKeys: const {'code', 'message', 'details'},
    schemaName: 'ApiError',
  );
  final code = requireString(map, 'code', 'ApiError');
  final message = requireString(map, 'message', 'ApiError');
  final rawDetails = map['details'];
  if (rawDetails is! List<dynamic>) {
    throw const ContractViolation('ApiError.details must be a JSON array.');
  }
  final parsedDetails = rawDetails.map(parseStrictErrorDetail).toList();
  return ApiError(
    code: code,
    message: message,
    httpStatus: httpStatus,
    errorDetails: parsedDetails,
    retryAfterSeconds: retryAfterSeconds,
  );
}

/// Canonical Phase 4 `{ok, data, error, meta}` envelope parser enforcing
/// `additionalProperties: false`, required `meta`, `contract_version: "1.0.0"`,
/// `ok=true` <=> `error==null`, and `ok=false` <=> `data==null`.
class Phase4Envelope<T> {
  final bool ok;
  final T? data;
  final ApiError? error;
  final Phase4Meta meta;

  const Phase4Envelope({
    required this.ok,
    this.data,
    this.error,
    required this.meta,
  });

  static Phase4Envelope<T> parse<T>(
    Object? rawJson,
    T Function(Object? data) parseData, {
    bool expectNullData = false,
    int httpStatus = 200,
    int? retryAfterSeconds,
  }) {
    final map = requireJsonMap(rawJson, 'Envelope');
    assertExactKeys(
      map,
      requiredKeys: const {'ok', 'data', 'error', 'meta'},
      schemaName: 'Envelope',
    );
    final ok = requireBool(map, 'ok', 'Envelope');
    final meta = Phase4Meta.fromStrictJson(map['meta']);
    final rawData = map['data'];
    final rawError = map['error'];

    if (ok) {
      if (rawError != null) {
        throw const ContractViolation('Envelope with ok=true must have error=null.');
      }
      if (expectNullData) {
        if (rawData != null) {
          throw const ContractViolation(
            'Envelope expecting null data received non-null data.',
          );
        }
        return Phase4Envelope<T>(
          ok: true,
          data: parseData(null),
          meta: meta,
        );
      }
      if (rawData == null) {
        throw const ContractViolation('Envelope with ok=true missing non-null data.');
      }
      return Phase4Envelope<T>(
        ok: true,
        data: parseData(rawData),
        meta: meta,
      );
    } else {
      if (rawData != null) {
        throw const ContractViolation('Envelope with ok=false must have data=null.');
      }
      if (rawError == null) {
        throw const ContractViolation('Envelope with ok=false must have error object.');
      }
      final err = parseStrictApiError(
        rawError,
        httpStatus: httpStatus,
        retryAfterSeconds: retryAfterSeconds,
      );
      return Phase4Envelope<T>(
        ok: false,
        error: err,
        meta: meta,
      );
    }
  }

  ApiEnvelope<T> toApiEnvelope() => ApiEnvelope<T>(
        ok: ok,
        data: data,
        error: error,
        meta: meta.toApiMeta(),
      );
}

/// Typed failure hierarchy strictly keyed on `error.code` (NEVER reads `error.message`).
sealed class Phase4ApiFailure implements Exception {
  final int httpStatus;
  final String code;
  final String serverMessage;
  final String requestId;
  final int? retryAfterSeconds;

  const Phase4ApiFailure({
    required this.httpStatus,
    required this.code,
    required this.serverMessage,
    required this.requestId,
    this.retryAfterSeconds,
  });

  /// Safe, user-facing guidance derived from the contract `error.code`.
  String get userDisplayMessage;

  factory Phase4ApiFailure.fromError(
    ApiError error, {
    required String requestId,
  }) {
    final s = error.httpStatus;
    final c = error.code;
    final m = error.message;
    final r = error.retryAfterSeconds;

    switch (c) {
      case ErrorCatalog.authenticationFailed:
        return AuthenticationFailedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.authenticationRequired:
      case ErrorCatalog.unauthorized:
      case ErrorCatalog.sessionExpired:
        return AuthenticationRequiredFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.accessDenied:
      case ErrorCatalog.forbidden:
        return AccessDeniedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.validationError:
      case ErrorCatalog.validationFailed:
        return ValidationErrorFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.serviceUnavailable:
        return ServiceUnavailableFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.currentPasswordInvalid:
        return CurrentPasswordInvalidFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.passwordPolicyRejected:
        return PasswordPolicyRejectedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.passwordChangeConflict:
        return PasswordChangeConflictFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.passwordChangeLimited:
        return PasswordChangeLimitedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId, retryAfterSeconds: r ?? 60);
      case ErrorCatalog.passwordResetRejected:
        return PasswordResetRejectedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.passwordResetLimited:
        return PasswordResetLimitedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId, retryAfterSeconds: r ?? 60);
      case ErrorCatalog.activationRejected:
        return ActivationRejectedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.registrationInvalid:
        return RegistrationInvalidFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.reclaimInvalid:
        return ReclaimInvalidFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.idempotencyKeyInvalid:
        return IdempotencyKeyInvalidFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.registrationNotFound:
        return RegistrationNotFoundFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.registrationConflict:
        return RegistrationConflictFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.idempotencyConflict:
        return IdempotencyConflictFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.reissueNotAllowed:
        return ReissueNotAllowedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.recoveryNotAllowed:
        return RecoveryNotAllowedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.deliveryInProgress:
        return DeliveryInProgressFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.reissueExhausted:
        return ReissueExhaustedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.reclaimNotEligible:
        return ReclaimNotEligibleFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.reclaimLimitReached:
        return ReclaimLimitReachedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.reissueLimited:
        return ReissueLimitedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId, retryAfterSeconds: r ?? 60);
      case ErrorCatalog.reclaimLimited:
        return ReclaimLimitedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId, retryAfterSeconds: r ?? 60);
      case ErrorCatalog.resourceNotFound:
      case ErrorCatalog.notFound:
        return ResourceNotFoundFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.methodNotAllowed:
        return MethodNotAllowedFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      case ErrorCatalog.internalError:
        return InternalErrorFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId);
      default:
        return UnexpectedResponseFailure(httpStatus: s, code: c, serverMessage: m, requestId: requestId, retryAfterSeconds: r);
    }
  }

  factory Phase4ApiFailure.fromEnvelope(
    int httpStatus,
    Object? rawJson, {
    int? retryAfterSeconds,
    String? headerRequestId,
  }) {
    try {
      final env = Phase4Envelope.parse<void>(
        rawJson,
        (_) {},
        httpStatus: httpStatus,
        retryAfterSeconds: retryAfterSeconds,
      );
      if (env.ok || env.error == null) {
        return UnexpectedResponseFailure(
          httpStatus: httpStatus,
          code: 'UNEXPECTED_RESPONSE',
          serverMessage: 'Expected error envelope for HTTP $httpStatus.',
          requestId: env.meta.requestId,
          retryAfterSeconds: retryAfterSeconds,
        );
      }
      return Phase4ApiFailure.fromError(
        env.error!,
        requestId: env.meta.requestId,
      );
    } on ContractViolation catch (e) {
      return UnexpectedResponseFailure(
        httpStatus: httpStatus,
        code: 'CONTRACT_VIOLATION',
        serverMessage: e.message,
        requestId: headerRequestId ?? 'unknown',
        retryAfterSeconds: retryAfterSeconds,
      );
    }
  }
}

final class AuthenticationFailedFailure extends Phase4ApiFailure {
  const AuthenticationFailedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Sign-in failed';
}

final class AuthenticationRequiredFailure extends Phase4ApiFailure {
  const AuthenticationRequiredFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Your session is missing or expired. Please sign in again.';
}

final class AccessDeniedFailure extends Phase4ApiFailure {
  const AccessDeniedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Not permitted or temporarily limited — try again later with the same submission (do not change the Idempotency-Key).';
}

final class ValidationErrorFailure extends Phase4ApiFailure {
  const ValidationErrorFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Request validation failed. Check field formatting and required values.';
}

final class ServiceUnavailableFailure extends Phase4ApiFailure {
  const ServiceUnavailableFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Service unavailable or commit outcome unknown. Do not automatically replay state-changing requests.';
}

final class CurrentPasswordInvalidFailure extends Phase4ApiFailure {
  const CurrentPasswordInvalidFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Current password is incorrect.';
}

final class PasswordPolicyRejectedFailure extends Phase4ApiFailure {
  const PasswordPolicyRejectedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'New password does not meet policy (12–1024 characters, <=4096 UTF-8 bytes, cannot reuse current password).';
}

final class PasswordChangeConflictFailure extends Phase4ApiFailure {
  const PasswordChangeConflictFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Credentials changed concurrently. Please sign in again.';
}

final class PasswordChangeLimitedFailure extends Phase4ApiFailure {
  const PasswordChangeLimitedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId, super.retryAfterSeconds});
  @override
  String get userDisplayMessage => 'Too many password change attempts. Wait ${retryAfterSeconds ?? 60}s before retrying.';
}

final class PasswordResetRejectedFailure extends Phase4ApiFailure {
  const PasswordResetRejectedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Reset code or grant is invalid or expired. Restart the password reset flow.';
}

final class PasswordResetLimitedFailure extends Phase4ApiFailure {
  const PasswordResetLimitedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId, super.retryAfterSeconds});
  @override
  String get userDisplayMessage => 'Password reset temporarily rate-limited. Wait ${retryAfterSeconds ?? 60}s.';
}

final class ActivationRejectedFailure extends Phase4ApiFailure {
  const ActivationRejectedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Activation code invalid or expired. Please contact an administrator.';
}

final class RegistrationInvalidFailure extends Phase4ApiFailure {
  const RegistrationInvalidFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Registration details were rejected. Review all form fields.';
}

final class ReclaimInvalidFailure extends Phase4ApiFailure {
  const ReclaimInvalidFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Reclaim details were rejected. Review all form fields.';
}

final class IdempotencyKeyInvalidFailure extends Phase4ApiFailure {
  const IdempotencyKeyInvalidFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Client error: missing or malformed Idempotency-Key header.';
}

final class RegistrationNotFoundFailure extends Phase4ApiFailure {
  const RegistrationNotFoundFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Registration ID was not found. Verify the UUID from the registration receipt.';
}

final class RegistrationConflictFailure extends Phase4ApiFailure {
  const RegistrationConflictFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Conflicts with an existing registration or active account.';
}

final class IdempotencyConflictFailure extends Phase4ApiFailure {
  const IdempotencyConflictFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'This Idempotency-Key was already used with different form data. Edit fields or start a new intent.';
}

final class ReissueNotAllowedFailure extends Phase4ApiFailure {
  const ReissueNotAllowedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Not eligible for OTP reissue (this response does not reveal the underlying registration state).';
}

final class RecoveryNotAllowedFailure extends Phase4ApiFailure {
  const RecoveryNotAllowedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Not eligible for password-setup recovery (e.g., account already active, expired, or <5m remaining).';
}

final class DeliveryInProgressFailure extends Phase4ApiFailure {
  const DeliveryInProgressFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'An activation code email delivery is currently in flight. Wait and confirm with the user.';
}

final class ReissueExhaustedFailure extends Phase4ApiFailure {
  const ReissueExhaustedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Maximum of 5 activation codes reached for this registration.';
}

final class ReclaimNotEligibleFailure extends Phase4ApiFailure {
  const ReclaimNotEligibleFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Registration is not eligible for reclaim (identity mismatch, dependency, or not expired).';
}

final class ReclaimLimitReachedFailure extends Phase4ApiFailure {
  const ReclaimLimitReachedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Maximum reclaim limit reached for this account.';
}

final class ReissueLimitedFailure extends Phase4ApiFailure {
  const ReissueLimitedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId, super.retryAfterSeconds});
  @override
  String get userDisplayMessage => 'Activation code reissue rate-limited. Wait ${retryAfterSeconds ?? 60}s.';
}

final class ReclaimLimitedFailure extends Phase4ApiFailure {
  const ReclaimLimitedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId, super.retryAfterSeconds});
  @override
  String get userDisplayMessage => 'Registration reclaim cooldown active. Wait ${retryAfterSeconds ?? 60}s.';
}

final class ResourceNotFoundFailure extends Phase4ApiFailure {
  const ResourceNotFoundFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Endpoint or resource not found ($httpStatus).';
}

final class MethodNotAllowedFailure extends Phase4ApiFailure {
  const MethodNotAllowedFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'HTTP method not allowed on this endpoint.';
}

final class InternalErrorFailure extends Phase4ApiFailure {
  const InternalErrorFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId});
  @override
  String get userDisplayMessage => 'Internal backend error. Share Request ID ($requestId) with backend support.';
}

final class UnexpectedResponseFailure extends Phase4ApiFailure {
  const UnexpectedResponseFailure({required super.httpStatus, required super.code, required super.serverMessage, required super.requestId, super.retryAfterSeconds});
  @override
  String get userDisplayMessage => 'Unexpected backend response ($code, HTTP $httpStatus).';
}
