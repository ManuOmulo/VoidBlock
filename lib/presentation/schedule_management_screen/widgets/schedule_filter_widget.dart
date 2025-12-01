import 'package:flutter/material.dart';

/// Filter options for schedule list
class ScheduleFilterWidget extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;

  const ScheduleFilterWidget({
    Key? key,
    required this.selectedFilter,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(context, theme, 'All', 'all'),
          SizedBox(width: 8),
          _buildFilterChip(context, theme, 'Active', 'active'),
          SizedBox(width: 8),
          _buildFilterChip(context, theme, 'Inactive', 'inactive'),
          SizedBox(width: 8),
          _buildFilterChip(context, theme, 'Strict Mode', 'strict'),
          SizedBox(width: 8),
          _buildFilterChip(context, theme, 'Today\'s Schedules', 'today'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    ThemeData theme,
    String label,
    String value,
  ) {
    final isSelected = selectedFilter == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onFilterChanged(value),
      backgroundColor: theme.colorScheme.surface,
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      checkmarkColor: theme.colorScheme.primary,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: 1,
        ),
      ),
    );
  }
}
