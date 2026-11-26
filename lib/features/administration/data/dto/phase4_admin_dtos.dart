import '../../../../core/network/phase4_contract.dart';

enum RegistrationRole {
  student('student', 'Student'),
  guard('guard', 'Security Guard');

  final String wireValue;
  final String label;
  const RegistrationRole(this.wireValue, this.label);

  static RegistrationRole parseStrict(String v) {
    return RegistrationRole.values.firstWhere(
      (e) => e.wireValue == v,
      orElse: () => throw ContractViolation('Unknown RegistrationRole "$v".'),
    );
  }
}

enum EmployeeRegistrationRole {
  faculty('faculty', 'Faculty'),
  staff('staff', 'Staff');

  final String wireValue;
  final String label;
  const EmployeeRegistrationRole(this.wireValue, this.label);

  static EmployeeRegistrationRole parseStrict(String v) {
    return EmployeeRegistrationRole.values.firstWhere(
      (e) => e.wireValue == v,
      orElse: () =>
          throw ContractViolation('Unknown EmployeeRegistrationRole "$v".'),
    );
  }
}

enum IdentityKind {
  student('student', 'Student ID'),
  employee('employee', 'University Employee ID'),
  externalGuard('external_guard', 'External Agency Guard ID');

  final String wireValue;
  final String label;
  const IdentityKind(this.wireValue, this.label);

  static List<IdentityKind> allowedFor(RegistrationRole role) {
    return role == RegistrationRole.student
        ? const [IdentityKind.student]
        : const [IdentityKind.employee, IdentityKind.externalGuard];
  }

  static IdentityKind parseStrict(String v) {
    return IdentityKind.values.firstWhere(
      (e) => e.wireValue == v,
      orElse: () => throw ContractViolation('Unknown IdentityKind "$v".'),
    );
  }
}

enum ActivationCodeDelivery {
  providerAccepted('provider_accepted'),
  providerRejected('provider_rejected'),
  outcomeUnknown('outcome_unknown'),
  notSent('not_sent'),
  notReported('not_reported');

  final String wireValue;
  const ActivationCodeDelivery(this.wireValue);

  /// Parses all 5 labels permitted in `RegistrationReceiptData`,
  /// `ReclaimReceiptData`, and `EmployeeReceiptData`.
  static ActivationCodeDelivery parseReceipt(String v) {
    return ActivationCodeDelivery.values.firstWhere(
      (e) => e.wireValue == v,
      orElse: () =>
          throw ContractViolation('Unknown activation_code_delivery "$v".'),
    );
  }

  /// Parses ONLY the 4 non-replay labels permitted in `ReissueReceiptData`
  /// and `GrantRecoveryReceiptData` (`not_reported` is forbidden).
  static ActivationCodeDelivery parseReissueOrRecovery(String v) {
    final parsed = parseReceipt(v);
    if (parsed == ActivationCodeDelivery.notReported) {
      throw const ContractViolation(
        'activation_code_delivery="not_reported" is invalid on reissue/recovery receipts.',
      );
    }
    return parsed;
  }

  String get displayTitle {
    switch (this) {
      case ActivationCodeDelivery.providerAccepted:
        return 'Sent to email provider';
      case ActivationCodeDelivery.providerRejected:
        return 'Email provider refused delivery';
      case ActivationCodeDelivery.outcomeUnknown:
        return 'Email delivery outcome unknown';
      case ActivationCodeDelivery.notSent:
        return 'Activation code was not sent';
      case ActivationCodeDelivery.notReported:
        return 'Idempotent replay (delivery not re-sent)';
    }
  }

  String get explanation {
    switch (this) {
      case ActivationCodeDelivery.providerAccepted:
        return 'An email provider accepted the message. Inbox delivery is NOT confirmed.';
      case ActivationCodeDelivery.providerRejected:
        return 'The provider refused the message; no code can be assumed delivered. Use OTP reissue after the 60-second cooldown.';
      case ActivationCodeDelivery.outcomeUnknown:
        return 'The provider outcome is unknown; the message may or may not arrive. Confirm with the user before reissuing (a reissue replaces any earlier code).';
      case ActivationCodeDelivery.notSent:
        return 'Nothing was sent (for example, the code expired or the send was cancelled). Wait 60 seconds and offer OTP reissue.';
      case ActivationCodeDelivery.notReported:
        return 'This is the earlier submission\'s receipt; the activation code was not re-sent or reconstructed.';
    }
  }
}

/// Request schema `EmployeeAttestationData` (`additionalProperties: false`).
/// NEVER echoed by the backend or logged in client strings.
class EmployeeAttestationData {
  final String reference;

