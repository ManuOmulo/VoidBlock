import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Recurring schedule options with pattern selection
class RecurringScheduleSection extends StatelessWidget {
  final String selectedPattern;
  final Function(String) onPatternChanged;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const RecurringScheduleSection({
    Key? key,
    required this.selectedPattern,
    required this.onPatternChanged,
    required this.isExpanded,
    required this.onToggleExpand,
  }) : super(key: key);

  static const List<Map<String, dynamic>> patterns = [
    {'value': 'daily', 'label': 'Daily', 'icon': 'today'},
    {'value': 'weekdays', 'label': 'Weekdays', 'icon': 'work'},
    {'value': 'weekends', 'label': 'Weekends', 'icon': 'weekend'},
    {'value': 'custom', 'label': 'Custom', 'icon': 'edit_calendar'},
  ];

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
                    iconName: 'repeat',
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      'Recurring Pattern',
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
                  Text(
                    'Select Pattern',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Wrap(
                    spacing: 2.w,
                    runSpacing: 1.h,
                    children: patterns.map((pattern) {
                      final isSelected = selectedPattern == pattern['value'];
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomIconWidget(
                              iconName: pattern['icon'] as String,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                              size: 16,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              pattern['label'] as String,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surface,
                        onSelected: (_) =>
                            onPatternChanged(pattern['value'] as String),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 2.h),
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'info',
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            _getPatternDescription(selectedPattern),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getPatternDescription(String pattern) {
    switch (pattern) {
      case 'daily':
        return 'Schedule will repeat every day';
      case 'weekdays':
        return 'Schedule will repeat Monday through Friday';
      case 'weekends':
        return 'Schedule will repeat Saturday and Sunday';
      case 'custom':
        return 'Schedule will repeat on selected days only';
      default:
        return '';
    }
  }
}
