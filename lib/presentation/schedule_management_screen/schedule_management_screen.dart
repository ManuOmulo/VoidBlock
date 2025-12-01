import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/schedule_service.dart';
import '../../core/app_export.dart';
import '../../main.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/empty_state_widget.dart';
import './widgets/schedule_card_widget.dart';
import './widgets/schedule_filter_widget.dart';
import './widgets/schedule_search_widget.dart';

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({Key? key}) : super(key: key);

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen>
    with RouteAware {
  final TextEditingController _searchController = TextEditingController();
  final ScheduleService _scheduleService = ScheduleService();

  String _selectedFilter = 'all';
  bool _isMultiSelectMode = false;
  bool _isLoading = true;
  Set<int> _selectedScheduleIds = {};
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _filteredSchedules = [];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      MyApp.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    MyApp.routeObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Auto-refresh when returning to this screen
    _loadSchedules();
  }

  @override
  void didPush() {}

  @override
  void didPushNext() {}

  @override
  void didPop() {}

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);

    try {
      final schedulesList = await _scheduleService.getAllSchedules().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Schedule loading timed out');
          return [];
        },
      );

      final mappedSchedules = schedulesList.map((s) {
        final isRunning = _isScheduleRunning(s);
        return {
          'id': s.id,
          'name': s.name,
          'isActive': s.isActive,
          'isStrictMode': s.isStrictMode,
          'isRecurring': s.daysOfWeek.isNotEmpty,
          'nextActivation': _getNextActivationText(s),
          'appCount': s.blockedApps.length,
          'isCurrentlyRunning': isRunning,
          'remainingTime': isRunning ? _calculateRemainingTime(s) : '',
          'hasConflict': false,
          'startTime': s.startTime,
          'endTime': s.endTime,
          'daysOfWeek': s.daysOfWeek,
        };
      }).toList();

      setState(() {
        _schedules = mappedSchedules;
        _filteredSchedules = _applyFilters(mappedSchedules);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading schedules: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load schedules. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadSchedules,
            ),
          ),
        );
      }
    }
  }

  bool _isScheduleRunning(Schedule schedule) {
    if (!schedule.isActive) return false;

    final now = DateTime.now();

    // Schedule uses 0-6 (Sunday=0, Saturday=6)
    // DateTime.weekday uses 1-7 (Monday=1, Sunday=7)
    // Convert DateTime.weekday to 0-6 format
    final todayIn0To6 =
        now.weekday % 7; // Converts 1-7 to 1-6,0 then shifts to 0-6

    if (!schedule.daysOfWeek.contains(todayIn0To6)) return false;

    final startParts = schedule.startTime.split(':').map(int.parse).toList();
    final endParts = schedule.endTime.split(':').map(int.parse).toList();

    final start =
        DateTime(now.year, now.month, now.day, startParts[0], startParts[1]);
    var end = DateTime(now.year, now.month, now.day, endParts[0], endParts[1]);

    if (end.isBefore(start)) {
      end = end.add(Duration(days: 1)); // Overnight schedule
    }

    return now.isAfter(start) && now.isBefore(end);
  }

  String _calculateRemainingTime(Schedule schedule) {
    final now = DateTime.now();
    final endParts = schedule.endTime.split(':').map(int.parse).toList();
    var end = DateTime(now.year, now.month, now.day, endParts[0], endParts[1]);

    // Handle overnight
    final startParts = schedule.startTime.split(':').map(int.parse).toList();
    final start =
        DateTime(now.year, now.month, now.day, startParts[0], startParts[1]);
    if (end.isBefore(start)) {
      end = end.add(Duration(days: 1));
    }

    if (now.isAfter(end)) return '0m';

    final diff = end.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> schedules) {
    var filtered = schedules;

    // Apply status filter
    if (_selectedFilter == 'active') {
      filtered = filtered.where((s) => s['isActive'] == true).toList();
    } else if (_selectedFilter == 'inactive') {
      filtered = filtered.where((s) => s['isActive'] == false).toList();
    } else if (_selectedFilter == 'strict') {
      filtered = filtered.where((s) => s['isStrictMode'] == true).toList();
    } else if (_selectedFilter == 'today') {
      filtered = filtered
          .where((s) => (s['nextActivation'] as String).contains('Today'))
          .toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where((s) => (s['name'] as String).toLowerCase().contains(query))
          .toList();
    }

    return filtered;
  }

  String _getNextActivationText(Schedule schedule) {
    if (!schedule.isActive) return 'Inactive';

    // Parse time
    final startParts = schedule.startTime.split(':');
    final hour = int.tryParse(startParts[0]) ?? 0;
    final minute = int.tryParse(startParts[1]) ?? 0;
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    // Determine day
    final now = DateTime.now();
    final today = now.weekday;

    // Find next active day
    // Sort days
    final sortedDays = List<int>.from(schedule.daysOfWeek)..sort();

    if (sortedDays.isEmpty) return 'Never';

    // Check if runs today later
    if (sortedDays.contains(today)) {
      final start = DateTime(now.year, now.month, now.day, hour, minute);
      if (start.isAfter(now)) {
        return 'Today at $timeStr';
      }
    }

    // Find next day
    int? nextDay;
    for (final day in sortedDays) {
      if (day > today) {
        nextDay = day;
        break;
      }
    }
    // If no later day this week, wrap around to first day next week
    nextDay ??= sortedDays.first;

    final dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[nextDay];

    return '$dayName at $timeStr';
  }

  void _filterSchedules() {
    setState(() {
      _filteredSchedules = _applyFilters(_schedules);
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _filterSchedules();
  }

  void _onSearchChanged(String query) {
    _filterSchedules();
  }

  void _clearSearch() {
    _searchController.clear();
    _filterSchedules();
  }

  Future<void> _toggleSchedule(int scheduleId, bool value) async {
    // Optimistic update
    setState(() {
      final index = _schedules.indexWhere((s) => s['id'] == scheduleId);
      if (index != -1) {
        _schedules[index]['isActive'] = value;
      }
    });
    _filterSchedules();

    // Call service
    final success = await _scheduleService.toggleSchedule(scheduleId, value);

    if (success) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Schedule activated' : 'Schedule deactivated'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Revert on failure
      _loadSchedules();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update schedule')),
      );
    }
  }

  Future<void> _deleteSchedule(int scheduleId) async {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text('Delete Schedule'),
          content: Text(
            'Are you sure you want to delete this schedule? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog first

                // Optimistic remove
                final removedSchedule = _schedules
                    .firstWhere((s) => s['id'] == scheduleId, orElse: () => {});
                setState(() {
                  _schedules.removeWhere((s) => s['id'] == scheduleId);
                });
                _filterSchedules();

                try {
                  final success =
                      await _scheduleService.deleteSchedule(scheduleId);

                  if (success) {
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Schedule deleted'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    // Revert (generic failure)
                    if (removedSchedule.isNotEmpty) {
                      setState(() {
                        _schedules.add(removedSchedule);
                      });
                      _filterSchedules();
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete schedule')),
                    );
                  }
                } catch (e) {
                  // Revert (exception)
                  if (removedSchedule.isNotEmpty) {
                    setState(() {
                      _schedules.add(removedSchedule);
                    });
                    _filterSchedules();
                  }

                  // Handle specific error messages
                  String errorMessage = 'Failed to delete schedule';
                  if (e is PlatformException && e.message != null) {
                    errorMessage = e.message!;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _editSchedule(int scheduleId) {
    Navigator.pushNamed(
      context,
      '/schedule-creator-screen',
      arguments: scheduleId,
    ).then((_) => _loadSchedules()); // Reload on return
  }

  Future<void> _duplicateSchedule(int scheduleId) async {
    // Ideally we should fetch full schedule details first to get blocked apps
    // For now, let's just reload

    final fullSchedule = await _scheduleService.getScheduleById(scheduleId);
    if (fullSchedule != null) {
      final copy = Schedule(
        name: '${fullSchedule.name} (Copy)',
        startTime: fullSchedule.startTime,
        endTime: fullSchedule.endTime,
        daysOfWeek: fullSchedule.daysOfWeek,
        isActive: false,
        isStrictMode: fullSchedule.isStrictMode,
        blockedApps: fullSchedule.blockedApps,
        motivationalMessage: fullSchedule.motivationalMessage,
        notificationsEnabled: fullSchedule.notificationsEnabled,
      );

      await _scheduleService.createSchedule(copy);
      _loadSchedules();

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Schedule duplicated'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _viewStats(int scheduleId) {
    Navigator.pushNamed(context, '/dashboard-screen');
  }

  void _testRun(int scheduleId) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting test run...'),
        duration: Duration(seconds: 2),
      ),
    );
    // Implement test run logic if needed
  }

  void _shareSchedule(int scheduleId) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing schedule configuration...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _exportSchedule(int scheduleId) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting schedule settings...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _createSchedule() {
    Navigator.pushNamed(context, '/schedule-creator-screen')
        .then((_) => _loadSchedules());
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedScheduleIds.clear();
      }
    });
  }

  Future<void> _bulkEnableDisable(bool enable) async {
    final ids = List<int>.from(_selectedScheduleIds);

    // Optimistic update
    setState(() {
      for (final id in ids) {
        final index = _schedules.indexWhere((s) => s['id'] == id);
        if (index != -1) {
          _schedules[index]['isActive'] = enable;
        }
      }
      _selectedScheduleIds.clear();
      _isMultiSelectMode = false;
    });
    _filterSchedules();

    // Process in background
    for (final id in ids) {
      await _scheduleService.toggleSchedule(id, enable);
    }

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enable ? 'Schedules enabled' : 'Schedules disabled'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _bulkDelete() async {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text('Delete Schedules'),
          content: Text(
            'Are you sure you want to delete ${_selectedScheduleIds.length} schedule(s)? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final ids = List<int>.from(_selectedScheduleIds);

                setState(() {
                  _schedules.removeWhere(
                    (s) => ids.contains(s['id']),
                  );
                  _selectedScheduleIds.clear();
                  _isMultiSelectMode = false;
                });
                _filterSchedules();

                for (final id in ids) {
                  await _scheduleService.deleteSchedule(id);
                }

                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Schedules deleted'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshSchedules() async {
    await _loadSchedules();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: _isMultiSelectMode
            ? '${_selectedScheduleIds.length} selected'
            : 'Schedules',
        variant: CustomAppBarVariant.standard,
        actions: [
          if (_isMultiSelectMode) ...[
            IconButton(
              icon: CustomIconWidget(
                iconName: 'check_circle',
                color: theme.colorScheme.primary,
              ),
              onPressed: () => _bulkEnableDisable(true),
              tooltip: 'Enable Selected',
            ),
            IconButton(
              icon: CustomIconWidget(
                iconName: 'cancel',
                color: theme.colorScheme.error,
              ),
              onPressed: () => _bulkEnableDisable(false),
              tooltip: 'Disable Selected',
            ),
            IconButton(
              icon: CustomIconWidget(
                iconName: 'delete',
                color: theme.colorScheme.error,
              ),
              onPressed: _bulkDelete,
              tooltip: 'Delete Selected',
            ),
            IconButton(
              icon: CustomIconWidget(
                iconName: 'close',
                color: theme.colorScheme.onSurface,
              ),
              onPressed: _toggleMultiSelectMode,
              tooltip: 'Cancel',
            ),
          ] else ...[
            IconButton(
              icon: CustomIconWidget(
                iconName: 'checklist',
                color: theme.colorScheme.onSurface,
              ),
              onPressed: _toggleMultiSelectMode,
              tooltip: 'Multi-select',
            ),
            IconButton(
              icon: CustomIconWidget(
                iconName: 'add',
                color: theme.colorScheme.onSurface,
              ),
              onPressed: _createSchedule,
              tooltip: 'Add Schedule',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
              ? EmptyStateWidget(onCreateSchedule: _createSchedule)
              : RefreshIndicator(
                  onRefresh: _refreshSchedules,
                  child: Column(
                    children: [
                      ScheduleSearchWidget(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onClear: _clearSearch,
                      ),
                      ScheduleFilterWidget(
                        selectedFilter: _selectedFilter,
                        onFilterChanged: _onFilterChanged,
                      ),
                      SizedBox(height: 8),
                      Expanded(
                        child: _filteredSchedules.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CustomIconWidget(
                                      iconName: 'search_off',
                                      size: 64,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No schedules found',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your filters',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.only(bottom: 80),
                                itemCount: _filteredSchedules.length,
                                itemBuilder: (context, index) {
                                  final schedule = _filteredSchedules[index];
                                  final scheduleId = schedule['id'] as int;

                                  return _isMultiSelectMode
                                      ? CheckboxListTile(
                                          value: _selectedScheduleIds.contains(
                                            scheduleId,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedScheduleIds.add(
                                                  scheduleId,
                                                );
                                              } else {
                                                _selectedScheduleIds.remove(
                                                  scheduleId,
                                                );
                                              }
                                            });
                                          },
                                          title:
                                              Text(schedule['name'] as String),
                                          subtitle: Text(
                                            schedule['nextActivation']
                                                as String,
                                          ),
                                          secondary: CustomIconWidget(
                                            iconName:
                                                schedule['isActive'] == true
                                                    ? 'check_circle'
                                                    : 'cancel',
                                            color: schedule['isActive'] == true
                                                ? theme.colorScheme.secondary
                                                : theme.colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        )
                                      : ScheduleCardWidget(
                                          schedule: schedule,
                                          onEdit: () =>
                                              _editSchedule(scheduleId),
                                          onDuplicate: () =>
                                              _duplicateSchedule(scheduleId),
                                          onViewStats: () =>
                                              _viewStats(scheduleId),
                                          onDelete: () =>
                                              _deleteSchedule(scheduleId),
                                          onTestRun: () => _testRun(scheduleId),
                                          onShare: () =>
                                              _shareSchedule(scheduleId),
                                          onExport: () =>
                                              _exportSchedule(scheduleId),
                                          onToggle: (value) => _toggleSchedule(
                                              scheduleId, value),
                                        );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: _schedules.isNotEmpty && !_isMultiSelectMode
          ? FloatingActionButton.extended(
              onPressed: _createSchedule,
              icon: CustomIconWidget(iconName: 'add', color: Colors.white),
              label: Text('New Schedule'),
            )
          : null,
    );
  }
}
