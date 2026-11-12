import '../../core/network/api_envelope.dart';

/// Parking Space DTO enforcing Invariant #3:
/// - `physicalStatus`: `available` | `occupied` | `unknown` (from overhead camera AI)
/// - `allocationStatus`: `unassigned` | `held` | `assigned` (from backend reservations/visits)
/// - `compatibility`: strictly `car_only` or `motorcycle_only` (flags any legacy `mixed` value as config warning)
/// - CRITICAL: `unknown` or `isStale: true` MUST NEVER be displayed or treated as available/empty!
class SpaceDto {
  final String spaceId;
  final String spaceCode; // e.g. 'A-C01', 'B-C04', 'C-M01'
  final String lotCode; // 'A' | 'B' | 'C' | 'D'
  final String compatibility; // 'car_only' | 'motorcycle_only'
  final String physicalStatus; // 'available' | 'occupied' | 'unknown'
  final String allocationStatus; // 'unassigned' | 'held' | 'assigned'
  final double? confidence;
  final DateTime? lastObservedAtUtc;
  final bool isStale;
  final String? producerId;
  final String? assignmentId;
  final String? visitId; // null when held!
  final String? assignedVehicleCode;
  final String? assignedUserCode;
  final DateTime? holdExpiresAtUtc;
  final Map<String, int> buildingDistanceMeters;

  const SpaceDto({
    required this.spaceId,
    required this.spaceCode,
    required this.lotCode,
    required this.compatibility,
    required this.physicalStatus,
    required this.allocationStatus,
    this.confidence,
    this.lastObservedAtUtc,
    this.isStale = false,
    this.producerId,
    this.assignmentId,
    this.visitId,
    this.assignedVehicleCode,
    this.assignedUserCode,
    this.holdExpiresAtUtc,
    this.buildingDistanceMeters = const {},
  });

  /// True ONLY when camera feed is fresh, physical status is `available`,
  /// and backend allocation status is `unassigned`.
  /// `unknown` or `isStale` spaces are NEVER treated as available!
  bool get isTrulyAvailableForAllocation =>
      !isStale &&
      physicalStatus == 'available' &&
      allocationStatus == 'unassigned' &&
      !hasLegacyCompatibilityWarning;

  /// Detects if a space is physically occupied while backend thinks it is `unassigned` or `held`.
  bool get hasOccupancyConflict =>
      !isStale &&
      physicalStatus == 'occupied' &&
      (allocationStatus == 'unassigned' || allocationStatus == 'held');

  /// Per `PARKING_COMPATIBILITY_REQUIREMENTS.md`, only `car_only` and `motorcycle_only` are valid.
  bool get hasLegacyCompatibilityWarning =>
      compatibility != 'car_only' && compatibility != 'motorcycle_only';

  bool get isUnknownOrStale => isStale || physicalStatus == 'unknown';

  SpaceDto copyWith({
    String? compatibility,
    String? physicalStatus,
    String? allocationStatus,
    double? confidence,
    DateTime? lastObservedAtUtc,
    bool? isStale,
    String? assignmentId,
    bool clearAssignment = false,
    String? visitId,
    bool clearVisit = false,
    String? assignedVehicleCode,
    String? assignedUserCode,
    DateTime? holdExpiresAtUtc,
  }) {
    return SpaceDto(
      spaceId: spaceId,
      spaceCode: spaceCode,
      lotCode: lotCode,
      compatibility: compatibility ?? this.compatibility,
      physicalStatus: physicalStatus ?? this.physicalStatus,
      allocationStatus: allocationStatus ?? this.allocationStatus,
      confidence: confidence ?? this.confidence,
      lastObservedAtUtc: lastObservedAtUtc ?? this.lastObservedAtUtc,
      isStale: isStale ?? this.isStale,
      producerId: producerId,
      assignmentId:
          clearAssignment ? null : (assignmentId ?? this.assignmentId),
      visitId: clearVisit ? null : (visitId ?? this.visitId),
      assignedVehicleCode: clearAssignment
          ? null
          : (assignedVehicleCode ?? this.assignedVehicleCode),
      assignedUserCode:
          clearAssignment ? null : (assignedUserCode ?? this.assignedUserCode),
      holdExpiresAtUtc:
          clearAssignment ? null : (holdExpiresAtUtc ?? this.holdExpiresAtUtc),
      buildingDistanceMeters: buildingDistanceMeters,
    );
  }

