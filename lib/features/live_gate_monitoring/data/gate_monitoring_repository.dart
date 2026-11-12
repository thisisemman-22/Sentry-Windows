import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../shared/models/attempt_models.dart';
import '../../../shared/models/visit_models.dart';

/// Repository adapter for View 3 (`live_gate_monitoring`) supporting:
/// - `GET /api/v1/access-attempts`
/// - `GET /api/v1/access-attempts/{correlation_id}` (Patrick Carpio Contract #1: extended with
///   `plate_text`, `ocr_confidence`, `detection_confidence`, `rfid_uid`, `face_recognition_status`, `face_similarity_score`)
/// - `POST /api/v1/access-attempts/{correlation_id}/cancel`
/// - `POST /api/v1/passages/entries` & `POST /api/v1/passages/exits` (Patrick Carpio Contract #3)
class GateMonitoringRepository {
  final ApiClient apiClient;

  const GateMonitoringRepository({required this.apiClient});

  Future<ApiEnvelope<List<AttemptDto>>> fetchAccessAttemptsReal({
    String? gateId,
    String? laneId,
    String? state,
    int limit = 50,
  }) {
    return apiClient.get<List<AttemptDto>>(
      '/api/v1/access-attempts',
      queryParameters: {
        'limit': limit,
        if (gateId != null) 'gate_id': gateId,
        if (laneId != null) 'lane_id': laneId,
        if (state != null) 'state': state,
      },
      parser: (json) => (json as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(AttemptDto.fromJson)
          .toList(),
    );
  }

  Future<ApiEnvelope<AttemptDto>> fetchAccessAttemptByIdReal(
    String correlationId,
  ) {
    return apiClient.get<AttemptDto>(
      '/api/v1/access-attempts/$correlationId',
      parser: (json) => AttemptDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<ApiEnvelope<AttemptDto>> cancelAccessAttemptReal({
    required String correlationId,
    required String reason,
  }) {
    return apiClient.post<AttemptDto>(
      '/api/v1/access-attempts/$correlationId/cancel',
      body: {'reason': reason.trim()},
      parser: (json) => AttemptDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<ApiEnvelope<VisitDto>> confirmEntryPassageReal(
    PassageConfirmationRequest request,
  ) {
    return apiClient.post<VisitDto>(
      '/api/v1/passages/entries',
      body: request.toJson(),
      parser: (json) => VisitDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<ApiEnvelope<VisitDto>> confirmExitPassageReal(
    PassageConfirmationRequest request,
  ) {
    return apiClient.post<VisitDto>(
      '/api/v1/passages/exits',
      body: request.toJson(),
      parser: (json) => VisitDto.fromJson(json as Map<String, dynamic>),
    );
  }
}
