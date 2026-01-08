import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_icon_widget.dart';
import '../../services/strict_mode_service.dart';
import '../../presentation/strict_mode_setup/strict_mode_setup_dialog.dart';
import './widgets/advanced_options_section.dart';
import './widgets/app_selection_section.dart';
import './widgets/recurring_schedule_section.dart';
import './widgets/schedule_details_section.dart';
import './widgets/time_configuration_section.dart';
import './widgets/timeline_preview_widget.dart';

import '../../services/analytics_service.dart';
import '../../services/schedule_service.dart';

/// Schedule Creator Screen for comprehensive blocking schedule configuration
class ScheduleCreatorScreen extends StatefulWidget {
  const ScheduleCreatorScreen({Key? key}) : super(key: key);

  @override
  State<ScheduleCreatorScreen> createState() => _ScheduleCreatorScreenState();
}

class _ScheduleCreatorScreenState extends State<ScheduleCreatorScreen> {
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _motivationalMessageController =
      TextEditingController();

  // Schedule configuration state
  int? _scheduleId;
  int _selectedAppsCount = 0;
  List<Map<String, dynamic>> _selectedApps = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  Set<int> _selectedDays = {};
  bool _strictModeEnabled = false;
  String? _strictModeLevel; // NONE, EASY, MEDIUM, HARD
  String? _strictModePin; // Encrypted PIN
  int? _strictModeCooldownMinutes;
  bool _notificationsEnabled = true;
  String _selectedPattern = 'custom';
  bool _isEditing = false;
  bool _isLoading = false;

  // UI state
  bool _scheduleDetailsExpanded = true;
  bool _appSelectionExpanded = true;
  bool _timeConfigExpanded = true;
  bool _advancedOptionsExpanded = false;
  bool _recurringPatternExpanded = false;
  bool _hasUnsavedChanges = false;

