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
/// Staff Operator Accounts (`G001`, `A001`), 7-Building Priority Matrix, Lots A–D Spaces,
/// and Registered Producers (`D01`–`D07`).
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
    fullName: 'Emmanuel Tamboong (ICT Administrator)',
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

  // Official 7-Building × 4-Lot Priority Matrix
  static const List<BuildingPriorityRow> buildingPriorityRows = [
    BuildingPriorityRow(
      buildingCode: 'CET',
      buildingName: 'College of Engineering & Technology (CET)',
      orderedLots: ['A', 'B', 'C', 'D'],
    ),
    BuildingPriorityRow(
      buildingCode: 'REGISTRAR',
      buildingName: 'University Registrar & Administration',
      orderedLots: ['A', 'B', 'C', 'D'],
    ),
    BuildingPriorityRow(
      buildingCode: 'STEERHUB',
      buildingName: 'STEER Hub (Science, Technology, Engineering & Research)',
      orderedLots: ['B', 'A', 'C', 'D'],
    ),
    BuildingPriorityRow(
      buildingCode: 'FITNESS CENTER',
      buildingName: 'Campus Fitness & Wellness Center',
      orderedLots: ['B', 'C', 'D', 'A'],
    ),
    BuildingPriorityRow(
      buildingCode: 'CEAFA',
      buildingName: 'College of Engineering, Architecture & Fine Arts (CEAFA)',
      orderedLots: ['C', 'D', 'B', 'A'],
    ),
    BuildingPriorityRow(
      buildingCode: 'CICS',
      buildingName: 'College of Informatics & Computing Sciences (CICS)',
      orderedLots: ['C', 'D', 'B', 'A'],
    ),
    BuildingPriorityRow(
      buildingCode: 'RGR',
      buildingName: 'RGR Academic & Laboratory Building',
      orderedLots: ['D', 'C', 'B', 'A'],
    ),
  ];

  // Initial Spaces across Lots A, B, C, D (32 bays total: 8 per lot)
  static List<SpaceDto> buildInitialSpaces([DateTime? nowUtc]) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    return [
      // LOT A — STEER Hub & CET Forecourt
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000101',
        spaceCode: 'A-C01',
        lotCode: 'A',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.98,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 4)),
        producerId: 'occupancy-lot-a-01',
        buildingDistanceMeters: const {'CET': 35, 'STEERHUB': 42, 'CEAFA': 160},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000102',
        spaceCode: 'A-C02',
        lotCode: 'A',
        compatibility: 'car_only',
        physicalStatus: 'occupied',
        allocationStatus: 'assigned',
        confidence: 0.99,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 4)),
        producerId: 'occupancy-lot-a-01',
        assignmentId: '50000000-0000-4000-8000-000000000003',
        visitId: '60000000-0000-4000-8000-000000000003',
        assignedVehicleCode: 'V003',
        assignedUserCode: 'U003',
        buildingDistanceMeters: const {'CET': 38, 'STEERHUB': 40, 'CEAFA': 165},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000103',
        spaceCode: 'A-C03',
        lotCode: 'A',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'held',
        confidence: 0.97,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 4)),
        producerId: 'occupancy-lot-a-01',
        assignmentId: '50000000-0000-4000-8000-000000000001',
        visitId: null, // Strictly null while held before passage!
        assignedVehicleCode: 'V001',
        assignedUserCode: 'U001',
        holdExpiresAtUtc: now.add(const Duration(seconds: 26)),
        buildingDistanceMeters: const {'CET': 42, 'STEERHUB': 45, 'CEAFA': 170},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000104',
        spaceCode: 'A-C04',
        lotCode: 'A',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.96,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 4)),
        producerId: 'occupancy-lot-a-01',
        buildingDistanceMeters: const {'CET': 46, 'STEERHUB': 48, 'CEAFA': 175},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000105',
        spaceCode: 'A-C05',
        lotCode: 'A',
        compatibility: 'car_only',
        physicalStatus: 'occupied',
        allocationStatus: 'unassigned', // Occupancy Conflict Alert!
        confidence: 0.94,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 4)),
        producerId: 'occupancy-lot-a-01',
        buildingDistanceMeters: const {'CET': 50, 'STEERHUB': 52, 'CEAFA': 180},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000106',
        spaceCode: 'A-C06',
        lotCode: 'A',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.98,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 4)),
        producerId: 'occupancy-lot-a-01',
        buildingDistanceMeters: const {'CET': 54, 'STEERHUB': 55, 'CEAFA': 185},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000107',
        spaceCode: 'A-M01',
        lotCode: 'A',
        compatibility: 'motorcycle_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.97,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 4)),
        producerId: 'occupancy-lot-a-01',
        buildingDistanceMeters: const {'CET': 30, 'STEERHUB': 34, 'CEAFA': 155},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000108',
        spaceCode: 'A-M02',
        lotCode: 'A',
        compatibility: 'motorcycle_only',
        physicalStatus: 'occupied',
        allocationStatus: 'assigned',
        confidence: 0.96,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 4)),
        producerId: 'occupancy-lot-a-01',
        assignmentId: '50000000-0000-4000-8000-000000000002',
        visitId: '60000000-0000-4000-8000-000000000002',
        assignedVehicleCode: 'V002',
        assignedUserCode: 'U002',
        buildingDistanceMeters: const {'CET': 32, 'STEERHUB': 36, 'CEAFA': 158},
      ),

      // LOT B — CEAFA Building & STEER Hub North
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000201',
        spaceCode: 'B-C01',
        lotCode: 'B',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.99,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 5)),
        producerId: 'occupancy-lot-b-01',
        buildingDistanceMeters: const {'CEAFA': 28, 'STEERHUB': 35, 'CICS': 60},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000202',
        spaceCode: 'B-C02',
        lotCode: 'B',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.98,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 5)),
        producerId: 'occupancy-lot-b-01',
        buildingDistanceMeters: const {'CEAFA': 30, 'STEERHUB': 38, 'CICS': 62},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000203',
        spaceCode: 'B-C03',
        lotCode: 'B',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.97,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 5)),
        producerId: 'occupancy-lot-b-01',
        buildingDistanceMeters: const {'CEAFA': 34, 'STEERHUB': 42, 'CICS': 65},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000204',
        spaceCode: 'B-C04',
        lotCode: 'B',
        compatibility: 'car_only',
        physicalStatus: 'occupied',
        allocationStatus: 'assigned',
        confidence: 0.99,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 5)),
        producerId: 'occupancy-lot-b-01',
        assignmentId: '50000000-0000-4000-8000-000000000007',
        visitId: '60000000-0000-4000-8000-000000000007',
        assignedVehicleCode: 'V007',
        assignedUserCode: 'U007',
        buildingDistanceMeters: const {'CEAFA': 24, 'STEERHUB': 44, 'CICS': 58},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000205',
        spaceCode: 'B-C05',
        lotCode: 'B',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.96,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 5)),
        producerId: 'occupancy-lot-b-01',
        buildingDistanceMeters: const {'CEAFA': 38, 'STEERHUB': 48, 'CICS': 68},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000206',
        spaceCode: 'B-C06',
        lotCode: 'B',
        compatibility: 'car_only',
        physicalStatus: 'unknown', // Camera occluded / unknown -> NEVER available!
        allocationStatus: 'unassigned',
        confidence: null,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 15)),
        producerId: 'occupancy-lot-b-01',
        buildingDistanceMeters: const {'CEAFA': 42, 'STEERHUB': 50, 'CICS': 70},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000207',
        spaceCode: 'B-M01',
        lotCode: 'B',
        compatibility: 'motorcycle_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.98,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 5)),
        producerId: 'occupancy-lot-b-01',
        buildingDistanceMeters: const {'CEAFA': 22, 'STEERHUB': 32, 'CICS': 55},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000208',
        spaceCode: 'B-M02',
        lotCode: 'B',
        compatibility: 'motorcycle_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.98,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 5)),
        producerId: 'occupancy-lot-b-01',
        buildingDistanceMeters: const {'CEAFA': 25, 'STEERHUB': 34, 'CICS': 57},
      ),

      // LOT C — Gov. Feliciano Leviste Gymnasium & CICS
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000301',
        spaceCode: 'C-C01',
        lotCode: 'C',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.97,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 6)),
        producerId: 'occupancy-lot-c-01',
        buildingDistanceMeters: const {'CICS': 25, 'CEAFA': 40, 'FITNESS CENTER': 30},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000302',
        spaceCode: 'C-C02',
        lotCode: 'C',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.98,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 6)),
        producerId: 'occupancy-lot-c-01',
        buildingDistanceMeters: const {'CICS': 28, 'CEAFA': 42, 'FITNESS CENTER': 34},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000303',
        spaceCode: 'C-C03',
        lotCode: 'C',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.96,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 6)),
        producerId: 'occupancy-lot-c-01',
        buildingDistanceMeters: const {'CICS': 32, 'CEAFA': 46, 'FITNESS CENTER': 38},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000304',
        spaceCode: 'C-C04',
        lotCode: 'C',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.95,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 6)),
        producerId: 'occupancy-lot-c-01',
        buildingDistanceMeters: const {'CICS': 36, 'CEAFA': 50, 'FITNESS CENTER': 42},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000305',
        spaceCode: 'C-M01',
        lotCode: 'C',
        compatibility: 'motorcycle_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.98,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 6)),
        producerId: 'occupancy-lot-c-01',
        buildingDistanceMeters: const {'CICS': 20, 'CEAFA': 35, 'FITNESS CENTER': 22},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000306',
        spaceCode: 'C-M02',
        lotCode: 'C',
        compatibility: 'motorcycle_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.97,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 6)),
        producerId: 'occupancy-lot-c-01',
        buildingDistanceMeters: const {'CICS': 22, 'CEAFA': 37, 'FITNESS CENTER': 24},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000307',
        spaceCode: 'C-M03',
        lotCode: 'C',
        compatibility: 'motorcycle_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.99,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 6)),
        producerId: 'occupancy-lot-c-01',
        buildingDistanceMeters: const {'CICS': 24, 'CEAFA': 39, 'FITNESS CENTER': 26},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000308',
        spaceCode: 'C-M04',
        lotCode: 'C',
        compatibility: 'motorcycle_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.98,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 6)),
        producerId: 'occupancy-lot-c-01',
        buildingDistanceMeters: const {'CICS': 26, 'CEAFA': 41, 'FITNESS CENTER': 28},
      ),

      // LOT D — RGR Academic & Laboratory Annex
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000401',
        spaceCode: 'D-C01',
        lotCode: 'D',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.98,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 7)),
        producerId: 'occupancy-lot-d-01',
        buildingDistanceMeters: const {'RGR': 22, 'CICS': 48, 'CEAFA': 75},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000402',
        spaceCode: 'D-C02',
        lotCode: 'D',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.97,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 7)),
        producerId: 'occupancy-lot-d-01',
        buildingDistanceMeters: const {'RGR': 25, 'CICS': 50, 'CEAFA': 78},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000403',
        spaceCode: 'D-C03',
        lotCode: 'D',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.96,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 7)),
        producerId: 'occupancy-lot-d-01',
        buildingDistanceMeters: const {'RGR': 28, 'CICS': 54, 'CEAFA': 82},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000404',
        spaceCode: 'D-C04',
        lotCode: 'D',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.97,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 7)),
        producerId: 'occupancy-lot-d-01',
        buildingDistanceMeters: const {'RGR': 32, 'CICS': 58, 'CEAFA': 86},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000405',
        spaceCode: 'D-C05',
        lotCode: 'D',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.98,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 7)),
        producerId: 'occupancy-lot-d-01',
        buildingDistanceMeters: const {'RGR': 35, 'CICS': 62, 'CEAFA': 90},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000406',
        spaceCode: 'D-C06',
        lotCode: 'D',
        compatibility: 'car_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.95,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 7)),
        producerId: 'occupancy-lot-d-01',
        buildingDistanceMeters: const {'RGR': 38, 'CICS': 65, 'CEAFA': 94},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000407',
        spaceCode: 'D-M01',
        lotCode: 'D',
        compatibility: 'motorcycle_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.99,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 7)),
        producerId: 'occupancy-lot-d-01',
        buildingDistanceMeters: const {'RGR': 18, 'CICS': 44, 'CEAFA': 70},
      ),
      SpaceDto(
        spaceId: '30000000-0000-4000-8000-000000000408',
        spaceCode: 'D-M02',
        lotCode: 'D',
        compatibility: 'motorcycle_only',
        physicalStatus: 'available',
        allocationStatus: 'unassigned',
        confidence: 0.98,
        lastObservedAtUtc: now.subtract(const Duration(seconds: 7)),
        producerId: 'occupancy-lot-d-01',
        buildingDistanceMeters: const {'RGR': 20, 'CICS': 46, 'CEAFA': 72},
      ),
    ];
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
        producerId: 'occupancy-lot-a-01',
        deviceType: 'occupancy_camera',
        displayName: 'Overhead Lot A–D Occupancy Vision Node',
        locationLabel: 'STEER Hub & CEAFA Overhead Mast',
        reportedStatus: 'online',
        bootId: '70000000-0000-4000-8000-000000000005',
        sequenceNumber: 964,
        uptimeSeconds: 9640,
        softwareVersion: 'sentry-occupancy-poly-v1.3.1',
        capabilities: const ['occupancy'],
        lastReceivedAtUtc: now.subtract(const Duration(seconds: 4)),
        mappedLotCode: 'A',
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
