import 'package:campus_parking_desktop/app/app.dart';
import 'package:campus_parking_desktop/app/providers.dart';
import 'package:campus_parking_desktop/app/router.dart';
import 'package:campus_parking_desktop/core/config/app_config.dart';
import 'package:campus_parking_desktop/core/config/roster_mode.dart';
import 'package:campus_parking_desktop/core/network/secure_session_store.dart';
import 'package:campus_parking_desktop/shared/fixtures/synthetic_fixtures.dart';
import 'package:campus_parking_desktop/shared/models/auth_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Prompt 4 Demo Trace Sweep & Production Cleanliness Audits', () {
    testWidgets(
        '1. Login screen in real mode: empty inputs, no persona chips, no backdoor hints',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: SentryDesktopApp(),
        ),
      );
      await tester.pump();

      // Screen title and subtitle render
      expect(find.text('Sign in to Guard & ICT Console'), findsOneWidget);

      // Verify persona chips are NOT present in real mode
      expect(find.byKey(const Key('persona_guard_chip')), findsNothing);
      expect(find.byKey(const Key('persona_admin_chip')), findsNothing);

      // Verify username and password fields start completely empty
      final usernameField = tester.widget<TextField>(
        find.byKey(const Key('login_username_field')),
      );
      expect(usernameField.controller?.text ?? '', isEmpty);

      final passwordField = tester.widget<TextField>(
        find.byKey(const Key('login_password_field')),
      );
      expect(passwordField.controller?.text ?? '', isEmpty);

      // Verify no hints reveal secret backdoor credentials or gestures
      expect(find.textContaining('4102'), findsNothing);
      expect(find.textContaining('tap'), findsNothing);
      expect(find.textContaining('gesture'), findsNothing);
      expect(find.textContaining('Ctrl+Shift'), findsNothing);
    });

    testWidgets(
        '2. Backdoor login unlocks mock mode and sign-out completely resets back to real mode',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              capturedRef = ref;
              return const SentryDesktopApp();
            },
          ),
        ),
      );
      await tester.pump();

      expect(capturedRef.read(appConfigProvider).isReal, isTrue);
      expect(capturedRef.read(devModeUnlockedProvider), isFalse);

      // Enter developer backdoor credentials
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
      await tester.pump(const Duration(milliseconds: 200));

      // Now developer mode should be unlocked
      expect(capturedRef.read(devModeUnlockedProvider), isTrue);
      expect(capturedRef.read(appConfigProvider).isMock, isTrue);
      expect(find.text('Campus overview'), findsOneWidget);

      // Top bar in mock mode displays DEV indicator
      expect(find.text('DEV'), findsOneWidget);

      // Sign out via desktop shell sign-out action
      await tester.tap(find.byKey(const Key('nav_tab_administration')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('admin_logout_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // After sign-out, session is cleared, dev mode reverts to false, and real mode is active
      expect(capturedRef.read(devModeUnlockedProvider), isFalse);
      expect(capturedRef.read(appConfigProvider).isReal, isTrue);
      expect(find.text('Sign in to Guard & ICT Console'), findsOneWidget);

      // Fields are empty and persona chips are gone again
      expect(find.byKey(const Key('persona_guard_chip')), findsNothing);
      expect(find.byKey(const Key('persona_admin_chip')), findsNothing);
    });

    testWidgets(
        '3. Production Cleanliness Audit across all tabs in disconnected real mode',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionStore = InMemorySessionStore();
      final now = DateTime.now().toUtc();
      final realAdminSession = SessionDto(
        sessionId: 'sess-real-admin-01',
        accessToken: 'jwt-real-admin-token',
        refreshToken: 'refresh-real-admin-token',
        issuedAtUtc: now,
        expiresAtUtc: now.add(const Duration(hours: 8)),
        profile: SentryFixtures.adminOperator,
      );
      await sessionStore.saveSession(realAdminSession);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(sessionStore),
            authControllerProvider.overrideWith((ref) {
              return AuthController(
                config: const AppConfig(
                  appEnv: 'prod',
                  dataSource: DataSourceMode.real,
                  initialRosterMode: RosterMode.contractSynthetic,
                  apiBaseUrl: 'http://127.0.0.1:8000',
                  wsBaseUrl: 'ws://127.0.0.1:8000/api/v1/ws/updates',
                  requestTimeoutMs: 5000,
                  displayTimezone: 'Asia/Manila',
                ),
                sessionStore: sessionStore,
              )..state = AuthState(session: realAdminSession);
            }),
          ],
          child: const SentryDesktopApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // --- TAB 1: OVERVIEW SCREEN AUDIT ---
      expect(find.text('Campus overview'), findsOneWidget);
      // Top bar must NOT have DEV or MOCK pills
      expect(find.text('DEV'), findsNothing);
      expect(find.text('MOCK'), findsNothing);
      // Top bar demo controls sheet trigger must NOT be clickable
      expect(find.byKey(const Key('open_demo_controls_button')), findsNothing);

      // Overview KPI tiles should display '—' and 'Awaiting backend connection'
      expect(find.text('—'), findsAtLeastNWidgets(4));
      expect(find.text('Awaiting backend connection'), findsAtLeastNWidgets(3));
      // Parking lots card and recent activity card show clean empty states
      expect(find.text('Awaiting parking lot telemetry'), findsOneWidget);
      expect(find.text('No recent gate activity'), findsOneWidget);

      // --- TAB 2: LIVE GATE MONITORING AUDIT ---
      await tester.tap(find.byKey(const Key('nav_tab_liveGateMonitoring')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Live gates'), findsOneWidget);
      // NO 'Simulate encounter' button
      expect(find.text('Simulate encounter'), findsNothing);
      // All 4 lanes show 'Idle — Waiting for vehicle'
      expect(find.text('Idle — Waiting for vehicle'), findsNWidgets(4));
      // Center card shows idle prompt
      expect(
        find.text('Gate idle — monitoring for incoming vehicle'),
        findsOneWidget,
      );

      // --- TAB 3: GUARD REVIEWS AUDIT ---
      await tester.tap(find.byKey(const Key('nav_tab_guardReviews')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Guard reviews'), findsOneWidget);
      // Starts with empty queue
      expect(find.text('No pending guard reviews'), findsOneWidget);
      // NO version conflict test button
      expect(find.byKey(const Key('simulate_stale_version_button')), findsNothing);
      expect(find.text('Test version conflict'), findsNothing);

      // --- TAB 4: PARKING MANAGEMENT AUDIT ---
      await tester.tap(find.byKey(const Key('nav_tab_parkingManagement')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Parking map'), findsOneWidget);
      for (final lot in const ['B1', 'B2', 'B3', 'B4', 'B5']) {
        await tester.tap(find.byKey(Key('parking_tab_$lot')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        expect(find.text('Awaiting lot telemetry'), findsOneWidget);
        expect(find.text('Occupied'), findsNothing);
        expect(find.text('Conflict'), findsNothing);
        expect(find.text('Held (30s)'), findsNothing);
        expect(
          find.byKey(const Key('cycle_bay_physical_status_btn')),
          findsNothing,
        );
      }

      // --- TAB 5: ACCESS LOGS AUDIT ---
      await tester.tap(find.byKey(const Key('nav_tab_accessLogs')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Access logs'), findsOneWidget);
      // Subtab 0: Campus visits empty state
      expect(find.text('No campus visits recorded'), findsOneWidget);
      // Subtab 1: Gate attempts empty state
      await tester.tap(find.byKey(const Key('access_logs_subtab_1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('No gate attempts recorded'), findsOneWidget);
      // Subtab 2: Drivers & vehicles empty state
      await tester.tap(find.byKey(const Key('access_logs_subtab_2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('No registered drivers loaded'), findsOneWidget);

      // --- TAB 6: DEVICE MONITORING AUDIT ---
      await tester.tap(find.byKey(const Key('nav_tab_deviceMonitoring')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Site devices'), findsOneWidget);
      expect(find.text('No site devices loaded'), findsOneWidget);
      expect(find.text('Online'), findsNothing);
      expect(find.text('Degraded'), findsNothing);
      expect(find.text('Offline'), findsNothing);

      // --- TAB 7: ADMINISTRATION AUDIT ---
      await tester.tap(find.byKey(const Key('nav_tab_administration')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Administration'), findsAtLeastNWidgets(1));
      // Subtab 3: Drivers & vehicles (Planned) empty state
      await tester.tap(find.byKey(const Key('admin_subtab_3')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('No registered participants loaded'), findsOneWidget);
      // NO test session expiry button
      expect(
        find.byKey(const Key('simulate_ws_1008_expiry_button')),
        findsNothing,
      );
      // Subtab 2: Facial enrollment (Planned)
      await tester.tap(find.byKey(const Key('admin_subtab_2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('No registered users available'), findsOneWidget);
      expect(find.text('Biometric Enrollment: U001'), findsNothing);
      expect(find.text('Biometric Enrollment: U002'), findsNothing);
    });

    testWidgets(
        '4. Guard role isolation: hides Administration tab and blocks direct router navigation in real mode',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionStore = InMemorySessionStore();
      final now = DateTime.now().toUtc();
      final realGuardSession = SessionDto(
        sessionId: 'sess-real-guard-01',
        accessToken: 'jwt-real-guard-token',
        refreshToken: 'refresh-real-guard-token',
        issuedAtUtc: now,
        expiresAtUtc: now.add(const Duration(hours: 8)),
        profile: SentryFixtures.guardOperator,
      );
      await sessionStore.saveSession(realGuardSession);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(sessionStore),
            authControllerProvider.overrideWith((ref) {
              return AuthController(
                config: const AppConfig(
                  appEnv: 'prod',
                  dataSource: DataSourceMode.real,
                  initialRosterMode: RosterMode.contractSynthetic,
                  apiBaseUrl: 'http://127.0.0.1:8000',
                  wsBaseUrl: 'ws://127.0.0.1:8000/api/v1/ws/updates',
                  requestTimeoutMs: 5000,
                  displayTimezone: 'Asia/Manila',
                ),
                sessionStore: sessionStore,
              )..state = AuthState(session: realGuardSession);
            }),
          ],
          child: const SentryDesktopApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Guard must NEVER see the Administration nav tab in the sidebar
      expect(find.byKey(const Key('nav_tab_administration')), findsNothing);

      // Even if tab state is mutated programmatically, RoleGate keeps Guard off
      // AdministrationScreen and never instantiates Admin-only providers.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DesktopViewRouter)),
      );
      container.read(selectedDesktopTabProvider.notifier).state =
          DesktopNavTab.administration;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Administrator access required'), findsNothing);
      expect(
        find.text('Test Calling Endpoint as Guard (Verify HTTP 403 ACCESS_DENIED)'),
        findsNothing,
      );
      expect(container.exists(adminRegistrationApiProvider), isFalse);
      expect(container.exists(registerFormControllerProvider), isFalse);
    });
  });
}
