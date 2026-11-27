import '../../core/config/roster_mode.dart';
import '../models/auth_models.dart';
import '../models/device_models.dart';
import '../models/parking_models.dart';
import '../models/participant_models.dart';

class ParticipantFixture {
  final String userId;
  final String userCode;
  final String faceTemplateId;
  final String classDemoName;
  final String syntheticName;
  final String email;
  final String demoBuildingHint; // Used only for class demo display; null in strict contract mode

  const ParticipantFixture({
    required this.userId,
    required this.userCode,
    required this.faceTemplateId,
    required this.classDemoName,
    required this.syntheticName,
    required this.email,
    required this.demoBuildingHint,
  });

  String displayName(RosterMode mode) =>
      mode == RosterMode.classDemo ? classDemoName : syntheticName;

  /// Per `01_SYSTEM_OVERVIEW.md`, `building_code` is `null` by default in strict contract fixtures.
  String? buildingCode(RosterMode mode) =>
      mode == RosterMode.classDemo ? demoBuildingHint : null;
}

class VehicleFixture {
  final String vehicleId;
  final String vehicleCode;
  final String ownerUserId;
  final String ownerUserCode;
  final String vehicleType; // 'car' | 'motorcycle'
  final String classDemoPlateDisplay;
  final String classDemoNormalizedPlate;
  final String? contractPlateDisplay;
  final String? contractNormalizedPlate;
  final String? rfidUid; // Motorcycles use RFID UID on entry & exit
  final bool isPrimaryVehicle;

  const VehicleFixture({
    required this.vehicleId,
    required this.vehicleCode,
    required this.ownerUserId,
    required this.ownerUserCode,
    required this.vehicleType,
    required this.classDemoPlateDisplay,
    required this.classDemoNormalizedPlate,
    this.contractPlateDisplay,
    this.contractNormalizedPlate,
    this.rfidUid,
    this.isPrimaryVehicle = true,
  });

  String? plateDisplay(RosterMode mode) => mode == RosterMode.classDemo
      ? classDemoPlateDisplay
      : contractPlateDisplay;

  String? normalizedPlate(RosterMode mode) => mode == RosterMode.classDemo
      ? classDemoNormalizedPlate
      : contractNormalizedPlate;
}

/// Official SENTRY 7-Participant / 8-Vehicle Fixtures (`U001`–`U007`, `V001`–`V008`),
/// Staff Operator Accounts (`G001`, `A001`), 7-Building Priority Matrix,
/// Surveyed Campus Parking Lots `B1–B5`, and Registered Producers (`D01`–`D07`).
class SentryFixtures {
  SentryFixtures._();

  // Staff Operator Accounts (Not Student Participants)
  static const ProfileDto guardOperator = ProfileDto(
    userId: '10000000-0000-4000-8000-000000000101',
    userCode: 'G001',
    username: 'guard01@sentry.test',
    fullName: 'Harper Guard (Gate 1 Duty)',
    role: UserRole.guard,
    assignedStation: 'Gate 1 North Command Booth',
  );

  static const ProfileDto adminOperator = ProfileDto(
    userId: '10000000-0000-4000-8000-000000000201',
    userCode: 'A001',
    username: 'admin01@sentry.test',
    fullName: 'Emmanuel Tamboong',
    role: UserRole.administrator,
    assignedStation: 'BSU TNEU Alangilan ICT Command Center',
  );