  factory SpaceDto.fromJson(Map<String, dynamic> json) {
    final distMap = <String, int>{};
    final rawDist = json['building_distance_meters'];
    if (rawDist is Map) {
      rawDist.forEach((k, v) {
        if (k != null && v is num) {
          distMap[k.toString()] = v.toInt();
        }
      });
    }
    return SpaceDto(
      spaceId: json['space_id']?.toString() ?? '',
      spaceCode: json['space_code']?.toString() ?? '',
      lotCode: json['lot_code']?.toString() ?? 'A',
      compatibility: json['compatibility']?.toString() ?? 'car_only',
      physicalStatus: json['physical_status']?.toString() ?? 'unknown',
      allocationStatus: json['allocation_status']?.toString() ?? 'unassigned',
      confidence: (json['confidence'] as num?)?.toDouble(),
      lastObservedAtUtc: json['last_observed_at'] != null
          ? DateTime.tryParse(json['last_observed_at'].toString())?.toUtc()
          : null,
      isStale: json['is_stale'] == true,
      producerId: json['producer_id']?.toString(),
      assignmentId: json['assignment_id']?.toString(),
      visitId: json['visit_id']?.toString(),
      assignedVehicleCode: json['assigned_vehicle_code']?.toString(),
      assignedUserCode: json['assigned_user_code']?.toString(),
      holdExpiresAtUtc: json['hold_expires_at'] != null
          ? DateTime.tryParse(json['hold_expires_at'].toString())?.toUtc()
          : null,
      buildingDistanceMeters: distMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'space_id': spaceId,
        'space_code': spaceCode,
        'lot_code': lotCode,
        'compatibility': compatibility,
        'physical_status': physicalStatus,
        'allocation_status': allocationStatus,
        'confidence': confidence,
        'last_observed_at': lastObservedAtUtc != null
            ? ManilaTime.toUtcIso(lastObservedAtUtc!)
            : null,
        'is_stale': isStale,
        'producer_id': producerId,
        'assignment_id': assignmentId,
        'visit_id': visitId,
        'assigned_vehicle_code': assignedVehicleCode,
        'assigned_user_code': assignedUserCode,
      };
}

class LotSummaryDto {
  final String lotCode; // 'A' | 'B' | 'C' | 'D'
  final String lotName;
  final String nearestLandmark;
  final int totalSpaces;
  final int physicalAvailable;
  final int physicalOccupied;
  final int physicalUnknownOrStale;
  final int allocationUnassigned;
  final int allocationHeld;
  final int allocationAssigned;
  final int conflictCount;
  final bool cameraStale;

  const LotSummaryDto({
    required this.lotCode,
    required this.lotName,
    required this.nearestLandmark,
    required this.totalSpaces,
    required this.physicalAvailable,
    required this.physicalOccupied,
    required this.physicalUnknownOrStale,
    required this.allocationUnassigned,
    required this.allocationHeld,
    required this.allocationAssigned,
    required this.conflictCount,
    required this.cameraStale,
  });

  factory LotSummaryDto.fromSpaces({
    required String lotCode,
    required String lotName,
    required String nearestLandmark,
    required List<SpaceDto> spaces,
  }) {
    final lotSpaces = spaces.where((s) => s.lotCode == lotCode).toList();
    int physAvail = 0;
    int physOcc = 0;
    int physUnk = 0;
    int allocUnassigned = 0;
    int allocHeld = 0;
    int allocAssigned = 0;
    int conflicts = 0;
    bool anyStale = false;

    for (final s in lotSpaces) {
      if (s.isUnknownOrStale) {
        physUnk++;
        if (s.isStale) anyStale = true;
      } else if (s.physicalStatus == 'available') {
        physAvail++;
      } else if (s.physicalStatus == 'occupied') {
        physOcc++;
      }

      if (s.allocationStatus == 'unassigned') {
        allocUnassigned++;
      } else if (s.allocationStatus == 'held') {
        allocHeld++;
      } else if (s.allocationStatus == 'assigned') {
        allocAssigned++;
      }

      if (s.hasOccupancyConflict) {
        conflicts++;
      }
    }

    return LotSummaryDto(
      lotCode: lotCode,
      lotName: lotName,
      nearestLandmark: nearestLandmark,
      totalSpaces: lotSpaces.length,
      physicalAvailable: physAvail,
      physicalOccupied: physOcc,
      physicalUnknownOrStale: physUnk,
      allocationUnassigned: allocUnassigned,
      allocationHeld: allocHeld,
      allocationAssigned: allocAssigned,
      conflictCount: conflicts,
      cameraStale: anyStale,
    );
  }
}

class BuildingPriorityRow {
  final String buildingCode;
  final String buildingName;
  final List<String> orderedLots; // e.g. ['A', 'B', 'C', 'D']

  const BuildingPriorityRow({
    required this.buildingCode,
    required this.buildingName,
    required this.orderedLots,
  });

  factory BuildingPriorityRow.fromJson(Map<String, dynamic> json) {
    final lots = json['ordered_lots'] ?? json['lots'];
    return BuildingPriorityRow(
      buildingCode: json['building_code']?.toString() ?? '',
      buildingName: json['building_name']?.toString() ?? '',
      orderedLots: lots is List
          ? lots.map((e) => e.toString()).toList()
          : const ['A', 'B', 'C', 'D'],
    );
  }
}
