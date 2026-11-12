import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../shared/models/review_models.dart';

/// Repository adapter for View 4 (`guard_reviews`) supporting:
/// - `GET /api/v1/guard-reviews`
/// - `POST /api/v1/guard-reviews` (with `expected_attempt_version` optimistic concurrency check)
class GuardReviewsRepository {
  final ApiClient apiClient;

  const GuardReviewsRepository({required this.apiClient});

  Future<ApiEnvelope<List<GuardReviewQueueItem>>> fetchGuardReviewsReal({
    bool? resolved,
    int limit = 50,
  }) {
    return apiClient.get<List<GuardReviewQueueItem>>(
      '/api/v1/guard-reviews',
      queryParameters: {
        'limit': limit,
        if (resolved != null) 'resolved': resolved,
      },
      parser: (json) => (json as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(GuardReviewQueueItem.fromJson)
          .toList(),
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> submitGuardReviewReal(
    GuardReviewSubmission submission,
  ) {
    return apiClient.post<Map<String, dynamic>>(
      '/api/v1/guard-reviews',
      body: submission.toJson(),
      parser: (json) => json as Map<String, dynamic>,
    );
  }
}