  // Official 7 Participants (U001–U007)
  static const List<ParticipantFixture> participants = [
    ParticipantFixture(
      userId: '10000000-0000-4000-8000-000000000001',
      userCode: 'U001',
      faceTemplateId: '11000000-0000-4000-8000-000000000001',
      classDemoName: 'Jalen Brent P. Blay',
      syntheticName: 'Synthetic Student 001',
      email: 'student001@sentry.test',
      demoBuildingHint: 'CET',
    ),
    ParticipantFixture(
      userId: '10000000-0000-4000-8000-000000000002',
      userCode: 'U002',
      faceTemplateId: '11000000-0000-4000-8000-000000000002',
      classDemoName: 'Maximus Catacutan',
      syntheticName: 'Synthetic Student 002',
      email: 'student002@sentry.test',
      demoBuildingHint: 'CEAFA',
    ),
    ParticipantFixture(
      userId: '10000000-0000-4000-8000-000000000003',
      userCode: 'U003',
      faceTemplateId: '11000000-0000-4000-8000-000000000003',
      classDemoName: 'Emmiery Jodie I. Agdon',
      syntheticName: 'Synthetic Student 003',
      email: 'student003@sentry.test',
      demoBuildingHint: 'STEERHUB',
    ),
    ParticipantFixture(
      userId: '10000000-0000-4000-8000-000000000004',
      userCode: 'U004',
      faceTemplateId: '11000000-0000-4000-8000-000000000004',
      classDemoName: 'Jansen Lance T. Alvarez',
      syntheticName: 'Synthetic Student 004',
      email: 'student004@sentry.test',
      demoBuildingHint: 'CICS',
    ),
    ParticipantFixture(
      userId: '10000000-0000-4000-8000-000000000005',
      userCode: 'U005',
      faceTemplateId: '11000000-0000-4000-8000-000000000005',
      classDemoName: 'Von Homersly M. Magbojos',
      syntheticName: 'Synthetic Student 005',
      email: 'student005@sentry.test',
      demoBuildingHint: 'RGR',
    ),
    ParticipantFixture(
      userId: '10000000-0000-4000-8000-000000000006',
      userCode: 'U006',
      faceTemplateId: '11000000-0000-4000-8000-000000000006',
      classDemoName: 'Richard Lagarde',
      syntheticName: 'Synthetic Student 006',
      email: 'student006@sentry.test',
      demoBuildingHint: 'FITNESS CENTER',
    ),
    ParticipantFixture(
      userId: '10000000-0000-4000-8000-000000000007',
      userCode: 'U007',
      faceTemplateId: '11000000-0000-4000-8000-000000000007',
      classDemoName: 'Steven Dave Abril',
      syntheticName: 'Synthetic Student 007',
      email: 'student007@sentry.test',
      demoBuildingHint: 'CEAFA',
    ),
  ];

