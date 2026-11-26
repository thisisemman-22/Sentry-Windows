import '../../core/network/api_envelope.dart';

/// Classification of a surveyed campus slot so formal allocatable bays stay
/// strictly separated from unconfirmed far-end shadows and informal aisle zones.
enum SpaceSlotCategory {
  formal('formal'),
  unconfirmedFarEnd('unconfirmed_far_end'),
  informalAisle('informal_aisle'),
  formalCenterPainted('formal_center_painted');

  final String wireValue;
  const SpaceSlotCategory(this.wireValue);

  static SpaceSlotCategory fromWire(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'unconfirmed_far_end':
      case 'unconfirmed':
        return SpaceSlotCategory.unconfirmedFarEnd;
      case 'informal_aisle':
      case 'informal':
        return SpaceSlotCategory.informalAisle;
      case 'formal_center_painted':
      case 'center_painted':
        return SpaceSlotCategory.formalCenterPainted;
      case 'formal':
      default:
        return SpaceSlotCategory.formal;
    }
  }
}

/// Canonical metadata for each BatStateU Alangilan Campus parking lot (`B1–B5`).
/// Display names remain overridable from backend `parking_zones.name`.
class ParkingLotZoneMeta {
  final String lotCode;
  final String defaultName;
  final String shortTabLabel;
  final String nearestLandmark;
  final String dimensionsNote;
  final bool isOverflow;
  final bool isSchematicPending;

  const ParkingLotZoneMeta({
    required this.lotCode,
    required this.defaultName,
    required this.shortTabLabel,
    required this.nearestLandmark,
    required this.dimensionsNote,
    this.isOverflow = false,
    this.isSchematicPending = false,
  });

  /// Prefers backend `parking_zones.name` (`SpaceDto.zoneName`) if present.
  String resolveName(List<SpaceDto> allSpaces) {
    for (final s in allSpaces) {
      if (s.lotCode == lotCode &&
          s.zoneName != null &&
          s.zoneName!.trim().isNotEmpty) {
        return s.zoneName!.trim();
      }
    }
    return defaultName;
  }
}

const List<ParkingLotZoneMeta> kCampusParkingLots = [
  ParkingLotZoneMeta(
    lotCode: 'B1',
    defaultName: 'Albert Einstein / CEAFA Left',
    shortTabLabel: 'B1 · CEAFA Left',
    nearestLandmark: 'Albert Einstein / CEAFA Left Wing',
    dimensionsNote: '2.4m × 5.0m bays · 27 confirmed + 2 unconfirmed far-end',
  ),
  ParkingLotZoneMeta(
    lotCode: 'B2',
    defaultName: 'Gymnasium & STEER Hub',
    shortTabLabel: 'B2 · Gym & STEER',
    nearestLandmark: 'Gov. Feliciano Leviste Gym & STEER Hub',
    dimensionsNote: '10 motorcycle strip + 18 car bays + 4 informal aisle',
  ),
  ParkingLotZoneMeta(
    lotCode: 'B3',
    defaultName: 'Albert Einstein / CEAFA Right',
    shortTabLabel: 'B3 · CEAFA Right',
    nearestLandmark: 'Albert Einstein / CEAFA Right Wing',
    dimensionsNote: '20 formal bays (incl. PWD R10 & center C1) + 3 informal aisle',
  ),
  ParkingLotZoneMeta(
    lotCode: 'B4',
    defaultName: 'CET Building',
    shortTabLabel: 'B4 · CET',
    nearestLandmark: 'College of Engineering & Technology (CET)',
    dimensionsNote: 'Survey schematic pending · dynamic bay rendering when live',
    isSchematicPending: true,
  ),
  ParkingLotZoneMeta(
    lotCode: 'B5',
    defaultName: 'Overflow Lot',
    shortTabLabel: 'B5 · Overflow',
    nearestLandmark: 'Campus Overflow Parking Zone',
    dimensionsNote: 'Designated overflow lot for peak campus demand',
    isOverflow: true,
  ),
];

