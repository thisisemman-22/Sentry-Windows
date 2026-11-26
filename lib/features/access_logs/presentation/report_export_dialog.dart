import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/fixtures/scenario_simulator.dart';

enum ReportExportFormat {
  csv('csv', 'CSV (.csv)'),
  pdf('pdf', 'PDF (.pdf)');

  final String wireValue;
  final String label;
  const ReportExportFormat(this.wireValue, this.label);
}

enum ReportDateRangePreset {
  today('Today'),
  last7Days('Last 7 Days'),
  last30Days('Last 30 Days'),
  custom('Custom');

  final String label;
  const ReportDateRangePreset(this.label);
}

enum ReportExportScope {
  campusVisits('campus_visits', 'Campus Visits', false),
  gateAttempts('gate_attempts', 'Gate Attempts', false),
  parkingUtilization(
      'parking_utilization', 'Parking Utilization Summary', false),
  auditLogs('audit_logs', 'Audit Logs', true);

  final String wireValue;
  final String label;
  final bool adminOnly;
  const ReportExportScope(this.wireValue, this.label, this.adminOnly);
}

/// Optional test hook allowing automated tests to inspect saved filenames and
/// bytes without invoking the OS native save dialog.
final reportSaveFileOverrideProvider = StateProvider<
    Future<String?> Function(String suggestedName, Uint8List bytes)?>(
  (ref) => null,
);

/// Pure Dart RFC 4180 CSV & minimal `%PDF-1.4` binary generator used ONLY in
/// Developer Test Mode when offline/unbacked by FastAPI.
class LocalReportGenerator {
  LocalReportGenerator._();

  static String _csvCell(Object? value) {
    final raw = (value ?? '').toString();
    final needsQuotes = raw.contains(',') ||
        raw.contains('"') ||
        raw.contains('\n') ||
        raw.contains('\r');
    if (!needsQuotes) return raw;
    return '"${raw.replaceAll('"', '""')}"';
  }

  static String _csvRow(List<Object?> cols) =>
      cols.map(_csvCell).join(',');

  static List<String> _buildHeadersAndRows({
    required ReportExportScope scope,
    required SentrySystemState state,
    required DateTime dateFromUtc,
    required DateTime dateToUtc,
  }) {
    final rows = <String>[];
    switch (scope) {
      case ReportExportScope.campusVisits:
        rows.add(_csvRow([
          'visit_code',
          'user_code',
          'vehicle_code',
          'lot_code',
          'space_code',
          'status',
          'entered_at_pht',
          'exited_at_pht',
        ]));
        for (final v in state.visits) {
          rows.add(_csvRow([
            v.visitCode,
            v.userCode,
            v.vehicleCode,
            v.lotCode ?? '',
            v.spaceCode ?? '',
            v.status,
            ManilaTime.formatDateTime(v.enteredAtUtc),
            ManilaTime.formatDateTime(v.exitedAtUtc),
          ]));
        }
        break;
      case ReportExportScope.gateAttempts:
        rows.add(_csvRow([
          'correlation_id',
          'lane_id',
          'direction',
          'vehicle_type',
          'user_code',
          'vehicle_code',
          'plate_or_rfid',
          'outcome',
          'state',
          'started_at_pht',
        ]));
        for (final a in state.attemptHistory) {
          rows.add(_csvRow([
            a.correlationId,
            a.laneId,
            a.direction,
            a.vehicleType,
            a.userCode ?? '',
            a.vehicleCode ?? '',
            a.plateText ?? a.rfidUid ?? '',
            a.latestDecision?.outcome ?? 'pending',
            a.state,
            ManilaTime.formatDateTime(a.startedAtUtc),
          ]));
        }
        break;
      case ReportExportScope.parkingUtilization:
        rows.add(_csvRow([
          'lot_code',
          'lot_name',
          'formal_bays',
          'free_bays',
          'occupied_bays',
          'held_bays',
          'unknown_stale',
          'conflicts',
          'informal_aisle',
        ]));
        for (final l in state.computeLotSummaries()) {
          rows.add(_csvRow([
            l.lotCode,
            l.lotName,
            l.totalSpaces,
            l.trulyAvailableSpaces,
            l.physicalOccupied,
            l.allocationHeld,
            l.physicalUnknownOrStale,
            l.conflictCount,
            l.informalAisleSpaces,
          ]));
        }
        break;
      case ReportExportScope.auditLogs:
        rows.add(_csvRow([
          'audit_id',
          'occurred_at_pht',
          'actor_user_code',
          'actor_role',
          'action',
          'resource_type',
          'request_id',
          'summary',
        ]));
        for (final log in state.auditLogs) {
          rows.add(_csvRow([
            log.auditId,
            ManilaTime.formatDateTime(log.occurredAtUtc),
            log.actorUserCode,
            log.actorRole,
            log.action,
            log.resourceType,
            log.requestId,
            log.summary,
          ]));
        }
        break;
    }
    return rows;
  }

