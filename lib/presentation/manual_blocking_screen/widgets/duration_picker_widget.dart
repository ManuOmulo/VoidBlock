import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Widget for duration selection with preset buttons and custom time picker
/// Provides platform-specific time selection experience
class DurationPickerWidget extends StatelessWidget {
  final int selectedMinutes;
  final Function(int) onDurationChanged;
  final VoidCallback onCustomTimePressed;

  const DurationPickerWidget({
    Key? key,
    required this.selectedMinutes,
    required this.onDurationChanged,
    required this.onCustomTimePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Duration',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 16),
        _buildPresetButtons(context, theme),
        SizedBox(height: 16),
        _buildCustomTimeButton(context, theme),
        SizedBox(height: 16),
        _buildSelectedDurationDisplay(context, theme),
      ],
    );
  }

  Widget _buildPresetButtons(BuildContext context, ThemeData theme) {
    final presets = [
      {'label': '15 min', 'minutes': 15},
      {'label': '30 min', 'minutes': 30},
      {'label': '1 hr', 'minutes': 60},
      {'label': '2 hr', 'minutes': 120},
      {'label': '4 hr', 'minutes': 240},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: presets.map((preset) {
        final minutes = preset['minutes'] as int;
        final isSelected = selectedMinutes == minutes;

        return InkWell(
          onTap: () => onDurationChanged(minutes),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              preset['label'] as String,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomTimeButton(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: onCustomTimePressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            CustomIconWidget(
              iconName: 'schedule',
              color: theme.colorScheme.primary,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Duration',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Set your own blocking time',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            CustomIconWidget(
              iconName: 'chevron_right',
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDurationDisplay(BuildContext context, ThemeData theme) {
    if (selectedMinutes == 0) {
      return SizedBox.shrink();
    }

    final hours = selectedMinutes ~/ 60;
    final minutes = selectedMinutes % 60;
    String durationText = '';

    if (hours > 0 && minutes > 0) {
      durationText = '$hours hr $minutes min';
    } else if (hours > 0) {
      durationText = '$hours hr';
    } else {
      durationText = '$minutes min';
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomIconWidget(
              iconName: 'timer',
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Duration',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  durationText,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
