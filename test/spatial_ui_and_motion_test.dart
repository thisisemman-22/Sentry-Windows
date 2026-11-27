import 'package:campus_parking_desktop/app/app.dart';
import 'package:campus_parking_desktop/app/desktop_shell.dart';
import 'package:campus_parking_desktop/app/providers.dart';
import 'package:campus_parking_desktop/core/config/app_config.dart';
import 'package:campus_parking_desktop/core/config/roster_mode.dart';
import 'package:campus_parking_desktop/core/network/secure_session_store.dart';
import 'package:campus_parking_desktop/shared/fixtures/synthetic_fixtures.dart';
import 'package:campus_parking_desktop/shared/models/auth_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 90));
    }
  }

  group('Prompt C: Spatial Command-Center UI, Floating Controls & Motion', () {
    testWidgets(
        'Floating sidebar rail switches OLED Dark mode and collapses cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 960);
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
      await settle(tester);

      await tester.tap(find.byKey(const Key('login_submit_button')));
      await settle(tester);

      final railFinder = find.byKey(const Key('floating_sidebar_rail'));
      expect(railFinder, findsOneWidget);
      expect(
        Theme.of(tester.element(railFinder)).brightness,
        Brightness.light,
      );

      await tester.tap(find.byKey(const Key('sidebar_theme_toggle')));
      await settle(tester);

      final container = ProviderScope.containerOf(tester.element(railFinder));
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(
        Theme.of(tester.element(railFinder)).brightness,
        Brightness.dark,
      );

      await tester.tap(find.byKey(const Key('sidebar_collapse_toggle')));
      await settle(tester);
      expect(container.read(sidebarCollapsedProvider), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Spatial Bento Overview renders Tactical Map, layer filters, frosted callout & charts',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 960);
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
      await settle(tester);

      await tester.tap(find.byKey(const Key('persona_admin_chip')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await settle(tester);

      expect(
        find.byKey(const Key('overview_floating_search_bar')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map_layer_all')), findsOneWidget);
      expect(find.byKey(const Key('map_layer_motorcycles')), findsOneWidget);
      expect(find.text('Campus mix'), findsOneWidget);
      expect(find.text('Gate activity'), findsOneWidget);
      expect(find.text('Active gate lanes'), findsOneWidget);
      expect(find.text('Campus capacity'), findsOneWidget);
      expect(find.textContaining('Peak:'), findsOneWidget);

      await tester.tap(find.byKey(const Key('map_layer_motorcycles')));
      await settle(tester);
      expect(find.text('10 moto bays'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tactical_lot_B2')));
      await settle(tester);
      expect(find.byKey(const Key('tactical_callout_B2')), findsOneWidget);
      expect(find.byKey(const Key('callout_open_lot_B2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('callout_open_lot_B2')));
      await settle(tester);
      expect(find.text('Parking map'), findsOneWidget);
      expect(find.byKey(const Key('bay_card_B2-MB10')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Parking Management floats lot tabs, zoom controls, legend chips & frosted inspector drawer',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 960);
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
      await settle(tester);

      await tester.tap(find.byKey(const Key('persona_admin_chip')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('nav_tab_parking')));
      await settle(tester);

      expect(find.byKey(const Key('parking_tab_B1')), findsOneWidget);
      expect(find.byKey(const Key('parking_tab_B5')), findsOneWidget);
      expect(find.byKey(const Key('blueprint_zoom_in_btn')), findsOneWidget);
      expect(find.byKey(const Key('blueprint_zoom_out_btn')), findsOneWidget);
      expect(find.byKey(const Key('blueprint_reset_zoom_btn')), findsOneWidget);
      expect(find.text('PWD / Accessible'), findsOneWidget);
      expect(find.text('Informal Aisle'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('blueprint_zoom_in_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('blueprint_zoom_in_btn')));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('blueprint_zoom_out_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('blueprint_zoom_out_btn')));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('blueprint_reset_zoom_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('blueprint_reset_zoom_btn')));
      await settle(tester);

      await tester.ensureVisible(find.byKey(const Key('bay_card_B1-L1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bay_card_B1-L1')));
      await settle(tester);
      expect(find.text('Bay B1-L1 Inspector'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Disconnected DATA_SOURCE=real Overview renders zero fake numbers, clean chart frames & no Peak badges',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = InMemorySessionStore();
      final now = DateTime.now().toUtc();
      final session = SessionDto(
        sessionId: 'sess-real-spatial-01',
        accessToken: 'jwt-real-spatial',
        refreshToken: 'refresh-real-spatial',
        issuedAtUtc: now,
        expiresAtUtc: now.add(const Duration(hours: 8)),
        profile: SentryFixtures.adminOperator,
      );
      await store.saveSession(session);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(store),
            authControllerProvider.overrideWith((ref) {
              return AuthController(
                config: const AppConfig(
                  appEnv: 'production',
                  dataSource: DataSourceMode.real,
                  initialRosterMode: RosterMode.contractSynthetic,
                  apiBaseUrl: 'https://sentry.batstate-u.example',
                  wsBaseUrl: 'wss://sentry.batstate-u.example/api/v1/ws/updates',
                  requestTimeoutMs: 5000,
                  displayTimezone: 'Asia/Manila',
                ),
                sessionStore: store,
              )..state = AuthState(session: session);
            }),
          ],
          child: const SentryDesktopApp(),
        ),
      );
      await settle(tester);

      expect(find.text('Awaiting parking lot telemetry'), findsOneWidget);
      expect(find.text('Awaiting live telemetry'), findsAtLeastNWidgets(2));
      expect(find.text('—'), findsAtLeastNWidgets(4));
      expect(find.textContaining('Peak:'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
