import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../shared/models/visit_models.dart';

/// Repository adapter for View 6 (`access_logs`) supporting:
/// - `GET /api/v1/access-visits` (with `limit`, `cursor`, `date_from`, `date_to`,
///   `status`, `vehicle_code`, `user_code`, `gate_id`)
/// - `GET /api/v1/access-visits/{visit_id}`
class AccessLogsRepository {
  final ApiClient apiClient;

  const AccessLogsRepository({required this.apiClient});

  Future<ApiEnvelope<List<VisitDto>>> fetchCampusVisitsReal({
    int limit = 50,
    String? cursor,
    DateTime? dateFromUtc,
    DateTime? dateToUtc,
    String? status,
    String? vehicleCode,
    String? userCode,
    String? gateId,
  }) {
    return apiClient.get<List<VisitDto>>(
      '/api/v1/access-visits',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (dateFromUtc != null)
          'date_from': ManilaTime.toUtcIso(dateFromUtc),
        if (dateToUtc != null) 'date_to': ManilaTime.toUtcIso(dateToUtc),
        if (status != null) 'status': status,
        if (vehicleCode != null) 'vehicle_code': vehicleCode,
        if (userCode != null) 'user_code': userCode,
        if (gateId != null) 'gate_id': gateId,
      },
      parser: (json) => (json as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(VisitDto.fromJson)
          .toList(),
    );
  }

  Future<ApiEnvelope<VisitDto>> fetchVisitByIdReal(String visitId) {
    return apiClient.get<VisitDto>(
      '/api/v1/access-visits/$visitId',
      parser: (json) => VisitDto.fromJson(json as Map<String, dynamic>),
    );
  }
}
