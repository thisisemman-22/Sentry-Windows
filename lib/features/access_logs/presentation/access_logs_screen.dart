import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/theme/sentry_colors.dart';
import '../../../core/theme/sentry_theme.dart';
import '../../../core/widgets/plate_badge.dart';
import '../../../core/widgets/ui/sentry_ui.dart';
import '../../../shared/fixtures/synthetic_fixtures.dart';

/// View 6: `Access Logs` — clean, searchable history of campus visits, gate
/// attempts, and registered drivers/vehicles.
class AccessLogsScreen extends ConsumerStatefulWidget {
  const AccessLogsScreen({super.key});

  @override
  ConsumerState<AccessLogsScreen> createState() => _AccessLogsScreenState();
}

class _AccessLogsScreenState extends ConsumerState<AccessLogsScreen> {
  int _activeSubTab = 0; // 0: Visits, 1: Attempts, 2: Drivers & vehicles
  String _visitStatusFilter = 'all'; // 'all' | 'active' | 'closed'
  String _searchQuery = '';
  String _selectedUserCode = 'U007'; // Showcases V007 & V008 independence
  String? _selectedVehicleCodeFilter;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      children: [
        PageIntro(
          title: 'Access logs',
          subtitle:
              'Search confirmed campus stays, gate attempts, and registered vehicles.',
          actions: [
            SegmentTabs(
              keyPrefix: 'access_logs_subtab',
              labels: const [
                'Campus visits',
                'Gate attempts',
                'Drivers & vehicles',
              ],
              icons: const [
                Icons.directions_car_filled_outlined,
                Icons.history_rounded,
                Icons.badge_outlined,
              ],
              selected: _activeSubTab,
              onChanged: (i) => setState(() => _activeSubTab = i),
            ),
          ],
        ),
        const SizedBox(height: 24),

        SmoothSwitcher(
          switchKey: _activeSubTab,
          child: switch (_activeSubTab) {
            0 => _buildConfirmedVisitsTab(context),
            1 => _buildAttemptHistoryTab(context),
            _ => _buildParticipantMultiVehicleLookupTab(context),
          },
        ),
      ],
    );
  }

  Widget _buildConfirmedVisitsTab(BuildContext context) {
    final p = SentryPalette.of(context);
    final sysState = ref.watch(sentryScenarioProvider);

    final filteredVisits = sysState.visits.where((v) {
      if (_visitStatusFilter == 'active' && !v.isActive) return false;
      if (_visitStatusFilter == 'closed' && v.isActive) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toUpperCase();
        final vf = SentryFixtures.findVehicleByCode(v.vehicleCode);
        final pf = SentryFixtures.findParticipantByCode(v.userCode);
        final plate =
            vf?.plateDisplay(sysState.rosterMode)?.toUpperCase() ?? '';
        final name = pf?.displayName(sysState.rosterMode).toUpperCase() ?? '';
        if (!v.userCode.contains(q) &&
            !v.vehicleCode.contains(q) &&
            !v.visitCode.contains(q) &&
            !plate.contains(q) &&
            !name.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return SentryCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, size: 19),
                    hintText: 'Search by driver, plate or vehicle code…',
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _visitStatusFilter == 'all',
                    onSelected: (_) =>
                        setState(() => _visitStatusFilter = 'all'),
                  ),
                  ChoiceChip(
                    label: const Text('Inside campus'),
                    selected: _visitStatusFilter == 'active',
                    onSelected: (_) =>
                        setState(() => _visitStatusFilter = 'active'),
                  ),
                  ChoiceChip(
                    label: const Text('Exited'),
                    selected: _visitStatusFilter == 'closed',
                    onSelected: (_) =>
                        setState(() => _visitStatusFilter = 'closed'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (filteredVisits.isEmpty)
            const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching visits',
              message: 'Try clearing the filter or search query.',
            )
          else
            for (var i = 0; i < filteredVisits.length; i++) ...[
              if (i > 0) Divider(color: p.line, height: 22),
              Builder(builder: (context) {
                final visit = filteredVisits[i];
                final pf = SentryFixtures.findParticipantByCode(visit.userCode);
                final vf = SentryFixtures.findVehicleByCode(visit.vehicleCode);
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlateBadge(
                          plateText: vf?.plateDisplay(sysState.rosterMode),
                          rfidUid: vf?.rfidUid,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pf?.displayName(sysState.rosterMode) ??
                                  visit.userCode,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${visit.userCode} · Vehicle ${visit.vehicleCode} · Bay ${visit.spaceCode ?? 'N/A'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          visit.isActive
                              ? 'Entered ${ManilaTime.formatTimeOnly(visit.enteredAtUtc)} · ${ManilaTime.formatDuration(visit.duration())}'
                              : '${ManilaTime.formatTimeOnly(visit.enteredAtUtc)} – ${ManilaTime.formatTimeOnly(visit.exitedAtUtc)}',
                          style: SentryTheme.mono(
                            fontSize: 13,
                            color: p.slate,
                          ),
                        ),
                        StatusPill(
                          label: visit.isActive ? 'Inside campus' : 'Exited',
                          tone: visit.isActive ? PillTone.ok : PillTone.neutral,
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ],
        ],
      ),
    );
  }

  Widget _buildAttemptHistoryTab(BuildContext context) {
    final p = SentryPalette.of(context);
    final sysState = ref.watch(sentryScenarioProvider);

    return SentryCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Gate attempts',
            subtitle:
                'Every entry and exit check, including denied and expired holds.',
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < sysState.attemptHistory.length; i++) ...[
            if (i > 0) Divider(color: p.line, height: 22),
            Builder(builder: (context) {
              final att = sysState.attemptHistory[i];
              final outcome = att.latestDecision?.outcome ?? 'pending';
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 10,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlateBadge(
                        plateText: att.plateText,
                        rfidUid: att.rfidUid,
                        isCompact: true,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            att.latestDecision?.reasonMessage ?? att.state,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${att.userCode ?? 'Unregistered'} · ${att.vehicleCode ?? 'Unknown vehicle'} · ${att.laneId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      StatusPill.fromDecisionOutcome(outcome),
                      StatusPill.fromAttemptState(att.state),
                    ],
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantMultiVehicleLookupTab(BuildContext context) {
    final p = SentryPalette.of(context);
    final sysState = ref.watch(sentryScenarioProvider);
    final selectedUser =
        SentryFixtures.findParticipantByCode(_selectedUserCode)!;
    final userVehicles = SentryFixtures.vehiclesForUser(_selectedUserCode);

    final matchingVisits = sysState.visits.where((v) {
      if (v.userCode != _selectedUserCode) return false;
      if (_selectedVehicleCodeFilter != null &&
          v.vehicleCode != _selectedVehicleCodeFilter) {
        return false;
      }
      return true;
    }).toList();

    final matchingAttempts = sysState.attemptHistory.where((a) {
      if (a.userCode != _selectedUserCode) return false;
      if (_selectedVehicleCodeFilter != null &&
          a.vehicleCode != _selectedVehicleCodeFilter) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SentryCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Select a registered driver',
                subtitle:
                    'Multi-vehicle owners (such as U007 with V007 and V008) keep separate history per vehicle.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SentryFixtures.participants.map((pf) {
                  final isSelected = pf.userCode == _selectedUserCode;
                  return ChoiceChip(
                    key: Key('lookup_user_${pf.userCode}'),
                    label: Text(
                      '${pf.displayName(sysState.rosterMode)} (${pf.userCode})',
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedUserCode = pf.userCode;
                        _selectedVehicleCodeFilter = null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              Text(
                'Vehicles registered to ${selectedUser.displayName(sysState.rosterMode)}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    key: const Key('filter_vehicle_all'),
                    label: Text('All vehicles (${userVehicles.length})'),
                    selected: _selectedVehicleCodeFilter == null,
                    onSelected: (_) =>
                        setState(() => _selectedVehicleCodeFilter = null),
                  ),
                  ...userVehicles.map((vf) {
                    final isVehSelected =
                        _selectedVehicleCodeFilter == vf.vehicleCode;
                    return SentryCard(
                      key: Key('vehicle_card_${vf.vehicleCode}'),
                      selected: isVehSelected,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      radius: 14,
                      color: isVehSelected ? p.crimsonTint : p.subtle,
                      onTap: () {
                        setState(() {
                          _selectedVehicleCodeFilter = vf.vehicleCode;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            vf.vehicleType == 'motorcycle'
                                ? Icons.two_wheeler_rounded
                                : Icons.directions_car_rounded,
                            size: 18,
                            color: isVehSelected ? p.crimson : p.slate,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            vf.vehicleCode,
                            style: SentryTheme.mono(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: p.text,
                            ),
                          ),
                          const SizedBox(width: 10),
                          PlateBadge(
                            plateText: vf.plateDisplay(sysState.rosterMode),
                            rfidUid: vf.rfidUid,
                            isCompact: true,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SentryCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: _selectedVehicleCodeFilter == null
                    ? 'History for ${selectedUser.displayName(sysState.rosterMode)}'
                    : 'History for vehicle $_selectedVehicleCodeFilter',
              ),
              const SizedBox(height: 14),
              if (matchingVisits.isEmpty && matchingAttempts.isEmpty)
                const EmptyState(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'No visits or attempts yet',
                  message:
                      'Records for this selection will appear here as vehicles pass the gate.',
                ),
              for (final v in matchingVisits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      StatusPill(
                        label: v.isActive ? 'Inside campus' : 'Exited',
                        tone: v.isActive ? PillTone.ok : PillTone.neutral,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Vehicle ${v.vehicleCode} · Bay ${v.spaceCode} · Entered ${ManilaTime.formatShort(v.enteredAtUtc)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final a in matchingAttempts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      StatusPill.fromDecisionOutcome(
                        a.latestDecision?.outcome ?? 'denied',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Vehicle ${a.vehicleCode} · ${a.latestDecision?.reasonMessage ?? a.state}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
