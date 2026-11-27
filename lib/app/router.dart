import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/announcements/presentation/announcements_screen.dart';
import '../features/audit/presentation/audit_screen.dart';
import '../features/guard_ops/presentation/guard_guest_check_screen.dart';
import '../features/guard_ops/presentation/guard_manual_entry_screen.dart';
import '../features/guard_ops/presentation/guard_monitor_screen.dart';
import '../features/guard_ops/presentation/guard_overdue_guests_screen.dart';
import '../features/guard_reviews/presentation/guard_reviews_screen.dart';
import '../features/guests/presentation/guests_screen.dart';
import '../features/monitoring/presentation/monitoring_screen.dart';
import '../features/overview/presentation/overview_screen.dart';
import '../features/parking_management/presentation/parking_management_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/users/presentation/users_screen.dart';
import '../features/vehicles_rfid/presentation/vehicles_rfid_screen.dart';
import 'providers.dart';

/// Resolves Desktop Navigation tabs (10 Admin sections + 5 Guard sections)
/// while strictly enforcing role-scoped RBAC isolation.
class DesktopRouter {
  DesktopRouter._();

  static Widget screenFor(DesktopNavTab tab, {required bool isAdmin}) {
    if (!isAdmin && tab.isAdminOnly) {
      return const GuardReviewsScreen();
    }
    if (isAdmin && tab.isGuardOnly) {
      return const OverviewScreen();
    }
    switch (tab) {
      case DesktopNavTab.dashboard:
        return const OverviewScreen();
      case DesktopNavTab.users:
        return const UsersScreen();
      case DesktopNavTab.vehiclesRfid:
        return const VehiclesRfidScreen();
      case DesktopNavTab.parking:
        return const ParkingManagementScreen();
      case DesktopNavTab.guests:
        return const GuestsScreen();
      case DesktopNavTab.monitoring:
        return const MonitoringScreen();
      case DesktopNavTab.reports:
        return const ReportsScreen();
      case DesktopNavTab.announcements:
        return const AnnouncementsScreen();
      case DesktopNavTab.audit:
        return const AuditScreen();
      case DesktopNavTab.settings:
        return const SettingsScreen();
      case DesktopNavTab.guardReviewQueue:
        return const GuardReviewsScreen();
      case DesktopNavTab.guardMonitor:
        return const GuardMonitorScreen();
      case DesktopNavTab.guardGuestCheck:
        return const GuardGuestCheckScreen();
      case DesktopNavTab.guardManualEntry:
        return const GuardManualEntryScreen();
      case DesktopNavTab.guardOverdueGuests:
        return const GuardOverdueGuestsScreen();
    }
  }
}

/// Widget wrapper that enforces RBAC isolation when rendering [tab].
class DesktopViewRouter extends ConsumerWidget {
  final DesktopNavTab tab;
  const DesktopViewRouter({super.key, required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin =
        ref.watch(authControllerProvider).profile?.role.isAdmin ?? false;
    return DesktopRouter.screenFor(tab, isAdmin: isAdmin);
  }
}
