import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/models/audit_models.dart';

/// Admin-only `Audit` log explorer — searchable, role-filtered timeline of
/// authentication, password reset, slot overrides, guest decisions, and exports.
class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  String _searchQuery = '';
  String _roleFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final profile = ref.watch(authControllerProvider).profile;
    final isAdmin = profile?.role.isAdmin ?? false;
    if (!isAdmin) {
      return const ScreenScaffold(
        children: [
          PageIntro(
            title: 'Audit log',
            subtitle: 'Immutable administrative and security action history.',
          ),
          SizedBox(height: 18),
          RoleRestrictedPanel(
            featureName: 'System Security Audit Trail',
            minimumRole: 'administrator',
          ),
        ],
      );
    }

    final sysState = ref.watch(sentryScenarioProvider);
    final q = _searchQuery.trim().toLowerCase();
    final filtered = sysState.auditLogs.where((log) {
      if (_roleFilter != 'all' && log.actorRole != _roleFilter) return false;
      if (q.isEmpty) return true;
      return log.action.toLowerCase().contains(q) ||
          log.actorUserCode.toLowerCase().contains(q) ||
          log.resourceType.toLowerCase().contains(q) ||
          log.resourceId.toLowerCase().contains(q) ||
          log.summary.toLowerCase().contains(q);
    }).toList();

    return ScreenScaffold(
      children: [
        const PageIntro(
          title: 'Audit log',
          subtitle:
              'Immutable security & operational trail (password resets, Lot B1 manual overrides, guest decisions, exports, and device alerts).',
        ),
        const SizedBox(height: 18),
        SentryCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      key: const Key('audit_search_field'),
                      decoration: const InputDecoration(
                        labelText: 'Search action, actor, resource, or summary',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  for (final role in const ['all', 'administrator', 'guard'])
                    FilterChip(
                      key: Key('audit_role_filter_$role'),
                      label: Text(role == 'all' ? 'All roles' : role),
                      selected: _roleFilter == role,
                      onSelected: (_) => setState(() => _roleFilter = role),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const EmptyState(
                  showBrandLogo: true,
                  icon: Icons.fact_check_outlined,
                  title: 'No matching audit entries',
                  message:
                      'Audit entries appear automatically as operators act on campus resources.',
                )
              else
                for (var i = 0; i < filtered.length; i++) ...[
                  if (i > 0) Divider(color: p.line, height: 1),
                  _buildLogRow(context, p, filtered[i]),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogRow(
    BuildContext context,
    SentryPalette p,
    AuditLogDto log,
  ) {
    final prettyAction = log.action.replaceAll('_', ' ');
    return SentryRowTile(
      title: log.summary,
      subtitle:
          '${log.actorUserCode} (${log.actorRole}) · ${ManilaTime.formatDateTime(log.occurredAtUtc)}',
      badges: [
        StatusPill(
          label: prettyAction,
          tone: PillTone.info,
        ),
      ],
      onTap: () {
        showDetailsSheet<void>(
          context,
          frosted: true,
          title: prettyAction,
          subtitle: ManilaTime.formatDateTime(log.occurredAtUtc),
          builder: (ctx) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyValueRow(
                  label: 'Actor',
                  value: '${log.actorUserCode} (${log.actorRole})',
                  mono: true),
              KeyValueRow(
                  label: 'Resource',
                  value: '${log.resourceType} · ${log.resourceId}',
                  mono: true),
              KeyValueRow(label: 'Summary', value: log.summary),
              const Divider(height: 22),
              KeyValueRow(label: 'Audit ID', value: log.auditId, mono: true),
              KeyValueRow(
                  label: 'Request ID', value: log.requestId, mono: true),
              KeyValueRow(
                  label: 'Actor UUID', value: log.actorUserId, mono: true),
            ],
          ),
        );
      },
    );
  }
}
