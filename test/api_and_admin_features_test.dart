import 'dart:convert';
import 'dart:typed_data';
import 'package:campus_parking_desktop/app/app.dart';
import 'package:campus_parking_desktop/app/providers.dart';
import 'package:campus_parking_desktop/core/config/app_config.dart';
import 'package:campus_parking_desktop/core/config/roster_mode.dart';
import 'package:campus_parking_desktop/core/network/api_client.dart';
import 'package:campus_parking_desktop/core/network/api_envelope.dart';
import 'package:campus_parking_desktop/core/network/secure_session_store.dart';
import 'package:campus_parking_desktop/core/network/ws_client.dart';
import 'package:campus_parking_desktop/shared/fixtures/scenario_simulator.dart';
import 'package:campus_parking_desktop/shared/fixtures/synthetic_fixtures.dart';
import 'package:campus_parking_desktop/shared/models/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Custom in-memory [HttpClientAdapter] for testing [ApiClient] interceptors,
/// `Idempotency-Key` injection, `Authorization` headers, `401` refresh retry,
/// and `401`/`403`/`409` envelope error mapping without network I/O.
class _MockHttpAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) responder;

  _MockHttpAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('Part A: ApiClient & WsRealtimeClient Contract Tests', () {
    const realConfig = AppConfig(
      appEnv: 'local',
      dataSource: DataSourceMode.real,
      initialRosterMode: RosterMode.classDemo,
      apiBaseUrl: 'http://127.0.0.1:8000',
      wsBaseUrl: 'ws://127.0.0.1:8000/api/v1/ws/updates',
      requestTimeoutMs: 5000,
      displayTimezone: 'Asia/Manila',
    );

    test(
        'ApiClient attaches Bearer token, injects Idempotency-Key on POST/PATCH/DELETE, and parses ApiEnvelope',
        () async {
      final sessionStore = InMemorySessionStore();
      final now = DateTime.now().toUtc();
      await sessionStore.saveSession(
        SessionDto(
          sessionId: 'sess-admin-01',
          accessToken: 'jwt-access-token-123',
          refreshToken: 'jwt-refresh-token-456',
          issuedAtUtc: now,
          expiresAtUtc: now.add(const Duration(hours: 8)),
          profile: SentryFixtures.adminOperator,
        ),
      );

      final capturedRequests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: realConfig.apiBaseUrl));
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        capturedRequests.add(options);
        return _jsonResponse({
          'ok': true,
          'data': {'status': 'confirmed', 'method': options.method},
          'meta': {
            'request_id': 'req-test-101',
            'timestamp': '2026-11-12T10:00:00Z',
          },
        });
      });

      final client = ApiClient(
        config: realConfig,
        sessionStore: sessionStore,
        dio: dio,
      );

      // 1. GET request -> has Authorization Bearer, NO Idempotency-Key
      final getRes = await client.get<Map<String, dynamic>>(
        '/api/v1/dashboard',
        parser: (j) => j as Map<String, dynamic>,
      );
      expect(getRes.ok, isTrue);
      expect(capturedRequests.last.headers['Authorization'],
          'Bearer jwt-access-token-123');
      expect(
          capturedRequests.last.headers.containsKey('Idempotency-Key'), isFalse);

      // 2. POST request -> has Authorization Bearer AND UUID v4 Idempotency-Key
      final postRes = await client.post<Map<String, dynamic>>(
        '/api/v1/admin/users/register',
        body: const {'full_name': 'Test Student'},
        parser: (j) => j as Map<String, dynamic>,
      );
      expect(postRes.ok, isTrue);
      expect(capturedRequests.last.headers['Authorization'],
          'Bearer jwt-access-token-123');
      expect(capturedRequests.last.headers['Idempotency-Key'], isNotEmpty);

      // 3. PATCH request -> has Idempotency-Key
      await client.patch<Map<String, dynamic>>(
        '/api/v1/participants/U001/vehicles/V001',
        body: const {'authorization_status': 'suspended'},
        parser: (j) => j as Map<String, dynamic>,
      );
      expect(capturedRequests.last.headers['Idempotency-Key'], isNotEmpty);

      // 4. DELETE request -> has Idempotency-Key
      await client.delete<Map<String, dynamic>>(
        '/api/v1/admin/users/10000000-0000-4000-8000-000000000001/face-enrollment',
        parser: (j) => j as Map<String, dynamic>,
      );
      expect(capturedRequests.last.headers['Idempotency-Key'], isNotEmpty);
    });

    test(
        'ApiClient maps 403 FORBIDDEN and 409 DATABASE_CONFLICT with field-level details accurately',
        () async {
      final sessionStore = InMemorySessionStore();
      final dio = Dio(BaseOptions(baseUrl: realConfig.apiBaseUrl));
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        if (options.path.contains('audit-logs')) {
          return _jsonResponse(
            {
              'ok': false,
              'error': {
                'code': 'FORBIDDEN',
                'message': 'Administrator role required.',
              },
              'meta': {
                'request_id': 'req-403',
                'timestamp': '2026-11-12T10:00:00Z',
              },
            },
            statusCode: 403,
          );
        }
        return _jsonResponse(
          {
            'ok': false,
            'error': {
              'code': 'DATABASE_CONFLICT',
              'message': 'Normalized plate UKQ247 already exists.',
              'details': {
                'field': 'plate_number',
                'reason': 'Normalized plate UKQ247 is already registered.',
              },
            },
            'meta': {
              'request_id': 'req-409',
              'timestamp': '2026-11-12T10:00:00Z',
            },
          },
          statusCode: 409,
        );
      });

      final client = ApiClient(
        config: realConfig,
        sessionStore: sessionStore,
        dio: dio,
      );

      final forbiddenRes = await client.get<List<dynamic>>(
        '/api/v1/admin/audit-logs',
        parser: (j) => j as List<dynamic>,
      );
      expect(forbiddenRes.ok, isFalse);
      expect(forbiddenRes.error?.httpStatus, 403);
      expect(forbiddenRes.error?.code, ErrorCatalog.forbidden);

      final conflictRes = await client.post<Map<String, dynamic>>(
        '/api/v1/admin/users/register',
        body: const {'plate_number': 'UKQ 247'},
        parser: (j) => j as Map<String, dynamic>,
      );
      expect(conflictRes.ok, isFalse);
      expect(conflictRes.error?.httpStatus, 409);
      expect(conflictRes.error?.code, ErrorCatalog.databaseConflict);
      expect(
        conflictRes.error?.fieldError('plate_number'),
        'Normalized plate UKQ247 is already registered.',
      );
    });

    test(
        'ApiClient performs single-attempt token refresh on 401 and clears session if refresh fails',
        () async {
      final sessionStore = InMemorySessionStore();
      final now = DateTime.now().toUtc();
      await sessionStore.saveSession(
        SessionDto(
          sessionId: 'sess-guard-01',
          accessToken: 'expired-token',
          refreshToken: 'valid-refresh-token',
          issuedAtUtc: now,
          expiresAtUtc: now.add(const Duration(hours: 1)),
          profile: SentryFixtures.guardOperator,
        ),
      );

      int dashboardAttempts = 0;
      int refreshCalls = 0;
      String? expiredReason;

      final dio = Dio(BaseOptions(baseUrl: realConfig.apiBaseUrl));
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        if (options.path == '/api/v1/auth/refresh') {
          refreshCalls++;
          return _jsonResponse({
            'ok': true,
            'data': {
              'access_token': 'fresh-token-999',
              'refresh_token': 'fresh-refresh-999',
            },
          });
        }
        dashboardAttempts++;
        if (dashboardAttempts == 1) {
          return _jsonResponse(
            {
              'ok': false,
              'error': {
                'code': 'UNAUTHORIZED',
                'message': 'Access token expired.',
              },
            },
            statusCode: 401,
          );
        }
        return _jsonResponse({
          'ok': true,
          'data': {'active_visits_count': 3},
        });
      });

      final client = ApiClient(
        config: realConfig,
        sessionStore: sessionStore,
        dio: dio,
        onSessionExpired: (reason) => expiredReason = reason,
      );

      final res = await client.get<Map<String, dynamic>>(
        '/api/v1/dashboard',
        parser: (j) => j as Map<String, dynamic>,
      );
      expect(res.ok, isTrue);
      expect(refreshCalls, 1);
      expect(dashboardAttempts, 2);
      expect(expiredReason, isNull);
      final updatedSession = await sessionStore.readSession();
      expect(updatedSession?.accessToken, 'fresh-token-999');

      // Now simulate refresh failure -> session must be cleared and onSessionExpired invoked
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        return _jsonResponse(
          {
            'ok': false,
            'error': {
              'code': 'UNAUTHORIZED',
              'message': 'Refresh token revoked.',
            },
          },
          statusCode: 401,
        );
      });

      final failedRes = await client.get<Map<String, dynamic>>(
        '/api/v1/dashboard',
        parser: (j) => j as Map<String, dynamic>,
      );
      expect(failedRes.ok, isFalse);
      expect(failedRes.error?.httpStatus, 401);
      expect(await sessionStore.readSession(), isNull);
      expect(expiredReason, isNotNull);
    });

    test('WsRealtimeClient strips any accidental bearer tokens from query URL',
        () {
      final sanitized = WsRealtimeClient.buildSanitizedWsUri(
        'ws://127.0.0.1:8000/api/v1/ws/updates?token=secret-jwt&access_token=abc&client=desktop',
      );
      expect(sanitized.queryParameters.containsKey('token'), isFalse);
      expect(sanitized.queryParameters.containsKey('access_token'), isFalse);
      expect(sanitized.queryParameters['client'], 'desktop');
    });
  });

  group(
      'Part B: Manual User Registration & RA 10173 Facial Enrollment Widget & Flow Tests',
      () {
    testWidgets(
        'Admin can validate Manual Registration, handle 409 duplicate plate conflict, register new user, proceed to Facial Enrollment, enforce RA 10173 consent gate, and revoke embedding',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            devModeUnlockedProvider.overrideWith((ref) => true),
          ],
          child: const SentryDesktopApp(),
        ),
      );
      await tester.pump();

      // 1. Switch to Administrator credentials on LoginScreen and sign in
      await tester.tap(find.text('Administrator'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      // 2. Navigate to View 8: Administration
      await tester.tap(find.byKey(const Key('nav_tab_administration')));
      await tester.pump();

      // Open Tab 1: Manual registration
      await tester.tap(find.byKey(const Key('admin_subtab_1')));
      await tester.pump();

      // 3. Test duplicate plate 409 DATABASE_CONFLICT (UKQ 247 belongs to V001)
      await tester.enterText(
        find.byKey(const Key('reg_full_name_field')),
        'Clarisse Mendoza',
      );
      await tester.enterText(
        find.byKey(const Key('reg_email_field')),
        'clarisse.mendoza@sentry.test',
      );
      await tester.enterText(
        find.byKey(const Key('reg_plate_number_field')),
        'ukq-247', // Should normalize to UKQ247 and trigger 409 DATABASE_CONFLICT
      );
      await tester.tap(
        find.byKey(const Key('submit_manual_registration_button')),
      );
      await tester.pump();

      // Inline field error for duplicate normalized plate must be shown
      expect(
        find.textContaining('Normalized plate UKQ247 is already registered'),
        findsWidgets,
      );

      // 4. Enter a unique plate number and submit -> 201 Created banner + Proceed to Facial Enrollment button
      await tester.enterText(
        find.byKey(const Key('reg_plate_number_field')),
        'BSU 8899',
      );
      await tester.tap(
        find.byKey(const Key('submit_manual_registration_button')),
      );
      await tester.pump();

      expect(
        find.textContaining('201 Created · Registered Clarisse Mendoza (U008)'),
        findsOneWidget,
      );
      final proceedBtn = find.byKey(
        const Key('proceed_to_facial_enrollment_button'),
      );
      expect(proceedBtn, findsOneWidget);

      // 5. Click "Proceed to Facial Enrollment →" -> switches to Facial Enrollment tab with U008 selected
      await tester.tap(proceedBtn);
      await tester.pump();

      expect(find.text('not_enrolled'), findsWidgets);

      // Verify RA 10173 consent gate: Upload, Webcam, and Submit buttons are disabled before checking consent
      final uploadBtnBefore = tester.widget<OutlinedButton>(
        find.byKey(const Key('upload_face_images_button')),
      );
      final webcamBtnBefore = tester.widget<OutlinedButton>(
        find.byKey(const Key('capture_webcam_button')),
      );
      final submitBtnBefore = tester.widget<FilledButton>(
        find.byKey(const Key('submit_face_enrollment_button')),
      );
      expect(uploadBtnBefore.onPressed, isNull);
      expect(webcamBtnBefore.onPressed, isNull);
      expect(submitBtnBefore.onPressed, isNull);

      // 6. Check the mandatory RA 10173 consent checkbox
      await tester.tap(find.byKey(const Key('ra10173_consent_checkbox')));
      await tester.pump();

      // Capture 2 frames from webcam
      await tester.tap(find.byKey(const Key('capture_webcam_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('capture_webcam_button')));
      await tester.pump();

      // Submit facial enrollment
      await tester.tap(find.byKey(const Key('submit_face_enrollment_button')));
      await tester.pump();

      expect(find.text('enrolled'), findsWidgets);
      expect(
        find.textContaining('Raw photos purged from memory'),
        findsOneWidget,
      );

      // 7. Test Revoke & Delete Embedding with confirmation dialog
      await tester.tap(find.byKey(const Key('revoke_face_enrollment_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(
        find.byKey(const Key('confirm_revoke_face_enrollment_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('not_enrolled'), findsWidgets);

      // 8. Verify newly registered user U008 also appears in View 6: Access Logs & Lookup
      await tester.tap(find.byKey(const Key('nav_tab_accessLogs')));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byKey(const Key('access_logs_subtab_2')));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byKey(const Key('lookup_user_U008')), findsOneWidget);
    });
  });

  group('Part C (Prompt 1.5 Audit): Real-Mode Fail-Closed, Hold Expiry & Backoff', () {
    test('WsRealtimeClient enforces 1s, 2s, 4s, 8s, 16s capped backoff with bounded jitter', () {
      expect(
        WsRealtimeClient.computeBackoffDelay(0, jitterMsOverride: 50),
        const Duration(seconds: 1, milliseconds: 50),
      );
      expect(
        WsRealtimeClient.computeBackoffDelay(1, jitterMsOverride: 120),
        const Duration(seconds: 2, milliseconds: 120),
      );
      expect(
        WsRealtimeClient.computeBackoffDelay(2, jitterMsOverride: 0),
        const Duration(seconds: 4),
      );
      expect(
        WsRealtimeClient.computeBackoffDelay(3, jitterMsOverride: 200),
        const Duration(seconds: 8, milliseconds: 200),
      );
      expect(
        WsRealtimeClient.computeBackoffDelay(4, jitterMsOverride: 100),
        const Duration(seconds: 16, milliseconds: 100),
      );
      // Capped at 16s for higher attempt indices
      expect(
        WsRealtimeClient.computeBackoffDelay(9, jitterMsOverride: 75),
        const Duration(seconds: 16, milliseconds: 75),
      );
    });

    test(
      'DATA_SOURCE=real starts with zero synthetic fixtures and fails closed without mock fallback',
      () {
        final wsCoord = WsInvalidationCoordinator();
        final realController = SentryScenarioController(
          initialRosterMode: RosterMode.classDemo,
          wsCoordinator: wsCoord,
          dataSourceMode: DataSourceMode.real,
        );

        // Zero synthetic mock data in real mode
        expect(realController.state.activeLaneAttempts, isEmpty);
        expect(realController.state.visits, isEmpty);
        expect(realController.state.spaces, isEmpty);
        expect(realController.state.reviewQueue, isEmpty);
        expect(realController.state.participantDirectory, isEmpty);

        // Attempting synchronous mock mutation in real mode fails closed with 503
        final res = realController.confirmVehicleCrossedGate(
          laneId: 'lane-car-in',
          notes: 'Attempting local mock attestation in real mode.',
          actor: SentryFixtures.guardOperator,
        );
        expect(res.ok, isFalse);
        expect(res.error?.code, ErrorCatalog.serviceUnavailable);
        expect(realController.state.lastRealApiError, isNotNull);
        wsCoord.dispose();
      },
    );

    test(
      'Expired 30s space hold blocks passage confirmation, marks attempt expired, and releases held bay',
      () {
        final wsCoord = WsInvalidationCoordinator();
        final controller = SentryScenarioController(
          initialRosterMode: RosterMode.classDemo,
          wsCoordinator: wsCoord,
        );

        // Trigger T01: Normal Car Entry -> ALLOWED + 30s Hold on A-C01
        controller.triggerScenario('T01');
        final initialAttempt =
            controller.state.activeLaneAttempts['lane-car-in']!;
        expect(initialAttempt.canConfirmPassage(), isTrue);
        expect(initialAttempt.assignmentStatus, 'held');

        // Simulate 30s hold expiration via holdExpiresAtUtc in the past
        final expiredHoldAttempt = initialAttempt.copyWith(
          holdExpiresAtUtc:
              DateTime.now().toUtc().subtract(const Duration(seconds: 2)),
        );
        expect(expiredHoldAttempt.isHoldExpired(), isTrue);
        expect(expiredHoldAttempt.canConfirmPassage(), isFalse);

        // Expire hold on lane and verify attempt is marked expired & bay A-C01 is released
        controller.expireHoldOrDecisionOnLane('lane-car-in');
        final afterExpiry = controller.state.activeLaneAttempts['lane-car-in']!;
        expect(afterExpiry.state, 'expired');
        expect(afterExpiry.assignmentStatus, 'released');
        expect(afterExpiry.canConfirmPassage(), isFalse);

        final bayAC01 =
            controller.state.spaces.firstWhere((s) => s.spaceCode == 'A-C01');
        expect(bayAC01.allocationStatus, 'unassigned');
        expect(bayAC01.visitId, isNull);

        // Attempting confirmVehicleCrossedGate after expiry is blocked with 409
        final confirmRes = controller.confirmVehicleCrossedGate(
          laneId: 'lane-car-in',
          notes: 'Trying to confirm after 30s hold expired.',
          actor: SentryFixtures.guardOperator,
        );
        expect(confirmRes.ok, isFalse);
        expect(confirmRes.error?.httpStatus, 409);
        wsCoord.dispose();
      },
    );

    testWidgets(
      'DATA_SOURCE=real with missing API_BASE_URL fails closed at startup with configuration error screen',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWithValue(
                const AppConfig(
                  appEnv: 'production',
                  dataSource: DataSourceMode.real,
                  initialRosterMode: RosterMode.classDemo,
                  apiBaseUrl: '',
                  wsBaseUrl: 'ws://127.0.0.1:8000/api/v1/ws/updates',
                  requestTimeoutMs: 5000,
                  displayTimezone: 'Asia/Manila',
                ),
              ),
            ],
            child: const SentryDesktopApp(),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('real_config_error_screen')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('real_mode_config_error_text')),
          findsOneWidget,
        );
      },
    );
  });

  group(
      'Part D (Prompt 3 Audit): Production-First Default & Hidden Developer Backdoor',
      () {
    test(
      'AppConfig.fromEnvironment() defaults to DATA_SOURCE=real and APP_ENV=production with API_URL_PLACEHOLDER',
      () {
        final cfg = AppConfig.fromEnvironment();
        expect(cfg.dataSource, DataSourceMode.real);
        expect(cfg.isReal, isTrue);
        expect(cfg.isMock, isFalse);
        expect(cfg.appEnv, 'production');
        expect(cfg.apiBaseUrl, 'https://API_URL_PLACEHOLDER.local:8000');
        expect(
          cfg.wsBaseUrl,
          'wss://API_URL_PLACEHOLDER.local:8000/api/v1/ws/updates',
        );
      },
    );

    testWidgets(
      'Default production boot hides demo persona chips and unlocks mock fixtures via secret credentials or 5x logo tap',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: SentryDesktopApp(),
          ),
        );
        await tester.pump();

        // In default production mode, persona chips are hidden and credentials are empty
        expect(find.byKey(const Key('persona_guard_chip')), findsNothing);
        expect(find.byKey(const Key('persona_admin_chip')), findsNothing);

        // Tap logo 5 times within 2 seconds -> unlocks Developer Test Mode
        final logoFinder = find.byKey(const Key('login_logo_hero'));
        expect(logoFinder, findsOneWidget);
        for (var i = 0; i < 5; i++) {
          await tester.tap(logoFinder);
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.text('Developer Test Mode Enabled'), findsOneWidget);
        expect(find.byKey(const Key('persona_guard_chip')), findsOneWidget);
        expect(find.byKey(const Key('persona_admin_chip')), findsOneWidget);
      },
    );

    testWidgets(
      'Secret developer backdoor credentials bypass HTTP login, switch session to mock mode, and load U001–U007',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: SentryDesktopApp(),
          ),
        );
        await tester.pump();

        await tester.enterText(
          find.byKey(const Key('login_username_field')),
          'emman.dev@sentry.internal',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'SENTRY-DEV-4102!',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pump();
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }

        // Logged in as Administrator (Emmanuel Tamboong) with mock fixtures loaded
        expect(find.text('Confirmed inside'), findsOneWidget);
        expect(find.text('Emmanuel Tamboong'), findsWidgets);
      },
    );
  });
}
