import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/fixtures/scenario_simulator.dart';
import '../../../shared/models/parking_models.dart';
import '../../../shared/models/spec_2026_models.dart';
import '../../access_logs/presentation/report_export_dialog.dart';

/// Unified `Reports` workspace:
/// - Guard sees 3 presets (`Occupancy`, `Entries & Exits`, `Review Cases`)
/// - Admin sees all 6 presets (adds `Vehicles`, `Users`, `Guests`)
/// - Filters: Date Range, Lot (B1–B5), Role, Status
/// - Masked identifier preview table (no raw email/plate exposure in shared previews)
/// - CSV/PDF export saved via OS Save Dialog + recorded in Export History
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPreset _preset = ReportPreset.occupancy;
  String _dateWindow = 'Last 7 Days';
  String _lotFilter = 'All';
  String _roleFilter = 'All';
  String _statusFilter = 'All';
  bool _isExporting = false;
  String? _exportFeedback;

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final profile = ref.watch(authControllerProvider).profile;
    final isAdmin = profile?.role.isAdmin ?? false;
    final sysState = ref.watch(sentryScenarioProvider);
    final ops = ref.watch(desktopOpsControllerProvider);

    final availablePresets =
        ReportPreset.values.where((r) => isAdmin || !r.adminOnly).toList();
    if (!availablePresets.contains(_preset)) {
      _preset = availablePresets.first;
    }

    final previewRows = _buildPreviewRows(_preset, sysState, ops);

    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Reports',
          subtitle: isAdmin
              ? 'Generate filtered Occupancy, Entries & Exits, Vehicles, Users, Guests, and Review Cases reports.'
              : 'Generate Occupancy, Entries & Exits, and Review Cases operational reports.',
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('reports_export_csv_btn'),
                  onPressed: _isExporting || profile == null
                      ? null
                      : () => _exportReport('csv', previewRows, profile),
                  icon: const Icon(Icons.table_chart_outlined, size: 17),
                  label: const Text('Export CSV'),
                ),
                FilledButton.icon(
                  key: const Key('reports_export_pdf_btn'),
                  onPressed: _isExporting || profile == null
                      ? null
                      : () => _exportReport('pdf', previewRows, profile),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                  label: const Text('Export PDF'),
                ),
              ],
            ),
          ],
        ),
        if (_exportFeedback != null) ...[
          const SizedBox(height: 14),
          Callout(
            tone: PillTone.ok,
            icon: Icons.file_download_done_outlined,
            title: 'Report exported',
            message: _exportFeedback!,
          ),
        ],
        const SizedBox(height: 18),
        SentryCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Report preset & filters',
                subtitle: 'Identifiers are automatically masked in previews.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in availablePresets)
                    ChoiceChip(
                      key: Key('report_preset_${preset.wireValue}'),
                      label: Text(preset.label),
                      selected: _preset == preset,
                      onSelected: (_) => setState(() => _preset = preset),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildDropdownFilter(
                    key: const Key('report_date_window_dropdown'),
                    label: 'Date range',
                    value: _dateWindow,
                    items: const ['Today', 'Last 7 Days', 'Last 30 Days'],
                    onChanged: (v) => setState(() => _dateWindow = v),
                  ),
                  _buildDropdownFilter(
                    key: const Key('report_lot_dropdown'),
                    label: 'Lot',
                    value: _lotFilter,
                    items: [
                      'All',
                      for (final meta in kCampusParkingLots) meta.lotCode,
                    ],
                    onChanged: (v) => setState(() => _lotFilter = v),
                  ),
                  _buildDropdownFilter(
                    key: const Key('report_role_dropdown'),
                    label: 'Role',
                    value: _roleFilter,
                    items: const [
                      'All',
                      'student',
                      'faculty',
                      'staff',
                      'guard',
                      'guest',
                    ],
                    onChanged: (v) => setState(() => _roleFilter = v),
                  ),
                  _buildDropdownFilter(
                    key: const Key('report_status_dropdown'),
                    label: 'Status',
                    value: _statusFilter,
                    items: const [
                      'All',
                      'active',
                      'closed',
                      'pending',
                      'approved',
                      'denied',
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SentryCard(
          key: const Key('reports_preview_table'),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Preview — ${_preset.label}',
                subtitle:
                    '${previewRows.length > 1 ? previewRows.length - 1 : 0} row(s) matching filters.',
              ),
              const SizedBox(height: 12),
              if (previewRows.length <= 1)
                const EmptyState(
                  icon: Icons.assessment_outlined,
                  title: 'No matching report rows',
                  message:
                      'Adjust your filters or wait for live telemetry to populate rows.',
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      for (final h in previewRows.first)
                        DataColumn(
                          label: Text(
                            h,
                            style: SentryTheme.eyebrow(color: p.muted),
                          ),
                        ),
                    ],
                    rows: [
                      for (final row in previewRows.skip(1).take(15))
                        DataRow(
                          cells: [
                            for (final cell in row)
                              DataCell(
                                Text(
                                  cell,
                                  style: SentryTheme.mono(
                                    fontSize: 12.5,
                                    color: p.text,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SentryCard(
          key: const Key('reports_export_history_table'),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Export history',
                subtitle: 'CSV and PDF exports generated in this session.',
              ),
              const SizedBox(height: 12),
              if (ops.exportHistory.isEmpty)
                const EmptyState(
                  showBrandLogo: true,
                  icon: Icons.history_toggle_off_outlined,
                  title: 'No exports yet',
                  message:
                      'Use Export CSV or Export PDF above to download a report.',
                )
              else
                for (var i = 0; i < ops.exportHistory.length; i++) ...[
                  if (i > 0) Divider(color: p.line, height: 1),
                  SentryRowTile(
                    title:
                        '${ops.exportHistory[i].presetLabel} (${ops.exportHistory[i].format})',
                    subtitle:
                        'Exported by ${ops.exportHistory[i].exportedByUserCode} · ${ManilaTime.formatDateTime(ops.exportHistory[i].exportedAtUtc)}',
                    badges: [
                      StatusPill(
                        label: ops.exportHistory[i].format,
                        tone: PillTone.info,
                        monospace: true,
                      ),
                    ],
                    onTap: () => showDetailsSheet<void>(
                      context,
                      frosted: true,
                      title:
                          '${ops.exportHistory[i].presetLabel} (${ops.exportHistory[i].format})',
                      subtitle:
                          'Exported by ${ops.exportHistory[i].exportedByUserCode}',
                      builder: (ctx) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          KeyValueRow(
                            label: 'Export ID',
                            value: ops.exportHistory[i].exportId,
                            mono: true,
                          ),
                          KeyValueRow(
                            label: 'Filters applied',
                            value: ops.exportHistory[i].filterSummary,
                            mono: true,
                          ),
                          KeyValueRow(
                            label: 'Generated at',
                            value: ManilaTime.formatDateTime(
                                ops.exportHistory[i].exportedAtUtc),
                            mono: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownFilter({
    required Key key,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        key: key,
        initialValue: items.contains(value) ? value : items.first,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in items)
            DropdownMenuItem(
              value: item,
              child: Text(
                item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  List<List<String>> _buildPreviewRows(
    ReportPreset preset,
    SentrySystemState sys,
    dynamic ops,
  ) {
    switch (preset) {
      case ReportPreset.occupancy:
        final summaries = sys.computeLotSummaries().where(
              (l) => _lotFilter == 'All' || l.lotCode == _lotFilter,
            );
        return [
          const ['Lot', 'Campus Label', 'Formal Bays', 'Free', 'Occupied', 'Held'],
          for (final l in summaries)
            [
              l.lotCode,
              l.lotName,
              '${l.totalSpaces}',
              '${l.trulyAvailableSpaces}',
              '${l.physicalOccupied}',
              '${l.allocationHeld}',
            ],
        ];
      case ReportPreset.entriesExits:
        final visits = sys.visits.where((v) {
          if (_lotFilter != 'All' && v.lotCode != _lotFilter) return false;
          if (_statusFilter != 'All' && v.status != _statusFilter) return false;
          return true;
        });
        return [
          const ['Visit', 'Driver (Masked)', 'Vehicle', 'Bay', 'Status', 'Entered'],
          for (final v in visits)
            [
              v.visitCode,
              maskIdentifierForReport(v.userCode),
              v.vehicleCode,
              v.spaceCode ?? 'Pending',
              v.status,
              ManilaTime.formatDateTime(v.enteredAtUtc),
            ],
        ];
      case ReportPreset.vehicles:
        final rows = <List<String>>[
          const ['User (Masked)', 'Role', 'Vehicle', 'Plate / RFID', 'Status'],
        ];
        for (final u in sys.participantDirectory) {
          if (_roleFilter != 'All' && u.roleCode != _roleFilter) continue;
          for (final v in u.vehicles) {
            if (_statusFilter != 'All' && v.approvalStatus != _statusFilter) {
              continue;
            }
            rows.add([
              maskIdentifierForReport(u.email),
              u.roleCode,
              v.vehicleType,
              v.plateNumberDisplay ?? v.rfidUid ?? v.vehicleCode,
              v.approvalStatus,
            ]);
          }
        }
        return rows;
      case ReportPreset.users:
        return [
          const ['Code', 'Identifier (Masked)', 'Role', 'Face Status', 'Account'],
          for (final u in sys.participantDirectory.where(
              (u) => _roleFilter == 'All' || u.roleCode == _roleFilter))
            [
              u.userCode,
              maskIdentifierForReport(u.email),
              u.roleCode,
              u.faceEnrolled ? 'enrolled' : 'not_enrolled',
              u.status,
            ],
        ];
      case ReportPreset.guests:
        final reqs = ops.guestVisitRequests.where(
          (g) => _statusFilter == 'All' || g.status == _statusFilter,
        );
        return [
          const ['Guest', 'Contact (Masked)', 'Host', 'Plate', 'Status'],
          for (final g in reqs)
            [
              g.guestFullName,
              maskIdentifierForReport(g.guestEmail),
              g.hostName,
              g.plateNumber,
              g.status,
            ],
        ];
      case ReportPreset.reviewCases:
        final cases = sys.reviewQueue.where((c) {
          if (_statusFilter == 'pending' && c.isResolved) return false;
          if (_statusFilter == 'approved' && !c.isResolved) return false;
          return true;
        });
        return [
          const ['Case', 'Plate / ID', 'Reason', 'Outcome', 'Status'],
          for (final c in cases)
            [
              c.reviewCaseId,
              c.plateText ?? c.rfidUid ?? 'Unknown',
              c.reasonMessage,
              c.outcome,
              c.isResolved ? (c.resolvedAction ?? 'resolved') : 'pending',
            ],
        ];
    }
  }

  Future<void> _exportReport(
    String format,
    List<List<String>> rows,
    dynamic actor,
  ) async {
    setState(() => _isExporting = true);
    final ext = format.toLowerCase();
    final fileName =
        'sentry_${_preset.wireValue}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    final Uint8List bytes;
    if (ext == 'csv') {
      final csvText = rows
          .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
          .join('\r\n');
      bytes = Uint8List.fromList(utf8.encode('$csvText\r\n'));
    } else {
      final now = DateTime.now().toUtc();
      bytes = LocalReportGenerator.generatePdfBytes(
        scope: ReportExportScope.parkingUtilization,
        state: ref.read(sentryScenarioProvider),
        dateFromUtc: now.subtract(const Duration(days: 7)),
        dateToUtc: now,
      );
    }

    String? savedPath;
    final override = ref.read(reportSaveFileOverrideProvider);
    if (override != null) {
      savedPath = await override(fileName, bytes);
    } else {
      final location = await getSaveLocation(suggestedName: fileName);
      if (location != null) {
        await File(location.path).writeAsBytes(bytes);
        savedPath = location.path;
      }
    }

    if (!mounted) return;
    if (savedPath != null) {
      final summary = 'Window=$_dateWindow, Lot=$_lotFilter, Role=$_roleFilter, Status=$_statusFilter';
      ref.read(desktopOpsControllerProvider.notifier).recordReportExport(
            presetLabel: _preset.label,
            format: format,
            filterSummary: summary,
            actor: actor,
          );
    }
    setState(() {
      _isExporting = false;
      _exportFeedback = savedPath != null
          ? 'Saved ${format.toUpperCase()} report to $savedPath (${bytes.length} bytes).'
          : 'Export cancelled.';
    });
  }
}
