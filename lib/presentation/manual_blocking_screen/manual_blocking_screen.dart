import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../services/blocking_service.dart';
import '../../services/analytics_service.dart';
import '../../services/permission_service.dart';
import '../../services/strict_mode_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import '../../presentation/strict_mode_setup/strict_mode_setup_dialog.dart';
import './widgets/additional_options_widget.dart';
import './widgets/app_chip_list_widget.dart';
import './widgets/blocking_preview_card_widget.dart';
import './widgets/duration_picker_widget.dart';
import './widgets/strict_mode_toggle_widget.dart';

/// Manual Blocking Screen for immediate app blocking with custom duration
/// Provides comprehensive blocking configuration with strict mode and additional options
class ManualBlockingScreen extends StatefulWidget {
  const ManualBlockingScreen({Key? key}) : super(key: key);

  @override
  State<ManualBlockingScreen> createState() => _ManualBlockingScreenState();
}

class _ManualBlockingScreenState extends State<ManualBlockingScreen> {
  final List<Map<String, dynamic>> _selectedApps = [];

  int _selectedMinutes = 0;
  bool _isStrictMode = false;
  String? _strictModeLevel; // NONE, EASY, MEDIUM, HARD
  String? _strictModePin; // Encrypted PIN
  int? _strictModeCooldownMinutes;
  bool _isLoading = false;
  String _selectedMessage = 'Stay focused on your goals!';
  bool _notificationsEnabled = true;
  bool _emergencyAccessEnabled = false;
  bool _argsLoaded = false;

