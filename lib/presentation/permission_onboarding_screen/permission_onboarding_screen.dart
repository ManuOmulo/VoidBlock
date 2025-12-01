import 'package:flutter/material.dart';
import '../../services/permission_service.dart';

/**
 * Permission onboarding screen
 * Guides users through granting required permissions
 */
class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen>
    with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();

  Map<String, bool> _permissions = {
    'usageStats': false,
    'overlay': false,
    'notification': false,
    'batteryOptimization': false,
    'exactAlarms': false,
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-refresh when user returns from settings
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);

    final permissions = await _permissionService.checkAllPermissions();

    setState(() {
      _permissions = permissions;
      _isLoading = false;
    });
  }

  Future<void> _requestPermission(String permission) async {
    switch (permission) {
      case 'usageStats':
        await _permissionService.requestUsageStatsPermission();
        break;
      case 'overlay':
        await _permissionService.requestOverlayPermission();
        break;
      case 'notification':
        await _permissionService.requestNotificationPermission();
        break;
      case 'batteryOptimization':
        await _permissionService.requestBatteryOptimization();
        break;
      case 'exactAlarms':
        await _permissionService.requestExactAlarmsPermission();
        break;
    }

    // Refresh permissions after request
    await Future.delayed(Duration(seconds: 1));
    _checkPermissions();
  }

  bool get _allCriticalPermissionsGranted {
    return _permissions['usageStats'] == true &&
        _permissions['overlay'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Permissions'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(20),
                    children: [
                      Text(
                        'Required Permissions',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'FocusGuard needs these permissions to block apps effectively',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildPermissionCard(
                        'Usage Stats',
                        'Required to detect which apps you\'re using',
                        'usageStats',
                        Icons.analytics_outlined,
                        true,
                      ),
                      _buildPermissionCard(
                        'Display Overlay',
                        'Required to show blocking screen',
                        'overlay',
                        Icons.layers_outlined,
                        true,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Optional Permissions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildPermissionCard(
                        'Notifications',
                        'Get reminders and blocking notifications',
                        'notification',
                        Icons.notifications_outlined,
                        false,
                      ),
                      _buildPermissionCard(
                        'Battery Optimization',
                        'Keep blocking active in background',
                        'batteryOptimization',
                        Icons.battery_charging_full_outlined,
                        false,
                      ),
                      _buildPermissionCard(
                        'Exact Alarms',
                        'Schedule blocking sessions accurately',
                        'exactAlarms',
                        Icons.alarm_outlined,
                        false,
                      ),
                      SizedBox(height: 80),
                    ],
                  ),
                ),
                _buildBottomBar(theme),
              ],
            ),
    );
  }

  Widget _buildPermissionCard(
    String title,
    String description,
    String permissionKey,
    IconData icon,
    bool isRequired,
  ) {
    final theme = Theme.of(context);
    final isGranted = _permissions[permissionKey] == true;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGranted
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isGranted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 28,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRequired) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            if (isGranted)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 28,
              )
            else
              ElevatedButton(
                onPressed: () => _requestPermission(permissionKey),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text('Grant'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_allCriticalPermissionsGranted)
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_outlined,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Required permissions needed to continue',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _allCriticalPermissionsGranted
                    ? () {
                        Navigator.pushReplacementNamed(
                            context, '/dashboard-screen');
                      }
                    : null,
                child: Text(
                  _allCriticalPermissionsGranted
                      ? 'Get Started'
                      : 'Grant Required Permissions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
