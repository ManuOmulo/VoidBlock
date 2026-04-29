import 'package:flutter/material.dart';

class ScreenTimeComparisonCard extends StatelessWidget {
  final Map<String, dynamic> comparisonData;

  const ScreenTimeComparisonCard({
    super.key,
    required this.comparisonData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenTimeData = comparisonData['screenTime'] is Map
        ? Map<String, dynamic>.from(comparisonData['screenTime'] as Map)
        : null;

    if (screenTimeData == null || screenTimeData.isEmpty) {
      return _buildEmptyState(context);
    }

    final lastWeekAverage = screenTimeData['lastWeekAverage'] as int? ?? 0;
    final currentDayTotal = screenTimeData['currentDayTotal'] as int? ?? 0;
    final lastWeekSameDay = screenTimeData['lastWeekSameDay'] as int? ?? 0;
    final dayOverDayChange = screenTimeData['dayOverDayChange'] as double? ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Screen Time',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetricColumn(
                  context,
                  'Last Week Avg',
                  _formatDuration(lastWeekAverage),
                  null,
                  null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricColumn(
                  context,
                  'Today',
                  _formatDuration(currentDayTotal),
                  dayOverDayChange,
                  lastWeekSameDay,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(
    BuildContext context,
    String label,
    String value,
    double? percentageChange,
    int? previousValue,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 20,
          child: percentageChange != null && previousValue != null
              ? _buildChangeIndicator(context, percentageChange)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildChangeIndicator(BuildContext context, double percentageChange) {
    final theme = Theme.of(context);
    final isPositive = percentageChange > 0;
    final isNegative = percentageChange < 0;
    final isNeutral = percentageChange == 0;

    // For screen time, increase is bad (red), decrease is good (green)
    final color = isPositive
        ? Colors.red
        : isNegative
            ? Colors.green
            : Colors.grey;

    final icon = isPositive
        ? Icons.arrow_upward
        : isNegative
            ? Icons.arrow_downward
            : Icons.remove;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${isPositive ? '+' : ''}${percentageChange.toStringAsFixed(1)}%',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Screen Time',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No data available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
