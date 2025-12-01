import 'package:flutter/material.dart';
import '../presentation/app_selection_screen/app_selection_screen.dart';
import '../presentation/dashboard_screen/dashboard_screen.dart';
import '../presentation/schedule_management_screen/schedule_management_screen.dart';
import '../presentation/schedule_creator_screen/schedule_creator_screen.dart';
import '../presentation/manual_blocking_screen/manual_blocking_screen.dart';
import '../presentation/strict_mode_lock_screen/strict_mode_lock_screen.dart';
import '../presentation/permission_onboarding_screen/permission_onboarding_screen.dart';
import '../presentation/insights_screen/insights_screen.dart';

class AppRoutes {
  // TODO: Add your routes here
  static const String initial = '/';
  static const String appSelection = '/app-selection-screen';
  static const String dashboard = '/dashboard-screen';
  static const String scheduleManagement = '/schedule-management-screen';
  static const String scheduleCreator = '/schedule-creator-screen';
  static const String manualBlocking = '/manual-blocking-screen';
  static const String strictModeLock = '/strict-mode-lock-screen';
  static const String permissionOnboarding = '/permission-onboarding-screen';
  static const String insights = '/insights-screen';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const DashboardScreen(),
    appSelection: (context) => const AppSelectionScreen(),
    dashboard: (context) => const DashboardScreen(),
    scheduleManagement: (context) => const ScheduleManagementScreen(),
    scheduleCreator: (context) => const ScheduleCreatorScreen(),
    manualBlocking: (context) => const ManualBlockingScreen(),
    strictModeLock: (context) => const StrictModeLockScreen(),
    permissionOnboarding: (context) => const PermissionOnboardingScreen(),
    insights: (context) => const InsightsScreen(),
    // TODO: Add your other routes here
  };
}
