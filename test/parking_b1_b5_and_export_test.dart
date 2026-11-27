import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:campus_parking_desktop/app/app.dart';
import 'package:campus_parking_desktop/app/desktop_shell.dart';
import 'package:campus_parking_desktop/app/providers.dart';
import 'package:campus_parking_desktop/core/config/app_config.dart';
import 'package:campus_parking_desktop/core/config/roster_mode.dart';
import 'package:campus_parking_desktop/core/network/api_client.dart';
import 'package:campus_parking_desktop/core/network/api_envelope.dart';
import 'package:campus_parking_desktop/core/network/secure_session_store.dart';
import 'package:campus_parking_desktop/core/network/ws_client.dart';
import 'package:campus_parking_desktop/features/access_logs/data/access_logs_repository.dart';
import 'package:campus_parking_desktop/features/access_logs/presentation/report_export_dialog.dart';
import 'package:campus_parking_desktop/shared/fixtures/scenario_simulator.dart';
import 'package:campus_parking_desktop/shared/fixtures/synthetic_fixtures.dart';
import 'package:campus_parking_desktop/shared/models/auth_models.dart';
import 'package:campus_parking_desktop/shared/models/parking_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _BinaryMockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) responder;

  _BinaryMockAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      responder(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<void> pumpFrameSettle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  group('Lots B1–B5 Surveyed Models & Configurable Zone Labels', () {
    test('B1–B5 fixture counts, unconfirmed/informal exclusion & PWD flag match surveyed plans', () {
      final spaces = SentryFixtures.buildInitialSpaces();
      final b1 = spaces.where((s) => s.lotCode == 'B1').toList();
      final b2 = spaces.where((s) => s.lotCode == 'B2').toList();
      final b3 = spaces.where((s) => s.lotCode == 'B3').toList();
      final b4 = spaces.where((s) => s.lotCode == 'B4').toList();
      final b5 = spaces.where((s) => s.lotCode == 'B5').toList();

      // Lot B1: 29 mapped = 27 confirmed formal + 2 unconfirmed far-end (L11 & R11)
      expect(b1.length, 29);
      expect(b1.where((s) => s.isFormalAllocatableBay).length, 27);
      expect(
        b1.where((s) => s.isUnconfirmed).map((s) => s.spaceCode).toSet(),
        {'B1-L11', 'B1-R11'},
      );
      // R9, R10 marked far-end; L11, R11 must NEVER be truly available
      expect(b1.firstWhere((s) => s.spaceCode == 'B1-R9').isFarEnd, isTrue);
      expect(
        b1.firstWhere((s) => s.spaceCode == 'B1-L11').isTrulyAvailableForAllocation,
        isFalse,
      );

      // Lot B2: 32 mapped = 10 motorcycle strip + 18 car bays + 4 informal aisle (A1–A4)
      expect(b2.length, 32);
      expect(b2.where((s) => s.isFormalAllocatableBay).length, 28);
      expect(
        b2.where((s) => s.compatibility == 'motorcycle_only').length,
        10,
      );
      expect(b2.where((s) => s.isInformalAisle).length, 4);
      expect(
        b2.firstWhere((s) => s.spaceCode == 'B2-L8').isPartlyOutOfView,
        isTrue,
      );
      expect(
        b2.firstWhere((s) => s.spaceCode == 'B2-R10').isPartlyOutOfView,
        isTrue,
      );
      // Occupied informal aisle bay B2-A1 never triggers formal occupancy conflict!
      expect(
        b2.firstWhere((s) => s.spaceCode == 'B2-A1').hasOccupancyConflict,
        isFalse,
      );

      // Lot B3: 23 mapped = 20 formal (incl. PWD R10 & center C1) + 3 informal aisle
      expect(b3.length, 23);
      expect(b3.where((s) => s.isFormalAllocatableBay).length, 20);
      expect(b3.where((s) => s.isInformalAisle).length, 3);
      final r10 = b3.firstWhere((s) => s.spaceCode == 'B3-R10');
      expect(r10.isAccessiblePwd, isTrue);
      final c1 = b3.firstWhere((s) => s.spaceCode == 'B3-C1');
      expect(c1.slotCategory, SpaceSlotCategory.formalCenterPainted);

      // Lot B4: Schematic pending (empty mock); dynamic JSON spaces supported
      expect(b4, isEmpty);

      // Lot B5: Overflow Lot (8 spaces)
      expect(b5.length, 8);

      // Configurable display name override from backend `zone_name`
      final customSpace = SpaceDto.fromJson({
        'space_id': '30000000-0000-4000-8000-000000000999',
        'space_code': 'B4-C01',
        'lot_code': 'B4',
        'zone_name': 'CET North Annex Lot',
        'compatibility': 'car_only',
        'physical_status': 'available',
        'allocation_status': 'unassigned',
      });
      final b4Meta =
          kCampusParkingLots.firstWhere((m) => m.lotCode == 'B4');
      expect(b4Meta.resolveName([customSpace]), 'CET North Annex Lot');
      expect(b4Meta.resolveName(const []), 'CEAFA 2');
    });

    test('computeLotSummaries produces B1–B5 & excludes non-allocatable slots from totals', () {
      final wsCoord = WsInvalidationCoordinator();
      final ctrl = SentryScenarioController(
        initialRosterMode: RosterMode.classDemo,
        wsCoordinator: wsCoord,
      );
      final summaries = ctrl.state.computeLotSummaries();
      expect(summaries.map((s) => s.lotCode).toList(), [
        'B1',
        'B2',
        'B3',
        'B4',
        'B5',
      ]);
      expect(summaries[0].totalSpaces, 27);
      expect(summaries[0].unconfirmedSpaces, 2);
      expect(summaries[1].totalSpaces, 28);
      expect(summaries[1].informalAisleSpaces, 4);
      expect(summaries[2].totalSpaces, 20);
      expect(summaries[2].informalAisleSpaces, 3);
      expect(summaries[3].isSchematicPending, isTrue);
      expect(summaries[4].isOverflow, isTrue);
      wsCoord.dispose();
    });
  });

  group('Lots B1–B5 Blueprint UI & Inspector Drawer', () {
    testWidgets('Navigates B1–B5 blueprints, renders PWD R10 / B4 pending / B5 Overflow, and opens Bay Inspector', (tester) async {
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
      await pumpFrameSettle(tester);

      await tester.tap(find.byKey(const Key('persona_admin_chip')));
      await pumpFrameSettle(tester);
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await pumpFrameSettle(tester);

      await tester.tap(find.byKey(const Key('nav_tab_parking')));
      await pumpFrameSettle(tester);

      // B1 renders unconfirmed L11/R11 + formal M4 + click B1-L1 -> Bay Inspector Drawer
      expect(find.byKey(const Key('bay_card_B1-L11')), findsOneWidget);
      expect(find.byKey(const Key('bay_card_B1-M4')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('bay_card_B1-L1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bay_card_B1-L1')));
      await pumpFrameSettle(tester);
      expect(find.text('Bay B1-L1 Inspector'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await pumpFrameSettle(tester);

      // B3 renders PWD badge on R10 & center bay C1
      await tester.ensureVisible(find.byKey(const Key('parking_tab_B3')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('parking_tab_B3')));
      await pumpFrameSettle(tester);
      expect(find.byKey(const Key('bay_card_B3-R10')), findsOneWidget);
      expect(find.text('PWD'), findsOneWidget);
      expect(find.byKey(const Key('bay_card_B3-C1')), findsOneWidget);

      // B4 shows Schematic Pending notice
      await tester.ensureVisible(find.byKey(const Key('parking_tab_B4')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('parking_tab_B4')));
      await pumpFrameSettle(tester);
      expect(
        find.textContaining('Schematic pending'),
        findsWidgets,
      );

      // B5 shows Overflow Zone pill & aggregate card (no individual slots)
      await tester.ensureVisible(find.byKey(const Key('parking_tab_B5')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('parking_tab_B5')));
      await pumpFrameSettle(tester);
      expect(find.text('Overflow Zone'), findsOneWidget);
      expect(
        find.byKey(const Key('lot_b5_overflow_aggregate_card')),
        findsOneWidget,
      );
    });
  });

  group('CSV & PDF Report Export Service, Endpoint & UI', () {
    test('LocalReportGenerator emits RFC-4180 CSV and valid %PDF-1.4 binary across all scopes', () {
      final wsCoord = WsInvalidationCoordinator();
      final ctrl = SentryScenarioController(
        initialRosterMode: RosterMode.classDemo,
        wsCoordinator: wsCoord,
      );
      final fromUtc = DateTime.utc(2026, 11, 24, 0, 0);
      final toUtc = DateTime.utc(2026, 11, 24, 23, 59);

      for (final scope in ReportExportScope.values) {
        final csvBytes = LocalReportGenerator.generateCsvBytes(
          scope: scope,
          state: ctrl.state,
          dateFromUtc: fromUtc,
          dateToUtc: toUtc,
        );
        final csvStr = utf8.decode(csvBytes);
        expect(csvStr, contains('# SENTRY Report'));
        expect(csvStr, contains(scope.label));

        final pdfBytes = LocalReportGenerator.generatePdfBytes(
          scope: scope,
          state: ctrl.state,
          dateFromUtc: fromUtc,
          dateToUtc: toUtc,
        );
        final pdfStr = latin1.decode(pdfBytes);
        expect(pdfStr.startsWith('%PDF-1.4\n'), isTrue);
        expect(pdfStr, contains('/BaseFont /Helvetica'));
        expect(pdfStr, contains('xref'));
        expect(pdfStr.endsWith('%%EOF'), isTrue);
      }
      wsCoord.dispose();
    });

    test('AccessLogsRepository.exportReportReal hits GET /api/v1/reports/export and fails closed on API error', () async {
      const cfg = AppConfig(
        appEnv: 'production',
        dataSource: DataSourceMode.real,
        initialRosterMode: RosterMode.contractSynthetic,
        apiBaseUrl: 'https://sentry.batstate-u.example',
        wsBaseUrl: 'wss://sentry.batstate-u.example/api/v1/ws/updates',
        requestTimeoutMs: 5000,
        displayTimezone: 'Asia/Manila',
      );
      final store = InMemorySessionStore();
      bool returnError = false;
      RequestOptions? seenRequest;

      final dio = Dio(BaseOptions(baseUrl: cfg.apiBaseUrl));
      dio.httpClientAdapter = _BinaryMockAdapter((options) async {
        seenRequest = options;
        if (returnError) {
          return ResponseBody.fromString(
            jsonEncode({
              'ok': false,
              'error': {
                'code': 'ACCESS_DENIED',
                'message': 'Audit logs report requires administrator role.',
              },
              'meta': {
                'request_id': 'req-export-403',
                'timestamp': '2026-11-24T03:00:00Z',
              },
            }),
            403,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromBytes(
          utf8.encode('visit_code,status\r\nVS07,active\r\n'),
          200,
          headers: {
            Headers.contentTypeHeader: ['text/csv'],
            'x-request-id': ['req-export-200'],
          },
        );
      });

      final repo = AccessLogsRepository(
        apiClient: ApiClient(config: cfg, sessionStore: store, dio: dio),
      );
      final okRes = await repo.exportReportReal(
        format: 'csv',
        scope: 'campus_visits',
        dateFromUtc: DateTime.utc(2026, 11, 24, 0, 0),
        dateToUtc: DateTime.utc(2026, 11, 24, 12, 0),
      );
      expect(seenRequest?.path, '/api/v1/reports/export');
      expect(seenRequest?.queryParameters['format'], 'csv');
      expect(seenRequest?.queryParameters['scope'], 'campus_visits');
      expect(okRes.ok, isTrue);
      expect(utf8.decode(okRes.data!), contains('VS07,active'));

      returnError = true;
      final errRes = await repo.exportReportReal(
        format: 'pdf',
        scope: 'audit_logs',
        dateFromUtc: DateTime.utc(2026, 11, 24, 0, 0),
        dateToUtc: DateTime.utc(2026, 11, 24, 12, 0),
      );
      expect(errRes.ok, isFalse);
      expect(errRes.error?.code, ErrorCatalog.accessDenied);
      expect(errRes.error?.httpStatus, 403);
    });

    testWidgets('Export Report enforces Guard vs Admin scope visibility and saves CSV & PDF bytes', (tester) async {
      tester.view.physicalSize = const Size(1600, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? savedName;
      Uint8List? savedBytes;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            devModeUnlockedProvider.overrideWith((_) => true),
            reportSaveFileOverrideProvider.overrideWith((_) {
              return (name, bytes) async {
                savedName = name;
                savedBytes = bytes;
                return 'C:\\temp\\$name';
              };
            }),
          ],
          child: const SentryDesktopApp(),
        ),
      );
      await pumpFrameSettle(tester);

      // 1. Guard signs in -> open Export dialog -> Audit Logs hidden -> saves CSV
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await pumpFrameSettle(tester);

      unawaited(
        showReportExportDialog(
          tester.element(find.byType(DesktopShell)),
          initialFormat: ReportExportFormat.csv,
          initialScope: ReportExportScope.parkingUtilization,
        ),
      );
      await pumpFrameSettle(tester);

      expect(find.byKey(const Key('export_scope_audit_logs')), findsNothing);
      await tester.tap(find.byKey(const Key('export_confirm_button')));
      await pumpFrameSettle(tester);

      expect(savedName, 'sentry_parking_utilization.csv');
      expect(utf8.decode(savedBytes!), contains('B1'));
      expect(utf8.decode(savedBytes!), contains('B5'));

      // 2. Switch to Admin -> verify Audit Logs scope is visible -> save PDF
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DesktopShell)),
      );
      await container
          .read(authControllerProvider.notifier)
          .switchDemoPersona(UserRole.administrator);
      await pumpFrameSettle(tester);

      await tester.tap(find.byKey(const Key('nav_tab_monitoring')));
      await pumpFrameSettle(tester);
      await tester.tap(find.byKey(const Key('monitoring_subtab_2')));
      await pumpFrameSettle(tester);

      await tester.tap(find.byKey(const Key('access_logs_export_report_button')));
      await pumpFrameSettle(tester);
      await tester.tap(find.byKey(const Key('export_menu_pdf')));
      await pumpFrameSettle(tester);

      expect(find.byKey(const Key('export_scope_audit_logs')), findsOneWidget);
      await tester.tap(find.byKey(const Key('export_scope_audit_logs')));
      await pumpFrameSettle(tester);
      await tester.tap(find.byKey(const Key('export_confirm_button')));
      await pumpFrameSettle(tester);

      expect(savedName, 'sentry_audit_logs.pdf');
      expect(latin1.decode(savedBytes!).startsWith('%PDF-1.4\n'), isTrue);
    });
  });
}