  static Uint8List generateCsvBytes({
    required ReportExportScope scope,
    required SentrySystemState state,
    required DateTime dateFromUtc,
    required DateTime dateToUtc,
  }) {
    final lines = <String>[
      _csvRow([
        '# SENTRY Report',
        scope.label,
        'From: ${ManilaTime.formatDateTime(dateFromUtc)}',
        'To: ${ManilaTime.formatDateTime(dateToUtc)}',
      ]),
      ..._buildHeadersAndRows(
        scope: scope,
        state: state,
        dateFromUtc: dateFromUtc,
        dateToUtc: dateToUtc,
      ),
    ];
    return Uint8List.fromList(utf8.encode('${lines.join('\r\n')}\r\n'));
  }

  static String _pdfEscape(String text) {
    final ascii = text.replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
    return ascii
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }

  static Uint8List generatePdfBytes({
    required ReportExportScope scope,
    required SentrySystemState state,
    required DateTime dateFromUtc,
    required DateTime dateToUtc,
  }) {
    final rawRows = _buildHeadersAndRows(
      scope: scope,
      state: state,
      dateFromUtc: dateFromUtc,
      dateToUtc: dateToUtc,
    );

    final lines = <String>[
      'BatStateU TNEU Alangilan - SENTRY Operational Report',
      'Scope: ${scope.label}',
      'Window (Asia/Manila): ${ManilaTime.formatDateTime(dateFromUtc)} -> ${ManilaTime.formatDateTime(dateToUtc)}',
      '------------------------------------------------------------------------',
      ...rawRows,
    ];

    const linesPerPage = 42;
    final pagesLines = <List<String>>[];
    for (var i = 0; i < lines.length; i += linesPerPage) {
      pagesLines.add(
        lines.sublist(
          i,
          (i + linesPerPage > lines.length) ? lines.length : i + linesPerPage,
        ),
      );
    }

    // Object numbering:
    // 1: Catalog, 2: Pages, 3: Font (Helvetica)
    // Each page i uses objects (4 + i*2) for Page and (5 + i*2) for Content stream
    final objects = <String>[];
    final pageObjIds = <int>[];

    final pageObjects = <int, String>{};
    final contentObjects = <int, String>{};

    for (var i = 0; i < pagesLines.length; i++) {
      final pageObjId = 4 + i * 2;
      final contentObjId = 5 + i * 2;
      pageObjIds.add(pageObjId);

      final sb = StringBuffer()..writeln('BT')..writeln('/F1 9 Tf')..writeln('40 760 Td')..writeln('15 TL');
      for (final line in pagesLines[i]) {
        final clipped = line.length > 96 ? '${line.substring(0, 93)}...' : line;
        sb.writeln('(${_pdfEscape(clipped)}) Tj T*');
      }
      sb.writeln('ET');
      final streamStr = sb.toString();

      pageObjects[pageObjId] =
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents $contentObjId 0 R >>';
      contentObjects[contentObjId] =
          '<< /Length ${streamStr.length} >>\nstream\n$streamStr\nendstream';
    }

    objects.add('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
    objects.add(
      '2 0 obj\n<< /Type /Pages /Kids [${pageObjIds.map((id) => '$id 0 R').join(' ')}] /Count ${pageObjIds.length} >>\nendobj\n',
    );
    objects.add(
      '3 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
    );

    for (var i = 0; i < pagesLines.length; i++) {
      final pageObjId = 4 + i * 2;
      final contentObjId = 5 + i * 2;
      objects.add('$pageObjId 0 obj\n${pageObjects[pageObjId]}\nendobj\n');
      objects.add('$contentObjId 0 obj\n${contentObjects[contentObjId]}\nendobj\n');
    }

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (final obj in objects) {
      offsets.add(buffer.length);
      buffer.write(obj);
    }

    final xrefPos = buffer.length;
    buffer.writeln('xref');
    buffer.writeln('0 ${objects.length + 1}');
    buffer.writeln('0000000000 65535 f ');
    for (var i = 1; i < offsets.length; i++) {
      buffer.writeln('${offsets[i].toString().padLeft(10, '0')} 00000 n ');
    }
    buffer.writeln('trailer');
    buffer.writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>');
    buffer.writeln('startxref');
    buffer.writeln('$xrefPos');
    buffer.write('%%EOF');

    return Uint8List.fromList(latin1.encode(buffer.toString()));
  }
}

/// Top-right "Export Report" dropdown button (`CSV` / `PDF`) placed on Views 2 & 6.
class ExportReportMenuButton extends ConsumerWidget {
  final Key? buttonKey;
  final ReportExportScope defaultScope;

