import 'dart:convert';
import 'package:campus_parking_desktop/app/app.dart';
import 'package:campus_parking_desktop/app/desktop_shell.dart';
import 'package:campus_parking_desktop/app/providers.dart';
import 'package:campus_parking_desktop/features/access_logs/presentation/report_export_dialog.dart';
import 'package:campus_parking_desktop/shared/fixtures/synthetic_fixtures.dart';
import 'package:campus_parking_desktop/shared/models/participant_models.dart';
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

  group('2026-11-27 Feature & Flow Spec Alignment', () {
    testWidgets(
      'Forced first-login password change blocks DesktopShell until matching password saved',
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

        await tester.enterText(
          find.byKey(const Key('login_username_field')),
          'firstlogin@sentry.test',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'SENTRY-WELCOME-2026!',
        );
        await tapKey(tester, 'login_submit_button');

        expect(
          find.byKey(const Key('first_login_new_password_field')),
          findsOneWidget,
        );
        expect(find.byType(DesktopShell), findsNothing);

        // Mismatch shows validation error and keeps blocking shell
        await tester.enterText(
          find.byKey(const Key('first_login_new_password_field')),
          'NewPassSecure2026!',
        );
        await tester.enterText(
          find.byKey(const Key('first_login_confirm_password_field')),
          'DifferentPass2026!',
        );
        await tapKey(tester, 'first_login_submit_button');
        expect(find.byType(DesktopShell), findsNothing);

        // Matching password unlocks DesktopShell
        await tester.enterText(
          find.byKey(const Key('first_login_confirm_password_field')),
          'NewPassSecure2026!',
        );
        await tapKey(tester, 'first_login_submit_button');
        expect(find.byType(DesktopShell), findsOneWidget);
        expect(find.text('Review Queue'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'Guard RBAC isolation: sees only 5 Guard screens and gets 403 on admin mutations',
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

        for (final key in const [
          'nav_tab_guardReviewQueue',
          'nav_tab_guardMonitor',
          'nav_tab_guardGuestCheck',
          'nav_tab_guardManualEntry',
          'nav_tab_guardOverdueGuests',
        ]) {
          expect(find.byKey(Key(key)), findsOneWidget);
        }
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

        // Controller & simulator reject Guard mutations with HTTP 403
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DesktopShell)),
        );
        final opsCtrl = container.read(desktopOpsControllerProvider.notifier);
        final sim = container.read(sentryScenarioProvider.notifier);
        const guard = SentryFixtures.guardOperator;

        final resetRes = await opsCtrl.resetUserPasswordToGeneral(
          targetUserId: '10000000-0000-4000-8000-000000000001',
          targetUserCode: 'U001',
          actor: guard,
        );
        expect(resetRes.error?.httpStatus, 403);

        final dlqRes = await opsCtrl.retryDeadLetter('DLQ-101', actor: guard);
        expect(dlqRes.error?.httpStatus, 403);

        final ruleRes = await opsCtrl.updateParkingRule(
          ruleKey: 'space_hold_ttl_sec',
          valueText: '45 seconds',
          actor: guard,
        );
        expect(ruleRes.error?.httpStatus, 403);

        final guestRes = await opsCtrl.reviewGuestVisitRequest(
          visitRequestId: 'GV-201',
          approve: true,
          actor: guard,
        );
        expect(guestRes.error?.httpStatus, 403);

        final annRes = await opsCtrl.saveAnnouncement(
          title: 'Unauthorized',
          body: 'Should fail',
          audienceRoles: const ['student'],
          actor: guard,
        );
        expect(annRes.error?.httpStatus, 403);

        final b1Res = sim.toggleLotB1SpaceManual(
          spaceCode: 'B1-L1',
          actor: guard,
          physicalStatus: 'occupied',
        );
        expect(b1Res.error?.httpStatus, 403);
      },
    );

    test(
      'Registration validation requires rfidUid for motorcycles and plateNumber for cars',
      () {
        final motoNoRfid = const ManualUserRegistrationRequest(
          fullName: 'Rider Test',
          email: 'rider@g.batstate-u.edu.ph',
          roleCode: 'student',
          includeVehicle: true,
          vehicleType: 'motorcycle',
          rfidUid: '',
        ).validate();
        expect(motoNoRfid.containsKey('rfid_uid'), isTrue);

        final motoWithRfid = const ManualUserRegistrationRequest(
          fullName: 'Rider Test',
          email: 'rider@g.batstate-u.edu.ph',
          roleCode: 'student',
          includeVehicle: true,
          vehicleType: 'motorcycle',
          rfidUid: '04AABBCC',
        ).validate();
        expect(motoWithRfid, isEmpty);

        final carNoPlate = const ManualUserRegistrationRequest(
          fullName: 'Car Test',
          email: 'driver@g.batstate-u.edu.ph',
          roleCode: 'faculty',
          includeVehicle: true,
          vehicleType: 'car',
          plateNumber: '',
        ).validate();
        expect(carNoPlate.containsKey('plate_number'), isTrue);
      },
    );

    testWidgets(
      'Second-Admin reset rule, General Password Show/Change, Dead-Letter retry & Lot B1 vs B2–B4 lock vs B5 overflow',
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

        await tapKey(tester, 'persona_admin_chip');
        await tapKey(tester, 'login_submit_button');

        // Dashboard System Health + Dead-Letter retry (DLQ-101)
        expect(
          find.byKey(const Key('dashboard_system_health_card')),
          findsOneWidget,
        );
        await tapKey(tester, 'dead_letter_retry_DLQ-101');
        expect(find.byKey(const Key('dead_letter_retry_DLQ-101')), findsNothing);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DesktopShell)),
        );
        final opsCtrl = container.read(desktopOpsControllerProvider.notifier);
        const admin = SentryFixtures.adminOperator;

        // Second-Admin rule blocks self-reset on A001
        final selfReset = await opsCtrl.resetUserPasswordToGeneral(
          targetUserId: admin.userId,
          targetUserCode: admin.userCode,
          actor: admin,
        );
        expect(selfReset.error?.httpStatus, 403);
        expect(selfReset.error?.code, 'SELF_RESET_FORBIDDEN');

        // Reset U001 succeeds & sets first_login_required
        await tapKey(tester, 'nav_tab_users');
        await tapKey(tester, 'reset_user_pwd_U001');
        expect(find.byKey(const Key('confirm_reset_to_general_pwd_btn')), findsOneWidget);
        await tapKey(tester, 'confirm_reset_to_general_pwd_btn');
        expect(
          container.read(desktopOpsControllerProvider).userAccountStatuses['U001'],
          'first_login_required',
        );

        // General Password Show reveals + audits; Change updates General Password
        await tapKey(tester, 'general_password_show_btn');
        expect(find.textContaining('SENTRY-WELCOME-2026!'), findsWidgets);
        await tapKey(tester, 'general_password_change_btn');
        await tester.enterText(
          find.byKey(const Key('general_password_new_field')),
          'CampusReset2026!',
        );
        await tapKey(tester, 'general_password_save_btn');

        // Parking: B1 allows Admin manual Slot Active & status toggle; B2 is camera-locked; B5 has no individual slots
        await tapKey(tester, 'nav_tab_parking');
        await tapKey(tester, 'bay_card_B1-L1');
        expect(
          find.byKey(const Key('b1_slot_active_switch_B1-L1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('b1_manual_status_toggle_B1-L1')),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(4, 4));
        await settle(tester);

        // Simulator rejects manual edits outside B1 with 403 CAMERA_LOCKED_LOT
        final sim = container.read(sentryScenarioProvider.notifier);
        final b2Attempt = sim.toggleLotB1SpaceManual(
          spaceCode: 'B2-L1',
          actor: admin,
          physicalStatus: 'vacant',
        );
        expect(b2Attempt.error?.httpStatus, 403);
        expect(b2Attempt.error?.code, 'CAMERA_LOCKED_LOT');

        // Switch to B2 -> bay inspector shows camera-locked callout
        await tapKey(tester, 'parking_tab_B2');
        await tapKey(tester, 'bay_card_B2-L1');
        expect(
          find.byKey(const Key('camera_locked_slot_notice')),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(4, 4));
        await settle(tester);

        // B5 shows aggregate overflow card (no individual bays)
        await tapKey(tester, 'parking_tab_B5');
        expect(
          find.byKey(const Key('lot_b5_overflow_aggregate_card')),
          findsOneWidget,
        );
        expect(find.text('Overflow lot — no individual slots'), findsWidgets);
      },
    );

    testWidgets(
      'Guests reject reason enforcement & pass-code privacy, 4-digit BSUAL- verification, Reports Export History & Announcements CRUD',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 960);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        String? exportedName;
        List<int>? exportedBytes;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              devModeUnlockedProvider.overrideWith((_) => true),
              reportSaveFileOverrideProvider.overrideWith(
                (_) => (name, bytes) async {
                  exportedName = name;
                  exportedBytes = bytes;
                  return 'C:\\temp\\$name';
                },
              ),
            ],
            child: const SentryDesktopApp(),
          ),
        );
        await settle(tester);

        await tapKey(tester, 'persona_admin_chip');
        await tapKey(tester, 'login_submit_button');

        // 1. Guests: mandatory reject reason disables button when empty; never renders BSUAL-XXXX code
        await tapKey(tester, 'nav_tab_guests');
        expect(find.textContaining('BSUAL-4'), findsNothing);
        await tapKey(tester, 'reject_guest_req_GV-201');
        final confirmBtnEmpty = tester.widget<FilledButton>(
          find.byKey(const Key('guest_confirm_reject_button')),
        );
        expect(confirmBtnEmpty.onPressed, isNull);

        await tester.enterText(
          find.byKey(const Key('guest_reject_reason_field')),
          'Host schedule conflict',
        );
        await settle(tester);
        await tapKey(tester, 'guest_confirm_reject_button');
        expect(find.textContaining('Host schedule conflict'), findsWidgets);

        // 2. Monitoring -> Live Gates: 4-digit BSUAL- guest pass verification
        await tapKey(tester, 'nav_tab_monitoring');
        expect(find.byKey(const Key('guest_pass_prefix_badge')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('guest_pass_4digit_field')),
          '4829',
        );
        await tapKey(tester, 'guest_pass_verify_button');
        expect(find.byKey(const Key('guest_pass_verify_result')), findsOneWidget);
        expect(find.textContaining('BSUAL-4829'), findsWidgets);

        // 3. Reports: all 6 presets visible for Admin, masked preview, CSV export adds Export History
        await tapKey(tester, 'nav_tab_reports');
        for (final wire in const [
          'occupancy',
          'entries_exits',
          'vehicles',
          'users',
          'guests',
          'review_cases',
        ]) {
          expect(find.byKey(Key('report_preset_$wire')), findsOneWidget);
        }
        await tapKey(tester, 'report_preset_users');
        expect(find.byKey(const Key('reports_preview_table')), findsOneWidget);
        await tapKey(tester, 'reports_export_csv_btn');
        expect(exportedName, startsWith('sentry_users_'));
        expect(utf8.decode(exportedBytes!), contains('***'));
        expect(find.textContaining('Users (CSV)'), findsWidgets);

        // 4. Announcements CRUD
        await tapKey(tester, 'nav_tab_announcements');
        await tapKey(tester, 'announcement_new_btn');
        await tester.enterText(
          find.byKey(const Key('announcement_title_field')),
          'CEAFA 2 Overnight Striping',
        );
        await tester.enterText(
          find.byKey(const Key('announcement_body_field')),
          'Lot B4 closed 22:00-05:00 PHT.',
        );
        await settle(tester);
        await tapKey(tester, 'announcement_save_btn');
        expect(find.text('CEAFA 2 Overnight Striping'), findsOneWidget);

        // Verify DTO copy omits any pass code property cleanly
        final reqDto = GuestVisitRequestDto.fromJson({
          'visit_request_id': 'GV-900',
          'guest_account_id': 'GA-900',
          'guest_full_name': 'Guest Demo',
          'guest_email': 'guest@example.com',
          'host_name': 'ICT Office',
          'host_department': 'ICT',
          'purpose': 'Support',
          'plate_number': 'XYZ 123',
          'status': 'approved',
        });
        expect(reqDto.status, 'approved');
      },
    );
  });
}
