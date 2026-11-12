import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../shared/models/audit_models.dart';
import '../../../shared/models/parking_models.dart';

/// Repository adapter for View 2 (`overview`) supporting `GET /api/v1/dashboard`.
class OverviewRepository {
  final ApiClient apiClient;

  const OverviewRepository({required this.apiClient});

  Future<ApiEnvelope<DashboardDto>> fetchDashboardReal() {
    return apiClient.get<DashboardDto>(
      '/api/v1/dashboard',
      parser: (json) => DashboardDto.fromJson(json as Map<String, dynamic>),
    );
  }
}

/// Scoped selectors for View 2 (`overview`).
final overviewKpisProvider = Provider<DashboardDto>((ref) {
  final state = ref.watch(sentryScenarioProvider);
  return state.computeDashboardKpis();
});

final overviewLotsProvider = Provider<List<LotSummaryDto>>((ref) {
  final state = ref.watch(sentryScenarioProvider);
  return state.computeLotSummaries();
});
