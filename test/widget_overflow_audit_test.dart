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
        'overview',
        'liveGateMonitoring',
        'guardReviews',
        'parkingManagement',
        'accessLogs',
        'deviceMonitoring',
        'administration',
      ]) {
        await tapKey(tester, 'nav_tab_$tab');
      }

      // Administration sub-tabs: registration, facial enrollment, audit log.
      for (var i = 0; i < 4; i++) {
        await tapKey(tester, 'admin_subtab_$i');
      }

      // Access Logs sub-tabs.
      await tapKey(tester, 'nav_tab_accessLogs');
      for (var i = 0; i < 3; i++) {
        await tapKey(tester, 'access_logs_subtab_$i');
      }

      // Confirm-passage modal on Live Gate.
      await tapKey(tester, 'nav_tab_liveGateMonitoring');
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
      'overview',
      'liveGateMonitoring',
      'guardReviews',
      'parkingManagement',
      'accessLogs',
      'deviceMonitoring',
      'administration',
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