  const EmployeeAttestationData({required this.reference});

  Map<String, dynamic> toJson() => {'reference': reference};

  @override
  String toString() => 'EmployeeAttestationData(reference: [REDACTED])';
}

/// Request schema `RegistrationRequest` (`POST /api/v1/admin/accounts/registrations`).
class RegistrationRequest {
  final RegistrationRole role;
  final String identifier;
  final IdentityKind identityKind;
  final String identityIssuer;
  final String email;
  final String fullName;
  final String? buildingId;

  const RegistrationRequest({
    required this.role,
    required this.identifier,
    required this.identityKind,
    required this.identityIssuer,
    required this.email,
    required this.fullName,
    this.buildingId,
  });

  Map<String, dynamic> toJson() => {
        'role': role.wireValue,
        'identifier': identifier,
        'identity_kind': identityKind.wireValue,
        'identity_issuer': identityIssuer,
        'email': email,
        'full_name': fullName,
        'building_id': buildingId,
      };
}

/// Request schema `ReclaimRequest` (`POST /api/v1/admin/accounts/registrations/reclaim`).
class ReclaimRequest {
  final RegistrationRole role;
  final String identifier;
  final IdentityKind identityKind;
  final String identityIssuer;
  final String email;
  final String fullName;
  final String? buildingId;

  const ReclaimRequest({
    required this.role,
    required this.identifier,
    required this.identityKind,
    required this.identityIssuer,
    required this.email,
    required this.fullName,
    this.buildingId,
  });

  Map<String, dynamic> toJson() => {
        'role': role.wireValue,
        'identifier': identifier,
        'identity_kind': identityKind.wireValue,
        'identity_issuer': identityIssuer,
        'email': email,
        'full_name': fullName,
        'building_id': buildingId,
      };
}

/// Request schema `EmployeeRegistrationRequest` (`POST /api/v1/admin/accounts/registrations/employee`).
class EmployeeRegistrationRequest {
  final EmployeeRegistrationRole role;
  final String identifier;
  final String identityKind;
  final String identityIssuer;
  final String email;
  final String fullName;
  final String? buildingId;
  final EmployeeAttestationData attestation;

  const EmployeeRegistrationRequest({
    required this.role,
    required this.identifier,
    this.identityKind = 'employee',
    required this.identityIssuer,
    required this.email,
    required this.fullName,
    this.buildingId,
    required this.attestation,
  });

  Map<String, dynamic> toJson() => {
        'role': role.wireValue,
        'identifier': identifier,
        'identity_kind': identityKind,
        'identity_issuer': identityIssuer,
        'email': email,
        'full_name': fullName,
        'building_id': buildingId,
        'attestation': attestation.toJson(),
      };
}

/// Request schema `EmployeeReclaimRequest` (`POST /api/v1/admin/accounts/registrations/employee/reclaim`).
class EmployeeReclaimRequest {
  final EmployeeRegistrationRole role;
  final String identifier;
  final String identityKind;
  final String identityIssuer;
  final String email;
  final String fullName;
  final String? buildingId;
  final EmployeeAttestationData attestation;

  const EmployeeReclaimRequest({
    required this.role,
    required this.identifier,
    this.identityKind = 'employee',
    required this.identityIssuer,
    required this.email,
    required this.fullName,
    this.buildingId,
    required this.attestation,
  });

  Map<String, dynamic> toJson() => {
        'role': role.wireValue,
        'identifier': identifier,
        'identity_kind': identityKind,
        'identity_issuer': identityIssuer,
        'email': email,
        'full_name': fullName,
        'building_id': buildingId,
        'attestation': attestation.toJson(),
      };
}

/// Request schema `ReissueRequest` (`{}`).
class ReissueRequest {
  const ReissueRequest();

  Map<String, dynamic> toJson() => const <String, dynamic>{};
}

/// Request schema `GrantRecoveryRequest` (`{}`).
class GrantRecoveryRequest {
  const GrantRecoveryRequest();

  Map<String, dynamic> toJson() => const <String, dynamic>{};
}

/// Response schema `RegistrationReceiptData` (`202` on `registerStudentOrGuard`).
class RegistrationReceiptData {
  final String registrationId;
  final String registrationState;
  final bool accountActive;
  final bool activationRequired;
  final DateTime expiresAtUtc;
  final ActivationCodeDelivery activationCodeDelivery;

  const RegistrationReceiptData({
    required this.registrationId,
    required this.registrationState,
    required this.accountActive,
    required this.activationRequired,
    required this.expiresAtUtc,
    required this.activationCodeDelivery,
  });

