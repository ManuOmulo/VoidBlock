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

import '../../services/permission_service.dart';

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
    // Refresh every 10 seconds to catch schedule starts/stops/pauses
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
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
    ]);
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
    ]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dashboard updated'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _showQuickBlockingSheet() async {
    HapticFeedback.mediumImpact();

    // TODO: Implement getLastSession in BlockingService to retrieve actual last session
    // For now, show a dialog explaining the feature
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'replay',
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 12),
            Text('Quick Repeat'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will repeat your last blocking session with:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.apps, size: 16),
                      SizedBox(width: 8),
                      Text('Same apps'),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16),
                      SizedBox(width: 8),
                      Text('Same duration'),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.settings, size: 16),
                      SizedBox(width: 8),
                      Text('Same settings'),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Note: This feature will be fully implemented in the next update. For now, use Manual Blocking to configure your session.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Go to Manual Blocking'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Navigator.pushNamed(context, '/manual-blocking-screen');
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
            GreetingHeaderWidget(),
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
                      InsightsWidget(key: _insightsKey),
                      ActiveSchedulesWidget(key: _schedulesKey),
                      BlockedAppsWidget(key: _blockedAppsKey),
                      SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuickBlockingSheet,
        icon: CustomIconWidget(
          iconName: 'replay',
          size: 24,
          color: theme.colorScheme.onPrimary,
        ),
        label: Text('Quick Repeat'),
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
