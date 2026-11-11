import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';

/// Repository adapter for View 8 (`administration`) supporting:
/// - `GET /api/v1/admin/audit-logs` (Administrator Only)
/// - `P01–P06` `/api/v1/participants/...` (Administrator Only; `admission_evaluated: false`)
class AdministrationRepository {
  final ApiClient apiClient;

  const AdministrationRepository({required this.apiClient});

  Future<ApiEnvelope<List<dynamic>>> fetchAuditLogsReal({
    int limit = 50,
    String? cursor,
  }) {
    return apiClient.get<List<dynamic>>(
      '/api/v1/admin/audit-logs',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
      parser: (json) => json as List<dynamic>,
    );
  }
}