  const ExportReportMenuButton({
    super.key,
    this.buttonKey,
    this.defaultScope = ReportExportScope.campusVisits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          key: const Key('export_menu_csv'),
          leadingIcon: const Icon(Icons.table_chart_outlined, size: 18),
          onPressed: () => showReportExportDialog(
            context,
            initialFormat: ReportExportFormat.csv,
            initialScope: defaultScope,
          ),
          child: const Text('Export as CSV (.csv)'),
        ),
        MenuItemButton(
          key: const Key('export_menu_pdf'),
          leadingIcon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          onPressed: () => showReportExportDialog(
            context,
            initialFormat: ReportExportFormat.pdf,
            initialScope: defaultScope,
          ),
          child: const Text('Export as PDF (.pdf)'),
        ),
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        key: buttonKey,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Export Report'),
      ),
    );
  }
}

Future<void> showReportExportDialog(
  BuildContext context, {
  ReportExportFormat initialFormat = ReportExportFormat.csv,
  ReportExportScope initialScope = ReportExportScope.campusVisits,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReportExportDialog(
      initialFormat: initialFormat,
      initialScope: initialScope,
    ),
  );
}

class _ReportExportDialog extends ConsumerStatefulWidget {
  final ReportExportFormat initialFormat;
  final ReportExportScope initialScope;

  const _ReportExportDialog({
    required this.initialFormat,
    required this.initialScope,
  });

  @override
  ConsumerState<_ReportExportDialog> createState() =>
      _ReportExportDialogState();
}