/// Parking Space DTO enforcing Invariant #3:
/// - `physicalStatus`: `available` | `occupied` | `unknown` (from overhead camera AI)
/// - `allocationStatus`: `unassigned` | `held` | `assigned` (from backend reservations/visits)
/// - `compatibility`: strictly `car_only` or `motorcycle_only` (flags any legacy `mixed` value as config warning)
/// - CRITICAL: `unknown`, `isStale: true`, `unconfirmedFarEnd`, and `informalAisle` spaces
///   MUST NEVER be displayed or treated as allocatable free bays!
class SpaceDto {
  final String spaceId;
  final String spaceCode; // e.g. 'B1-L1', 'B2-MB1', 'B3-R10', 'B5-OF01'
  final String lotCode; // 'B1' | 'B2' | 'B3' | 'B4' | 'B5'
  final String slotLabel; // Short schematic label e.g. 'L1', 'M4', 'MB10', '9'
  final SpaceSlotCategory slotCategory;
  final bool isAccessiblePwd;
  final bool isPartlyOutOfView;
  final bool isFarEnd;
  final String? zoneName;
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
    this.slotLabel = '',
    this.slotCategory = SpaceSlotCategory.formal,
    this.isAccessiblePwd = false,
    this.isPartlyOutOfView = false,
    this.isFarEnd = false,
    this.zoneName,
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

  String get displaySlotLabel =>
      slotLabel.isNotEmpty ? slotLabel : spaceCode;

  bool get isFormalAllocatableBay =>
      slotCategory == SpaceSlotCategory.formal ||
      slotCategory == SpaceSlotCategory.formalCenterPainted;

  bool get isUnconfirmed => slotCategory == SpaceSlotCategory.unconfirmedFarEnd;

  bool get isInformalAisle => slotCategory == SpaceSlotCategory.informalAisle;

  /// True ONLY for confirmed formal bays when camera feed is fresh,
  /// physical status is `available`, and allocation status is `unassigned`.
  /// `unknown`, `isStale`, `unconfirmedFarEnd`, and `informalAisle` slots
  /// are NEVER treated as allocatable free capacity!
  bool get isTrulyAvailableForAllocation =>
      isFormalAllocatableBay &&
      !isStale &&
      physicalStatus == 'available' &&
      allocationStatus == 'unassigned' &&
      !hasLegacyCompatibilityWarning;

  /// Detects if a formal bay is physically occupied while backend thinks it is `unassigned` or `held`.
  bool get hasOccupancyConflict =>
      isFormalAllocatableBay &&
      !isStale &&
      physicalStatus == 'occupied' &&
      (allocationStatus == 'unassigned' || allocationStatus == 'held');

  /// Per `PARKING_COMPATIBILITY_REQUIREMENTS.md`, only `car_only` and `motorcycle_only` are valid.
  bool get hasLegacyCompatibilityWarning =>
      compatibility != 'car_only' && compatibility != 'motorcycle_only';

  bool get isUnknownOrStale => isStale || physicalStatus == 'unknown';

