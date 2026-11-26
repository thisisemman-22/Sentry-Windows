import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/phase4_contract.dart';
import 'dto/phase4_admin_dtos.dart';

/// Canonical Phase 4 Administrator account-management interface (`6` OpenAPI operations).
abstract interface class AdminRegistrationApi {
  Future<ApiEnvelope<RegistrationReceiptData>> registerStudentOrGuard(
    String idempotencyKey,
    RegistrationRequest body,
  );

  Future<ApiEnvelope<ReclaimReceiptData>> reclaimStudentOrGuardRegistration(
    String idempotencyKey,
    ReclaimRequest body,
  );

  Future<ApiEnvelope<EmployeeReceiptData>> registerFacultyOrStaff(
    String idempotencyKey,
    EmployeeRegistrationRequest body,
  );

  Future<ApiEnvelope<EmployeeReceiptData>> reclaimFacultyOrStaffRegistration(
    String idempotencyKey,
    EmployeeReclaimRequest body,
  );

  Future<ApiEnvelope<ReissueReceiptData>> reissueActivationCode(
    String registrationId,
  );

  Future<ApiEnvelope<GrantRecoveryReceiptData>> recoverPasswordSetup(
    String registrationId,
  );
}

/// Real HTTP implementation backed by [ApiClient] with strict Phase 4 envelope validation.
class HttpAdminRegistrationApi implements AdminRegistrationApi {
  final ApiClient apiClient;

  const HttpAdminRegistrationApi({required this.apiClient});

  ApiEnvelope<T> _invalidKey<T>() => ApiEnvelope.failure(
        code: ErrorCatalog.idempotencyKeyInvalid,
        message: 'A valid non-nil UUID v4 Idempotency-Key header is required.',
        httpStatus: 400,
      );

  ApiEnvelope<T> _invalidRegUuid<T>() => ApiEnvelope.failure(
        code: ErrorCatalog.validationError,
        message: 'registration_id must be a canonical UUID.',
        httpStatus: 422,
      );

  @override
  Future<ApiEnvelope<RegistrationReceiptData>> registerStudentOrGuard(
    String idempotencyKey,
    RegistrationRequest body,
  ) {
    if (!isValidIdempotencyKey(idempotencyKey)) {
      return Future.value(_invalidKey());
    }
    return apiClient.post<RegistrationReceiptData>(
      '/api/v1/admin/accounts/registrations',
      body: body.toJson(),
      idempotencyKey: idempotencyKey,
      includeAuth: true,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      parser: RegistrationReceiptData.fromStrictJson,
    );
  }

  @override
  Future<ApiEnvelope<ReclaimReceiptData>> reclaimStudentOrGuardRegistration(
    String idempotencyKey,
    ReclaimRequest body,
  ) {
    if (!isValidIdempotencyKey(idempotencyKey)) {
      return Future.value(_invalidKey());
    }
    return apiClient.post<ReclaimReceiptData>(
      '/api/v1/admin/accounts/registrations/reclaim',
      body: body.toJson(),
      idempotencyKey: idempotencyKey,
      includeAuth: true,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      parser: ReclaimReceiptData.fromStrictJson,
    );
  }

  @override
  Future<ApiEnvelope<EmployeeReceiptData>> registerFacultyOrStaff(
    String idempotencyKey,
    EmployeeRegistrationRequest body,
  ) {
    if (!isValidIdempotencyKey(idempotencyKey)) {
      return Future.value(_invalidKey());
    }
    return apiClient.post<EmployeeReceiptData>(
      '/api/v1/admin/accounts/registrations/employee',
      body: body.toJson(),
      idempotencyKey: idempotencyKey,
      includeAuth: true,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      parser: EmployeeReceiptData.fromStrictJson,
    );
  }

  @override
  Future<ApiEnvelope<EmployeeReceiptData>> reclaimFacultyOrStaffRegistration(
    String idempotencyKey,
    EmployeeReclaimRequest body,
  ) {
    if (!isValidIdempotencyKey(idempotencyKey)) {
      return Future.value(_invalidKey());
    }
    return apiClient.post<EmployeeReceiptData>(
      '/api/v1/admin/accounts/registrations/employee/reclaim',
      body: body.toJson(),
      idempotencyKey: idempotencyKey,
      includeAuth: true,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      parser: EmployeeReceiptData.fromStrictJson,
    );
  }

