import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../shared/models/audit_models.dart';
import '../../../shared/models/parking_models.dart';

/// Scoped selectors for View 2 (`overview`).
final overviewKpisProvider = Provider<DashboardDto>((ref) {
  final state = ref.watch(sentryScenarioProvider);
  return state.computeDashboardKpis();
});

final overviewLotsProvider = Provider<List<LotSummaryDto>>((ref) {
  final state = ref.watch(sentryScenarioProvider);
  return state.computeLotSummaries();
});
