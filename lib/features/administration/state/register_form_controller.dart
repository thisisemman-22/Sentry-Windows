import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/phase4_contract.dart';
import '../data/admin_registration_api.dart';
import '../data/dto/phase4_admin_dtos.dart';

enum AdminRegistrationFlow {
  registerStudentOrGuard,
  reclaimStudentOrGuard,
  registerFacultyOrStaff,
  reclaimFacultyOrStaff,
}

class RegisterFormState {
  final AdminRegistrationFlow flow;
  final RegistrationRole studentGuardRole;
  final EmployeeRegistrationRole employeeRole;
  final IdentityKind identityKind;
  final String identifier;
  final String identityIssuer;
  final String email;
  final String fullName;
  final String buildingId;
  final String attestationReference;

  /// Held across manual retries on `503` / timeout / `403 ACCESS_DENIED`.
  /// Regenerated only on a new submission intent after form edits following
  /// a definitive outcome (`202` receipt or non-retryable `400`/`409`).
  final String? pendingIdempotencyKey;
  final String? pendingBodyFingerprint;

  final bool isSubmitting;
  final bool canRetrySameSubmission;
  final String? errorCode;
  final String? errorMessage;
  final String? requestId;
  final int? retryAfterRemaining;
  final AdminRegistrationReceipt? lastReceipt;

  const RegisterFormState({
    this.flow = AdminRegistrationFlow.registerStudentOrGuard,
    this.studentGuardRole = RegistrationRole.student,
    this.employeeRole = EmployeeRegistrationRole.faculty,
    this.identityKind = IdentityKind.student,
    this.identifier = '',
    this.identityIssuer = '',
    this.email = '',
    this.fullName = '',
    this.buildingId = '',
    this.attestationReference = '',
    this.pendingIdempotencyKey,
    this.pendingBodyFingerprint,
    this.isSubmitting = false,
    this.canRetrySameSubmission = false,
    this.errorCode,
    this.errorMessage,
    this.requestId,
    this.retryAfterRemaining,
    this.lastReceipt,
  });

  bool get isEmployeeFlow =>
      flow == AdminRegistrationFlow.registerFacultyOrStaff ||
      flow == AdminRegistrationFlow.reclaimFacultyOrStaff;

  bool get isReclaimFlow =>
      flow == AdminRegistrationFlow.reclaimStudentOrGuard ||
      flow == AdminRegistrationFlow.reclaimFacultyOrStaff;

  RegisterFormState copyWith({
    AdminRegistrationFlow? flow,
    RegistrationRole? studentGuardRole,
    EmployeeRegistrationRole? employeeRole,
    IdentityKind? identityKind,
    String? identifier,
    String? identityIssuer,
    String? email,
    String? fullName,
    String? buildingId,
    String? attestationReference,
    String? pendingIdempotencyKey,
    bool clearPendingKey = false,
    String? pendingBodyFingerprint,
    bool isSubmitting = false,
    bool? canRetrySameSubmission,
    String? errorCode,
    String? errorMessage,
    String? requestId,
    bool clearError = false,
    int? retryAfterRemaining,
    bool clearRetryAfter = false,
    AdminRegistrationReceipt? lastReceipt,
    bool clearReceipt = false,
  }) {
    return RegisterFormState(
      flow: flow ?? this.flow,
      studentGuardRole: studentGuardRole ?? this.studentGuardRole,
      employeeRole: employeeRole ?? this.employeeRole,
      identityKind: identityKind ?? this.identityKind,
      identifier: identifier ?? this.identifier,
      identityIssuer: identityIssuer ?? this.identityIssuer,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      buildingId: buildingId ?? this.buildingId,
      attestationReference: attestationReference ?? this.attestationReference,
      pendingIdempotencyKey: clearPendingKey
          ? null
          : (pendingIdempotencyKey ?? this.pendingIdempotencyKey),
      pendingBodyFingerprint: clearPendingKey
          ? null
          : (pendingBodyFingerprint ?? this.pendingBodyFingerprint),
      isSubmitting: isSubmitting,
      canRetrySameSubmission:
          canRetrySameSubmission ?? this.canRetrySameSubmission,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      requestId: clearError ? null : (requestId ?? this.requestId),
      retryAfterRemaining: clearRetryAfter
          ? null
          : (retryAfterRemaining ?? this.retryAfterRemaining),
      lastReceipt: clearReceipt ? null : (lastReceipt ?? this.lastReceipt),
    );
  }
}