  // Official 8 Vehicles (V001–V008; U007 owns both V007 and V008)
  static const List<VehicleFixture> vehicles = [
    VehicleFixture(
      vehicleId: '20000000-0000-4000-8000-000000000001',
      vehicleCode: 'V001',
      ownerUserId: '10000000-0000-4000-8000-000000000001',
      ownerUserCode: 'U001',
      vehicleType: 'car',
      classDemoPlateDisplay: 'UKQ 247',
      classDemoNormalizedPlate: 'UKQ247',
      contractPlateDisplay: 'DEMO001',
      contractNormalizedPlate: 'DEMO001',
    ),
    VehicleFixture(
      vehicleId: '20000000-0000-4000-8000-000000000002',
      vehicleCode: 'V002',
      ownerUserId: '10000000-0000-4000-8000-000000000002',
      ownerUserCode: 'U002',
      vehicleType: 'motorcycle',
      classDemoPlateDisplay: '340 UDK',
      classDemoNormalizedPlate: '340UDK',
      contractPlateDisplay: null,
      contractNormalizedPlate: null,
      rfidUid: '04A1B2C3',
    ),
    VehicleFixture(
      vehicleId: '20000000-0000-4000-8000-000000000003',
      vehicleCode: 'V003',
      ownerUserId: '10000000-0000-4000-8000-000000000003',
      ownerUserCode: 'U003',
      vehicleType: 'car',
      classDemoPlateDisplay: 'DAL 4266',
      classDemoNormalizedPlate: 'DAL4266',
      contractPlateDisplay: 'DEMO003',
      contractNormalizedPlate: 'DEMO003',
    ),
    VehicleFixture(
      vehicleId: '20000000-0000-4000-8000-000000000004',
      vehicleCode: 'V004',
      ownerUserId: '10000000-0000-4000-8000-000000000004',
      ownerUserCode: 'U004',
      vehicleType: 'motorcycle',
      classDemoPlateDisplay: '797 OPW',
      classDemoNormalizedPlate: '797OPW',
      contractPlateDisplay: null,
      contractNormalizedPlate: null,
      rfidUid: '04D4E5F6',
    ),
    VehicleFixture(
      vehicleId: '20000000-0000-4000-8000-000000000005',
      vehicleCode: 'V005',
      ownerUserId: '10000000-0000-4000-8000-000000000005',
      ownerUserCode: 'U005',
      vehicleType: 'car',
      classDemoPlateDisplay: 'NJM 3470',
      classDemoNormalizedPlate: 'NJM3470',
      contractPlateDisplay: 'DEMO005',
      contractNormalizedPlate: 'DEMO005',
    ),
    VehicleFixture(
      vehicleId: '20000000-0000-4000-8000-000000000006',
      vehicleCode: 'V006',
      ownerUserId: '10000000-0000-4000-8000-000000000006',
      ownerUserCode: 'U006',
      vehicleType: 'motorcycle',
      classDemoPlateDisplay: '242 QMI',
      classDemoNormalizedPlate: '242QMI',
      contractPlateDisplay: null,
      contractNormalizedPlate: null,
      rfidUid: '04112233',
    ),
    VehicleFixture(
      vehicleId: '20000000-0000-4000-8000-000000000007',
      vehicleCode: 'V007',
      ownerUserId: '10000000-0000-4000-8000-000000000007',
      ownerUserCode: 'U007',
      vehicleType: 'car',
      classDemoPlateDisplay: 'NPO 541',
      classDemoNormalizedPlate: 'NPO541',
      contractPlateDisplay: 'DEMO007',
      contractNormalizedPlate: 'DEMO007',
      isPrimaryVehicle: true,
    ),
    VehicleFixture(
      vehicleId: '20000000-0000-4000-8000-000000000008',
      vehicleCode: 'V008',
      ownerUserId: '10000000-0000-4000-8000-000000000007',
      ownerUserCode: 'U007',
      vehicleType: 'car',
      classDemoPlateDisplay: 'DBF 2784',
      classDemoNormalizedPlate: 'DBF2784',
      contractPlateDisplay: 'DEMO008',
      contractNormalizedPlate: 'DEMO008',
      isPrimaryVehicle: false,
    ),
  ];

  static ParticipantFixture? findParticipantByCode(String? code) {
    if (code == null) return null;
    for (final p in participants) {
      if (p.userCode == code || p.userId == code) return p;
    }
    return null;
  }

  static VehicleFixture? findVehicleByCode(String? code) {
    if (code == null) return null;
    for (final v in vehicles) {
      if (v.vehicleCode == code || v.vehicleId == code) return v;
    }
    return null;
  }

  static List<VehicleFixture> vehiclesForUser(String userCode) {
    return vehicles.where((v) => v.ownerUserCode == userCode).toList();
  }

  static List<ParticipantUserDto> buildParticipantDirectory(RosterMode mode) {
    final now = DateTime.now().toUtc();
    return participants.map((p) {
      final userVehicles = vehiclesForUser(p.userCode).map((v) {
        return ParticipantVehicleDto(
          vehicleId: v.vehicleId,
          vehicleCode: v.vehicleCode,
          userCode: p.userCode,
          vehicleType: v.vehicleType,
          plateNumberDisplay: v.plateDisplay(mode),
          normalizedPlateNumber: v.normalizedPlate(mode),
          rfidUid: v.rfidUid,
          vehicleStatus: 'active',
          authorizationStatus: 'authorized',
          isPrimaryVehicle: v.isPrimaryVehicle,
          notes: v.vehicleCode == 'V008'
              ? 'Secondary registered car for multi-vehicle single-visit testing (U007).'
              : 'Primary registered campus vehicle.',
          updatedAtUtc: now.subtract(const Duration(days: 3)),
        );
      }).toList();

      return ParticipantUserDto(
        userId: p.userId,
        userCode: p.userCode,
        fullName: p.displayName(mode),
        email: p.email,
        status: 'active',
        buildingCode: p.buildingCode(mode),
        faceTemplateId: p.faceTemplateId,
        faceEnrolled: true,
        admissionEvaluated: false,
        vehicles: userVehicles,
      );
    }).toList();
  }

