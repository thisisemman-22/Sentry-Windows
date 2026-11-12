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
import '../../../shared/models/attempt_models.dart';
import '../../../shared/models/visit_models.dart';

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
  String? _selectedUserCode;
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

  ChoiceChip _buildFilterChip({
    Key? key,
    required BuildContext context,
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg =
        isDark ? const Color(0xFF18181C) : const Color(0xFFF1F5F9);
    final unselectedBorder =
        isDark ? const Color(0xFF24242A) : const Color(0xFFE2E8F0);
    final unselectedText = isDark ? Colors.white : const Color(0xFF0F172A);

    return ChoiceChip(
      key: key,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : unselectedText,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: unselectedBg,
      selectedColor: SentryColors.crimson,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: selected ? SentryColors.crimson : unselectedBorder,
      ),
      shape: const StadiumBorder(),
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
                  _buildFilterChip(
                    context: context,
                    label: 'All',
                    selected: _visitStatusFilter == 'all',
                    onSelected: (_) =>
                        setState(() => _visitStatusFilter = 'all'),
                  ),
                  _buildFilterChip(
                    context: context,
                    label: 'Inside campus',
                    selected: _visitStatusFilter == 'active',
                    onSelected: (_) =>
                        setState(() => _visitStatusFilter = 'active'),
                  ),
                  _buildFilterChip(
                    context: context,
                    label: 'Exited',
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
            EmptyState(
              icon: Icons.search_off_rounded,
              title: sysState.visits.isEmpty
                  ? 'No campus visits recorded'
                  : 'No matching visits',
              message: sysState.visits.isEmpty
                  ? 'Confirmed gate passages will appear here once vehicles enter the campus.'
                  : 'Try clearing the filter or search query.',
              action: OutlinedButton.icon(
                key: const Key('access_logs_retry_button'),
                onPressed: () {
                  ref
                      .read(sentryScenarioProvider.notifier)
                      .refreshRealSnapshot();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            )
          else
            for (var i = 0; i < filteredVisits.length; i++) ...[
              if (i > 0) Divider(color: p.line, height: 22),
              Builder(builder: (context) {
                final visit = filteredVisits[i];
                final pf = SentryFixtures.findParticipantByCode(visit.userCode);
                final vf = SentryFixtures.findVehicleByCode(visit.vehicleCode);
                final timeAndPill = Wrap(
                  spacing: 12,
                  runSpacing: 6,
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
                );

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 680;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlateBadge(
                              plateText: vf?.plateDisplay(sysState.rosterMode),
                              rfidUid: vf?.rfidUid,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pf?.displayName(sysState.rosterMode) ??
                                        visit.userCode,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${visit.userCode} · Vehicle ${visit.vehicleCode} · Bay ${visit.spaceCode ?? 'N/A'}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (!isNarrow) ...[
                              const SizedBox(width: 14),
                              timeAndPill,
                            ],
                          ],
                        ),
                        if (isNarrow) ...[
                          const SizedBox(height: 8),
                          timeAndPill,
                        ],
                      ],
                    );
                  },
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
          if (sysState.attemptHistory.isEmpty)
            EmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'No gate attempts recorded',
              message:
                  'Live entry and exit verification attempts will be logged here.',
              action: OutlinedButton.icon(
                key: const Key('attempt_history_retry_button'),
                onPressed: () {
                  ref
                      .read(sentryScenarioProvider.notifier)
                      .refreshRealSnapshot();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            )
          else
            for (var i = 0; i < sysState.attemptHistory.length; i++) ...[
            if (i > 0) Divider(color: p.line, height: 22),
            Builder(builder: (context) {
              final att = sysState.attemptHistory[i];
              final outcome = att.latestDecision?.outcome ?? 'pending';
              final pills = Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatusPill.fromDecisionOutcome(outcome),
                  StatusPill.fromAttemptState(att.state),
                ],
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 680;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PlateBadge(
                            plateText: att.plateText,
                            rfidUid: att.rfidUid,
                            isCompact: true,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
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
                          ),
                          if (!isNarrow) ...[
                            const SizedBox(width: 14),
                            pills,
                          ],
                        ],
                      ),
                      if (isNarrow) ...[
                        const SizedBox(height: 8),
                        pills,
                      ],
                    ],
                  );
                },
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
    final isMock = ref.watch(appConfigProvider).isMock;

    if (sysState.participantDirectory.isEmpty) {
      return const SentryCard(
        child: EmptyState(
          icon: Icons.badge_outlined,
          title: 'No registered drivers loaded',
          message:
              'Participant directory records will appear here once synced.',
        ),
      );
    }

    final selectedUser = _selectedUserCode != null
        ? sysState.participantDirectory
            .where((u) => u.userCode == _selectedUserCode)
            .firstOrNull
        : (isMock
            ? (sysState.participantDirectory
                    .where((u) => u.userCode == 'U007')
                    .firstOrNull ??
                sysState.participantDirectory.firstOrNull)
            : null);

    final userVehicles = selectedUser?.vehicles ?? const [];

    final matchingVisits = selectedUser == null
        ? const <VisitDto>[]
        : sysState.visits.where((v) {
            if (v.userCode != selectedUser.userCode) return false;
            if (_selectedVehicleCodeFilter != null &&
                v.vehicleCode != _selectedVehicleCodeFilter) {
              return false;
            }
            return true;
          }).toList();

    final matchingAttempts = selectedUser == null
        ? const <AttemptDto>[]
        : sysState.attemptHistory.where((a) {
            if (a.userCode != selectedUser.userCode) return false;
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
                    'Multi-vehicle owners keep separate history per vehicle.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sysState.participantDirectory.map((u) {
                  final isSelected =
                      selectedUser != null && u.userCode == selectedUser.userCode;
                  return _buildFilterChip(
                    key: Key('lookup_user_${u.userCode}'),
                    context: context,
                    label: '${u.fullName} (${u.userCode})',
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedUserCode = u.userCode;
                        _selectedVehicleCodeFilter = null;
                      });
                    },
                  );
                }).toList(),
              ),
              if (selectedUser != null) ...[
                const SizedBox(height: 22),
                Text(
                  'Vehicles registered to ${selectedUser.fullName}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildFilterChip(
                      key: const Key('filter_vehicle_all'),
                      context: context,
                      label: 'All vehicles (${userVehicles.length})',
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
                              plateText: vf.plateNumberDisplay,
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
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (selectedUser == null)
          const SentryCard(
            child: EmptyState(
              icon: Icons.person_search_outlined,
              title: 'No driver selected',
              message:
                  'Select a registered driver above to inspect their vehicles and visit history.',
            ),
          )
        else
          SentryCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: _selectedVehicleCodeFilter == null
                      ? 'History for ${selectedUser.fullName}'
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
