import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductivityTrendChart extends StatelessWidget {
  /// Map of date (YYYY-MM-DD) to minutes
  final Map<String, dynamic> dailyStats;

  const ProductivityTrendChart({
    super.key,
    required this.dailyStats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _getLast14Days();
    final maxMinutes = _getMaxMinutes(days);

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
                'Focus Trend',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
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
                  'Bi-Weekly',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.5,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxMinutes * 1.1,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: theme.colorScheme.inverseSurface,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.round()}m',
                        TextStyle(
                          color: theme.colorScheme.onInverseSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 2, // Show every other day to save space
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value >= days.length)
                          return const SizedBox();
                        final index = value.toInt();
                        if (index < 0 || index >= days.length)
                          return const SizedBox();
                        final date = days[index];
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            date.day.toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(days.length, (index) {
                  final date = days[index];
                  final dateKey = DateFormat('yyyy-MM-dd').format(date);
                  final minutes = (dailyStats[dateKey] ?? 0.0).toDouble();

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: minutes,
                        color: theme
                            .colorScheme.secondary, // Different color for trend
                        width: 8,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DateTime> _getLast14Days() {
    final now = DateTime.now();
    return List.generate(14, (index) {
      return now.subtract(Duration(days: 13 - index));
    });
  }

  double _getMaxMinutes(List<DateTime> days) {
    double max = 0;
    for (var date in days) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      final val = (dailyStats[key] ?? 0.0).toDouble();
      if (val > max) max = val;
    }
    return max == 0 ? 60 : max;
  }
}
