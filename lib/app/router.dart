import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/access_logs/presentation/access_logs_screen.dart';
import '../features/administration/presentation/administration_screen.dart';
import '../features/device_monitoring/presentation/device_monitoring_screen.dart';
import '../features/guard_reviews/presentation/guard_reviews_screen.dart';
import '../features/live_gate_monitoring/presentation/live_gate_monitoring_screen.dart';
import '../features/overview/presentation/overview_screen.dart';
import '../features/parking_management/presentation/parking_management_screen.dart';
import 'providers.dart';

/// Role-aware view host mapping [DesktopNavTab] to the 7 authenticated SENTRY views.
class DesktopViewRouter extends ConsumerWidget {
  /// When set, renders this tab regardless of the selected-tab provider
  /// (used by the shell so outgoing pages keep their content mid-transition).
  final DesktopNavTab? tab;

  const DesktopViewRouter({super.key, this.tab});

  static Widget screenFor(DesktopNavTab tab) {
    switch (tab) {
      case DesktopNavTab.overview:
        return const OverviewScreen();
      case DesktopNavTab.liveGateMonitoring:
        return const LiveGateMonitoringScreen();
      case DesktopNavTab.guardReviews:
        return const GuardReviewsScreen();
      case DesktopNavTab.parkingManagement:
        return const ParkingManagementScreen();
      case DesktopNavTab.accessLogs:
        return const AccessLogsScreen();
      case DesktopNavTab.deviceMonitoring:
        return const DeviceMonitoringScreen();
      case DesktopNavTab.administration:
        return const AdministrationScreen();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return screenFor(tab ?? ref.watch(selectedDesktopTabProvider));
  }
}