  @override
  Future<ApiEnvelope<ReissueReceiptData>> reissueActivationCode(
    String registrationId,
  ) {
    if (!isValidCanonicalUuid(registrationId.trim())) {
      return Future.value(_invalidRegUuid());
    }
    return apiClient.post<ReissueReceiptData>(
      '/api/v1/admin/accounts/registrations/${registrationId.trim()}/otp/reissue',
      body: const ReissueRequest().toJson(),
      includeAuth: true,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      parser: ReissueReceiptData.fromStrictJson,
    );
  }

  @override
  Future<ApiEnvelope<GrantRecoveryReceiptData>> recoverPasswordSetup(
    String registrationId,
  ) {
    if (!isValidCanonicalUuid(registrationId.trim())) {
      return Future.value(_invalidRegUuid());
    }
    return apiClient.post<GrantRecoveryReceiptData>(
      '/api/v1/admin/accounts/registrations/${registrationId.trim()}/password-setup/recover',
      body: const GrantRecoveryRequest().toJson(),
      includeAuth: true,
      autoIdempotencyKey: false,
      strictPhase4Envelope: true,
      parser: GrantRecoveryReceiptData.fromStrictJson,
    );
  }
}

class _StoredMockReceipt {
  final String bodyFingerprint;
  final String registrationId;
  final DateTime expiresAtUtc;
  final bool isEmployee;
  final bool isReclaim;

  const _StoredMockReceipt({
    required this.bodyFingerprint,
    required this.registrationId,
    required this.expiresAtUtc,
    required this.isEmployee,
    required this.isReclaim,
  });
}

/// Fixture-faithful in-memory mock implementation ONLY used inside Developer Test Mode.
class MockAdminRegistrationApi implements AdminRegistrationApi {
  final Uuid _uuid = const Uuid();
  final Map<String, _StoredMockReceipt> _idempotencyRecords = {};
  final Set<String> _knownRegistrationIds = {
    '40000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000004',
  };

