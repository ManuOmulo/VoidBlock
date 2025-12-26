import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Time configuration section with time pickers and day selection
class TimeConfigurationSection extends StatelessWidget {
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final Set<int> selectedDays;
  final Function(TimeOfDay?) onStartTimeChanged;
  final Function(TimeOfDay?) onEndTimeChanged;
  final Function(int) onDayToggle;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const TimeConfigurationSection({
    Key? key,
    required this.startTime,
    required this.endTime,
    required this.selectedDays,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.onDayToggle,
    required this.isExpanded,
    required this.onToggleExpand,
  }) : super(key: key);

  static const List<String> dayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Not set';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleExpand,
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'schedule',
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      'Time Configuration',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CustomIconWidget(
                    iconName: isExpanded ? 'expand_less' : 'expand_more',
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: startTime ?? TimeOfDay.now(),
                            );
                            onStartTimeChanged(time);
                          },
                          child: Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CustomIconWidget(
                                      iconName: 'access_time',
                                      color: theme.colorScheme.primary,
                                      size: 16,
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Start Time',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  _formatTime(startTime),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: endTime ?? TimeOfDay.now(),
                            );
                            onEndTimeChanged(time);
                          },
                          child: Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CustomIconWidget(
                                      iconName: 'access_time',
                                      color: theme.colorScheme.primary,
                                      size: 16,
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'End Time',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  _formatTime(endTime),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Active Days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Wrap(
                    spacing: 2.w,
                    runSpacing: 1.h,
                    children: List.generate(7, (index) {
                      // Convert UI index (0=Mon) to Data index (1=Mon, ..., 6=Sat, 0=Sun)
                      final dataIndex = (index + 1) % 7;
                      final isSelected = selectedDays.contains(dataIndex);
                      return FilterChip(
                        label: Text(
                          dayNames[index],
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => onDayToggle(dataIndex),
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surface,
                        avatar: isSelected
                            ? CustomIconWidget(
                                iconName: 'check',
                                color: theme.colorScheme.onPrimary,
                                size: 16,
                              )
                            : null,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