  // Official 7-Building × 5-Lot Priority Matrix (B1–B5, B5 = Overflow)
  static const List<BuildingPriorityRow> buildingPriorityRows = [
    BuildingPriorityRow(
      buildingCode: 'CEAFA',
      buildingName: 'College of Engineering, Architecture & Fine Arts (CEAFA)',
      orderedLots: ['B1', 'B3', 'B2', 'B4', 'B5'],
    ),
    BuildingPriorityRow(
      buildingCode: 'CICS',
      buildingName: 'College of Informatics & Computing Sciences (CICS)',
      orderedLots: ['B3', 'B1', 'B2', 'B4', 'B5'],
    ),
    BuildingPriorityRow(
      buildingCode: 'STEERHUB',
      buildingName: 'STEER Hub (Science, Technology, Engineering & Research)',
      orderedLots: ['B2', 'B1', 'B3', 'B4', 'B5'],
    ),
    BuildingPriorityRow(
      buildingCode: 'FITNESS CENTER',
      buildingName: 'Campus Fitness & Gymnasium Center',
      orderedLots: ['B2', 'B3', 'B1', 'B4', 'B5'],
    ),
    BuildingPriorityRow(
      buildingCode: 'CET',
      buildingName: 'College of Engineering & Technology (CET)',
      orderedLots: ['B4', 'B1', 'B2', 'B3', 'B5'],
    ),
    BuildingPriorityRow(
      buildingCode: 'REGISTRAR',
      buildingName: 'University Registrar & Administration',
      orderedLots: ['B1', 'B3', 'B2', 'B4', 'B5'],
    ),
    BuildingPriorityRow(
      buildingCode: 'RGR',
      buildingName: 'RGR Academic & Laboratory Building',
      orderedLots: ['B3', 'B2', 'B1', 'B4', 'B5'],
    ),
  ];

  // Initial Surveyed Campus Spaces across Lots B1–B5 (92 mapped slots total)
  // - Lot B1: 29 mapped (27 confirmed formal + 2 unconfirmed far-end L11/R11)
  // - Lot B2: 32 mapped (10 moto strip + 18 car + 4 informal aisle A1–A4)
  // - Lot B3: 23 mapped (20 formal incl. PWD R10 & center C1 + 3 informal aisle A1–A3)
  // - Lot B4: CET (schematic pending; empty until backend supplies spaces)
  // - Lot B5: 8 overflow bays (B5-OF01..B5-OF08)
  static List<SpaceDto> buildInitialSpaces([DateTime? nowUtc]) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final spaces = <SpaceDto>[];

    SpaceDto makeSpace({
      required int uuidNum,
      required String spaceCode,
      required String lotCode,
      required String slotLabel,
      SpaceSlotCategory category = SpaceSlotCategory.formal,
      bool isAccessiblePwd = false,
      bool isPartlyOutOfView = false,
      bool isFarEnd = false,
      String compatibility = 'car_only',
      String physicalStatus = 'available',
      String allocationStatus = 'unassigned',
      double? confidence = 0.97,
      int staleSeconds = 4,
      String? producerId,
      String? assignmentId,
      String? visitId,
      String? assignedVehicleCode,
      String? assignedUserCode,
      DateTime? holdExpiresAtUtc,
      Map<String, int> distances = const {},
    }) {
      return SpaceDto(
        spaceId:
            '30000000-0000-4000-8000-${uuidNum.toString().padLeft(12, '0')}',
        spaceCode: spaceCode,
        lotCode: lotCode,
        slotLabel: slotLabel,
        slotCategory: category,
        isAccessiblePwd: isAccessiblePwd,
        isPartlyOutOfView: isPartlyOutOfView,
        isFarEnd: isFarEnd,
        compatibility: compatibility,
        physicalStatus: physicalStatus,
        allocationStatus: allocationStatus,
        confidence: confidence,
        lastObservedAtUtc: now.subtract(Duration(seconds: staleSeconds)),
        producerId: producerId ?? 'occupancy-lot-${lotCode.toLowerCase()}-01',
        assignmentId: assignmentId,
        visitId: visitId,
        assignedVehicleCode: assignedVehicleCode,
        assignedUserCode: assignedUserCode,
        holdExpiresAtUtc: holdExpiresAtUtc,
        buildingDistanceMeters: distances,
      );
    }