class _ReportExportDialogState extends ConsumerState<_ReportExportDialog> {
  late ReportExportFormat _format;
  late ReportExportScope _scope;
  ReportDateRangePreset _rangePreset = ReportDateRangePreset.today;
  late DateTime _customFromLocal;
  late DateTime _customToLocal;
  bool _submitting = false;
  String? _errorText;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _format = widget.initialFormat;
    _scope = widget.initialScope;
    final nowLocal = DateTime.now();
    _customFromLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    _customToLocal = nowLocal;
  }

  (DateTime, DateTime) _resolveUtcWindow() {
    final nowUtc = DateTime.now().toUtc();
    switch (_rangePreset) {
      case ReportDateRangePreset.today:
        final startOfDayUtc =
            DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
        return (startOfDayUtc, nowUtc);
      case ReportDateRangePreset.last7Days:
        return (nowUtc.subtract(const Duration(days: 7)), nowUtc);
      case ReportDateRangePreset.last30Days:
        return (nowUtc.subtract(const Duration(days: 30)), nowUtc);
      case ReportDateRangePreset.custom:
        final start = DateTime(
          _customFromLocal.year,
          _customFromLocal.month,
          _customFromLocal.day,
        ).toUtc();
        final end = DateTime(
          _customToLocal.year,
          _customToLocal.month,
          _customToLocal.day,
          23,
          59,
          59,
        ).toUtc();
        return (start, end.isBefore(start) ? start : end);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _customFromLocal : _customToLocal;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _customFromLocal = picked;
      } else {
        _customToLocal = picked;
      }
    });
  }

  Future<void> _exportNow() async {
    setState(() {
      _submitting = true;
      _errorText = null;
      _requestId = null;
    });

    final isAdmin = ref.read(authControllerProvider).role.isAdmin;
    final effectiveScope =
        (_scope.adminOnly && !isAdmin) ? ReportExportScope.campusVisits : _scope;
    final (fromUtc, toUtc) = _resolveUtcWindow();
    final config = ref.read(appConfigProvider);
    final sysState = ref.read(sentryScenarioProvider);

    late Uint8List bytes;
    if (config.isReal) {
      final res = await ref.read(accessLogsRepositoryProvider).exportReportReal(
            format: _format.wireValue,
            scope: effectiveScope.wireValue,
            dateFromUtc: fromUtc,
            dateToUtc: toUtc,
          );
      if (!mounted) return;
      if (!res.ok || res.data == null) {
        final err = res.error;
        setState(() {
          _submitting = false;
          _errorText = err != null
              ? '${err.httpStatus} ${err.code}: ${err.message}'
              : 'Report export failed.';
          _requestId = res.meta.requestId;
        });
        return;
      }
      bytes = res.data!;
    } else {
      bytes = _format == ReportExportFormat.csv
          ? LocalReportGenerator.generateCsvBytes(
              scope: effectiveScope,
              state: sysState,
              dateFromUtc: fromUtc,
              dateToUtc: toUtc,
            )
          : LocalReportGenerator.generatePdfBytes(
              scope: effectiveScope,
              state: sysState,
              dateFromUtc: fromUtc,
              dateToUtc: toUtc,
            );
    }

    final suggestedName =
        'sentry_${effectiveScope.wireValue}.${_format.wireValue}';
    final saveOverride = ref.read(reportSaveFileOverrideProvider);
    String? savedPath;
    if (saveOverride != null) {
      savedPath = await saveOverride(suggestedName, bytes);
    } else {
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: [
          XTypeGroup(
            label: _format.label,
            extensions: <String>[_format.wireValue],
          ),
        ],
      );
      if (location != null) {
        await File(location.path).writeAsBytes(bytes, flush: true);
        savedPath = location.path;
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    if (savedPath == null) return;

    final fileName = savedPath.split(Platform.pathSeparator).last;
    showSentryToast(
      context,
      'Saved report: $fileName',
      tone: PillTone.ok,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authControllerProvider).role.isAdmin;
    final availableScopes = ReportExportScope.values
        .where((s) => isAdmin || !s.adminOnly)
        .toList();
    if (_scope.adminOnly && !isAdmin) {
      _scope = ReportExportScope.campusVisits;
    }

    return AlertDialog(
      title: const Text('Export SENTRY Report'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorText != null) ...[
                Callout(
                  tone: PillTone.err,
                  icon: Icons.error_outline_rounded,
                  title: _requestId != null
                      ? 'Export failed (Request ID: $_requestId)'
                      : 'Export failed',
                  message: _errorText!,
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Format',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in ReportExportFormat.values)
                    ChoiceChip(
                      key: Key('export_format_${f.wireValue}'),
                      label: Text(f.label),
                      selected: _format == f,
                      onSelected: _submitting
                          ? null
                          : (_) => setState(() => _format = f),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Report scope',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in availableScopes)
                    ChoiceChip(
                      key: Key('export_scope_${s.wireValue}'),
                      label: Text(
                        s.adminOnly ? '${s.label} [Admin only]' : s.label,
                      ),
                      selected: _scope == s,
                      onSelected: _submitting
                          ? null
                          : (_) => setState(() => _scope = s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Date range',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in ReportDateRangePreset.values)
                    ChoiceChip(
                      key: Key('export_range_${preset.name}'),
                      label: Text(preset.label),
                      selected: _rangePreset == preset,
                      onSelected: _submitting
                          ? null
                          : (_) => setState(() => _rangePreset = preset),
                    ),
                ],
              ),
              if (_rangePreset == ReportDateRangePreset.custom) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed:
                          _submitting ? null : () => _pickDate(isFrom: true),
                      icon: const Icon(Icons.date_range_outlined, size: 17),
                      label: Text(
                        'From: ${_customFromLocal.year}-${_customFromLocal.month.toString().padLeft(2, '0')}-${_customFromLocal.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _submitting ? null : () => _pickDate(isFrom: false),
                      icon: const Icon(Icons.date_range_outlined, size: 17),
                      label: Text(
                        'To: ${_customToLocal.year}-${_customToLocal.month.toString().padLeft(2, '0')}-${_customToLocal.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          key: const Key('export_cancel_button'),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('export_confirm_button'),
          onPressed: _submitting ? null : _exportNow,
          icon: const Icon(Icons.save_alt_rounded, size: 18),
          label: Text(_submitting ? 'Exporting…' : 'Save ${_format.label}'),
        ),
      ],
    );
  }
}
