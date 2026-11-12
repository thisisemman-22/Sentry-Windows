import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../shared/models/parking_models.dart';

/// Repository adapter for View 5 (`parking_management`) supporting:
/// - `GET /api/v1/parking-availability`
/// - `GET /api/v1/building-parking-priorities`
class ParkingRepository {
  final ApiClient apiClient;

  const ParkingRepository({required this.apiClient});

  Future<ApiEnvelope<List<SpaceDto>>> fetchParkingAvailabilityReal({
    String? lotCode,
    String? compatibility,
  }) {
    return apiClient.get<List<SpaceDto>>(
      '/api/v1/parking-availability',
      queryParameters: {
        if (lotCode != null) 'lot_code': lotCode,
        if (compatibility != null) 'compatibility': compatibility,
      },
      parser: (json) {
        if (json is List<dynamic>) {
          return json
              .whereType<Map<String, dynamic>>()
              .map(SpaceDto.fromJson)
              .toList();
        }
        if (json is Map<String, dynamic> && json['spaces'] is List<dynamic>) {
          return (json['spaces'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(SpaceDto.fromJson)
              .toList();
        }
        return const <SpaceDto>[];
      },
    );
  }

  Future<ApiEnvelope<List<BuildingPriorityRow>>> fetchBuildingPrioritiesReal() {
    return apiClient.get<List<BuildingPriorityRow>>(
      '/api/v1/building-parking-priorities',
      parser: (json) => (json as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(BuildingPriorityRow.fromJson)
          .toList(),
    );
  }
}