  final AnalyticsService _analyticsService = AnalyticsService();
  final ScheduleService _scheduleService = ScheduleService();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFormChanged);
    _motivationalMessageController.addListener(_onFormChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is int && !_isEditing) {
      _scheduleId = args;
      _isEditing = true;
      _loadScheduleDetails(args);
    }
  }

  Future<void> _loadScheduleDetails(int id) async {
    setState(() => _isLoading = true);
    try {
      final schedule = await _scheduleService.getScheduleById(id);
      if (schedule != null) {
        _nameController.text = schedule.name;
        if (schedule.motivationalMessage != null) {
          _motivationalMessageController.text = schedule.motivationalMessage!;
        }

        final startParts = schedule.startTime.split(':');
        _startTime = TimeOfDay(
            hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));

        final endParts = schedule.endTime.split(':');
        _endTime = TimeOfDay(
            hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));

        _selectedDays = schedule.daysOfWeek.toSet();
        _strictModeEnabled = schedule.isStrictMode;
        if (_strictModeEnabled) {
          _strictModeLevel = schedule.strictModeLevel;
          _strictModePin = schedule.strictModePin;
          _strictModeCooldownMinutes = schedule.strictModeCooldownMinutes;
        }
        _notificationsEnabled = schedule.notificationsEnabled;

        // Load apps
        final List<Map<String, dynamic>> loadedApps = [];
        for (var pkg in schedule.blockedApps) {
          final appInfo = await _analyticsService.getAppInfo(pkg);
          if (appInfo != null) {
            loadedApps.add({
              'packageName': appInfo.packageName,
              'name': appInfo.appName,
              'icon': appInfo.iconBase64 != null
                  ? 'data:image/png;base64,${appInfo.iconBase64}'
                  : null,
            });
          }
        }
        _selectedApps = loadedApps;
        _selectedAppsCount = loadedApps.length;

        // Determine pattern
        if (_selectedDays.length == 7)
          _selectedPattern = 'daily';
        else if (_selectedDays.length == 5 &&
            !_selectedDays.contains(6) &&
            !_selectedDays.contains(0))
          _selectedPattern = 'weekdays';
        else if (_selectedDays.length == 2 &&
            _selectedDays.contains(6) &&
            _selectedDays.contains(0))
          _selectedPattern = 'weekends';
        else
          _selectedPattern = 'custom';
      }
    } catch (e) {
      print('Error loading schedule: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _motivationalMessageController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  bool _isFormValid() {
    return _nameController.text.trim().isNotEmpty &&
        _selectedAppsCount > 0 &&
        _startTime != null &&
        _endTime != null &&
        _selectedDays.isNotEmpty;
  }

  List<String> _getSuggestedNames() {
    if (_selectedAppsCount == 0) return [];

    final List<String> suggestions = [
      'Focus Time',
      'Work Hours',
      'Study Session',
      'Deep Work',
      'No Distractions',
    ];

    if (_selectedDays.length == 5 &&
        !_selectedDays.contains(6) && // Sat
        !_selectedDays.contains(0)) {
      // Sun
      suggestions.insert(0, 'Weekday Focus');
    } else if (_selectedDays.length == 2 &&
        _selectedDays.contains(6) && // Sat
        _selectedDays.contains(0)) {
      // Sun
      suggestions.insert(0, 'Weekend Detox');
    }

    return suggestions.take(3).toList();
  }

  void _handleSuggestionTap(String name) {
    setState(() {
      _nameController.text = name;
    });
  }

  Future<void> _handleChangeApps() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.pushNamed(context, '/app-selection-screen');

    if (result != null && result is List<String>) {
      final List<Map<String, dynamic>> newSelectedApps = [];

      for (String packageName in result) {
        final appInfo = await _analyticsService.getAppInfo(packageName);
        if (appInfo != null) {
          newSelectedApps.add({
            'packageName': appInfo.packageName,
            'name': appInfo.appName,
            'icon': appInfo.iconBase64 != null
                ? 'data:image/png;base64,${appInfo.iconBase64}'
                : null,
            'semanticLabel': 'App icon for ${appInfo.appName}',
          });
        }
      }

      if (mounted) {
        setState(() {
          _selectedApps = newSelectedApps;
          _selectedAppsCount = newSelectedApps.length;
          _hasUnsavedChanges = true;
        });
      }
    }
  }

  void _handleDayToggle(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
      _hasUnsavedChanges = true;
    });
  }

  void _handlePatternChanged(String pattern) {
    setState(() {
      _selectedPattern = pattern;
      _selectedDays.clear();

      switch (pattern) {
        case 'daily':
          _selectedDays = {0, 1, 2, 3, 4, 5, 6}; // Sun-Sat
          break;
        case 'weekdays':
          _selectedDays = {1, 2, 3, 4, 5}; // Mon-Fri (ISO weekday 1-5)
          break;
        case 'weekends':
          _selectedDays = {6, 0}; // Sat, Sun
          break;
        case 'custom':
          break;
      }
      _hasUnsavedChanges = true;
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unsaved Changes'),
        content: Text('You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _handleSave() async {
    if (!_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Get package names from selected apps
      final List<String> blockedApps = _selectedApps
          .map((app) => app['packageName'] as String? ?? '')
          .where((pkg) => pkg.isNotEmpty)
          .toList();

      // Create schedule object
      final schedule = Schedule(
        id: _scheduleId,
        name: _nameController.text.trim(),
        startTime:
            '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
        endTime:
            '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
        daysOfWeek: _selectedDays.toList(),
        isActive: true,
        isStrictMode: _strictModeEnabled,
        strictModeLevel: _strictModeLevel ?? 'NONE',
        strictModePin: _strictModePin,
        strictModeCooldownMinutes: _strictModeCooldownMinutes,
        motivationalMessage: _motivationalMessageController.text.trim().isEmpty
            ? null
            : _motivationalMessageController.text.trim(),
        notificationsEnabled: _notificationsEnabled,
        blockedApps: blockedApps,
      );

      // Call service to create schedule
      // Call service to create or update schedule
      bool success;
      if (_isEditing) {
        success = await _scheduleService.updateSchedule(schedule);
      } else {
        success = await _scheduleService.createSchedule(schedule);
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'check_circle',
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 3.w),
                  Text(_isEditing
                      ? 'Schedule updated successfully!'
                      : 'Schedule created successfully!'),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );

          // Navigate back to schedule management by popping until we reach it
          if (mounted) {
            Navigator.popUntil(
              context,
              (route) =>
                  route.settings.name == '/schedule-management-screen' ||
                  route.isFirst,
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create schedule. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving schedule: $e');

      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating schedule: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Schedule' : 'Create Schedule'),
          leading: IconButton(
            icon: CustomIconWidget(
              iconName: 'arrow_back',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton.icon(
              onPressed: _isFormValid() ? _handleSave : null,
              icon: CustomIconWidget(
                iconName: 'save',
                color: _isFormValid()
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
              label: Text(
                'Save',
                style: TextStyle(
                  color: _isFormValid()
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                ),
              ),
            ),
            SizedBox(width: 2.w),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  LinearProgressIndicator(
                    value: _calculateProgress(),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 2.h),
                          ScheduleDetailsSection(
                            nameController: _nameController,
                            characterCount: _nameController.text.length,
                            maxCharacters: 50,
                            suggestedNames: _getSuggestedNames(),
                            onSuggestionTap: _handleSuggestionTap,
                            isExpanded: _scheduleDetailsExpanded,
                            onToggleExpand: () {
                              setState(() {
                                _scheduleDetailsExpanded =
                                    !_scheduleDetailsExpanded;
                              });
                            },
                          ),
                          AppSelectionSection(
                            selectedAppsCount: _selectedAppsCount,
                            selectedApps: _selectedApps,
                            onChangeApps: _handleChangeApps,
                            isExpanded: _appSelectionExpanded,
                            onToggleExpand: () {
                              setState(() {
                                _appSelectionExpanded = !_appSelectionExpanded;
                              });
                            },
                          ),
                          TimeConfigurationSection(
                            startTime: _startTime,
                            endTime: _endTime,
                            selectedDays: _selectedDays,
                            onStartTimeChanged: (time) {
                              setState(() {
                                _startTime = time;
                                _hasUnsavedChanges = true;
                              });
                            },
                            onEndTimeChanged: (time) {
                              setState(() {
                                _endTime = time;
                                _hasUnsavedChanges = true;
                              });
                            },
                            onDayToggle: _handleDayToggle,
                            isExpanded: _timeConfigExpanded,
                            onToggleExpand: () {
                              setState(() {
                                _timeConfigExpanded = !_timeConfigExpanded;
                              });
                            },
                          ),
                          TimelinePreviewWidget(
                            startTime: _startTime,
                            endTime: _endTime,
                            selectedDays: _selectedDays,
                          ),
                          RecurringScheduleSection(
                            selectedPattern: _selectedPattern,
                            onPatternChanged: _handlePatternChanged,
                            isExpanded: _recurringPatternExpanded,
                            onToggleExpand: () {
                              setState(() {
                                _recurringPatternExpanded =
                                    !_recurringPatternExpanded;
                              });
                            },
                          ),
                          AdvancedOptionsSection(
                            strictModeEnabled: _strictModeEnabled,
                            onStrictModeChanged: (value) async {
                              if (value) {
                                // Show strict mode setup dialog
                                final result =
                                    await showDialog<Map<String, dynamic>>(
                                  context: context,
                                  builder: (context) => StrictModeSetupDialog(
                                    currentLevel: _strictModeLevel,
                                    currentPin: null,
                                    currentCooldownMinutes:
                                        _strictModeCooldownMinutes,
                                  ),
                                );

                                if (result != null) {
                                  final level = result['level'] as String;
                                  final pin = result['pin'] as String?;
                                  final cooldownMinutes =
                                      result['cooldownMinutes'] as int?;

                                  // Encrypt PIN if provided
                                  String? encryptedPin;
                                  if (pin != null && pin.isNotEmpty) {
                                    final strictModeService =
                                        StrictModeService();
                                    encryptedPin =
                                        await strictModeService.encryptPin(pin);
                                  }

                                  setState(() {
                                    _strictModeEnabled = level != 'NONE';
                                    _strictModeLevel = level;
                                    _strictModePin = encryptedPin;
                                    _strictModeCooldownMinutes =
                                        cooldownMinutes;
                                    _hasUnsavedChanges = true;
                                  });
                                }
                              } else {
                                setState(() {
                                  _strictModeEnabled = false;
                                  _strictModeLevel = 'NONE';
                                  _strictModePin = null;
                                  _strictModeCooldownMinutes = null;
                                  _hasUnsavedChanges = true;
                                });
                              }
                            },
                            motivationalMessageController:
                                _motivationalMessageController,
                            notificationsEnabled: _notificationsEnabled,
                            onNotificationsChanged: (value) {
                              setState(() {
                                _notificationsEnabled = value;
                                _hasUnsavedChanges = true;
                              });
                            },
                            isExpanded: _advancedOptionsExpanded,
                            onToggleExpand: () {
                              setState(() {
                                _advancedOptionsExpanded =
                                    !_advancedOptionsExpanded;
                              });
                            },
                          ),
                          SizedBox(height: 10.h),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        floatingActionButton: _isFormValid()
            ? FloatingActionButton.extended(
                onPressed: _handleSave,
                icon: CustomIconWidget(
                  iconName: 'check',
                  color: theme.colorScheme.onPrimary,
                  size: 24,
                ),
                label: Text(_isEditing ? 'Save Changes' : 'Create Schedule'),
              )
            : null,
      ),
    );
  }

  double _calculateProgress() {
    int completedSteps = 0;
    const int totalSteps = 4;

    if (_nameController.text.trim().isNotEmpty) completedSteps++;
    if (_selectedAppsCount > 0) completedSteps++;
    if (_startTime != null && _endTime != null && _selectedDays.isNotEmpty)
      completedSteps++;
    if (_motivationalMessageController.text.trim().isNotEmpty ||
        _strictModeEnabled) completedSteps++;

    return completedSteps / totalSteps;
  }
}
