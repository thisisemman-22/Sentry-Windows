import '../../core/network/api_envelope.dart';

/// Registered Edge & AI Producer Device DTO (`GET /api/v1/devices` — D01 through D07).
/// Derived status rules:
/// - Heartbeat interval: 10s
/// - Offline threshold: > 30s without heartbeat -> `offline`
class DeviceDto {
  final String deviceCode; // D01..D07
  final String producerId; // e.g. 'plate-entry-01'
  final String deviceType; // 'plate_adapter'|'face_adapter'|'rfid_reader'|'occupancy_camera'|'guard_client'
  final String displayName;
  final String locationLabel;
  final String reportedStatus; // 'online' | 'degraded' | 'offline'
  final String bootId;
  final int sequenceNumber;
  final int uptimeSeconds;
  final String softwareVersion;
  final List<String> capabilities;
  final DateTime lastReceivedAtUtc;
  final String? lastErrorCode;
  final String? mappedLotCode; // For occupancy cameras ('A'|'B'|'C'|'D')

  const DeviceDto({
    required this.deviceCode,
    required this.producerId,
    required this.deviceType,
    required this.displayName,
    required this.locationLabel,
    required this.reportedStatus,
    required this.bootId,
    required this.sequenceNumber,
    required this.uptimeSeconds,
    required this.softwareVersion,
    required this.capabilities,
    required this.lastReceivedAtUtc,
    this.lastErrorCode,
    this.mappedLotCode,
  });

  /// Derives effective status based on the 30-second heartbeat timeout rule.
  String effectiveStatus([DateTime? nowUtc]) {
    if (reportedStatus == 'offline') return 'offline';
    final check = (nowUtc ?? DateTime.now()).toUtc();
    final elapsedSeconds = check.difference(lastReceivedAtUtc).inSeconds;
    if (elapsedSeconds > 30) {
      return 'offline';
    }
    return reportedStatus;
  }

  DeviceDto copyWith({
    String? reportedStatus,
    String? bootId,
    int? sequenceNumber,
    int? uptimeSeconds,
    DateTime? lastReceivedAtUtc,
    String? lastErrorCode,
    bool clearError = false,
  }) {
    return DeviceDto(
      deviceCode: deviceCode,
      producerId: producerId,
      deviceType: deviceType,
      displayName: displayName,
      locationLabel: locationLabel,
      reportedStatus: reportedStatus ?? this.reportedStatus,
      bootId: bootId ?? this.bootId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      softwareVersion: softwareVersion,
      capabilities: capabilities,
      lastReceivedAtUtc: lastReceivedAtUtc ?? this.lastReceivedAtUtc,
      lastErrorCode: clearError ? null : (lastErrorCode ?? this.lastErrorCode),
      mappedLotCode: mappedLotCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'device_code': deviceCode,
        'producer_id': producerId,
        'device_type': deviceType,
        'display_name': displayName,
        'location_label': locationLabel,
        'status': reportedStatus,
        'boot_id': bootId,
        'sequence_number': sequenceNumber,
        'uptime_seconds': uptimeSeconds,
        'software_version': softwareVersion,
        'capabilities': capabilities,
        'last_received_at': ManilaTime.toUtcIso(lastReceivedAtUtc),
        if (lastErrorCode != null) 'last_error_code': lastErrorCode,
        if (mappedLotCode != null) 'mapped_lot_code': mappedLotCode,
      };
}
