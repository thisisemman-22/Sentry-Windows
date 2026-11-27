import 'dart:io';
import 'package:campus_parking_desktop/app/app.dart';
import 'package:campus_parking_desktop/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prompt 2 overflow audit: pumps every view, sub-tab and key modal at
/// guardhouse (1920×1080) and compact (1280×720) sizes and asserts that no
/// RenderFlex overflow or other framework exception is raised.
void main() {
  const sizes = <Size>[
    Size(1920, 1080),
    Size(1366, 768),
    Size(1280, 720),
  ];

  setUpAll(() {
    FlutterError.onError = (FlutterErrorDetails details) {
      stdout.writeln('FLUTTER_ERROR_DETAILS: ${details.exceptionAsString()}');
      if (details.informationCollector != null) {
        for (final node in details.informationCollector!()) {
          stdout.writeln(node.toStringDeep());
        }
      }
    };
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    expect(f, findsOneWidget, reason: 'Missing widget with key $key');
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f, warnIfMissed: false);
    await settle(tester);
    final exc = tester.takeException();
    if (exc != null) {
      stdout.writeln('EXC_DUMP for $key:');
      stdout.writeln(exc);
      if (exc is FlutterError) {
        for (final d in exc.diagnostics) {
          stdout.writeln('DIAG: ${d.toStringDeep()}');
        }
      }
    }
    expect(exc, isNull, reason: 'Exception after $key: $exc');
  }

  for (final size in sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('Overflow audit: every view & modal at $label', (tester) async {
      final origOnError = FlutterError.onError;
      addTearDown(() {
        FlutterError.onError = origOnError;
      });
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          stdout.writeln('=== FLUTTER_OVERFLOW ===');
          stdout.writeln(details.exceptionAsString());
          if (details.informationCollector != null) {
            for (final node in details.informationCollector!()) {
              stdout.writeln(node.toStringDeep());
            }
          }
          stdout.writeln('========================');
        }
        origOnError?.call(details);
      };

      tester.view.physicalSize = size;
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
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'Login at $label');

      // Sign in as Administrator so every view (incl. admin tabs) is reachable.
      await tapKey(tester, 'persona_admin_chip');
      await tapKey(tester, 'login_submit_button');

      for (final tab in const [
        'dashboard',
        'users',
        'vehiclesRfid',
        'parking',
        'guests',
        'monitoring',
        'reports',
        'announcements',
        'audit',
        'settings',
      ]) {
        await tapKey(tester, 'nav_tab_$tab');
      }

      // Parking lot tabs B1–B5 + Building routing + Parking Rules + Bay Inspector Drawer
      await tapKey(tester, 'nav_tab_parking');
      for (final lot in const ['B1', 'B2', 'B3', 'B4', 'B5', 'MATRIX', 'RULES']) {
        await tapKey(tester, 'parking_tab_$lot');
      }
      await tapKey(tester, 'parking_tab_B1');
      await tapKey(tester, 'bay_card_B1-L1');
      expect(find.textContaining('Inspector'), findsWidgets);
      await tester.tapAt(const Offset(4, 4));
      await settle(tester);

      // Overview Export Report dialog (CSV / PDF)
      await tapKey(tester, 'nav_tab_dashboard');
      await tapKey(tester, 'overview_export_report_button');
      await tapKey(tester, 'export_menu_csv');
      expect(find.byKey(const Key('export_confirm_button')), findsOneWidget);
      await tapKey(tester, 'export_cancel_button');

      // Users sub-tabs: Directory, Register User, Face Enrollment, OTP & Activation.
      await tapKey(tester, 'nav_tab_users');
      for (var i = 0; i < 4; i++) {
        await tapKey(tester, 'users_subtab_$i');
      }

      // Vehicles & RFID sub-tabs + Guests sub-tabs.
      await tapKey(tester, 'nav_tab_vehiclesRfid');
      for (var i = 0; i < 3; i++) {
        await tapKey(tester, 'vehicles_rfid_subtab_$i');
      }
      await tapKey(tester, 'nav_tab_guests');
      for (var i = 0; i < 3; i++) {
        await tapKey(tester, 'guests_subtab_$i');
      }

      // Monitoring sub-tabs + Access Logs sub-tabs + Export Report dialog.
      await tapKey(tester, 'nav_tab_monitoring');
      for (var i = 0; i < 5; i++) {
        await tapKey(tester, 'monitoring_subtab_$i');
      }
      await tapKey(tester, 'monitoring_subtab_2');
      for (var i = 0; i < 3; i++) {
        await tapKey(tester, 'access_logs_subtab_$i');
      }
      await tapKey(tester, 'access_logs_export_report_button');
      await tapKey(tester, 'export_menu_pdf');
      expect(find.byKey(const Key('export_confirm_button')), findsOneWidget);
      await tapKey(tester, 'export_cancel_button');

      // Confirm-passage modal on Monitoring -> Live Gates.
      await tapKey(tester, 'monitoring_subtab_0');
      await tapKey(tester, 'confirm_vehicle_crossed_button');
      expect(
        find.byKey(const Key('passage_attestation_notes_field')),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(4, 4));
      await settle(tester);

      // Command palette (Ctrl+K).
      await tapKey(tester, 'open_command_palette_button');
      expect(find.byKey(const Key('command_palette_field')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Overflow audit: mobile preview drawer & views at 600x800', (tester) async {
    final origOnError = FlutterError.onError;
    addTearDown(() {
      FlutterError.onError = origOnError;
    });
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        stdout.writeln('=== MOBILE_600x800_OVERFLOW ===');
        stdout.writeln(details.exceptionAsString());
        if (details.informationCollector != null) {
          for (final node in details.informationCollector!()) {
            stdout.writeln(node.toStringDeep());
          }
        }
        stdout.writeln('===============================');
      }
      origOnError?.call(details);
    };

    tester.view.physicalSize = const Size(600, 800);
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
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'Login at 600x800');

    await tapKey(tester, 'persona_admin_chip');
    await tapKey(tester, 'login_submit_button');

    // Open mobile drawer
    final menuBtn = find.byTooltip('Open navigation menu');
    expect(menuBtn, findsOneWidget);
    await tester.tap(menuBtn);
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'Open drawer at 600x800');

    for (final tab in const [
      'dashboard',
      'users',
      'vehiclesRfid',
      'parking',
      'guests',
      'monitoring',
      'reports',
      'announcements',
      'audit',
      'settings',
    ]) {
      final drawerFinder = find.byType(Drawer);
      if (drawerFinder.evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await settle(tester);
      }
      await tapKey(tester, 'nav_tab_$tab');
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'Tab $tab at 600x800');
    }
  });
}
