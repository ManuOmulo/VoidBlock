import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_export.dart';
import '../../main.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/active_schedules_widget.dart';
import './widgets/active_session_widget.dart';
import './widgets/blocked_apps_widget.dart';
import './widgets/daily_stats_widget.dart';
import './widgets/greeting_header_widget.dart';
import './widgets/insights_widget.dart';
import './widgets/active_limits_widget.dart';
import './widgets/peak_usage_heatmap.dart';

import '../../services/permission_service.dart';
import '../../services/analytics_service.dart';
import '../../services/blocking_service.dart';

/// Dashboard Screen - Primary hub for productivity management
/// Shows active schedules, blocked apps, and daily statistics
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, RouteAware {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  final GlobalKey<ActiveSessionWidgetState> _activeSessionKey = GlobalKey();
  final GlobalKey<DailyStatsWidgetState> _statsKey = GlobalKey();
  final GlobalKey<InsightsWidgetState> _insightsKey = GlobalKey();
  final GlobalKey<ActiveSchedulesWidgetState> _schedulesKey = GlobalKey();
  final GlobalKey<BlockedAppsWidgetState> _blockedAppsKey = GlobalKey();
  final GlobalKey<ActiveLimitsWidgetState> _limitsKey = GlobalKey();
  final GlobalKey<PeakUsageHeatmapState> _peakUsageKey = GlobalKey();

  Timer? _autoRefreshTimer;
  bool _isScreenVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load initial data and check permissions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
      _refreshDashboard();
      _startAutoRefresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      MyApp.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    MyApp.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startAutoRefresh() {
    _stopAutoRefresh(); // Cancel existing timer if any
    // Refresh every 30 seconds to catch state changes (schedules/pauses)
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isScreenVisible && mounted) {
        _refreshDashboardSilent();
      }
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  // Called when this route is pushed back onto the navigator
  @override
  void didPopNext() {
    // Auto-refresh when returning to this screen
    _isScreenVisible = true;
    _startAutoRefresh();
    _refreshDashboardSilent();
  }

  // Called when this route becomes active
  @override
  void didPush() {
    _isScreenVisible = true;
    _startAutoRefresh();
  }

  // Called when another route is pushed on top of this route
  @override
  void didPushNext() {
    // Pause auto-refresh when screen is covered
    _isScreenVisible = false;
    _stopAutoRefresh();
  }

  // Called when the route is popped off the navigator
  @override
  void didPop() {
    _stopAutoRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-refresh when app comes back to foreground
      _isScreenVisible = true;
      _startAutoRefresh();
      _refreshDashboardSilent();
    } else if (state == AppLifecycleState.paused) {
      // Stop refresh when app goes to background
      _isScreenVisible = false;
      _stopAutoRefresh();
    }
  }

  Future<void> _refreshDashboardSilent() async {
    // Silent refresh without showing snackbar
    await Future.wait([
      _activeSessionKey.currentState?.refresh() ?? Future.value(),
      _statsKey.currentState?.loadStats() ?? Future.value(),
      _insightsKey.currentState?.refresh() ?? Future.value(),
      _schedulesKey.currentState?.refresh() ?? Future.value(),
      _blockedAppsKey.currentState?.refresh() ?? Future.value(),
      _limitsKey.currentState?.refresh() ?? Future.value(),
      _peakUsageKey.currentState?.refresh() ?? Future.value(),
    ] as Iterable<Future>);
  }

  Future<void> _checkPermissions() async {
    final permissionService = PermissionService();
    final hasPermissions = await permissionService.hasAllCriticalPermissions();

    if (!hasPermissions && mounted) {
      Navigator.pushReplacementNamed(context, '/permission-onboarding-screen');
    }
  }

  Future<void> _refreshDashboard() async {
    HapticFeedback.lightImpact();

    // Trigger refresh on all child widgets
    await Future.wait([
      _activeSessionKey.currentState?.refresh() ?? Future.value(),
      _statsKey.currentState?.loadStats() ?? Future.value(),
      _insightsKey.currentState?.refresh() ?? Future.value(),
      _schedulesKey.currentState?.refresh() ?? Future.value(),
      _blockedAppsKey.currentState?.refresh() ?? Future.value(),
      _limitsKey.currentState?.refresh() ?? Future.value(),
      _peakUsageKey.currentState?.refresh() ?? Future.value(),
    ] as Iterable<Future>);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dashboard updated'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _handleInstantFocus() async {
    HapticFeedback.mediumImpact();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final analyticsService = AnalyticsService();
      final blockingService = BlockingService();

      // 1. Get top 5 most used apps today
      final mostUsedApps = await analyticsService.getMostUsedApps(limit: 5);
      final appsToBlock = mostUsedApps
          .map((app) => app['packageName'] as String)
          .where((pkg) => pkg != 'com.voidblock.app') // Don't block our own app
          .toList();

      if (appsToBlock.isEmpty) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No distracting apps identified yet.')),
        );
        return;
      }

      // 2. Start a 25-minute focus session (Pomodoro)
      final success = await blockingService.startBlocking(
        durationMinutes: 25,
        apps: appsToBlock,
        message: "Deep Focus Session Started",
      );

      if (mounted) Navigator.pop(context); // Close loading

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Instant Focus Active! Blocking ${appsToBlock.length} apps.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
          _refreshDashboard();
        }
      }
    } on PlatformException catch (e) {
      if (mounted) Navigator.pop(context);

      String errorMessage;
      if (e.code == "ACTIVE_SESSION") {
        errorMessage =
            "Failed to start Instant Focus. A blocking session is already active.";
      } else {
        errorMessage = "Failed to start Instant Focus.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to start Instant Focus."),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            GreetingHeaderWidget(
              onSettingsPressed: () => Navigator.pushNamed(context, '/settings-screen'),
            ),
            Expanded(
              child: RefreshIndicator(
                key: _refreshIndicatorKey,
                onRefresh: _refreshDashboard,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      ActiveSessionWidget(key: _activeSessionKey),
                      DailyStatsWidget(key: _statsKey),
                      PeakUsageHeatmap(key: _peakUsageKey),
                      SizedBox(height: 8),
                      InsightsWidget(key: _insightsKey),
                      ActiveLimitsWidget(key: _limitsKey),
                      ActiveSchedulesWidget(key: _schedulesKey),
                      BlockedAppsWidget(key: _blockedAppsKey),
                      SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleInstantFocus,
        icon: CustomIconWidget(
          iconName: 'bolt',
          size: 24,
          color: theme.colorScheme.onPrimary,
        ),
        label: Text('Instant Focus'),
        elevation: 6,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 0,
        onTap: (index) {
          HapticFeedback.lightImpact();
        },
      ),
    );
  }
}