    // -------------------------------------------------------------------------
    // LOT B1 — CIT (27 Confirmed + 2 Unconfirmed = 29)
    // -------------------------------------------------------------------------
    const b1Dist = {'CEAFA': 24, 'CICS': 45, 'REGISTRAR': 65, 'STEERHUB': 90};
    for (var i = 1; i <= 11; i++) {
      final isUnconfirmed = i == 11;
      String phys = 'available';
      String alloc = 'unassigned';
      double? conf = 0.98;
      String? assignId;
      String? visitId;
      String? veh;
      String? usr;
      DateTime? holdExp;

      if (i == 2) {
        phys = 'occupied';
        alloc = 'assigned';
        assignId = '50000000-0000-4000-8000-000000000003';
        visitId = '60000000-0000-4000-8000-000000000003';
        veh = 'V003';
        usr = 'U003';
      } else if (i == 3) {
        phys = 'available';
        alloc = 'held';
        assignId = '50000000-0000-4000-8000-000000000001';
        visitId = null;
        veh = 'V001';
        usr = 'U001';
        holdExp = now.add(const Duration(seconds: 26));
      } else if (i == 5) {
        // Intentional Occupancy Conflict demo bay
        phys = 'occupied';
        alloc = 'unassigned';
      } else if (i == 7 || i == 9) {
        phys = 'occupied';
        alloc = 'assigned';
        assignId = '50000000-0000-4000-8000-00000000010$i';
        visitId = '60000000-0000-4000-8000-00000000010$i';
      } else if (isUnconfirmed) {
        phys = 'unknown';
        conf = null;
      }

      spaces.add(
        makeSpace(
          uuidNum: 100 + i,
          spaceCode: 'B1-L$i',
          lotCode: 'B1',
          slotLabel: 'L$i',
          category: isUnconfirmed
              ? SpaceSlotCategory.unconfirmedFarEnd
              : SpaceSlotCategory.formal,
          isFarEnd: isUnconfirmed,
          physicalStatus: phys,
          allocationStatus: alloc,
          confidence: conf,
          producerId: 'occupancy-lot-b1-01',
          assignmentId: assignId,
          visitId: visitId,
          assignedVehicleCode: veh,
          assignedUserCode: usr,
          holdExpiresAtUtc: holdExp,
          distances: b1Dist,
        ),
      );
    }

    for (var i = 1; i <= 11; i++) {
      final isFarEnd = i >= 9;
      final isUnconfirmed = i == 11;
      String phys = 'available';
      String alloc = 'unassigned';
      double? conf = 0.97;
      String? assignId;
      String? visitId;
      String? veh;
      String? usr;

      if (i == 4) {
        phys = 'occupied';
        alloc = 'assigned';
        assignId = '50000000-0000-4000-8000-000000000007';
        visitId = '60000000-0000-4000-8000-000000000007';
        veh = 'V007';
        usr = 'U007';
      } else if (i == 6) {
        phys = 'unknown';
        conf = null;
      } else if (i == 2 || i == 8) {
        phys = 'occupied';
        alloc = 'assigned';
        assignId = '50000000-0000-4000-8000-00000000020$i';
        visitId = '60000000-0000-4000-8000-00000000020$i';
      } else if (isUnconfirmed) {
        phys = 'unknown';
        conf = null;
      }

      spaces.add(
        makeSpace(
          uuidNum: 120 + i,
          spaceCode: 'B1-R$i',
          lotCode: 'B1',
          slotLabel: 'R$i',
          category: isUnconfirmed
              ? SpaceSlotCategory.unconfirmedFarEnd
              : SpaceSlotCategory.formal,
          isFarEnd: isFarEnd,
          physicalStatus: phys,
          allocationStatus: alloc,
          confidence: conf,
          producerId: 'occupancy-lot-b1-01',
          assignmentId: assignId,
          visitId: visitId,
          assignedVehicleCode: veh,
          assignedUserCode: usr,
          distances: b1Dist,
        ),
      );
    }

