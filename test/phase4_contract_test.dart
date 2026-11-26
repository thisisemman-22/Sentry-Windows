import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:campus_parking_desktop/app/app.dart';
import 'package:campus_parking_desktop/app/providers.dart';
import 'package:campus_parking_desktop/app/router.dart';
import 'package:campus_parking_desktop/core/config/app_config.dart';
import 'package:campus_parking_desktop/core/config/roster_mode.dart';
import 'package:campus_parking_desktop/core/network/api_client.dart';
import 'package:campus_parking_desktop/core/network/api_envelope.dart';
import 'package:campus_parking_desktop/core/network/phase4_contract.dart';
import 'package:campus_parking_desktop/core/network/secure_session_store.dart';
import 'package:campus_parking_desktop/features/administration/data/admin_registration_api.dart';
import 'package:campus_parking_desktop/features/administration/data/dto/phase4_admin_dtos.dart';
import 'package:campus_parking_desktop/features/administration/state/register_form_controller.dart';
import 'package:campus_parking_desktop/features/authentication/data/auth_repository.dart';
import 'package:campus_parking_desktop/shared/fixtures/synthetic_fixtures.dart';
import 'package:campus_parking_desktop/shared/models/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ContractMockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _ContractMockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(
  Object body, {
  int statusCode = 200,
  Map<String, List<String>>? extraHeaders,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      if (extraHeaders != null) ...extraHeaders,
    },
  );
}

Directory _resolveFixturesDir() {
  final direct = Directory('test/fixtures/contract');
  if (direct.existsSync()) return direct;
  return Directory('campus_parking_desktop/test/fixtures/contract');
}

