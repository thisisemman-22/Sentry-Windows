import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';

/// Repository adapter for View 7 (`device_monitoring`) supporting:
/// - `GET /api/v1/devices` (D01–D07 registered producers)
class DeviceMonitoringRepository {
  final ApiClient apiClient;

  const DeviceMonitoringRepository({required this.apiClient});

  Future<ApiEnvelope<List<dynamic>>> fetchDevicesReal() {
    return apiClient.get<List<dynamic>>(
      '/api/v1/devices',
      parser: (json) => json as List<dynamic>,
    );
  }
}
