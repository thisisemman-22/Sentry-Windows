import 'package:campus_parking_desktop/app/app.dart';
import 'package:campus_parking_desktop/app/desktop_shell.dart';
import 'package:campus_parking_desktop/app/providers.dart';
import 'package:campus_parking_desktop/shared/fixtures/synthetic_fixtures.dart';
import 'package:campus_parking_desktop/shared/models/auth_models.dart';
import 'package:campus_parking_desktop/shared/models/spec_2026_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
  }

  Future<void> tapKey(WidgetTester tester, String keyName) async {
    final finder = find.byKey(Key(keyName));
    expect(finder, findsOneWidget, reason: 'Expected widget Key($keyName)');
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  group('Guard 5-Screen Role Layout & Guest Gate Flows Delta', () {
    test(
      'normalizeGuestPassDigits & normalizeGuestPassCode normalize bsual 1234 / BSUAL-1234 / 1234',
      () {
        expect(normalizeGuestPassDigits('1234'), '1234');
        expect(normalizeGuestPassDigits('bsual 1234'), '1234');
        expect(normalizeGuestPassDigits('BSUAL-1234'), '1234');
        expect(normalizeGuestPassDigits('  bsuAl – 48 29 '), '4829');
        expect(normalizeGuestPassCode('bsual 1234'), 'BSUAL-1234');
        expect(normalizeGuestPassDigits('BSUAL-12A4'), isNull);
        expect(normalizeGuestPassDigits('123'), isNull);
      },
    );

    testWidgets(
      'Guard sidebar shows ONLY the 5 Guard screens + account menu + status indicator',
      (tester) async {
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
        await settle(tester);

        await tapKey(tester, 'persona_guard_chip');
        await tapKey(tester, 'login_submit_button');

        expect(find.byType(DesktopShell), findsOneWidget);

        // Strictly 5 Guard navigation items
        for (final key in const [
          'nav_tab_guardReviewQueue',
          'nav_tab_guardMonitor',
          'nav_tab_guardGuestCheck',
          'nav_tab_guardManualEntry',
          'nav_tab_guardOverdueGuests',
        ]) {
          expect(find.byKey(Key(key)), findsOneWidget);
        }

        // All Admin tabs hidden
        for (final adminKey in const [
          'nav_tab_dashboard',
          'nav_tab_users',
          'nav_tab_vehiclesRfid',
          'nav_tab_parking',
          'nav_tab_guests',
          'nav_tab_monitoring',
          'nav_tab_reports',
          'nav_tab_announcements',
          'nav_tab_audit',
          'nav_tab_settings',
        ]) {
          expect(find.byKey(Key(adminKey)), findsNothing);
        }

        // Account menu (Change password & Logout) + Live/Connecting/Polling indicator
        expect(find.byKey(const Key('operator_account_menu_button')), findsOneWidget);
        await tapKey(tester, 'operator_account_menu_button');
        expect(find.byKey(const Key('menu_change_password')), findsOneWidget);
        expect(find.byKey(const Key('menu_sign_out')), findsOneWidget);
        await tester.tapAt(const Offset(4, 4));
        await settle(tester);

        final hasConnStatus = find.text('Live').evaluate().isNotEmpty ||
            find.text('Connecting').evaluate().isNotEmpty ||
            find.text('Polling').evaluate().isNotEmpty;
        expect(hasConnStatus, isTrue);
      },
    );

    testWidgets(
      'Only Guard accounts can resolve Review Cases; Admin sees Monitoring -> Review Cases read-only with "Resolved by Guards"',
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

        // 1. Admin signs in -> Monitoring -> Review Cases -> Read-only UI + 403 backend enforcement
        await tapKey(tester, 'persona_admin_chip');
        await tapKey(tester, 'login_submit_button');

        await tapKey(tester, 'nav_tab_monitoring');
        await tapKey(tester, 'monitoring_subtab_1');

        expect(find.byKey(const Key('resolved_by_guards_badge')), findsOneWidget);
        final adminApproveBtn = tester.widget<FilledButton>(
          find.byKey(const Key('guard_review_approve_button')),
        );
        final adminDenyBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('guard_review_deny_button')),
        );
        final adminEscalateBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('guard_review_escalate_button')),
        );
        expect(adminApproveBtn.onPressed, isNull);
        expect(adminDenyBtn.onPressed, isNull);
        expect(adminEscalateBtn.onPressed, isNull);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DesktopShell)),
        );
        final sim = container.read(sentryScenarioProvider.notifier);
        final adminAttempt = sim.submitGuardReview(
          reviewCaseId: 'RV-105',
          action: 'approve',
          reason: 'Administrator attempting to resolve a guard review case.',
          expectedAttemptVersion: 1,
          actor: SentryFixtures.adminOperator,
        );
        expect(adminAttempt.ok, isFalse);
        expect(adminAttempt.error?.httpStatus, 403);

        // 2. Switch to Guard session -> Review Queue displays new cases & resolves RV-106
        await container
            .read(authControllerProvider.notifier)
            .switchDemoPersona(UserRole.guard);
        await settle(tester);

        expect(find.byKey(const Key('resolved_by_guards_badge')), findsNothing);
        expect(find.byKey(const Key('review_case_RV-105')), findsOneWidget);
        expect(find.byKey(const Key('review_case_RV-106')), findsOneWidget);
        expect(find.byKey(const Key('review_case_RV-107')), findsOneWidget);

        await tapKey(tester, 'review_case_RV-106');
        await tester.pump(const Duration(milliseconds: 350));
        final guardApproveBtn = tester.widget<FilledButton>(
          find.byKey(const Key('guard_review_approve_button')).last,
        );
        expect(guardApproveBtn.onPressed, isNotNull);
        await tapKey(tester, 'guard_review_approve_button');
        expect(find.byKey(const Key('guard_review_feedback_banner')), findsOneWidget);
      },
    );

    testWidgets(
      'Guest Check normalizes bsual 1234, shows Guest details before Confirm, enforces outside-window & 429 lockout; Manual Entry & Overdue Guest Cars work cleanly',
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

        await tapKey(tester, 'persona_guard_chip');
        await tapKey(tester, 'login_submit_button');

        // 1. Navigate to Guest Check
        await tapKey(tester, 'nav_tab_guardGuestCheck');
        expect(find.byKey(const Key('guest_check_prefix_badge')), findsOneWidget);

        // Lookup with unnormalized pasted code "bsual 1234"
        await tester.enterText(
          find.byKey(const Key('guest_check_code_field')),
          'bsual 1234',
        );
        await tapKey(tester, 'guest_check_lookup_button');

        // Must display Guest Name, Visit Date & Time Window, Vehicle (type & plate) BEFORE Confirm
        expect(find.byKey(const Key('guest_check_details_card')), findsOneWidget);
        expect(find.text('Engr. Maria Clara Santos'), findsOneWidget);
        expect(find.byKey(const Key('guest_check_visit_window')), findsOneWidget);
        expect(find.byKey(const Key('guest_check_vehicle_info')), findsOneWidget);
        expect(find.text('NGA 8821'), findsOneWidget);
        expect(find.text('CAR'), findsOneWidget);

        // Confirm -> allows guest car by plate
        await tapKey(tester, 'guest_check_confirm_button');
        expect(find.byKey(const Key('guest_check_confirmed_banner')), findsOneWidget);

        // Outside visit window refusal (2030)
        await tester.enterText(
          find.byKey(const Key('guest_check_code_field')),
          '2030',
        );
        await tapKey(tester, 'guest_check_lookup_button');
        expect(
          find.byKey(const Key('guest_check_outside_window_banner')),
          findsOneWidget,
        );

        // 3 wrong codes -> error on tries 1-2, 429 rate-limit lockout + disabled button on try 3
        for (var attempt = 1; attempt <= 2; attempt++) {
          await tester.enterText(
            find.byKey(const Key('guest_check_code_field')),
            '9999',
          );
          await tapKey(tester, 'guest_check_lookup_button');
          expect(find.byKey(const Key('guest_check_error_banner')), findsOneWidget);
        }
        await tester.enterText(
          find.byKey(const Key('guest_check_code_field')),
          '9999',
        );
        await tapKey(tester, 'guest_check_lookup_button');
        expect(
          find.byKey(const Key('guest_check_rate_limit_banner')),
          findsOneWidget,
        );
        final lockedLookupBtn = tester.widget<FilledButton>(
          find.byKey(const Key('guest_check_lookup_button')),
        );
        expect(lockedLookupBtn.onPressed, isNull);

        // 2. Navigate to Manual Entry -> record Guest Motorcycle + Guest on Foot
        await tapKey(tester, 'nav_tab_guardManualEntry');
        await tester.enterText(
          find.byKey(const Key('manual_entry_guest_name_field')),
          'Mateo Rider',
        );
        await tester.enterText(
          find.byKey(const Key('manual_entry_plate_desc_field')),
          'MC 7741 · Blue NMAX',
        );
        await tapKey(tester, 'manual_entry_submit_button');
        expect(find.text('Mateo Rider'), findsOneWidget);

        await tapKey(tester, 'manual_entry_type_1');
        await tester.enterText(
          find.byKey(const Key('manual_entry_guest_name_field')),
          'Liza Visitor',
        );
        await tester.enterText(
          find.byKey(const Key('manual_entry_purpose_id_field')),
          'Alumni ID checked · Registrar errand',
        );
        await tapKey(tester, 'manual_entry_submit_button');
        expect(find.text('Liza Visitor'), findsOneWidget);

        // 3. Navigate to Overdue Guest Cars -> verify overdue entries render
        await tapKey(tester, 'nav_tab_guardOverdueGuests');
        expect(find.text('Atty. Patricia Reyes'), findsOneWidget);
        expect(find.text('DAB 509'), findsOneWidget);
        expect(find.text('Engr. Noel Villanueva'), findsOneWidget);
        expect(find.text('NQZ 314'), findsOneWidget);
      },
    );

    for (final entry in <(String, Size)>[
      ('1280x720', const Size(1280, 720)),
      ('1920x1080', const Size(1920, 1080)),
    ]) {
      testWidgets(
        'Zero RenderFlex overflows across all 5 Guard screens at ${entry.$1}',
        (tester) async {
          tester.view.physicalSize = entry.$2;
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

          await tapKey(tester, 'persona_guard_chip');
          await tapKey(tester, 'login_submit_button');

          for (final tabKey in const [
            'nav_tab_guardReviewQueue',
            'nav_tab_guardMonitor',
            'nav_tab_guardGuestCheck',
            'nav_tab_guardManualEntry',
            'nav_tab_guardOverdueGuests',
          ]) {
            await tapKey(tester, tabKey);
            expect(tester.takeException(), isNull,
                reason: 'Zero overflows on $tabKey at ${entry.$1}');
          }
        },
      );
    }
  });
}