Map<String, dynamic> _readJsonMap(File file) {
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

const _requestRequiredKeys = <String, Set<String>>{
  'login': {'identifier', 'password'},
  'refreshTokens': {'refresh_token'},
  'logoutCurrentSession': <String>{},
  'changePassword': {'current_password', 'new_password'},
  'requestPasswordReset': {'identifier'},
  'verifyPasswordReset': {'identifier', 'otp_code'},
  'completePasswordReset': {'identifier', 'reset_grant', 'new_password'},
  'verifyActivationCode': {'identifier', 'otp_code'},
  'setActivationPassword': {'identifier', 'setup_grant', 'password'},
  'registerStudentOrGuard': {
    'role',
    'identifier',
    'identity_kind',
    'identity_issuer',
    'email',
    'full_name',
    'building_id',
  },
  'reclaimStudentOrGuardRegistration': {
    'role',
    'identifier',
    'identity_kind',
    'identity_issuer',
    'email',
    'full_name',
    'building_id',
  },
  'registerFacultyOrStaff': {
    'role',
    'identifier',
    'identity_kind',
    'identity_issuer',
    'email',
    'full_name',
    'building_id',
    'attestation',
  },
  'reclaimFacultyOrStaffRegistration': {
    'role',
    'identifier',
    'identity_kind',
    'identity_issuer',
    'email',
    'full_name',
    'building_id',
    'attestation',
  },
  'reissueActivationCode': <String>{},
  'recoverPasswordSetup': <String>{},
};

Map<String, dynamic> _buildRequestJsonForOp(
  String opId,
  Map<String, dynamic> sample,
) {
  switch (opId) {
    case 'login':
      return LoginRequest(
        identifier: sample['identifier'] as String,
        password: sample['password'] as String,
      ).toJson();
    case 'refreshTokens':
      return RefreshRequest(
        refreshToken: sample['refresh_token'] as String,
      ).toJson();
    case 'logoutCurrentSession':
      return const LogoutRequest().toJson();
    case 'changePassword':
      return PasswordChangeRequest(
        currentPassword: sample['current_password'] as String,
        newPassword: sample['new_password'] as String,
      ).toJson();
    case 'requestPasswordReset':
      return PasswordResetRequest(
        identifier: sample['identifier'] as String,
      ).toJson();
    case 'verifyPasswordReset':
      return PasswordResetVerifyRequest(
        identifier: sample['identifier'] as String,
        otpCode: sample['otp_code'] as String,
      ).toJson();
    case 'completePasswordReset':
      return PasswordResetCompleteRequest(
        identifier: sample['identifier'] as String,
        resetGrant: sample['reset_grant'] as String,
        newPassword: sample['new_password'] as String,
      ).toJson();
    case 'verifyActivationCode':
      return OtpVerificationRequest(
        identifier: sample['identifier'] as String,
        otpCode: sample['otp_code'] as String,
      ).toJson();
    case 'setActivationPassword':
      return PasswordSetupRequest(
        identifier: sample['identifier'] as String,
        setupGrant: sample['setup_grant'] as String,
        password: sample['password'] as String,
      ).toJson();
    case 'registerStudentOrGuard':
      return RegistrationRequest(
        role: RegistrationRole.parseStrict(sample['role'] as String),
        identifier: sample['identifier'] as String,
        identityKind: IdentityKind.parseStrict(sample['identity_kind'] as String),
        identityIssuer: sample['identity_issuer'] as String,
        email: sample['email'] as String,
        fullName: sample['full_name'] as String,
        buildingId: sample['building_id'] as String?,
      ).toJson();
    case 'reclaimStudentOrGuardRegistration':
      return ReclaimRequest(
        role: RegistrationRole.parseStrict(sample['role'] as String),
        identifier: sample['identifier'] as String,
        identityKind: IdentityKind.parseStrict(sample['identity_kind'] as String),
        identityIssuer: sample['identity_issuer'] as String,
        email: sample['email'] as String,
        fullName: sample['full_name'] as String,
        buildingId: sample['building_id'] as String?,
      ).toJson();
    case 'registerFacultyOrStaff':
      final att = sample['attestation'] as Map<String, dynamic>;
      return EmployeeRegistrationRequest(
        role: EmployeeRegistrationRole.parseStrict(sample['role'] as String),
        identifier: sample['identifier'] as String,
        identityKind: sample['identity_kind'] as String,
        identityIssuer: sample['identity_issuer'] as String,
        email: sample['email'] as String,
        fullName: sample['full_name'] as String,
        buildingId: sample['building_id'] as String?,
        attestation: EmployeeAttestationData(reference: att['reference'] as String),
      ).toJson();
    case 'reclaimFacultyOrStaffRegistration':
      final att = sample['attestation'] as Map<String, dynamic>;
      return EmployeeReclaimRequest(
        role: EmployeeRegistrationRole.parseStrict(sample['role'] as String),
        identifier: sample['identifier'] as String,
        identityKind: sample['identity_kind'] as String,
        identityIssuer: sample['identity_issuer'] as String,
        email: sample['email'] as String,
        fullName: sample['full_name'] as String,
        buildingId: sample['building_id'] as String?,
        attestation: EmployeeAttestationData(reference: att['reference'] as String),
      ).toJson();
    case 'reissueActivationCode':
      return const ReissueRequest().toJson();
    case 'recoverPasswordSetup':
      return const GrantRecoveryRequest().toJson();
    default:
      throw StateError('Unhandled request operationId "$opId".');
  }
}

Phase4Envelope<dynamic> _parseSuccessFixtureForOp(
  String opId,
  Map<String, dynamic> raw,
  int httpStatus,
) {
  switch (opId) {
    case 'login':
    case 'refreshTokens':
      return Phase4Envelope.parse(
        raw,
        TokenPairData.fromStrictJson,
        httpStatus: httpStatus,
      );
    case 'logoutCurrentSession':
    case 'changePassword':
    case 'completePasswordReset':
      return Phase4Envelope.parse<bool>(
        raw,
        (_) => true,
        expectNullData: true,
        httpStatus: httpStatus,
      );
    case 'getOwnProfile':
      return Phase4Envelope.parse(
        raw,
        ProfileData.fromStrictJson,
        httpStatus: httpStatus,
      );
    case 'requestPasswordReset':
      return Phase4Envelope.parse(
        raw,
        PasswordResetAcceptedData.fromStrictJson,
        httpStatus: httpStatus,
      );
    case 'verifyPasswordReset':
      return Phase4Envelope.parse(
        raw,
        PasswordResetGrantData.fromStrictJson,
        httpStatus: httpStatus,
      );
    case 'verifyActivationCode':
      return Phase4Envelope.parse(
        raw,
        SetupGrantData.fromStrictJson,
        httpStatus: httpStatus,
      );
    case 'setActivationPassword':
      return Phase4Envelope.parse(
        raw,
        ActivationData.fromStrictJson,
        httpStatus: httpStatus,
      );
    case 'registerStudentOrGuard':
      return Phase4Envelope.parse(
        raw,
        RegistrationReceiptData.fromStrictJson,
        httpStatus: httpStatus,
      );
    case 'reclaimStudentOrGuardRegistration':
      return Phase4Envelope.parse(
        raw,
        ReclaimReceiptData.fromStrictJson,
        httpStatus: httpStatus,
      );
    case 'registerFacultyOrStaff':
    case 'reclaimFacultyOrStaffRegistration':
      return Phase4Envelope.parse(
        raw,
        EmployeeReceiptData.fromStrictJson,
        httpStatus: httpStatus,
      );
    case 'reissueActivationCode':
      return Phase4Envelope.parse(
        raw,
        ReissueReceiptData.fromStrictJson,
        httpStatus: httpStatus,
      );
    case 'recoverPasswordSetup':
      return Phase4Envelope.parse(
        raw,
        GrantRecoveryReceiptData.fromStrictJson,
        httpStatus: httpStatus,
      );
    default:
      throw StateError('Unhandled success operationId "$opId".');
  }
}

void main() {
  final fixturesRoot = _resolveFixturesDir();
  final indexJson = _readJsonMap(
    File('${fixturesRoot.path}${Platform.pathSeparator}fixture_index.json'),
  );
  final indexedFixtures =
      (indexJson['fixtures'] as List<dynamic>).cast<Map<String, dynamic>>();

  group('Phase 4 OpenAPI 3.1.0 Contract & Fixture Compliance', () {
    test('fixture directory contains all 149 files (148 indexed + index)', () {
      final allFiles = fixturesRoot
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      expect(allFiles.length, 149);
      expect(indexedFixtures.length, 148);
    });

    test('all 15 request-body fixtures serialize identically (additionalProperties: false)', () {
      final reqEntries = indexedFixtures
          .where((e) => e['kind'] == 'request-body')
          .toList();
      expect(reqEntries.length, 15);

      for (final entry in reqEntries) {
        final opId = entry['operationId'] as String;
        final relPath = (entry['file'] as String).replaceAll('/', Platform.pathSeparator);
        final expected = _readJsonMap(
          File('${fixturesRoot.path}${Platform.pathSeparator}$relPath'),
        );
        final actual = _buildRequestJsonForOp(opId, expected);
        expect(actual, expected, reason: 'Request DTO mismatch for $opId');
        assertExactKeys(
          actual,
          requiredKeys: _requestRequiredKeys[opId]!,
          schemaName: '$opId.request',
        );
      }
    });

    test('all 15 invalid-request-body fixtures are rejected by strict key checks', () {
      final invalidReqEntries = indexedFixtures
          .where((e) => e['kind'] == 'invalid-request-body')
          .toList();
      expect(invalidReqEntries.length, 15);

      for (final entry in invalidReqEntries) {
        final opId = entry['operationId'] as String;
        final relPath = (entry['file'] as String).replaceAll('/', Platform.pathSeparator);
        final payload = _readJsonMap(
          File('${fixturesRoot.path}${Platform.pathSeparator}$relPath'),
        );
        expect(
          () {
            assertExactKeys(
              payload,
              requiredKeys: _requestRequiredKeys[opId]!,
              schemaName: opId,
            );
            if (payload['attestation'] is Map<String, dynamic>) {
              assertExactKeys(
                payload['attestation'] as Map<String, dynamic>,
                requiredKeys: const {'reference'},
                schemaName: '$opId.attestation',
              );
            }
          },
          throwsA(isA<ContractViolation>()),
          reason: 'Expected unknown-field rejection for $relPath',
        );
      }
    });

    test('all 16 success-response fixtures pass strict Phase4Envelope parsing', () {
      final okEntries = indexedFixtures
          .where((e) => e['kind'] == 'success-response')
          .toList();
      expect(okEntries.length, 16);

      for (final entry in okEntries) {
        final opId = entry['operationId'] as String;
        final status = entry['status'] as int;
        final relPath = (entry['file'] as String).replaceAll('/', Platform.pathSeparator);
        final raw = _readJsonMap(
          File('${fixturesRoot.path}${Platform.pathSeparator}$relPath'),
        );
        final env = _parseSuccessFixtureForOp(opId, raw, status);
        expect(env.ok, isTrue, reason: '$relPath must parse ok=true');
        expect(env.meta.contractVersion, '1.0.0');
        expect(env.meta.requestId, isNotEmpty);
      }
    });

    test('all 6 invalid-response fixtures & negative enum/const rules throw ContractViolation', () {
      final badRespEntries = indexedFixtures
          .where((e) => e['kind'] == 'invalid-response')
          .toList();
      expect(badRespEntries.length, 6);

      for (final entry in badRespEntries) {
        final relPath = (entry['file'] as String).replaceAll('/', Platform.pathSeparator);
        final raw = _readJsonMap(
          File('${fixturesRoot.path}${Platform.pathSeparator}$relPath'),
        );
        expect(
          () => Phase4Envelope.parse(
            raw,
            (data) {
              if (data is Map<String, dynamic> &&
                  data.containsKey('registration_id')) {
                return RegistrationReceiptData.fromStrictJson(data);
              }
              return data;
            },
          ),
          throwsA(isA<ContractViolation>()),
          reason: 'Expected ContractViolation for $relPath',
        );
      }

      // not_reported allowed in receipt/reclaim replay, forbidden in reissue & recovery
      final replayReceipt = RegistrationReceiptData.fromStrictJson({
        'registration_id': '40000000-0000-4000-8000-000000000001',
        'registration_state': 'pending_email',
        'account_active': false,
        'activation_required': true,
        'expires_at': '2026-11-28T02:00:00Z',
        'activation_code_delivery': 'not_reported',
      });
      expect(replayReceipt.activationCodeDelivery, ActivationCodeDelivery.notReported);

      expect(
        () => ReissueReceiptData.fromStrictJson({
          'registration_id': '40000000-0000-4000-8000-000000000001',
          'activation_code_delivery': 'not_reported',
        }),
        throwsA(isA<ContractViolation>()),
      );
      expect(
        () => GrantRecoveryReceiptData.fromStrictJson({
          'registration_id': '40000000-0000-4000-8000-000000000001',
          'activation_code_delivery': 'not_reported',
        }),
        throwsA(isA<ContractViolation>()),
      );

      // Unknown UserRole and ProfileData maxItems(20) enforcement
      expect(() => UserRole.parseStrict('contractor'), throwsA(isA<ContractViolation>()));
      expect(
        () => ProfileData.fromStrictJson({
          'id': '10000000-0000-4000-8000-000000000001',
          'display_code': 'G001',
          'full_name': 'Guard One',
          'role': 'guard',
          'building': null,
          'email': null,
          'authorized_vehicles': List.generate(
            21,
            (i) => {
              'id': '20000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
              'display_code': 'V$i',
              'vehicle_type': 'car',
              'normalized_plate': null,
            },
          ),
        }),
        throwsA(isA<ContractViolation>()),
      );
    });

    test('all 96 error-response fixtures parse strictly & dispatch strictly by error.code', () {
      final errEntries = indexedFixtures
          .where((e) => e['kind'] == 'error-response')
          .toList();
      expect(errEntries.length, 96);

      for (final entry in errEntries) {
        final status = entry['status'] as int;
        final headers = entry['headers'] as Map<String, dynamic>?;
        final retryAfter = int.tryParse(headers?['Retry-After']?.toString() ?? '');
        final relPath = (entry['file'] as String).replaceAll('/', Platform.pathSeparator);
        final raw = _readJsonMap(
          File('${fixturesRoot.path}${Platform.pathSeparator}$relPath'),
        );

        final failure = Phase4ApiFailure.fromEnvelope(
          status,
          raw,
          retryAfterSeconds: retryAfter,
        );
        expect(
          failure,
          isNot(isA<UnexpectedResponseFailure>()),
          reason: 'Specific sealed Phase4ApiFailure expected for $relPath',
        );
        expect(failure.requestId, raw['meta']['request_id']);
        expect(failure.userDisplayMessage, isNotEmpty);

        // Mutating error.message must NEVER alter failure type or user message.
        final mutated = Map<String, dynamic>.from(raw);
        final mutatedErr = Map<String, dynamic>.from(raw['error'] as Map<String, dynamic>);
        mutatedErr['message'] = 'COMPLETELY_UNRELATED_MUTATED_TEXT_XYZ';
        mutated['error'] = mutatedErr;

        final mutatedFailure = Phase4ApiFailure.fromEnvelope(
          status,
          mutated,
          retryAfterSeconds: retryAfter,
        );
        expect(mutatedFailure.runtimeType, failure.runtimeType);
        expect(mutatedFailure.userDisplayMessage, failure.userDisplayMessage);
      }
    });
  });

  group('Phase 4 Single-Flight Refresh, Retry Limits & Transport', () {
    const realConfig = AppConfig(
      appEnv: 'production',
      dataSource: DataSourceMode.real,
      initialRosterMode: RosterMode.contractSynthetic,
      apiBaseUrl: 'https://sentry.batstate-u.example',
      wsBaseUrl: 'wss://sentry.batstate-u.example/api/v1/ws/updates',
      requestTimeoutMs: 5000,
      displayTimezone: 'Asia/Manila',
    );

    test('concurrent requests past access_expires_at trigger ONE single-flight refresh with exact body', () async {
      final store = InMemorySessionStore();
      final clock = DateTime.utc(2026, 11, 21, 10, 0, 0);
      await store.saveSession(
        SessionDto(
          sessionId: 'sess-1',
          accessToken: 'expired-access-token',
          refreshToken: 'valid-refresh-token-1',
          issuedAtUtc: clock.subtract(const Duration(minutes: 20)),
          expiresAtUtc: clock.subtract(const Duration(minutes: 5)),
          refreshExpiresAtUtc: clock.add(const Duration(days: 7)),
          profile: SentryFixtures.adminOperator,
        ),
      );

      int refreshCalls = 0;
      Map<String, dynamic>? seenRefreshBody;
      final dio = Dio(BaseOptions(baseUrl: realConfig.apiBaseUrl));
      dio.httpClientAdapter = _ContractMockAdapter((options) async {
        if (options.path == '/api/v1/auth/refresh') {
          refreshCalls++;
          seenRefreshBody = options.data as Map<String, dynamic>?;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _jsonResponse({
            'ok': true,
            'data': {
              'token_type': 'bearer',
              'access_token': 'fresh-access-2',
              'access_expires_at': '2026-11-21T10:15:00Z',
              'refresh_token': 'fresh-refresh-2',
              'refresh_expires_at': '2026-11-28T10:00:00Z',
            },
            'error': null,
            'meta': {
              'request_id': '90000000-0000-4000-8000-000000000099',
              'timestamp': '2026-11-21T10:00:00Z',
              'contract_version': '1.0.0',
              'idempotent_replay': false,
            },
          });
        }
        return _jsonResponse({
          'ok': true,
          'data': {
            'id': '10000000-0000-4000-8000-000000000001',
            'display_code': 'A001',
            'full_name': 'Admin One',
            'role': 'administrator',
            'building': null,
            'email': 'admin@batstate-u.example',
            'authorized_vehicles': const [],
          },
          'error': null,
          'meta': {
            'request_id': '90000000-0000-4000-8000-000000000100',
            'timestamp': '2026-11-21T10:00:00Z',
            'contract_version': '1.0.0',
            'idempotent_replay': false,
          },
        });
      });

      final client = ApiClient(
        config: realConfig,
        sessionStore: store,
        dio: dio,
        nowUtc: () => clock,
      );
      final authRepo = AuthRepository(apiClient: client);

      final results = await Future.wait([
        authRepo.getOwnProfile(),
        authRepo.getOwnProfile(),
      ]);

      expect(refreshCalls, 1);
      expect(seenRefreshBody, {'refresh_token': 'valid-refresh-token-1'});
      expect(results[0].ok, isTrue);
      expect(results[1].ok, isTrue);
      final stored = await store.readSession();
      expect(stored?.accessToken, 'fresh-access-2');
      expect(stored?.refreshToken, 'fresh-refresh-2');
    });

    test('refresh 503 clears stored tokens immediately & zero retry grace; POST mutations never auto-replay; logout 401 never refreshes', () async {
      final store = InMemorySessionStore();
      await store.saveSession(
        SessionDto(
          sessionId: 'sess-2',
          accessToken: 'token-abc',
          refreshToken: 'refresh-abc',
          issuedAtUtc: DateTime.utc(2026, 11, 21),
          expiresAtUtc: DateTime.utc(2030, 1, 1),
          profile: SentryFixtures.adminOperator,
        ),
      );

      int refreshCalls = 0;
      int mutationCalls = 0;
      String? expiredNotice;
      final dio = Dio(BaseOptions(baseUrl: realConfig.apiBaseUrl));
      dio.httpClientAdapter = _ContractMockAdapter((options) async {
        if (options.path == '/api/v1/auth/refresh') {
          refreshCalls++;
          return _jsonResponse(
            {
              'ok': false,
              'data': null,
              'error': {
                'code': 'SERVICE_UNAVAILABLE',
                'message': 'Busy',
                'details': [],
              },
              'meta': {
                'request_id': '90000000-0000-4000-8000-000000000201',
                'timestamp': '2026-11-21T10:00:00Z',
                'contract_version': '1.0.0',
                'idempotent_replay': false,
              },
            },
            statusCode: 503,
          );
        }
        if (options.path == '/api/v1/auth/logout') {
          return _jsonResponse(
            {
              'ok': false,
              'data': null,
              'error': {
                'code': 'AUTHENTICATION_REQUIRED',
                'message': 'Auth required',
                'details': [],
              },
              'meta': {
                'request_id': '90000000-0000-4000-8000-000000000202',
                'timestamp': '2026-11-21T10:00:00Z',
                'contract_version': '1.0.0',
                'idempotent_replay': false,
              },
            },
            statusCode: 401,
          );
        }
        mutationCalls++;
        return _jsonResponse(
          {
            'ok': false,
            'data': null,
            'error': {
              'code': 'AUTHENTICATION_REQUIRED',
              'message': 'Expired',
              'details': [],
            },
            'meta': {
              'request_id': '90000000-0000-4000-8000-000000000203',
              'timestamp': '2026-11-21T10:00:00Z',
              'contract_version': '1.0.0',
              'idempotent_replay': false,
            },
          },
          statusCode: 401,
        );
      });

      final client = ApiClient(
        config: realConfig,
        sessionStore: store,
        dio: dio,
        onSessionExpired: (r) => expiredNotice = r,
      );
      final authRepo = AuthRepository(apiClient: client);
      final adminApi = HttpAdminRegistrationApi(apiClient: client);

      // Logout 401 does NOT call refresh
      final logoutRes = await authRepo.logoutCurrentSession();
      expect(logoutRes.ok, isFalse);
      expect(refreshCalls, 0);

      // POST mutation receiving 401 invokes single-flight refresh once, sees 503, clears tokens, and NEVER replays POST
      final postRes = await adminApi.registerStudentOrGuard(
        '550e8400-e29b-41d4-a716-446655440001',
        const RegistrationRequest(
          role: RegistrationRole.student,
          identifier: '22-001',
          identityKind: IdentityKind.student,
          identityIssuer: 'batstate-u.edu.ph',
          email: 's@g.batstate-u.edu.ph',
          fullName: 'Student One',
        ),
      );
      expect(postRes.ok, isFalse);
      expect(refreshCalls, 1);
      expect(mutationCalls, 1);
      expect(await store.readSession(), isNull);
      expect(expiredNotice, isNotNull);
    });
  });

  group('Phase 4 Idempotency, Password Policy, Secret Redaction & Role Guard', () {
    test('RegisterFormController reuses Idempotency-Key across 503 retry & clears attestation on 202', () async {
      final seenKeys = <String>[];
      var shouldFail503 = true;
      final fakeApi = _FakeRetryableAdminApi(
        onRegister: (key) async {
          seenKeys.add(key);
          if (shouldFail503) {
            return ApiEnvelope.failure(
              code: ErrorCatalog.serviceUnavailable,
              message: 'Service busy',
              httpStatus: 503,
              requestId: 'req-503-retry',
            );
          }
          return ApiEnvelope.success(
            EmployeeReceiptData(
              registrationId: '40000000-0000-4000-8000-000000000010',
              expiresAtUtc: DateTime.utc(2026, 11, 28),
              activationCodeDelivery: ActivationCodeDelivery.providerAccepted,
            ),
            requestId: 'req-202-ok',
          );
        },
      );

      final ctrl = RegisterFormController(readApi: () => fakeApi);
      ctrl.setFlow(AdminRegistrationFlow.registerFacultyOrStaff);
      ctrl.updateFields(
        identifier: 'EMP-900',
        identityIssuer: 'batstate-u.edu.ph',
        email: 'emp900@g.batstate-u.edu.ph',
        fullName: 'Faculty Nine',
        attestationReference: 'SECRET-ATT-REF-01',
      );

      final firstAttempt = await ctrl.submitNewIntent();
      expect(firstAttempt, isNull);
      expect(ctrl.state.canRetrySameSubmission, isTrue);
      expect(ctrl.state.pendingIdempotencyKey, isNotNull);
      expect(isValidIdempotencyKey(ctrl.state.pendingIdempotencyKey!), isTrue);

      shouldFail503 = false;
      final retryReceipt = await ctrl.retrySameSubmission();
      expect(retryReceipt, isNotNull);
      expect(seenKeys.length, 2);
      expect(seenKeys[0], seenKeys[1]);
      expect(ctrl.state.attestationReference, isEmpty);
      expect(ctrl.state.pendingIdempotencyKey, isNull);
      ctrl.dispose();
    });

    test('MockAdminRegistrationApi replays same key+body with not_reported and rejects key reuse with different body', () async {
      final mockApi = MockAdminRegistrationApi();
      const key = '550e8400-e29b-41d4-a716-446655440099';
      const req1 = RegistrationRequest(
        role: RegistrationRole.guard,
        identifier: 'G-01',
        identityKind: IdentityKind.externalGuard,
        identityIssuer: 'AGENCY-A',
        email: 'g01@example.org',
        fullName: 'Guard 01',
      );

      final first = await mockApi.registerStudentOrGuard(key, req1);
      expect(first.ok, isTrue);
      expect(first.meta.idempotentReplay, isFalse);

      final replay = await mockApi.registerStudentOrGuard(key, req1);
      expect(replay.ok, isTrue);
      expect(replay.meta.idempotentReplay, isTrue);
      expect(
        replay.data!.activationCodeDelivery,
        ActivationCodeDelivery.notReported,
      );

      const reqDifferent = RegistrationRequest(
        role: RegistrationRole.guard,
        identifier: 'G-02',
        identityKind: IdentityKind.externalGuard,
        identityIssuer: 'AGENCY-A',
        email: 'g02@example.org',
        fullName: 'Guard 02',
      );
      final conflict = await mockApi.registerStudentOrGuard(key, reqDifferent);
      expect(conflict.ok, isFalse);
      expect(conflict.error?.code, ErrorCatalog.idempotencyConflict);
      expect(conflict.error?.httpStatus, 409);
    });

    test('password policy counts Unicode code points, <=4096 UTF-8 bytes, never trims whitespace; toString() redacts secrets', () {
      expect(validatePasswordPolicy('a' * 11), isNotNull);
      expect(validatePasswordPolicy('𝄞' * 12), isNull); // 12 code points, 48 UTF-8 bytes
      expect(validatePasswordPolicy('   spaces   '), isNull); // 12 chars with outer spaces preserved
      expect(validatePasswordPolicy('𝄞' * 1025), isNotNull); // >1024 runes
      expect(validatePasswordPolicy('😀' * 1025), isNotNull); // >4096 bytes

      const rawPwd = '  super-secret-pass-with-spaces  ';
      const loginReq = LoginRequest(identifier: 'G-01', password: rawPwd);
      expect(loginReq.toJson()['password'], rawPwd);
      expect(loginReq.toString(), isNot(contains(rawPwd)));

      const changeReq = PasswordChangeRequest(
        currentPassword: 'old-secret-password',
        newPassword: 'new-secret-password',
      );
      expect(changeReq.toJson()['current_password'], 'old-secret-password');
      expect(changeReq.toJson()['new_password'], 'new-secret-password');
      expect(changeReq.toString(), isNot(contains('old-secret-password')));
      expect(changeReq.toString(), isNot(contains('new-secret-password')));

      const refreshReq = RefreshRequest(refreshToken: 'refresh-secret-xyz');
      expect(refreshReq.toString(), isNot(contains('refresh-secret-xyz')));

      const resetVerify = PasswordResetVerifyRequest(identifier: 'G', otpCode: '654321');
      expect(resetVerify.toString(), isNot(contains('654321')));

      const resetComplete = PasswordResetCompleteRequest(
        identifier: 'G',
        resetGrant: 'reset-grant-xyz',
        newPassword: 'reset-new-password',
      );
      expect(resetComplete.toString(), isNot(contains('reset-grant-xyz')));
      expect(resetComplete.toString(), isNot(contains('reset-new-password')));

      const otpReq = OtpVerificationRequest(identifier: 'G', otpCode: '112233');
      expect(otpReq.toString(), isNot(contains('112233')));

      const setupReq = PasswordSetupRequest(
        identifier: 'G',
        setupGrant: 'setup-grant-xyz',
        password: 'setup-new-password',
      );
      expect(setupReq.toString(), isNot(contains('setup-grant-xyz')));
      expect(setupReq.toString(), isNot(contains('setup-new-password')));

      const att = EmployeeAttestationData(reference: 'PRIVATE-ATT-99');
      expect(att.toString(), isNot(contains('PRIVATE-ATT-99')));

      final tokenPair = TokenPairData(
        accessToken: 'acc-secret-999',
        refreshToken: 'ref-secret-999',
        tokenType: 'bearer',
        accessExpiresAtUtc: DateTime.utc(2026, 11, 21),
        refreshExpiresAtUtc: DateTime.utc(2026, 11, 28),
      );
      expect(tokenPair.toString(), isNot(contains('acc-secret-999')));
      expect(tokenPair.toString(), isNot(contains('ref-secret-999')));
    });

    test('AuthController rejects mobile roles (student/faculty/staff) on GET /me, clears tokens, and logs out', () async {
      const cfg = AppConfig(
        appEnv: 'production',
        dataSource: DataSourceMode.real,
        initialRosterMode: RosterMode.contractSynthetic,
        apiBaseUrl: 'https://sentry.batstate-u.example',
        wsBaseUrl: 'wss://sentry.batstate-u.example/api/v1/ws/updates',
        requestTimeoutMs: 5000,
        displayTimezone: 'Asia/Manila',
      );
      for (final mobileRole in const ['student', 'faculty', 'staff']) {
        final store = InMemorySessionStore();
        int logoutCalled = 0;
        final dio = Dio(BaseOptions(baseUrl: cfg.apiBaseUrl));
        dio.httpClientAdapter = _ContractMockAdapter((options) async {
          if (options.path == '/api/v1/auth/login') {
            return _jsonResponse({
              'ok': true,
              'data': {
                'token_type': 'bearer',
                'access_token': 'temp-token',
                'access_expires_at': '2030-01-01T00:00:00Z',
                'refresh_token': 'temp-refresh',
                'refresh_expires_at': '2030-01-08T00:00:00Z',
              },
              'error': null,
              'meta': {
                'request_id': '90000000-0000-4000-8000-000000000301',
                'timestamp': '2026-11-21T10:00:00Z',
                'contract_version': '1.0.0',
                'idempotent_replay': false,
              },
            });
          }
          if (options.path == '/api/v1/me') {
            return _jsonResponse({
              'ok': true,
              'data': {
                'id': '10000000-0000-4000-8000-000000000009',
                'display_code': 'U009',
                'full_name': 'Mobile User',
                'role': mobileRole,
                'building': null,
                'email': 'u009@example.invalid',
                'authorized_vehicles': const [],
              },
              'error': null,
              'meta': {
                'request_id': '90000000-0000-4000-8000-000000000302',
                'timestamp': '2026-11-21T10:00:00Z',
                'contract_version': '1.0.0',
                'idempotent_replay': false,
              },
            });
          }
          if (options.path == '/api/v1/auth/logout') {
            logoutCalled++;
            return _jsonResponse({
              'ok': true,
              'data': null,
              'error': null,
              'meta': {
                'request_id': '90000000-0000-4000-8000-000000000303',
                'timestamp': '2026-11-21T10:00:00Z',
                'contract_version': '1.0.0',
                'idempotent_replay': false,
              },
            });
          }
          throw StateError('Unexpected path ${options.path}');
        });

        final apiClient = ApiClient(config: cfg, sessionStore: store, dio: dio);
        final authController = AuthController(
          config: cfg,
          sessionStore: store,
          authRepository: AuthRepository(apiClient: apiClient),
        );

        final ok = await authController.signIn(
          identifier: 'U009',
          password: 'valid-password-123',
        );
        expect(ok, isFalse);
        expect(
          authController.state.errorBanner,
          'Please use the SENTRY Mobile Application',
        );
        expect(logoutCalled, 1);
        expect(await store.readSession(), isNull);
      }
    });
  });

  group('Phase 4 Desktop Widget Flows & Guard Role Isolation', () {
    Future<void> pumpFrameSettle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('signed-out Guard activation and password reset flows render cleanly in real UI', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            devModeUnlockedProvider.overrideWith((_) => true),
          ],
          child: const SentryDesktopApp(),
        ),
      );
      await pumpFrameSettle(tester);

      expect(find.text('University ID'), findsOneWidget);
      expect(find.byKey(const Key('guard_activation_link')), findsOneWidget);
      expect(find.byKey(const Key('guard_password_reset_link')), findsOneWidget);

      // Step through First-Time Activation modal
      await tester.ensureVisible(find.byKey(const Key('guard_activation_link')));
      await tester.tap(find.byKey(const Key('guard_activation_link')));
      await pumpFrameSettle(tester);
      await tester.enterText(
        find.byKey(const Key('activation_identifier_field')),
        'GUARD-01',
      );
      await tester.enterText(
        find.byKey(const Key('activation_otp_field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('activation_submit_button')));
      await pumpFrameSettle(tester);

      await tester.enterText(
        find.byKey(const Key('activation_new_password_field')),
        'correct horse battery staple',
      );
      await tester.enterText(
        find.byKey(const Key('activation_confirm_password_field')),
        'correct horse battery staple',
      );
      await tester.tap(find.byKey(const Key('activation_submit_button')));
      await pumpFrameSettle(tester);
      expect(
        find.textContaining('Security Guard account activated'),
        findsOneWidget,
      );

      // Step through Forgot Password modal
      await tester.ensureVisible(find.byKey(const Key('guard_password_reset_link')));
      await tester.tap(find.byKey(const Key('guard_password_reset_link')));
      await pumpFrameSettle(tester);
      await tester.enterText(
        find.byKey(const Key('reset_identifier_field')),
        'GUARD-01',
      );
      await tester.tap(find.byKey(const Key('reset_submit_button')));
      await pumpFrameSettle(tester);
      await tester.enterText(
        find.byKey(const Key('reset_otp_field')),
        '654321',
      );
      await tester.tap(find.byKey(const Key('reset_submit_button')));
      await pumpFrameSettle(tester);
      await tester.enterText(
        find.byKey(const Key('reset_new_password_field')),
        'another strong guard passphrase',
      );
      await tester.enterText(
        find.byKey(const Key('reset_confirm_password_field')),
        'another strong guard passphrase',
      );
      await tester.tap(find.byKey(const Key('reset_submit_button')));
      await pumpFrameSettle(tester);
      expect(find.textContaining('Password reset complete'), findsOneWidget);
    });

    testWidgets('Guard profile chip exposes My profile & Change password with zero Admin UI/providers', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            devModeUnlockedProvider.overrideWith((_) => true),
          ],
          child: const SentryDesktopApp(),
        ),
      );
      await pumpFrameSettle(tester);

      await tester.tap(find.byKey(const Key('login_submit_button')));
      await pumpFrameSettle(tester);

      expect(find.byKey(const Key('nav_tab_administration')), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DesktopViewRouter)),
      );
      expect(container.exists(adminRegistrationApiProvider), isFalse);
      expect(container.exists(registerFormControllerProvider), isFalse);

      // Open operator chip menu -> My profile & Change password exist
      await tester.tap(find.text(SentryFixtures.guardOperator.fullName));
      await pumpFrameSettle(tester);
      expect(find.byKey(const Key('menu_own_profile')), findsOneWidget);
      expect(find.byKey(const Key('menu_change_password')), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu_own_profile')));
      await pumpFrameSettle(tester);
      expect(find.text('Account profile'), findsOneWidget);
      expect(find.byKey(const Key('profile_change_password_button')), findsOneWidget);
    });

    testWidgets('Admin submits Phase 4 registration -> ReceiptDialog -> ActivationHelpPage -> OTP Reissue', (tester) async {
      tester.view.physicalSize = const Size(1600, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            devModeUnlockedProvider.overrideWith((_) => true),
          ],
          child: const SentryDesktopApp(),
        ),
      );
      await pumpFrameSettle(tester);

      await tester.tap(find.byKey(const Key('persona_admin_chip')));
      await pumpFrameSettle(tester);
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await pumpFrameSettle(tester);

      await tester.tap(find.byKey(const Key('nav_tab_administration')));
      await pumpFrameSettle(tester);

      await tester.enterText(
        find.byKey(const Key('p4_identifier_field')),
        '22-04123',
      );
      await tester.enterText(
        find.byKey(const Key('p4_issuer_field')),
        'batstate-u.edu.ph',
      );
      await tester.enterText(
        find.byKey(const Key('p4_email_field')),
        'student22@g.batstate-u.edu.ph',
      );
      await tester.enterText(
        find.byKey(const Key('p4_full_name_field')),
        'Maria Santos',
      );
      await tester.ensureVisible(find.byKey(const Key('p4_submit_button')));
      await tester.tap(find.byKey(const Key('p4_submit_button')));
      await pumpFrameSettle(tester);

      expect(
        find.byKey(const Key('receipt_registration_id_text')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('receipt_open_activation_help_button')),
      );
      await pumpFrameSettle(tester);

      await tester.ensureVisible(find.byKey(const Key('reissue_activation_button')));
      await tester.tap(find.byKey(const Key('reissue_activation_button')));
      await pumpFrameSettle(tester);
      await tester.tap(
        find.byKey(const Key('activation_help_confirm_proceed_button')),
      );
      await pumpFrameSettle(tester);

      expect(find.text('OTP Activation Code Reissue'), findsNWidgets(2));
      expect(find.byKey(const Key('receipt_close_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('receipt_close_button')));
      await pumpFrameSettle(tester);
    });
  });
}

class _FakeRetryableAdminApi implements AdminRegistrationApi {
  final Future<ApiEnvelope<EmployeeReceiptData>> Function(String key) onRegister;

  _FakeRetryableAdminApi({required this.onRegister});

  @override
  Future<ApiEnvelope<EmployeeReceiptData>> registerFacultyOrStaff(
    String idempotencyKey,
    EmployeeRegistrationRequest body,
  ) =>
      onRegister(idempotencyKey);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
