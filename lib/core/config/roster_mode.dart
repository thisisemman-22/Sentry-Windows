/// Roster display mode toggle supporting both:
/// - [RosterMode.classDemo]: Real CoE 4102 classmate names & license plates for live defense demo
/// - [RosterMode.contractSynthetic]: Strict `Synthetic Student 001–007` & `DEMO001–DEMO008` for automated tests
enum RosterMode {
  classDemo,
  contractSynthetic;

  static RosterMode fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'contract':
      case 'contract_synthetic':
      case 'synthetic':
        return RosterMode.contractSynthetic;
      case 'class_demo':
      case 'demo':
      default:
        return RosterMode.classDemo;
    }
  }

  String get label => this == RosterMode.classDemo
      ? 'Class Demo Roster (CoE 4102)'
      : 'Contract Synthetic Roster (DEMO001–008)';

  String get shortLabel =>
      this == RosterMode.classDemo ? 'CLASS DEMO ROSTER' : 'CONTRACT ROSTER';
}