    for (var i = 1; i <= 7; i++) {
      final occupied = i == 2 || i == 5;
      spaces.add(
        makeSpace(
          uuidNum: 140 + i,
          spaceCode: 'B1-M$i',
          lotCode: 'B1',
          slotLabel: 'M$i',
          physicalStatus: occupied ? 'occupied' : 'available',
          allocationStatus: occupied ? 'assigned' : 'unassigned',
          producerId: 'occupancy-lot-b1-01',
          assignmentId: occupied ? '50000000-0000-4000-8000-00000000030$i' : null,
          visitId: occupied ? '60000000-0000-4000-8000-00000000030$i' : null,
          distances: b1Dist,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // LOT B2 — GYM (32 Mapped: 10 Moto + 18 Car + 4 Aisle)
    // -------------------------------------------------------------------------
    const b2Dist = {'STEERHUB': 22, 'FITNESS CENTER': 18, 'CEAFA': 85, 'CET': 95};
    for (var i = 1; i <= 10; i++) {
      final label = i == 10 ? 'MB10' : '$i';
      final isV002 = i == 2;
      final isOcc = isV002 || i == 5 || i == 7;
      spaces.add(
        makeSpace(
          uuidNum: 200 + i,
          spaceCode: 'B2-MB$i',
          lotCode: 'B2',
          slotLabel: label,
          compatibility: 'motorcycle_only',
          physicalStatus: isOcc ? 'occupied' : 'available',
          allocationStatus: isOcc ? 'assigned' : 'unassigned',
          producerId: 'occupancy-lot-b2-01',
          assignmentId: isV002
              ? '50000000-0000-4000-8000-000000000002'
              : (isOcc ? '50000000-0000-4000-8000-00000000040$i' : null),
          visitId: isV002
              ? '60000000-0000-4000-8000-000000000002'
              : (isOcc ? '60000000-0000-4000-8000-00000000040$i' : null),
          assignedVehicleCode: isV002 ? 'V002' : null,
          assignedUserCode: isV002 ? 'U002' : null,
          distances: b2Dist,
        ),
      );
    }

    for (var i = 1; i <= 8; i++) {
      final isOcc = i == 3 || i == 6;
      spaces.add(
        makeSpace(
          uuidNum: 220 + i,
          spaceCode: 'B2-L$i',
          lotCode: 'B2',
          slotLabel: 'L$i',
          isPartlyOutOfView: i == 8,
          physicalStatus: isOcc ? 'occupied' : 'available',
          allocationStatus: isOcc ? 'assigned' : 'unassigned',
          producerId: 'occupancy-lot-b2-01',
          distances: b2Dist,
        ),
      );
    }

    for (var i = 1; i <= 10; i++) {
      final isOcc = i == 2 || i == 4 || i == 9;
      spaces.add(
        makeSpace(
          uuidNum: 240 + i,
          spaceCode: 'B2-R$i',
          lotCode: 'B2',
          slotLabel: 'R$i',
          isPartlyOutOfView: i == 10,
          physicalStatus: isOcc ? 'occupied' : 'available',
          allocationStatus: isOcc ? 'assigned' : 'unassigned',
          producerId: 'occupancy-lot-b2-01',
          distances: b2Dist,
        ),
      );
    }

    for (var i = 1; i <= 4; i++) {
      spaces.add(
        makeSpace(
          uuidNum: 260 + i,
          spaceCode: 'B2-A$i',
          lotCode: 'B2',
          slotLabel: 'A$i',
          category: SpaceSlotCategory.informalAisle,
          physicalStatus: (i == 1 || i == 4) ? 'occupied' : 'available',
          allocationStatus: 'unassigned',
          producerId: 'occupancy-lot-b2-01',
          distances: b2Dist,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // LOT B3 — CEAFA 1 (Tapat ng Gym) (20 Formal + 3 Informal = 23)
    // -------------------------------------------------------------------------
    const b3Dist = {'CEAFA': 26, 'CICS': 32, 'RGR': 55, 'REGISTRAR': 68};
    for (var i = 1; i <= 9; i++) {
      final isOcc = i == 2 || i == 5;
      spaces.add(
        makeSpace(
          uuidNum: 300 + i,
          spaceCode: 'B3-L$i',
          lotCode: 'B3',
          slotLabel: 'L$i',
          physicalStatus: isOcc ? 'occupied' : 'available',
          allocationStatus: isOcc ? 'assigned' : 'unassigned',
          producerId: 'occupancy-lot-b3-01',
          distances: b3Dist,
        ),
      );
    }

    for (var i = 1; i <= 10; i++) {
      final isOcc = i == 3 || i == 7;
      spaces.add(
        makeSpace(
          uuidNum: 320 + i,
          spaceCode: 'B3-R$i',
          lotCode: 'B3',
          slotLabel: 'R$i',
          isAccessiblePwd: i == 10, // Surveyed PWD / Accessible bay!
          physicalStatus: isOcc ? 'occupied' : 'available',
          allocationStatus: isOcc ? 'assigned' : 'unassigned',
          producerId: 'occupancy-lot-b3-01',
          distances: b3Dist,
        ),
      );
    }

    spaces.add(
      makeSpace(
        uuidNum: 341,
        spaceCode: 'B3-C1',
        lotCode: 'B3',
        slotLabel: 'C1',
        category: SpaceSlotCategory.formalCenterPainted,
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        producerId: 'occupancy-lot-b3-01',
        distances: b3Dist,
      ),
    );

    for (var i = 1; i <= 3; i++) {
      spaces.add(
        makeSpace(
          uuidNum: 350 + i,
          spaceCode: 'B3-A$i',
          lotCode: 'B3',
          slotLabel: 'A$i',
          category: SpaceSlotCategory.informalAisle,
          physicalStatus: i == 1 ? 'occupied' : 'available',
          allocationStatus: 'unassigned',
          producerId: 'occupancy-lot-b3-01',
          distances: b3Dist,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // LOT B4 — CEAFA 2 (Camera-sensed; Schematic Pending until backend supplies)
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // LOT B5 — Overflow Lot (8 dynamic overflow bays)
    // -------------------------------------------------------------------------
    const b5Dist = {'CET': 110, 'STEERHUB': 125, 'CEAFA': 140, 'RGR': 150};
    for (var i = 1; i <= 8; i++) {
      final isMoto = i > 6;
      final isOcc = i == 2;
      spaces.add(
        makeSpace(
          uuidNum: 500 + i,
          spaceCode: 'B5-OF0$i',
          lotCode: 'B5',
          slotLabel: 'OF0$i',
          compatibility: isMoto ? 'motorcycle_only' : 'car_only',
          physicalStatus: isOcc ? 'occupied' : 'available',
          allocationStatus: isOcc ? 'assigned' : 'unassigned',
          producerId: 'occupancy-lot-b5-01',
          distances: b5Dist,
        ),
      );
    }

    return spaces;
  }

  // Official 7 Registered Producers (D01–D07)
  static List<DeviceDto> buildInitialDevices([DateTime? nowUtc]) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    return [
      DeviceDto(
        deviceCode: 'D01',
        producerId: 'plate-entry-01',
        deviceType: 'plate_adapter',
        displayName: 'Gate 1 Car Entry Plate LPR (YOLO + OCR)',
        locationLabel: 'Gate 1 North · Car Entry Lane',
        reportedStatus: 'online',
        bootId: '70000000-0000-4000-8000-000000000001',
        sequenceNumber: 1420,
        uptimeSeconds: 14200,
        softwareVersion: 'sentry-plate-lpr-v1.2.0',
        capabilities: const ['plate'],
        lastReceivedAtUtc: now.subtract(const Duration(seconds: 3)),
      ),
      DeviceDto(
        deviceCode: 'D02',
        producerId: 'plate-exit-01',
        deviceType: 'plate_adapter',
        displayName: 'Gate 2 Car Exit Plate LPR (YOLO + OCR)',
        locationLabel: 'Gate 2 South · Car Exit Lane',
        reportedStatus: 'online',
        bootId: '70000000-0000-4000-8000-000000000002',
        sequenceNumber: 1388,
        uptimeSeconds: 13880,
        softwareVersion: 'sentry-plate-lpr-v1.2.0',
        capabilities: const ['plate'],
        lastReceivedAtUtc: now.subtract(const Duration(seconds: 4)),
      ),
      DeviceDto(
        deviceCode: 'D03',
        producerId: 'face-entry-01',
        deviceType: 'face_adapter',
        displayName: 'Gate 1 Driver Face Verification (YOLO + ArcFace)',
        locationLabel: 'Gate 1 North · Entry Verification Canopy',
        reportedStatus: 'online',
        bootId: '70000000-0000-4000-8000-000000000003',
        sequenceNumber: 1415,
        uptimeSeconds: 14150,
        softwareVersion: 'sentry-arcface-r100-v1.1.4',
        capabilities: const ['face'],
        lastReceivedAtUtc: now.subtract(const Duration(seconds: 2)),
      ),
      DeviceDto(
        deviceCode: 'D04',
        producerId: 'rfid-entry-01',
        deviceType: 'rfid_reader',
        displayName: 'Gate 1 Motorcycle Entry ESP32 RFID + Barrier',
        locationLabel: 'Gate 1 North · Motorcycle Entry Lane',
        reportedStatus: 'online',
        bootId: '70000000-0000-4000-8000-000000000004',
        sequenceNumber: 2890,
        uptimeSeconds: 28900,
        softwareVersion: 'esp32-rc522-fw-v1.0.8',
        capabilities: const ['rfid', 'passage', 'gate_controller'],
        lastReceivedAtUtc: now.subtract(const Duration(seconds: 5)),
      ),
      DeviceDto(
        deviceCode: 'D05',
        producerId: 'occupancy-lot-b1-01',
        deviceType: 'occupancy_camera',
        displayName: 'Overhead Lot B1–B5 Occupancy Vision Node',
        locationLabel: 'CEAFA & STEER Hub Overhead Mast',
        reportedStatus: 'online',
        bootId: '70000000-0000-4000-8000-000000000005',
        sequenceNumber: 964,
        uptimeSeconds: 9640,
        softwareVersion: 'sentry-occupancy-poly-v1.3.1',
        capabilities: const ['occupancy'],
        lastReceivedAtUtc: now.subtract(const Duration(seconds: 4)),
        mappedLotCode: 'B1',
      ),
      DeviceDto(
        deviceCode: 'D06',
        producerId: 'rfid-exit-01',
        deviceType: 'rfid_reader',
        displayName: 'Gate 2 Motorcycle Exit ESP32 RFID + Barrier',
        locationLabel: 'Gate 2 South · Motorcycle Exit Lane',
        reportedStatus: 'online',
        bootId: '70000000-0000-4000-8000-000000000006',
        sequenceNumber: 2840,
        uptimeSeconds: 28400,
        softwareVersion: 'esp32-rc522-fw-v1.0.8',
        capabilities: const ['rfid', 'passage', 'gate_controller'],
        lastReceivedAtUtc: now.subtract(const Duration(seconds: 6)),
      ),
      DeviceDto(
        deviceCode: 'D07',
        producerId: 'desktop-guard-01',
        deviceType: 'guard_client',
        displayName: 'Gate 1 Windows Desktop Command Console',
        locationLabel: 'Gate 1 Guardhouse Workstation',
        reportedStatus: 'online',
        bootId: '70000000-0000-4000-8000-000000000007',
        sequenceNumber: 512,
        uptimeSeconds: 5120,
        softwareVersion: 'campus_parking_desktop-v1.0.0',
        capabilities: const ['passage'],
        lastReceivedAtUtc: now.subtract(const Duration(seconds: 1)),
      ),
    ];
  }
}
