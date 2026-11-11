import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';

/// Repository adapter for View 6 (`access_logs`) supporting:
/// - `GET /api/v1/access-visits` (Patrick Carpio Confirmed Contract #2: Guard/Admin paginated campus visits)
/// - `GET /api/v1/access-attempts`
class AccessLogsRepository {
  final ApiClient apiClient;

  const AccessLogsRepository({required this.apiClient});

  Future<ApiEnvelope<List<dynamic>>> fetchCampusVisitsReal({
    int limit = 50,
    String? cursor,
    String? status,
    String? vehicleCode,
    String? userCode,
    String? gateId,
  }) {
    return apiClient.get<List<dynamic>>(
      '/api/v1/access-visits',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (status != null) 'status': status,
        if (vehicleCode != null) 'vehicle_code': vehicleCode,
        if (userCode != null) 'user_code': userCode,
        if (gateId != null) 'gate_id': gateId,
      },
      parser: (json) => json as List<dynamic>,
    );
  }
}