/// Owns Administrator registration form state + `Idempotency-Key` lifecycle.
/// Preserved across silent token refreshes and same-account re-sign-in;
/// reset only when a different account signs in or admin clicks Clear.
class RegisterFormController extends StateNotifier<RegisterFormState> {
  final AdminRegistrationApi Function() readApi;
  final Uuid _uuid;
  Timer? _cooldownTimer;

  RegisterFormController({
    required this.readApi,
    Uuid uuid = const Uuid(),
  })  : _uuid = uuid,
        super(const RegisterFormState());

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void setFlow(AdminRegistrationFlow flow) {
    final nextKind = switch (flow) {
      AdminRegistrationFlow.registerStudentOrGuard ||
      AdminRegistrationFlow.reclaimStudentOrGuard =>
        state.studentGuardRole == RegistrationRole.student
            ? IdentityKind.student
            : (state.identityKind == IdentityKind.student
                ? IdentityKind.employee
                : state.identityKind),
      AdminRegistrationFlow.registerFacultyOrStaff ||
      AdminRegistrationFlow.reclaimFacultyOrStaff =>
        IdentityKind.employee,
    };
    state = state.copyWith(
      flow: flow,
      identityKind: nextKind,
      clearPendingKey: true,
      canRetrySameSubmission: false,
      clearError: true,
      clearRetryAfter: true,
    );
  }

  void setStudentGuardRole(RegistrationRole role) {
    final allowed = IdentityKind.allowedFor(role);
    final nextKind =
        allowed.contains(state.identityKind) ? state.identityKind : allowed.first;
    state = state.copyWith(
      studentGuardRole: role,
      identityKind: nextKind,
      clearPendingKey: !state.canRetrySameSubmission,
      clearError: true,
    );
  }

  void setEmployeeRole(EmployeeRegistrationRole role) {
    state = state.copyWith(
      employeeRole: role,
      identityKind: IdentityKind.employee,
      clearPendingKey: !state.canRetrySameSubmission,
      clearError: true,
    );
  }

  void setIdentityKind(IdentityKind kind) {
    state = state.copyWith(
      identityKind: kind,
      clearPendingKey: !state.canRetrySameSubmission,
      clearError: true,
    );
  }

  void updateFields({
    String? identifier,
    String? identityIssuer,
    String? email,
    String? fullName,
    String? buildingId,
    String? attestationReference,
  }) {
    final changed = (identifier != null && identifier != state.identifier) ||
        (identityIssuer != null && identityIssuer != state.identityIssuer) ||
        (email != null && email != state.email) ||
        (fullName != null && fullName != state.fullName) ||
        (buildingId != null && buildingId != state.buildingId) ||
        (attestationReference != null &&
            attestationReference != state.attestationReference);

    // Editing fields after a definitive outcome or while retrying invalidates
    // the previous intent's Idempotency-Key so we never trigger 409 IDEMPOTENCY_CONFLICT.
    state = state.copyWith(
      identifier: identifier,
      identityIssuer: identityIssuer,
      email: email,
      fullName: fullName,
      buildingId: buildingId,
      attestationReference: attestationReference,
      clearPendingKey: changed,
      canRetrySameSubmission: changed ? false : state.canRetrySameSubmission,
      clearError: changed,
    );
  }

  void resetAll() {
    _cooldownTimer?.cancel();
    state = const RegisterFormState();
  }