  DateTime? get _estimatedEndTime {
    if (_selectedMinutes == 0) return null;
    return DateTime.now().add(Duration(minutes: _selectedMinutes));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        setState(() => _selectedMinutes = args);
      }
      _argsLoaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Manual Blocking',
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: CustomIconWidget(
              iconName: 'help_outline',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected Apps',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addApps,
                          icon: Icon(Icons.add, size: 20),
                          label: Text('Add Apps'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    AppChipListWidget(
                      selectedApps: _selectedApps,
                      onRemoveApp: _removeApp,
                    ),
                    SizedBox(height: 24),
                    DurationPickerWidget(
                      selectedMinutes: _selectedMinutes,
                      onDurationChanged: _updateDuration,
                      onCustomTimePressed: _showCustomTimePicker,
                    ),
                    SizedBox(height: 24),
                    BlockingPreviewCardWidget(
                      appCount: _selectedApps.length,
                      durationMinutes: _selectedMinutes,
                      estimatedEndTime: _estimatedEndTime,
                    ),
                    SizedBox(height: 24),
                    StrictModeToggleWidget(
                      isStrictMode: _isStrictMode,
                      onToggleChanged: _toggleStrictMode,
                    ),
                    SizedBox(height: 24),
                    AdditionalOptionsWidget(
                      selectedMessage: _selectedMessage,
                      notificationsEnabled: _notificationsEnabled,
                      emergencyAccessEnabled: _emergencyAccessEnabled,
                      onMessageChanged: (message) =>
                          setState(() => _selectedMessage = message),
                      onNotificationsChanged: (enabled) =>
                          setState(() => _notificationsEnabled = enabled),
                      onEmergencyAccessChanged: (enabled) =>
                          setState(() => _emergencyAccessEnabled = enabled),
                    ),
                    SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildStartBlockingButton(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStartBlockingButton(BuildContext context, ThemeData theme) {
    final isEnabled = _selectedApps.isNotEmpty && _selectedMinutes >= 5;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedMinutes > 0 && _selectedMinutes < 5)
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'warning',
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Minimum blocking duration is 5 minutes',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isEnabled && !_isLoading ? _startBlocking : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEnabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: isEnabled
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isEnabled ? 2 : 0,
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomIconWidget(
                            iconName: 'block',
                            color: isEnabled
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Start Blocking',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isEnabled
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addApps() async {
    final result = await Navigator.pushNamed(context, '/app-selection-screen');
    print('DEBUG: App selection result: $result');
    print('DEBUG: Result type: ${result.runtimeType}');

    if (result != null && result is List) {
      print('DEBUG: Result is a list with ${result.length} items');
      setState(() => _isLoading = true);

      try {
        final analyticsService = AnalyticsService();
        final newApps = <Map<String, dynamic>>[];

        for (final package in result) {
          print('DEBUG: Processing package: $package');
          if (_selectedApps.any((app) => app['package'] == package)) {
            print('DEBUG: Package $package already selected, skipping');
            continue;
          }

          final appInfo = await analyticsService.getAppInfo(package.toString());
          if (appInfo != null) {
            print('DEBUG: Got app info for ${appInfo.appName}');
            newApps.add({
              'name': appInfo.appName,
              'package': appInfo.packageName,
              'iconBase64': appInfo.iconBase64,
              'icon': 'apps', // Fallback
            });
          } else {
            print('DEBUG: No app info found for package: $package');
          }
        }

        print('DEBUG: Adding ${newApps.length} new apps to selection');
        if (mounted) {
          setState(() {
            _selectedApps.addAll(newApps);
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error adding apps: $e');
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      print('DEBUG: Result is null or not a list');
    }
  }

  void _removeApp(int index) {
    setState(() {
      _selectedApps.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('App removed from blocking list'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _updateDuration(int minutes) {
    setState(() {
      _selectedMinutes = minutes;
    });
  }

  void _showCustomTimePicker() {
    if (Platform.isIOS) {
      _showIOSTimePicker();
    } else {
      _showAndroidTimePicker();
    }
  }

  void _showIOSTimePicker() {
    int hours = 0;
    int minutes = 15;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 300,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Select Custom Duration',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 40,
                      onSelectedItemChanged: (index) => hours = index,
                      children: List.generate(
                        25,
                        (index) => Center(child: Text('$index hr')),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 40,
                      scrollController: FixedExtentScrollController(
                        initialItem: 3,
                      ),
                      onSelectedItemChanged: (index) => minutes = index * 5,
                      children: List.generate(
                        12,
                        (index) => Center(child: Text('${index * 5} min')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final totalMinutes = (hours * 60) + minutes;
                  if (totalMinutes > 1440) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Maximum blocking duration is 24 hours'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  } else {
                    _updateDuration(totalMinutes);
                    Navigator.pop(context);
                  }
                },
                child: Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAndroidTimePicker() async {
    int hours = 0;
    int minutes = 15;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Custom Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Hours',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      hours = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Minutes',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      minutes = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final totalMinutes = (hours * 60) + minutes;
              if (totalMinutes > 1440) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Maximum blocking duration is 24 hours'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              } else if (totalMinutes < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Minimum blocking duration is 5 minutes'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              } else {
                _updateDuration(totalMinutes);
                Navigator.pop(context);
              }
            },
            child: Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _toggleStrictMode(bool value) async {
    if (value) {
      // Show strict mode setup dialog
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StrictModeSetupDialog(
          currentLevel: _strictModeLevel,
          currentPin: null, // Don't show existing PIN
          currentCooldownMinutes: _strictModeCooldownMinutes,
        ),
      );

      if (result != null) {
        // User configured strict mode
        final level = result['level'] as String;
        final pin = result['pin'] as String?;
        final cooldownMinutes = result['cooldownMinutes'] as int?;

        // Encrypt PIN if provided
        String? encryptedPin;
        if (pin != null && pin.isNotEmpty) {
          final strictModeService = StrictModeService();
          encryptedPin = await strictModeService.encryptPin(pin);
        }

        setState(() {
          _isStrictMode = level != 'NONE';
          _strictModeLevel = level;
          _strictModePin = encryptedPin;
          _strictModeCooldownMinutes = cooldownMinutes;
        });
      }
    } else {
      // Disable strict mode
      setState(() {
        _isStrictMode = false;
        _strictModeLevel = 'NONE';
        _strictModePin = null;
        _strictModeCooldownMinutes = null;
      });
    }
  }

  void _startBlocking() async {
    if (_selectedApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one app to block')),
      );
      return;
    }

    if (_selectedMinutes < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least 5 minutes')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check permissions first
      final permissionService = PermissionService();
      final hasPermissions =
          await permissionService.hasAllCriticalPermissions();

      if (!hasPermissions) {
        setState(() => _isLoading = false);
        _showPermissionDialog();
        return;
      }

      final blockingService = BlockingService();
      final packages =
          _selectedApps.map((app) => app['package'] as String).toList();

      final success = await blockingService.startBlocking(
        durationMinutes: _selectedMinutes,
        apps: packages,
        strictMode: _isStrictMode,
        strictModeLevel: _strictModeLevel ?? 'NONE',
        strictModePin: _strictModePin,
        strictModeCooldownMinutes: _strictModeCooldownMinutes,
        message: _selectedMessage,
      );

      setState(() => _isLoading = false);

      if (success) {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start blocking. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      String errorMessage = 'Error starting blocking: $e';
      if (e.toString().contains("ACTIVE_SESSION")) {
        errorMessage = "A blocking session is already active.";
      } else if (e.toString().contains("SecurityException")) {
        errorMessage = "Permission denied. Please grant all permissions.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Check Permissions',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, '/permission-onboarding-screen');
            },
          ),
        ),
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permissions Required'),
        content: Text(
            'VoidBlock needs permissions to block apps. Please grant them in the next screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/permission-onboarding-screen');
            },
            child: Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: CustomIconWidget(
                iconName: 'check_circle',
                color: theme.colorScheme.primary,
                size: 48,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Blocking Started!',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              '${_selectedApps.length} apps will be blocked for ${_selectedMinutes} minutes',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (_estimatedEndTime != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomIconWidget(
                      iconName: 'access_time',
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Ends at ${_formatTime(_estimatedEndTime!)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/dashboard-screen');
              },
              child: Text('Go to Dashboard'),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manual Blocking Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem(
                theme,
                'Duration Selection',
                'Choose from preset durations or set a custom time between 5 minutes and 24 hours.',
              ),
              SizedBox(height: 12),
              _buildHelpItem(
                theme,
                'Strict Mode',
                'When enabled, you cannot stop blocking until the timer ends. Emergency unlock requires PIN.',
              ),
              SizedBox(height: 12),
              _buildHelpItem(
                theme,
                'Motivational Messages',
                'Select a message that will be displayed when you try to access blocked apps.',
              ),
              SizedBox(height: 12),
              _buildHelpItem(
                theme,
                'Emergency Access',
                'Allow access to phone and messaging apps during blocking for emergencies.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(ThemeData theme, String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
