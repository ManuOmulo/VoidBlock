import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklyBarChart extends StatelessWidget {
  /// Map of date (YYYY-MM-DD) to minutes of focus time
  final Map<String, dynamic> dailyStats;

  const WeeklyBarChart({
    super.key,
    required this.dailyStats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _getLast7Days();
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
                'Time Saved (7 Days)',
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
                  'Minutes Recovered',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
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
                maxY: maxMinutes * 1.2, // Add some headroom
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: theme.colorScheme.inverseSurface,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        _formatDuration(rod.toY.round()),
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
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value >= days.length)
                          return const SizedBox();
                        final index = value.toInt();
                        if (index < 0 || index >= days.length)
                          return const SizedBox();
                        final date = days[index];
                        // Show first letter of day name (e.g., M, T, W)
                        final dayName = DateFormat('E').format(date);
                        final isToday = _isSameDay(date, DateTime.now());

                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            dayName[0],
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight:
                                  isToday ? FontWeight.bold : FontWeight.w400,
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
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(days.length, (index) {
                  final date = days[index];
                  final dateKey = DateFormat('yyyy-MM-dd').format(date);
                  // Stats map might be { "date": duration } or list of maps.
                  // Assuming simplified map for now, or we process list in parent.
                  // For now, let's assume parent passes a map keyed by date string.
                  final minutes = (dailyStats[dateKey] ?? 0.0).toDouble();
                  final isToday = _isSameDay(date, DateTime.now());

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: minutes,
                        color: isToday
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.3),
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxMinutes * 1.2,
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                        ),
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

  List<DateTime> _getLast7Days() {
    final now = DateTime.now();
    // Calculate the most recent Sunday (start of current week)
    final sundayOffset = now.weekday % 7;
    final sunday = now.subtract(Duration(days: sundayOffset));

    return List.generate(7, (index) {
      return sunday.add(Duration(days: index));
    });
  }

  double _getMaxMinutes(List<DateTime> days) {
    double max = 0;
    for (var date in days) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      final val = (dailyStats[key] ?? 0.0).toDouble();
      if (val > max) max = val;
    }
    return max == 0 ? 60 : max; // Default to 60 if empty
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }
}
