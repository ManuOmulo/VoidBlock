import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/app_export.dart';
import '../../../services/schedule_service.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Active schedules section showing currently running schedules
class ActiveSchedulesWidget extends StatefulWidget {
  const ActiveSchedulesWidget({Key? key}) : super(key: key);

  @override
  State<ActiveSchedulesWidget> createState() => ActiveSchedulesWidgetState();
}

class ActiveSchedulesWidgetState extends State<ActiveSchedulesWidget> {
  final ScheduleService _scheduleService = ScheduleService();
  List<Schedule> _activeSchedules = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    // Update UI every minute to keep countdown fresh
    _timer = Timer.periodic(Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    await _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    if (!mounted) return;

    try {
      final schedules = await _scheduleService.getAllSchedules().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Schedule loading timed out');
          return [];
        },
      );

      if (mounted) {
        setState(() {
          // Filter to show only enabled schedules
          _activeSchedules = schedules.where((s) => s.isActive).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading schedules: $e');
      if (mounted) {
        setState(() {
          _activeSchedules = [];
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSchedule(Schedule schedule) async {
    HapticFeedback.lightImpact();
    if (schedule.id == null) return;

    final newStatus = !schedule.isActive;

    // Optimistic update
    setState(() {
      // We can't modify Schedule as it's final, so we wait for refresh
    });

    final success =
        await _scheduleService.toggleSchedule(schedule.id!, newStatus);

    if (success) {
      _loadSchedules();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Schedule "${schedule.name}" activated'
                : 'Schedule "${schedule.name}" paused',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _editSchedule(Schedule schedule) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(
      context,
      '/schedule-creator-screen',
      arguments: schedule.toJson(),
    ).then((_) => _loadSchedules());
  }

  void _duplicateSchedule(Schedule schedule) async {
    HapticFeedback.lightImpact();

    final newSchedule = Schedule(
      name: "${schedule.name} (Copy)",
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      daysOfWeek: schedule.daysOfWeek,
      isActive: schedule.isActive,
      isStrictMode: false,
      motivationalMessage: schedule.motivationalMessage,
      notificationsEnabled: schedule.notificationsEnabled,
      blockedApps: schedule.blockedApps,
    );

    final success = await _scheduleService.createSchedule(newSchedule);

    if (success) {
      _loadSchedules();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Schedule duplicated successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _deleteSchedule(Schedule schedule) {
    HapticFeedback.mediumImpact();
    if (schedule.id == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Schedule'),
        content: Text('Are you sure you want to delete "${schedule.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final success =
                    await _scheduleService.deleteSchedule(schedule.id!);
                if (success) {
                  _loadSchedules();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Schedule deleted'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                // Handle specific error messages (e.g. Hard Mode)
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
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Schedules',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, '/schedule-management-screen')
                      .then((_) => _loadSchedules());
                },
                child: Text('View All'),
              ),
            ],
          ),
          SizedBox(height: 12),
          _activeSchedules.isEmpty
              ? _buildEmptyState(theme)
              : ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _activeSchedules.length,
                  separatorBuilder: (context, index) => SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildScheduleCard(
                      context,
                      theme,
                      _activeSchedules[index],
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CustomIconWidget(
            iconName: 'schedule',
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16),
          Text(
            'No Active Schedules',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Create your first schedule to start blocking distracting apps',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(context, '/schedule-creator-screen')
                  .then((_) => _loadSchedules());
            },
            icon: CustomIconWidget(
              iconName: 'add',
              size: 20,
              color: theme.colorScheme.onPrimary,
            ),
            label: Text('Create Schedule'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(
    BuildContext context,
    ThemeData theme,
    Schedule schedule,
  ) {
    final now = TimeOfDay.now();
    final start = _parseTime(schedule.startTime);
    final end = _parseTime(schedule.endTime);

    final isRunning = _isScheduleRunning(start, end, now, schedule.daysOfWeek);
    final remainingMinutes = _calculateRemainingMinutes(end, now);
    final totalMinutes = _calculateDurationMinutes(start, end);
    final progress = totalMinutes > 0
        ? (totalMinutes - remainingMinutes) / totalMinutes
        : 0.0;

    final hours = remainingMinutes ~/ 60;
    final minutes = remainingMinutes % 60;

    return Slidable(
      key: ValueKey(schedule.id),
      enabled: !schedule.isStrictMode,
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _editSchedule(schedule),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (context) => _duplicateSchedule(schedule),
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: theme.colorScheme.onSecondary,
            icon: Icons.copy,
            label: 'Duplicate',
          ),
          SlidableAction(
            onPressed: (context) => _deleteSchedule(schedule),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _editSchedule(schedule);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  schedule.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (schedule.isStrictMode) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CustomIconWidget(
                                        iconName: 'lock',
                                        size: 12,
                                        color: theme.colorScheme.error,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Strict',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme.colorScheme.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${schedule.blockedApps.length} apps blocked',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: schedule.isActive,
                      onChanged: schedule.isStrictMode
                          ? null
                          : (value) => _toggleSchedule(schedule),
                    ),
                  ],
                ),
                if (schedule.isPaused) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pause_circle_outline,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Schedule Paused',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isRunning) ...[
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time Remaining',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              hours > 0
                                  ? '${hours}h ${minutes}m'
                                  : '${minutes}m',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              strokeWidth: 6,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              '${(progress * 100).clamp(0, 100).toInt()}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                    minHeight: 4,
                  ),
                ] else ...[
                  SizedBox(height: 12),
                  Text(
                    'Runs ${schedule.startTime} - ${schedule.endTime}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  bool _isScheduleRunning(
      TimeOfDay start, TimeOfDay end, TimeOfDay now, List<int> days) {
    final currentDay = DateTime.now().weekday % 7;
    if (!days.contains(currentDay)) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (endMinutes < startMinutes) {
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    } else {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
  }

  int _calculateRemainingMinutes(TimeOfDay end, TimeOfDay now) {
    final nowMinutes = now.hour * 60 + now.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (endMinutes < nowMinutes) {
      return (24 * 60 - nowMinutes) + endMinutes;
    }
    return endMinutes - nowMinutes;
  }

  int _calculateDurationMinutes(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (endMinutes < startMinutes) {
      return (24 * 60 - startMinutes) + endMinutes;
    }
    return endMinutes - startMinutes;
  }
}
