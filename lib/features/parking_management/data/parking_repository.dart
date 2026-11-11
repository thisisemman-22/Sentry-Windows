import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';

/// Repository adapter for View 5 (`parking_management`) supporting:
/// - `GET /api/v1/parking/lots`
/// - `GET /api/v1/parking/spaces`
/// - `GET /api/v1/building-parking-priorities`
class ParkingRepository {
  final ApiClient apiClient;

  const ParkingRepository({required this.apiClient});

  Future<ApiEnvelope<List<dynamic>>> fetchBuildingPrioritiesReal() {
    return apiClient.get<List<dynamic>>(
      '/api/v1/building-parking-priorities',
      parser: (json) => json as List<dynamic>,
    );
  }
}