  String _fingerprint() =>
      '${state.flow.name}|${state.studentGuardRole.wireValue}|${state.employeeRole.wireValue}|${state.identityKind.wireValue}|${state.identifier.trim()}|${state.identityIssuer.trim()}|${state.email.trim()}|${state.fullName.trim()}|${state.buildingId.trim()}|${state.attestationReference}';

  String? _validateInputs() {
    if (state.identifier.trim().isEmpty || state.identifier.trim().length > 128) {
      return 'University ID (identifier) must be 1–128 characters.';
    }
    if (state.identityIssuer.trim().isEmpty ||
        state.identityIssuer.trim().length > 64) {
      return 'Identity issuer must be 1–64 characters.';
    }
    if (state.email.trim().isEmpty || state.email.trim().length > 254) {
      return 'Email must be 1–254 characters.';
    }
    if (state.fullName.trim().isEmpty || state.fullName.trim().length > 160) {
      return 'Full name must be 1–160 characters.';
    }
    final bldg = state.buildingId.trim();
    if (bldg.isNotEmpty && !isValidCanonicalUuid(bldg)) {
      return 'Building ID must be blank/null or a valid canonical UUID.';
    }
    if (state.isEmployeeFlow &&
        !isValidAttestationReference(state.attestationReference)) {
      return 'Attestation reference must be 1–64 printable ASCII chars with no leading/trailing spaces.';
    }
    return null;
  }

  Future<AdminRegistrationReceipt?> submitNewIntent() async {
    final validationErr = _validateInputs();
    if (validationErr != null) {
      state = state.copyWith(
        errorCode: ErrorCatalog.validationError,
        errorMessage: validationErr,
        canRetrySameSubmission: false,
      );
      return null;
    }

    final fp = _fingerprint();
    // Create ONE Idempotency-Key for this unchanged intent if none is active.
    final key = (state.pendingIdempotencyKey != null &&
            state.pendingBodyFingerprint == fp)
        ? state.pendingIdempotencyKey!
        : _uuid.v4();

    state = state.copyWith(
      pendingIdempotencyKey: key,
      pendingBodyFingerprint: fp,
      isSubmitting: true,
      clearError: true,
      clearReceipt: true,
      clearRetryAfter: true,
    );

    return _dispatchWithKey(key);
  }