  factory RegistrationReceiptData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'RegistrationReceiptData');
    assertExactKeys(
      map,
      requiredKeys: const {
        'registration_id',
        'registration_state',
        'account_active',
        'activation_required',
        'expires_at',
        'activation_code_delivery',
      },
      schemaName: 'RegistrationReceiptData',
    );
    final regState =
        requireString(map, 'registration_state', 'RegistrationReceiptData');
    if (regState != 'pending_email') {
      throw ContractViolation(
        'RegistrationReceiptData.registration_state must equal "pending_email", got "$regState".',
      );
    }
    final active = requireBool(map, 'account_active', 'RegistrationReceiptData');
    if (active != false) {
      throw const ContractViolation(
        'RegistrationReceiptData.account_active must equal false.',
      );
    }
    final reqAct =
        requireBool(map, 'activation_required', 'RegistrationReceiptData');
    if (reqAct != true) {
      throw const ContractViolation(
        'RegistrationReceiptData.activation_required must equal true.',
      );
    }
    return RegistrationReceiptData(
      registrationId:
          requireUuid(map, 'registration_id', 'RegistrationReceiptData'),
      registrationState: regState,
      accountActive: active,
      activationRequired: reqAct,
      expiresAtUtc: parseStrictUtcDateTime(
        map['expires_at'],
        'RegistrationReceiptData.expires_at',
      ),
      activationCodeDelivery: ActivationCodeDelivery.parseReceipt(
        requireString(
          map,
          'activation_code_delivery',
          'RegistrationReceiptData',
        ),
      ),
    );
  }
}

/// Response schema `ReclaimReceiptData` (`202` on `reclaimStudentOrGuardRegistration`).
class ReclaimReceiptData {
  final String registrationId;
  final DateTime expiresAtUtc;
  final ActivationCodeDelivery activationCodeDelivery;

  const ReclaimReceiptData({
    required this.registrationId,
    required this.expiresAtUtc,
    required this.activationCodeDelivery,
  });

  factory ReclaimReceiptData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'ReclaimReceiptData');
    assertExactKeys(
      map,
      requiredKeys: const {
        'registration_id',
        'expires_at',
        'activation_code_delivery',
      },
      schemaName: 'ReclaimReceiptData',
    );
    return ReclaimReceiptData(
      registrationId: requireUuid(map, 'registration_id', 'ReclaimReceiptData'),
      expiresAtUtc: parseStrictUtcDateTime(
        map['expires_at'],
        'ReclaimReceiptData.expires_at',
      ),
      activationCodeDelivery: ActivationCodeDelivery.parseReceipt(
        requireString(map, 'activation_code_delivery', 'ReclaimReceiptData'),
      ),
    );
  }
}

/// Response schema `EmployeeReceiptData` (`202` on employee register/reclaim).
class EmployeeReceiptData {
  final String registrationId;
  final DateTime expiresAtUtc;
  final ActivationCodeDelivery activationCodeDelivery;

  const EmployeeReceiptData({
    required this.registrationId,
    required this.expiresAtUtc,
    required this.activationCodeDelivery,
  });

  factory EmployeeReceiptData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'EmployeeReceiptData');
    assertExactKeys(
      map,
      requiredKeys: const {
        'registration_id',
        'expires_at',
        'activation_code_delivery',
      },
      schemaName: 'EmployeeReceiptData',
    );
    return EmployeeReceiptData(
      registrationId:
          requireUuid(map, 'registration_id', 'EmployeeReceiptData'),
      expiresAtUtc: parseStrictUtcDateTime(
        map['expires_at'],
        'EmployeeReceiptData.expires_at',
      ),
      activationCodeDelivery: ActivationCodeDelivery.parseReceipt(
        requireString(map, 'activation_code_delivery', 'EmployeeReceiptData'),
      ),
    );
  }
}

/// Response schema `ReissueReceiptData` (`202` on `reissueActivationCode`).
class ReissueReceiptData {
  final String registrationId;
  final ActivationCodeDelivery activationCodeDelivery;

  const ReissueReceiptData({
    required this.registrationId,
    required this.activationCodeDelivery,
  });

  factory ReissueReceiptData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'ReissueReceiptData');
    assertExactKeys(
      map,
      requiredKeys: const {'registration_id', 'activation_code_delivery'},
      schemaName: 'ReissueReceiptData',
    );
    return ReissueReceiptData(
      registrationId:
          requireUuid(map, 'registration_id', 'ReissueReceiptData'),
      activationCodeDelivery: ActivationCodeDelivery.parseReissueOrRecovery(
        requireString(map, 'activation_code_delivery', 'ReissueReceiptData'),
      ),
    );
  }
}

