import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AppUsagePieChart extends StatelessWidget {
  /// List of apps with usage info { 'appName': String, 'usageMinutes': int, ... }
  final List<Map<String, dynamic>> appUsageData;

  const AppUsagePieChart({
    super.key,
    required this.appUsageData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMinutes = _calculateTotalMinutes();

    // Process data for the chart - take top 4 and group rest as "Other"
    final chartSections = _generateChartSections(theme);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top App Usage (7 Days)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Weekly Distribution',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 65,
                    sections: chartSections,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDuration(totalMinutes),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Total This Week',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Legend
          ..._buildLegendItems(theme),
        ],
      ),
    );
  }

  int _calculateTotalMinutes() {
    return appUsageData.fold(
        0, (sum, item) => sum + (item['usageMinutes'] as int? ?? 0));
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  List<PieChartSectionData> _generateChartSections(ThemeData theme) {
    if (appUsageData.isEmpty) {
      return [
        PieChartSectionData(
          color: theme.colorScheme.surfaceContainerHighest,
          value: 100,
          title: '',
          radius: 15,
        ),
      ];
    }

    final total = _calculateTotalMinutes().toDouble();
    if (total == 0) return [];

    // Define colors for the chart slices
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      Colors.orange,
      Colors.purple,
    ];

    return List.generate(appUsageData.length.clamp(0, 5), (index) {
      final item = appUsageData[index];
      final value = (item['usageMinutes'] as int? ?? 0).toDouble();
      final percentage = (value / total * 100);

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: value,
        title: '${percentage.round()}%',
        radius: 40,
        titleStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimary,
        ),
      );
    });
  }

  List<Widget> _buildLegendItems(ThemeData theme) {
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      Colors.orange,
      Colors.purple,
    ];

    return List.generate(appUsageData.length.clamp(0, 5), (index) {
      final item = appUsageData[index];
      final minutes = item['usageMinutes'] as int? ?? 0;
      final totalMinutes = _calculateTotalMinutes();
      final percentage =
          totalMinutes == 0 ? 0 : (minutes / totalMinutes * 100).round();

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item['appName'] ?? 'Unknown App',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatDuration(minutes),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percentage%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    });
  }
}