  /// Manual retry reusing the EXACT same `Idempotency-Key` and body.
  Future<AdminRegistrationReceipt?> retrySameSubmission() async {
    final key = state.pendingIdempotencyKey;
    if (key == null || state.isSubmitting) return null;
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );
    return _dispatchWithKey(key);
  }

  Future<AdminRegistrationReceipt?> _dispatchWithKey(String key) async {
    final api = readApi();
    final cleanId = state.identifier.trim();
    final cleanIssuer = state.identityIssuer.trim();
    final cleanEmail = state.email.trim();
    final cleanName = state.fullName.trim();
    final cleanBuilding =
        state.buildingId.trim().isEmpty ? null : state.buildingId.trim();

    late final ApiEnvelope<dynamic> envelope;
    AdminRegistrationReceipt? receipt;

    switch (state.flow) {
      case AdminRegistrationFlow.registerStudentOrGuard:
        final res = await api.registerStudentOrGuard(
          key,
          RegistrationRequest(
            role: state.studentGuardRole,
            identifier: cleanId,
            identityKind: state.identityKind,
            identityIssuer: cleanIssuer,
            email: cleanEmail,
            fullName: cleanName,
            buildingId: cleanBuilding,
          ),
        );
        envelope = res;
        if (res.ok && res.data != null) {
          receipt = AdminRegistrationReceipt.fromRegistration(
            res.data!,
            idempotentReplay: res.meta.idempotentReplay,
            requestId: res.meta.requestId,
          );
        }
        break;
      case AdminRegistrationFlow.reclaimStudentOrGuard:
        final res = await api.reclaimStudentOrGuardRegistration(
          key,
          ReclaimRequest(
            role: state.studentGuardRole,
            identifier: cleanId,
            identityKind: state.identityKind,
            identityIssuer: cleanIssuer,
            email: cleanEmail,
            fullName: cleanName,
            buildingId: cleanBuilding,
          ),
        );
        envelope = res;
        if (res.ok && res.data != null) {
          receipt = AdminRegistrationReceipt.fromReclaim(
            res.data!,
            idempotentReplay: res.meta.idempotentReplay,
            requestId: res.meta.requestId,
          );
        }
        break;
      case AdminRegistrationFlow.registerFacultyOrStaff:
        final res = await api.registerFacultyOrStaff(
          key,
          EmployeeRegistrationRequest(
            role: state.employeeRole,
            identifier: cleanId,
            identityIssuer: cleanIssuer,
            email: cleanEmail,
            fullName: cleanName,
            buildingId: cleanBuilding,
            attestation:
                EmployeeAttestationData(reference: state.attestationReference),
          ),
        );
        envelope = res;
        if (res.ok && res.data != null) {
          receipt = AdminRegistrationReceipt.fromEmployee(
            res.data!,
            isReclaim: false,
            idempotentReplay: res.meta.idempotentReplay,
            requestId: res.meta.requestId,
          );
        }
        break;
      case AdminRegistrationFlow.reclaimFacultyOrStaff:
        final res = await api.reclaimFacultyOrStaffRegistration(
          key,
          EmployeeReclaimRequest(
            role: state.employeeRole,
            identifier: cleanId,
            identityIssuer: cleanIssuer,
            email: cleanEmail,
            fullName: cleanName,
            buildingId: cleanBuilding,
            attestation:
                EmployeeAttestationData(reference: state.attestationReference),
          ),
        );
        envelope = res;
        if (res.ok && res.data != null) {
          receipt = AdminRegistrationReceipt.fromEmployee(
            res.data!,
            isReclaim: true,
            idempotentReplay: res.meta.idempotentReplay,
            requestId: res.meta.requestId,
          );
        }
        break;
    }

    if (receipt != null) {
      // Clear sensitive attestation reference from state immediately upon receipt.
      state = state.copyWith(
        attestationReference: '',
        isSubmitting: false,
        canRetrySameSubmission: false,
        lastReceipt: receipt,
        clearPendingKey: true,
        clearError: true,
      );
      return receipt;
    }

    final err = envelope.error;
    final reqId = envelope.meta.requestId;
    if (err == null) {
      state = state.copyWith(
        isSubmitting: false,
        canRetrySameSubmission: true,
        errorCode: ErrorCatalog.serviceUnavailable,
        errorMessage: 'Outcome unknown. Confirm before retrying manually.',
        requestId: reqId,
      );
      return null;
    }

    final failure = Phase4ApiFailure.fromError(err, requestId: reqId);
    final isRetryableSameKey = err.code == ErrorCatalog.serviceUnavailable ||
        err.code == ErrorCatalog.accessDenied ||
        err.code == ErrorCatalog.forbidden ||
        err.httpStatus == 401 ||
        err.httpStatus == 503;

    if (err.httpStatus == 429 && (err.retryAfterSeconds ?? 0) > 0) {
      _startCooldownTimer(err.retryAfterSeconds!);
    }

    state = state.copyWith(
      isSubmitting: false,
      canRetrySameSubmission: isRetryableSameKey,
      clearPendingKey: !isRetryableSameKey,
      errorCode: err.code,
      errorMessage: failure.userDisplayMessage,
      requestId: reqId,
      retryAfterRemaining: err.retryAfterSeconds,
    );
    return null;
  }

  void _startCooldownTimer(int seconds) {
    _cooldownTimer?.cancel();
    var remaining = seconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      remaining--;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(
          isSubmitting: state.isSubmitting,
          clearRetryAfter: true,
        );
      } else {
        state = state.copyWith(
          isSubmitting: state.isSubmitting,
          retryAfterRemaining: remaining,
        );
      }
    });
  }
}