/// Response schema `GrantRecoveryReceiptData` (`202` on `recoverPasswordSetup`).
class GrantRecoveryReceiptData {
  final String registrationId;
  final ActivationCodeDelivery activationCodeDelivery;

  const GrantRecoveryReceiptData({
    required this.registrationId,
    required this.activationCodeDelivery,
  });

  factory GrantRecoveryReceiptData.fromStrictJson(Object? raw) {
    final map = requireJsonMap(raw, 'GrantRecoveryReceiptData');
    assertExactKeys(
      map,
      requiredKeys: const {'registration_id', 'activation_code_delivery'},
      schemaName: 'GrantRecoveryReceiptData',
    );
    return GrantRecoveryReceiptData(
      registrationId:
          requireUuid(map, 'registration_id', 'GrantRecoveryReceiptData'),
      activationCodeDelivery: ActivationCodeDelivery.parseReissueOrRecovery(
        requireString(
          map,
          'activation_code_delivery',
          'GrantRecoveryReceiptData',
        ),
      ),
    );
  }
}

/// Normalized UI receipt shown in [ReceiptDialog] across all 6 Admin Phase 4 ops.
class AdminRegistrationReceipt {
  final String operationTitle;
  final String registrationId;
  final String? registrationStateAtCreation;
  final bool? accountActiveAtCreation;
  final bool? activationRequired;
  final DateTime? expiresAtUtc;
  final ActivationCodeDelivery activationCodeDelivery;
  final bool idempotentReplay;
  final String requestId;

  const AdminRegistrationReceipt({
    required this.operationTitle,
    required this.registrationId,
    this.registrationStateAtCreation,
    this.accountActiveAtCreation,
    this.activationRequired,
    this.expiresAtUtc,
    required this.activationCodeDelivery,
    required this.idempotentReplay,
    required this.requestId,
  });

  factory AdminRegistrationReceipt.fromRegistration(
    RegistrationReceiptData data, {
    required bool idempotentReplay,
    required String requestId,
  }) =>
      AdminRegistrationReceipt(
        operationTitle: 'Student / Guard Registration',
        registrationId: data.registrationId,
        registrationStateAtCreation: data.registrationState,
        accountActiveAtCreation: data.accountActive,
        activationRequired: data.activationRequired,
        expiresAtUtc: data.expiresAtUtc,
        activationCodeDelivery: data.activationCodeDelivery,
        idempotentReplay: idempotentReplay,
        requestId: requestId,
      );

  factory AdminRegistrationReceipt.fromReclaim(
    ReclaimReceiptData data, {
    required bool idempotentReplay,
    required String requestId,
  }) =>
      AdminRegistrationReceipt(
        operationTitle: 'Expired Student / Guard Reclaim',
        registrationId: data.registrationId,
        expiresAtUtc: data.expiresAtUtc,
        activationCodeDelivery: data.activationCodeDelivery,
        idempotentReplay: idempotentReplay,
        requestId: requestId,
      );

  factory AdminRegistrationReceipt.fromEmployee(
    EmployeeReceiptData data, {
    required bool isReclaim,
    required bool idempotentReplay,
    required String requestId,
  }) =>
      AdminRegistrationReceipt(
        operationTitle: isReclaim
            ? 'Expired Faculty / Staff Reclaim'
            : 'Faculty / Staff Registration',
        registrationId: data.registrationId,
        expiresAtUtc: data.expiresAtUtc,
        activationCodeDelivery: data.activationCodeDelivery,
        idempotentReplay: idempotentReplay,
        requestId: requestId,
      );

  factory AdminRegistrationReceipt.fromReissue(
    ReissueReceiptData data, {
    required String requestId,
  }) =>
      AdminRegistrationReceipt(
        operationTitle: 'OTP Activation Code Reissue',
        registrationId: data.registrationId,
        activationCodeDelivery: data.activationCodeDelivery,
        idempotentReplay: false,
        requestId: requestId,
      );

  factory AdminRegistrationReceipt.fromRecovery(
    GrantRecoveryReceiptData data, {
    required String requestId,
  }) =>
      AdminRegistrationReceipt(
        operationTitle: 'Password-Setup Recovery',
        registrationId: data.registrationId,
        activationCodeDelivery: data.activationCodeDelivery,
        idempotentReplay: false,
        requestId: requestId,
      );
}