  SpaceDto copyWith({
    String? slotLabel,
    SpaceSlotCategory? slotCategory,
    bool? isAccessiblePwd,
    bool? isPartlyOutOfView,
    bool? isFarEnd,
    String? zoneName,
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
      slotLabel: slotLabel ?? this.slotLabel,
      slotCategory: slotCategory ?? this.slotCategory,
      isAccessiblePwd: isAccessiblePwd ?? this.isAccessiblePwd,
      isPartlyOutOfView: isPartlyOutOfView ?? this.isPartlyOutOfView,
      isFarEnd: isFarEnd ?? this.isFarEnd,
      zoneName: zoneName ?? this.zoneName,
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
      lotCode: json['lot_code']?.toString() ?? 'B1',
      slotLabel: json['slot_label']?.toString() ?? '',
      slotCategory:
          SpaceSlotCategory.fromWire(json['slot_category']?.toString()),
      isAccessiblePwd:
          json['is_accessible_pwd'] == true || json['is_pwd'] == true,
      isPartlyOutOfView: json['is_partly_out_of_view'] == true,
      isFarEnd: json['is_far_end'] == true,
      zoneName: (json['zone_name'] ?? json['parking_zone_name'])?.toString(),
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
        if (slotLabel.isNotEmpty) 'slot_label': slotLabel,
        'slot_category': slotCategory.wireValue,
        if (isAccessiblePwd) 'is_accessible_pwd': true,
        if (isPartlyOutOfView) 'is_partly_out_of_view': true,
        if (isFarEnd) 'is_far_end': true,
        if (zoneName != null) 'zone_name': zoneName,
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
  final String lotCode; // 'B1' | 'B2' | 'B3' | 'B4' | 'B5'
  final String lotName;
  final String nearestLandmark;
  final int totalSpaces; // Formal allocatable bays count
  final int unconfirmedSpaces;
  final int informalAisleSpaces;
  final int trulyAvailableSpaces;
  final int physicalAvailable;
  final int physicalOccupied;
  final int physicalUnknownOrStale;
  final int allocationUnassigned;
  final int allocationHeld;
  final int allocationAssigned;
  final int conflictCount;
  final bool cameraStale;
  final bool isOverflow;
  final bool isSchematicPending;

  const LotSummaryDto({
    required this.lotCode,
    required this.lotName,
    required this.nearestLandmark,
    required this.totalSpaces,
    this.unconfirmedSpaces = 0,
    this.informalAisleSpaces = 0,
    required this.trulyAvailableSpaces,
    required this.physicalAvailable,
    required this.physicalOccupied,
    required this.physicalUnknownOrStale,
    required this.allocationUnassigned,
    required this.allocationHeld,
    required this.allocationAssigned,
    required this.conflictCount,
    required this.cameraStale,
    this.isOverflow = false,
    this.isSchematicPending = false,
  });

  factory LotSummaryDto.fromSpaces({
    required String lotCode,
    required String lotName,
    required String nearestLandmark,
    required List<SpaceDto> spaces,
    bool isOverflow = false,
    bool isSchematicPending = false,
  }) {
    final lotSpaces = spaces.where((s) => s.lotCode == lotCode).toList();
    int formalTotal = 0;
    int unconfirmed = 0;
    int informal = 0;
    int trulyAvail = 0;
    int physAvail = 0;
    int physOcc = 0;
    int physUnk = 0;
    int allocUnassigned = 0;
    int allocHeld = 0;
    int allocAssigned = 0;
    int conflicts = 0;
    bool anyStale = false;

    for (final s in lotSpaces) {
      if (s.isUnconfirmed) {
        unconfirmed++;
        continue;
      }
      if (s.isInformalAisle) {
        informal++;
        continue;
      }

      formalTotal++;
      if (s.isTrulyAvailableForAllocation) {
        trulyAvail++;
      }

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
      totalSpaces: formalTotal,
      unconfirmedSpaces: unconfirmed,
      informalAisleSpaces: informal,
      trulyAvailableSpaces: trulyAvail,
      physicalAvailable: physAvail,
      physicalOccupied: physOcc,
      physicalUnknownOrStale: physUnk,
      allocationUnassigned: allocUnassigned,
      allocationHeld: allocHeld,
      allocationAssigned: allocAssigned,
      conflictCount: conflicts,
      cameraStale: anyStale,
      isOverflow: isOverflow,
      isSchematicPending: isSchematicPending,
    );
  }
}

class BuildingPriorityRow {
  final String buildingCode;
  final String buildingName;
  final List<String> orderedLots; // e.g. ['B1', 'B2', 'B3', 'B4', 'B5']

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
          : const ['B1', 'B2', 'B3', 'B4', 'B5'],
    );
  }
}