  @override
  Future<ApiEnvelope<RegistrationReceiptData>> registerStudentOrGuard(
    String idempotencyKey,
    RegistrationRequest body,
  ) async {
    if (!isValidIdempotencyKey(idempotencyKey)) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.idempotencyKeyInvalid,
        message: 'A valid non-nil Idempotency-Key header is required.',
        httpStatus: 400,
        requestId: _uuid.v4(),
      );
    }
    final fp = 'reg:${body.role.wireValue}:${body.identifier}:${body.identityKind.wireValue}:${body.email}:${body.fullName}';
    final existing = _idempotencyRecords[idempotencyKey];
    if (existing != null) {
      if (existing.bodyFingerprint != fp) {
        return ApiEnvelope.failure(
          code: ErrorCatalog.idempotencyConflict,
          message: 'Idempotency-Key already used with different request body.',
          httpStatus: 409,
          requestId: _uuid.v4(),
        );
      }
      return ApiEnvelope<RegistrationReceiptData>(
        ok: true,
        data: RegistrationReceiptData(
          registrationId: existing.registrationId,
          registrationState: 'pending_email',
          accountActive: false,
          activationRequired: true,
          expiresAtUtc: existing.expiresAtUtc,
          activationCodeDelivery: ActivationCodeDelivery.notReported,
        ),
        meta: ApiMeta(
          requestId: _uuid.v4(),
          timestampUtc: DateTime.now().toUtc(),
          contractVersion: '1.0.0',
          idempotentReplay: true,
        ),
      );
    }

    final regId = _uuid.v4();
    final expires = DateTime.now().toUtc().add(const Duration(days: 7));
    _knownRegistrationIds.add(regId);
    _idempotencyRecords[idempotencyKey] = _StoredMockReceipt(
      bodyFingerprint: fp,
      registrationId: regId,
      expiresAtUtc: expires,
      isEmployee: false,
      isReclaim: false,
    );
    return ApiEnvelope<RegistrationReceiptData>(
      ok: true,
      data: RegistrationReceiptData(
        registrationId: regId,
        registrationState: 'pending_email',
        accountActive: false,
        activationRequired: true,
        expiresAtUtc: expires,
        activationCodeDelivery: ActivationCodeDelivery.providerAccepted,
      ),
      meta: ApiMeta(
        requestId: _uuid.v4(),
        timestampUtc: DateTime.now().toUtc(),
        contractVersion: '1.0.0',
        idempotentReplay: false,
      ),
    );
  }

  @override
  Future<ApiEnvelope<ReclaimReceiptData>> reclaimStudentOrGuardRegistration(
    String idempotencyKey,
    ReclaimRequest body,
  ) async {
    if (!isValidIdempotencyKey(idempotencyKey)) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.idempotencyKeyInvalid,
        message: 'A valid non-nil Idempotency-Key header is required.',
        httpStatus: 400,
        requestId: _uuid.v4(),
      );
    }
    final fp = 'reclaim:${body.role.wireValue}:${body.identifier}:${body.identityKind.wireValue}:${body.email}:${body.fullName}';
    final existing = _idempotencyRecords[idempotencyKey];
    if (existing != null) {
      if (existing.bodyFingerprint != fp) {
        return ApiEnvelope.failure(
          code: ErrorCatalog.idempotencyConflict,
          message: 'Idempotency-Key already used with different request body.',
          httpStatus: 409,
          requestId: _uuid.v4(),
        );
      }
      return ApiEnvelope<ReclaimReceiptData>(
        ok: true,
        data: ReclaimReceiptData(
          registrationId: existing.registrationId,
          expiresAtUtc: existing.expiresAtUtc,
          activationCodeDelivery: ActivationCodeDelivery.notReported,
        ),
        meta: ApiMeta(
          requestId: _uuid.v4(),
          timestampUtc: DateTime.now().toUtc(),
          contractVersion: '1.0.0',
          idempotentReplay: true,
        ),
      );
    }

    final regId = _uuid.v4();
    final expires = DateTime.now().toUtc().add(const Duration(days: 7));
    _knownRegistrationIds.add(regId);
    _idempotencyRecords[idempotencyKey] = _StoredMockReceipt(
      bodyFingerprint: fp,
      registrationId: regId,
      expiresAtUtc: expires,
      isEmployee: false,
      isReclaim: true,
    );
    return ApiEnvelope<ReclaimReceiptData>(
      ok: true,
      data: ReclaimReceiptData(
        registrationId: regId,
        expiresAtUtc: expires,
        activationCodeDelivery: ActivationCodeDelivery.providerAccepted,
      ),
      meta: ApiMeta(
        requestId: _uuid.v4(),
        timestampUtc: DateTime.now().toUtc(),
        contractVersion: '1.0.0',
        idempotentReplay: false,
      ),
    );
  }

  @override
  Future<ApiEnvelope<EmployeeReceiptData>> registerFacultyOrStaff(
    String idempotencyKey,
    EmployeeRegistrationRequest body,
  ) async {
    if (!isValidIdempotencyKey(idempotencyKey)) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.idempotencyKeyInvalid,
        message: 'A valid non-nil Idempotency-Key header is required.',
        httpStatus: 400,
        requestId: _uuid.v4(),
      );
    }
    final fp = 'emp:${body.role.wireValue}:${body.identifier}:${body.email}:${body.fullName}';
    final existing = _idempotencyRecords[idempotencyKey];
    if (existing != null) {
      if (existing.bodyFingerprint != fp) {
        return ApiEnvelope.failure(
          code: ErrorCatalog.idempotencyConflict,
          message: 'Idempotency-Key already used with different request body.',
          httpStatus: 409,
          requestId: _uuid.v4(),
        );
      }
      return ApiEnvelope<EmployeeReceiptData>(
        ok: true,
        data: EmployeeReceiptData(
          registrationId: existing.registrationId,
          expiresAtUtc: existing.expiresAtUtc,
          activationCodeDelivery: ActivationCodeDelivery.notReported,
        ),
        meta: ApiMeta(
          requestId: _uuid.v4(),
          timestampUtc: DateTime.now().toUtc(),
          contractVersion: '1.0.0',
          idempotentReplay: true,
        ),
      );
    }

    final regId = _uuid.v4();
    final expires = DateTime.now().toUtc().add(const Duration(days: 7));
    _knownRegistrationIds.add(regId);
    _idempotencyRecords[idempotencyKey] = _StoredMockReceipt(
      bodyFingerprint: fp,
      registrationId: regId,
      expiresAtUtc: expires,
      isEmployee: true,
      isReclaim: false,
    );
    return ApiEnvelope<EmployeeReceiptData>(
      ok: true,
      data: EmployeeReceiptData(
        registrationId: regId,
        expiresAtUtc: expires,
        activationCodeDelivery: ActivationCodeDelivery.outcomeUnknown,
      ),
      meta: ApiMeta(
        requestId: _uuid.v4(),
        timestampUtc: DateTime.now().toUtc(),
        contractVersion: '1.0.0',
        idempotentReplay: false,
      ),
    );
  }

  @override
  Future<ApiEnvelope<EmployeeReceiptData>> reclaimFacultyOrStaffRegistration(
    String idempotencyKey,
    EmployeeReclaimRequest body,
  ) async {
    if (!isValidIdempotencyKey(idempotencyKey)) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.idempotencyKeyInvalid,
        message: 'A valid non-nil Idempotency-Key header is required.',
        httpStatus: 400,
        requestId: _uuid.v4(),
      );
    }
    final fp = 'emp_reclaim:${body.role.wireValue}:${body.identifier}:${body.email}:${body.fullName}';
    final existing = _idempotencyRecords[idempotencyKey];
    if (existing != null) {
      if (existing.bodyFingerprint != fp) {
        return ApiEnvelope.failure(
          code: ErrorCatalog.idempotencyConflict,
          message: 'Idempotency-Key already used with different request body.',
          httpStatus: 409,
          requestId: _uuid.v4(),
        );
      }
      return ApiEnvelope<EmployeeReceiptData>(
        ok: true,
        data: EmployeeReceiptData(
          registrationId: existing.registrationId,
          expiresAtUtc: existing.expiresAtUtc,
          activationCodeDelivery: ActivationCodeDelivery.notReported,
        ),
        meta: ApiMeta(
          requestId: _uuid.v4(),
          timestampUtc: DateTime.now().toUtc(),
          contractVersion: '1.0.0',
          idempotentReplay: true,
        ),
      );
    }

    final regId = _uuid.v4();
    final expires = DateTime.now().toUtc().add(const Duration(days: 7));
    _knownRegistrationIds.add(regId);
    _idempotencyRecords[idempotencyKey] = _StoredMockReceipt(
      bodyFingerprint: fp,
      registrationId: regId,
      expiresAtUtc: expires,
      isEmployee: true,
      isReclaim: true,
    );
    return ApiEnvelope<EmployeeReceiptData>(
      ok: true,
      data: EmployeeReceiptData(
        registrationId: regId,
        expiresAtUtc: expires,
        activationCodeDelivery: ActivationCodeDelivery.providerAccepted,
      ),
      meta: ApiMeta(
        requestId: _uuid.v4(),
        timestampUtc: DateTime.now().toUtc(),
        contractVersion: '1.0.0',
        idempotentReplay: false,
      ),
    );
  }

  @override
  Future<ApiEnvelope<ReissueReceiptData>> reissueActivationCode(
    String registrationId,
  ) async {
    final clean = registrationId.trim();
    if (!isValidCanonicalUuid(clean)) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.validationError,
        message: 'registration_id must be a valid UUID.',
        httpStatus: 422,
        requestId: _uuid.v4(),
      );
    }
    if (!_knownRegistrationIds.contains(clean)) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.registrationNotFound,
        message: 'Registration reference not found.',
        httpStatus: 404,
        requestId: _uuid.v4(),
      );
    }
    return ApiEnvelope<ReissueReceiptData>(
      ok: true,
      data: ReissueReceiptData(
        registrationId: clean,
        activationCodeDelivery: ActivationCodeDelivery.providerAccepted,
      ),
      meta: ApiMeta(
        requestId: _uuid.v4(),
        timestampUtc: DateTime.now().toUtc(),
        contractVersion: '1.0.0',
        idempotentReplay: false,
      ),
    );
  }

  @override
  Future<ApiEnvelope<GrantRecoveryReceiptData>> recoverPasswordSetup(
    String registrationId,
  ) async {
    final clean = registrationId.trim();
    if (!isValidCanonicalUuid(clean)) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.validationError,
        message: 'registration_id must be a valid UUID.',
        httpStatus: 422,
        requestId: _uuid.v4(),
      );
    }
    if (!_knownRegistrationIds.contains(clean)) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.registrationNotFound,
        message: 'Registration reference not found.',
        httpStatus: 404,
        requestId: _uuid.v4(),
      );
    }
    return ApiEnvelope<GrantRecoveryReceiptData>(
      ok: true,
      data: GrantRecoveryReceiptData(
        registrationId: clean,
        activationCodeDelivery: ActivationCodeDelivery.providerAccepted,
      ),
      meta: ApiMeta(
        requestId: _uuid.v4(),
        timestampUtc: DateTime.now().toUtc(),
        contractVersion: '1.0.0',
        idempotentReplay: false,
      ),
    );
  }
}
