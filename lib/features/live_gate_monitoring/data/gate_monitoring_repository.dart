import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../shared/models/visit_models.dart';

/// Repository adapter for View 3 (`live_gate_monitoring`) supporting:
/// - `GET /api/v1/access-attempts` & `GET /api/v1/access-attempts/{correlation_id}` (Patrick Carpio Contract #1)
/// - `POST /api/v1/passages/entries` & `POST /api/v1/passages/exits` (Patrick Carpio Contract #3)
/// - `POST /api/v1/access-attempts/{correlation_id}/cancel`
class GateMonitoringRepository {
  final ApiClient apiClient;

  const GateMonitoringRepository({required this.apiClient});

  Future<ApiEnvelope<Map<String, dynamic>>> confirmEntryPassageReal(
    PassageConfirmationRequest request,
  ) {
    return apiClient.post<Map<String, dynamic>>(
      '/api/v1/passages/entries',
      body: request.toJson(),
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> confirmExitPassageReal(
    PassageConfirmationRequest request,
  ) {
    return apiClient.post<Map<String, dynamic>>(
      '/api/v1/passages/exits',
      body: request.toJson(),
      parser: (json) => json as Map<String, dynamic>,
    );
  }
}
